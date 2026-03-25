"""
Face Recognition Attendance System - FastAPI Backend
Main application file with all endpoints and business logic
"""

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Request,  BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from typing import List, Dict, Optional
import base64
import io
import numpy as np
from PIL import Image
import cv2
import insightface
from insightface.app import FaceAnalysis
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import uuid
import asyncio
import traceback
import logging
import threading
import time as time_module
import requests

import config

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
ESP32_CAM_IP = "10.171.194.168"  # <--- UPDATE THIS TO YOUR ESPCAM IP

# Initialize FastAPI app
app = FastAPI(
    title="Face Recognition Attendance System",
    description="Backend API for student registration and attendance marking",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add request logging middleware
@app.middleware("http")
async def log_requests(request, call_next):
    logger.info(f"Incoming request: {request.method} {request.url}")
    logger.info(f"Client: {request.client}")
    response = await call_next(request)
    logger.info(f"Response status: {response.status_code}")
    return response

# Initialize Firebase Admin SDK
try:
    cred = credentials.Certificate(config.FIREBASE_CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    logger.info("Firebase Admin SDK initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize Firebase: {e}")
    raise

# Pydantic Models
class StudentRegistration(BaseModel):
    full_name: str = Field(..., min_length=1, max_length=100)
    roll_no: str = Field(..., min_length=1, max_length=50)
    batch: str = Field(..., min_length=1, max_length=20)
    faculty: str = Field(..., min_length=1, max_length=100)
    images: List[str] = Field(..., min_items=5, max_items=5)

class AttendanceSessionStart(BaseModel):
    batch: str = Field(..., min_length=1)
    faculty: str = Field(..., min_length=1)
    class_name: Optional[str] = None
    created_by: Optional[str] = None
    created_by_name: Optional[str] = None

# Global session storage
active_sessions: Dict[str, dict] = {}

# Initialize InsightFace model (ArcFace - 512-D embeddings, ~99.83% accuracy on LFW)
logger.info("Loading InsightFace ArcFace model...")
face_app = FaceAnalysis(
    name='buffalo_l',
    providers=['CPUExecutionProvider']
)
face_app.prepare(ctx_id=-1, det_size=(640, 640))
logger.info("InsightFace model loaded successfully")


# ─── Auto-Scheduler: watches Firestore schedules and auto-starts/stops webcam ───

class AutoScheduler:
    """
    Background scheduler that monitors Firestore schedules.
    When a scheduled class starts, it auto-opens the webcam and marks attendance.
    When the class ends, it stops the webcam and saves the session.
    """

    def __init__(self):
        self._running = False
        self._thread: Optional[threading.Thread] = None
        self._current_auto_session: Optional[dict] = None
        self._stop_webcam = threading.Event()
        self._processed_schedule_keys: set = set()  # track what we already started today
        self.enabled = True

    def start(self):
        if self._running:
            return
        self._running = True
        self._thread = threading.Thread(target=self._scheduler_loop, daemon=True)
        self._thread.start()
        logger.info("Auto-scheduler started")

    def stop(self):
        self._running = False
        self._stop_webcam.set()
        if self._thread:
            self._thread.join(timeout=5)
        logger.info("Auto-scheduler stopped")

    def _get_current_day_name(self) -> str:
        days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        return days[datetime.now().weekday()]

    def _scheduler_loop(self):
        """Main loop: checks every 30 seconds for matching schedules."""
        logger.info("Scheduler loop running...")
        last_date = None

        while self._running:
            try:
                now = datetime.now()
                today = now.date()
                current_day = self._get_current_day_name()
                current_time_str = now.strftime('%H:%M')

                # Reset processed keys at midnight
                if last_date != today:
                    self._processed_schedule_keys.clear()
                    last_date = today

                # Skip if an auto-session is already running
                if self._current_auto_session is not None:
                    time_module.sleep(30)
                    continue

                # Query Firestore for today's schedules
                schedules_ref = db.collection('schedules')
                schedules = schedules_ref.where('dayOfWeek', '==', current_day).stream()

                for sched_doc in schedules:
                    sched = sched_doc.to_dict()
                    start_time = sched.get('startTime')  # "HH:MM"
                    end_time = sched.get('endTime')
                    department = sched.get('department')
                    year = sched.get('year')
                    title = sched.get('title', 'N/A')

                    if not start_time or not end_time or not department:
                        continue

                    # Unique key to avoid re-starting same class today
                    sched_key = f"{today}_{sched_doc.id}"
                    if sched_key in self._processed_schedule_keys:
                        continue

                    # Check if current time is within the schedule window
                    if start_time <= current_time_str < end_time:
                        logger.info(
                            f"[AutoScheduler] Schedule match! "
                            f"{title} ({department} Year {year}) "
                            f"{start_time}-{end_time}"
                        )
                        self._processed_schedule_keys.add(sched_key)
                        self._run_auto_session(sched, sched_doc.id, end_time)
                        break  # only one session at a time

            except Exception as e:
                logger.error(f"[AutoScheduler] Error in scheduler loop: {e}")

            time_module.sleep(30)

    def _run_auto_session(self, schedule: dict, schedule_id: str, end_time: str):
        """Triggers ESP32-CAM at intervals, accumulates detections, applies threshold."""
        department = schedule.get('department')
        year = schedule.get('year')
        title = schedule.get('title', 'Auto Session')
        start_time = schedule.get('startTime', '')

        self._stop_webcam.clear()

        TOTAL_LOOPS = 4
        LOOP_INTERVAL_SECONDS = 30
        THRESHOLD = 2  # Must be detected in >= 2 out of 6 loops

        try:
            # Load students
            users_ref = db.collection('users')
            query = users_ref.where('role', '==', 'student') \
                            .where('department', '==', department) \
                            .where('year', '==', int(year))
            students_data = []
            for doc in query.stream():
                student = doc.to_dict()
                student['id'] = doc.id
                if student.get('embeddings') and len(student['embeddings']) == 2560:
                    students_data.append(student)

            if not students_data:
                logger.warning(f"[AutoScheduler] No students with embeddings for {department} Year {year}")
                return

            # --- Reuse or create session ---
            existing_sessions_query = db.collection(config.SESSIONS_COLLECTION) \
                .where('schedule_id', '==', schedule_id) \
                .where('department', '==', department) \
                .where('year', '==', int(year)) \
                .where('class_name', '==', title) \
                .limit(1) \
                .stream()

            existing_session = None
            for s_doc in existing_sessions_query:
                existing_session = s_doc
                break

            today_str = datetime.now().strftime('%Y-%m-%d')

            if existing_session:
                session_id = existing_session.id
                existing_data = existing_session.to_dict()
                attendance_dates = existing_data.get('attendance_dates', [])
                if today_str not in attendance_dates:
                    attendance_dates.append(today_str)
                db.collection(config.SESSIONS_COLLECTION).document(session_id).update({
                    'status': 'active',
                    'total_students': len(students_data),
                    'attendance_dates': attendance_dates,
                    'last_active': firestore.SERVER_TIMESTAMP,
                    'total_classes': len(attendance_dates),
                })
                logger.info(f"[AutoScheduler] Reusing session {session_id[:8]} for {title}")
            else:
                session_id = str(uuid.uuid4())
                session_doc = {
                    'session_id': session_id,
                    'year': int(year),
                    'department': department,
                    'class_name': title,
                    'total_students': len(students_data),
                    'created_at': firestore.SERVER_TIMESTAMP,
                    'status': 'active',
                    'created_by': 'auto_scheduler',
                    'created_by_name': f'Auto ({title})',
                    'schedule_id': schedule_id,
                    'attendance_dates': [today_str],
                    'total_classes': 1,
                    'last_active': firestore.SERVER_TIMESTAMP,
                }
                db.collection(config.SESSIONS_COLLECTION).document(session_id).set(session_doc)
                logger.info(f"[AutoScheduler] Created new session {session_id[:8]} for {title}")

            self._current_auto_session = {
                'session_id': session_id,
                'title': title,
                'end_time': end_time,
                'students': students_data,
                'marked_present': set(),
                'today_str': today_str,
            }

            # Register in active_sessions so /camera/pan_capture can find it
            active_sessions[session_id] = {
                'session_id': session_id,
                'batch': str(year),
                'faculty': department,
                'class_name': title,
                'students': students_data,
                'marked_present': set(),
                'start_time': datetime.now(),
                'webcam': None,
                # === NEW: Threshold-based tracking ===
                'detection_tracker': {},   # {student_id: {'name','roll_no','loops_detected': set()}}
                'current_loop': 0,
                'total_loops': TOTAL_LOOPS,
                'threshold': THRESHOLD,
                'loop_results': [],        # List of dicts, one per loop
            }

            logger.info(
                f"[AutoScheduler] Session {session_id[:8]} | "
                f"{len(students_data)} students | {TOTAL_LOOPS} loops | "
                f"{LOOP_INTERVAL_SECONDS}s interval | Threshold: {THRESHOLD}/{TOTAL_LOOPS}"
            )

            # =============================================
            # MAIN LOOP: Trigger ESP32-CAM 6 times
            # =============================================
            for loop_num in range(1, TOTAL_LOOPS + 1):
                if self._stop_webcam.is_set():
                    logger.info("[AutoScheduler] Stopped by signal")
                    break

                now_str = datetime.now().strftime('%H:%M')
                if now_str >= end_time:
                    logger.info(f"[AutoScheduler] End time {end_time} reached")
                    break

                # Set current loop number so /camera/pan_capture knows which loop this is
                active_sessions[session_id]['current_loop'] = loop_num

                logger.info(f"[AutoScheduler] ═══ LOOP {loop_num}/{TOTAL_LOOPS} ═══ Triggering ESP32-CAM...")

                try:
                    url = f"http://{ESP32_CAM_IP}/scan"
                    resp = requests.get(url, timeout=5.0)
                    logger.info(f"[AutoScheduler] ESP32-CAM triggered! Servo scanning...")
                except Exception as e:
                    logger.error(f"[AutoScheduler] Failed to reach ESP32-CAM: {e}")

                # Wait for interval (ESP32-CAM will POST photos to /camera/pan_capture during this time)
                if loop_num < TOTAL_LOOPS:
                    logger.info(f"[AutoScheduler] Waiting {LOOP_INTERVAL_SECONDS}s before next loop...")
                    sleep_elapsed = 0
                    while sleep_elapsed < LOOP_INTERVAL_SECONDS:
                        if self._stop_webcam.is_set() or datetime.now().strftime('%H:%M') >= end_time:
                            break
                        time_module.sleep(1)
                        sleep_elapsed += 1
                else:
                    # Last loop — wait 35 seconds for ESP32-CAM to finish and POST results
                    logger.info("[AutoScheduler] Last loop — waiting 35s for final photos...")
                    time_module.sleep(35)

            # =============================================
            # FINALIZATION: Apply threshold and mark attendance
            # =============================================
            logger.info(f"[AutoScheduler] ═══ ALL {TOTAL_LOOPS} LOOPS COMPLETE ═══")
            logger.info(f"[AutoScheduler] Applying threshold: {THRESHOLD}/{TOTAL_LOOPS}")

            session_data = active_sessions.get(session_id, {})
            tracker = session_data.get('detection_tracker', {})
            loop_results = session_data.get('loop_results', [])

            # Print per-loop summary
            for lr in loop_results:
                logger.info(
                    f"[AutoScheduler] Loop {lr['loop']}: "
                    f"{lr['faces_detected']} faces, "
                    f"{len(lr['students_found'])} students identified"
                )

            # Apply threshold
            marked_count = 0
            total_detected = len(tracker)

            for student_id, info in tracker.items():
                loops_detected = len(info['loops_detected'])
                passed = loops_detected >= THRESHOLD

                logger.info(
                    f"[AutoScheduler]   {info['roll_no']} - {info['name']}: "
                    f"detected in {loops_detected}/{TOTAL_LOOPS} loops → "
                    f"{'✅ PRESENT' if passed else '❌ NOT ENOUGH'}"
                )

                if passed:
                    # Mark attendance in Firestore
                    att_doc = {
                        'student_id': student_id,
                        'student_name': info['name'],
                        'roll_no': info['roll_no'],
                        'department': department,
                        'year': int(year),
                        'session_id': session_id,
                        'timestamp': firestore.SERVER_TIMESTAMP,
                        'marked_at': datetime.now().isoformat(),
                        'attendance_date': today_str,
                        'loops_detected': loops_detected,
                        'total_loops': TOTAL_LOOPS,
                        'threshold': THRESHOLD,
                        'detection_percentage': round((loops_detected / TOTAL_LOOPS) * 100, 1),
                    }
                    db.collection(config.ATTENDANCE_COLLECTION).add(att_doc)
                    marked_count += 1

            # Update session in Firestore
            total = len(students_data)
            pct = (marked_count / total * 100) if total > 0 else 0

            db.collection(config.SESSIONS_COLLECTION).document(session_id).update({
                'status': 'completed',
                'last_completed_at': firestore.SERVER_TIMESTAMP,
                'present_count_today': marked_count,
                'attendance_percentage_today': round(pct, 2),
                'total_detected_unique': total_detected,
                'threshold_used': f"{THRESHOLD}/{TOTAL_LOOPS}",
            })

            logger.info(
                f"[AutoScheduler] ═══ SESSION COMPLETE ═══\n"
                f"  Total students: {total}\n"
                f"  Unique faces detected: {total_detected}\n"
                f"  Passed threshold ({THRESHOLD}/{TOTAL_LOOPS}): {marked_count}\n"
                f"  Attendance: {pct:.1f}%"
            )

            # Cleanup
            if session_id in active_sessions:
                del active_sessions[session_id]

        except Exception as e:
            logger.error(f"[AutoScheduler] Error: {traceback.format_exc()}")
            if session_id in active_sessions:
                del active_sessions[session_id]
        finally:
            self._current_auto_session = None

# Create global scheduler instance
auto_scheduler = AutoScheduler()


@app.on_event("startup")
async def startup_event():
    """Start the auto-scheduler when the server starts."""
    auto_scheduler.start()
    logger.info("Auto-scheduler background task started on server startup")


@app.on_event("shutdown")
async def shutdown_event():
    """Stop the auto-scheduler on shutdown."""
    auto_scheduler.stop()


@app.get("/scheduler/status")
async def scheduler_status():
    """Get current auto-scheduler status."""
    session_info = None
    if auto_scheduler._current_auto_session:
        s = auto_scheduler._current_auto_session
        session_info = {
            'session_id': s['session_id'],
            'title': s['title'],
            'end_time': s['end_time'],
            'present_count': len(s['marked_present']),
            'total_students': len(s['students']),
        }
    return {
        'enabled': auto_scheduler.enabled,
        'running': auto_scheduler._running,
        'active_session': session_info,
    }


@app.post("/scheduler/toggle")
async def toggle_scheduler(enable: bool = True):
    """Enable or disable the auto-scheduler."""
    auto_scheduler.enabled = enable
    if enable and not auto_scheduler._running:
        auto_scheduler.start()
    elif not enable:
        auto_scheduler.stop()
    return {"enabled": enable, "message": f"Auto-scheduler {'enabled' if enable else 'disabled'}"}


# ─── End Auto-Scheduler ─────────────────────────────────────────────────────────


def decode_base64_image(base64_string: str) -> np.ndarray:
    """
    Decode base64 string to numpy array image
    """
    try:
        # Remove data URL prefix if present
        if "base64," in base64_string:
            base64_string = base64_string.split("base64,")[1]
        
        # Decode base64
        image_bytes = base64.b64decode(base64_string)
        
        # Convert to PIL Image
        image = Image.open(io.BytesIO(image_bytes))
        
        # Convert to RGB if needed
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Convert to numpy array
        image_array = np.array(image)
        
        return image_array
    except Exception as e:
        raise ValueError(f"Failed to decode image: {str(e)}")
   
def trigger_hardware_scan_loop(session_id: str):
    """
    Background task for manual sessions (Flutter app trigger).
    Triggers ESP32-CAM 6 times with 50-second intervals.
    After all loops, applies 4/6 threshold.
    """
    TOTAL_LOOPS = 3
    LOOP_INTERVAL_SECONDS = 50
    THRESHOLD = 1

    logger.info(f"[ManualTrigger] Starting {TOTAL_LOOPS} hardware scan loops for session {session_id}")

    # Initialize tracking in the session
    if session_id in active_sessions:
        active_sessions[session_id]['detection_tracker'] = {}
        active_sessions[session_id]['current_loop'] = 0
        active_sessions[session_id]['total_loops'] = TOTAL_LOOPS
        active_sessions[session_id]['threshold'] = THRESHOLD
        active_sessions[session_id]['loop_results'] = []

    for loop_num in range(1, TOTAL_LOOPS + 1):
        if session_id not in active_sessions:
            logger.info("[ManualTrigger] Session ended early. Stopping.")
            return

        active_sessions[session_id]['current_loop'] = loop_num

        logger.info(f"[ManualTrigger] ═══ LOOP {loop_num}/{TOTAL_LOOPS} ═══ Triggering ESP32-CAM...")
        try:
            url = f"http://{ESP32_CAM_IP}/scan"
            requests.get(url, timeout=5.0)
            logger.info(f"[ManualTrigger] ESP32-CAM triggered!")
        except Exception as e:
            logger.error(f"[ManualTrigger] Failed to trigger ESP32-CAM: {e}")

        if loop_num < TOTAL_LOOPS:
            logger.info(f"[ManualTrigger] Waiting {LOOP_INTERVAL_SECONDS}s...")
            time_module.sleep(LOOP_INTERVAL_SECONDS)
        else:
            logger.info("[ManualTrigger] Last loop — waiting 35s for photos...")
            time_module.sleep(35)

    # === FINALIZATION ===
    if session_id not in active_sessions:
        return

    session = active_sessions[session_id]
    tracker = session.get('detection_tracker', {})

    logger.info(f"[ManualTrigger] ═══ APPLYING THRESHOLD {THRESHOLD}/{TOTAL_LOOPS} ═══")

    marked_count = 0
    for student_id, info in tracker.items():
        loops_detected = len(info['loops_detected'])
        passed = loops_detected >= THRESHOLD

        logger.info(
            f"  {info['roll_no']} - {info['name']}: "
            f"{loops_detected}/{TOTAL_LOOPS} → {'✅ PRESENT' if passed else '❌ BELOW THRESHOLD'}"
        )

        if passed:
            db.collection(config.ATTENDANCE_COLLECTION).add({
                'student_id': student_id,
                'student_name': info['name'],
                'roll_no': info['roll_no'],
                'department': session.get('faculty', ''),
                'year': int(session.get('batch', 1)),
                'session_id': session_id,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'marked_at': datetime.now().isoformat(),
                'loops_detected': loops_detected,
                'total_loops': TOTAL_LOOPS,
                'threshold': THRESHOLD,
            })
            session['marked_present'].add(student_id)
            marked_count += 1

    total = len(session.get('students', []))
    pct = (marked_count / total * 100) if total > 0 else 0

    db.collection(config.SESSIONS_COLLECTION).document(session_id).update({
        'status': 'completed',
        'end_time': firestore.SERVER_TIMESTAMP,
        'present_count': marked_count,
        'attendance_percentage': round(pct, 2),
        'threshold_used': f"{THRESHOLD}/{TOTAL_LOOPS}",
    })

    logger.info(f"[ManualTrigger] ═══ DONE: {marked_count}/{total} present ({pct:.1f}%) ═══")

def generate_face_embedding(image_array: np.ndarray, image_number: int) -> List[float]:
    """
    Generate face embedding from image array using InsightFace (ArcFace).
    Returns 512-dimensional embedding as list.
    """
    try:
        # InsightFace expects BGR format
        if len(image_array.shape) == 3 and image_array.shape[2] == 3:
            bgr_image = cv2.cvtColor(image_array, cv2.COLOR_RGB2BGR)
        else:
            bgr_image = image_array

        
        # Detect and analyze faces
        faces = face_app.get(bgr_image)
        
        if len(faces) == 0:
            raise ValueError(f"No face detected in image {image_number}")
        
        if len(faces) > 1:
            raise ValueError(f"Multiple faces detected in image {image_number}. Please ensure only one face is visible.")
        
        # Get 512-D embedding from ArcFace
        embedding = faces[0].embedding
        
        if embedding is None:
            raise ValueError(f"Failed to generate embedding for image {image_number}")
        
        # Normalize embedding
        norm = np.linalg.norm(embedding)
        if norm > 0:
            embedding = embedding / norm
        
        return embedding.tolist()
    except ValueError:
        raise
    except Exception as e:
        raise ValueError(f"Error processing image {image_number}: {str(e)}")


@app.get("/")
async def root():
    """
    Root endpoint - API health check
    """
    return {
        "status": "running",
        "service": "Face Recognition Attendance System",
        "version": "1.0.0",
        "endpoints": {
            "register": "/register_student",
            "start_attendance": "/start_attendance",
            "websocket": "/ws/attendance/{session_id}",
            "stop_attendance": "/stop_attendance/{session_id}"
        }
    }


@app.post("/register_student")
async def register_student(registration: StudentRegistration):
    """
    Register a new student by processing 5 face images and generating embeddings.
    
    Returns:
        - success: True if all embeddings generated successfully
        - embeddings: List of 5 embeddings (each is 512 floats from ArcFace)
        - student_info: Echo of student information
        - errors: List of any errors encountered
    """
    try:
        logger.info(f"Starting registration for student: {registration.roll_no}")
        
        embeddings = []
        errors = []
        
        # Process each of the 5 images
        for i, base64_image in enumerate(registration.images, start=1):
            try:
                # Decode image
                image_array = decode_base64_image(base64_image)
                
                # Generate embedding
                embedding = generate_face_embedding(image_array, i)
                embeddings.append(embedding)
                
                logger.info(f"Successfully processed image {i} for {registration.roll_no}")
                
            except ValueError as e:
                error_msg = str(e)
                errors.append(error_msg)
                logger.error(f"Error processing image {i}: {error_msg}")
            except Exception as e:
                error_msg = f"Unexpected error in image {i}: {str(e)}"
                errors.append(error_msg)
                logger.error(error_msg)
        
        # Check if we got all 5 embeddings
        if len(embeddings) != 5:
            return {
                "success": False,
                "embeddings": embeddings,
                "errors": errors,
                "message": f"Failed to process all images. Got {len(embeddings)}/5 embeddings."
            }
        
        # All embeddings generated successfully
        logger.info(f"Successfully generated all 5 embeddings for {registration.roll_no}")
        
        # --- Duplicate face detection ---
        # Check if this face is already registered by comparing against all existing students
        logger.info("Checking for duplicate face registrations...")
        
        # Average the 5 new embeddings into one for comparison
        new_avg = np.mean(np.array(embeddings), axis=0)
        norm = np.linalg.norm(new_avg)
        if norm > 0:
            new_avg = new_avg / norm
        
        # Query all students who have embeddings
        all_users = db.collection('users').where('role', '==', 'student').stream()
        
        for user_doc in all_users:
            user_data = user_doc.to_dict()
            stored_embeddings_flat = user_data.get('embeddings', [])
            
            # Skip students without proper embeddings
            if not stored_embeddings_flat or len(stored_embeddings_flat) != 2560:
                continue
            
            # Average the stored 5 embeddings
            stored_embeddings = [stored_embeddings_flat[i:i+512] for i in range(0, 2560, 512)]
            stored_avg = np.mean(np.array(stored_embeddings), axis=0)
            s_norm = np.linalg.norm(stored_avg)
            if s_norm > 0:
                stored_avg = stored_avg / s_norm
            
            # Cosine similarity
            similarity = float(np.dot(new_avg, stored_avg))
            
            if similarity > config.FACE_RECOGNITION_TOLERANCE:
                existing_name = user_data.get('fullName', 'Unknown')
                existing_roll = user_data.get('rollNo', 'N/A')
                logger.warning(
                    f"Duplicate face detected! New: {registration.roll_no} matches existing: "
                    f"{existing_roll} ({existing_name}) with similarity {similarity:.4f}"
                )
                return {
                    "success": False,
                    "embeddings": [],
                    "errors": [f"This face is already registered under {existing_name} (Roll: {existing_roll})"],
                    "message": f"Duplicate face detected! Already registered as {existing_name} (Roll: {existing_roll}). "
                               f"Match confidence: {similarity:.0%}"
                }
        
        logger.info(f"No duplicate faces found for {registration.roll_no}")
        # --- End duplicate check ---
        
        return {
            "success": True,
            "embeddings": embeddings,
            "student_info": {
                "full_name": registration.full_name,
                "roll_no": registration.roll_no,
                "batch": registration.batch,
                "faculty": registration.faculty
            },
            "errors": [],
            "message": "All face embeddings generated successfully"
        }
        
    except Exception as e:
        logger.error(f"Registration error: {traceback.format_exc()}")
        raise HTTPException(
            status_code=500,
            detail=f"Internal server error during registration: {str(e)}"
        )


@app.post("/start_attendance")
async def start_attendance(session_data: AttendanceSessionStart , background_tasks: BackgroundTasks):
    """
    Start an attendance session for a specific batch and faculty.
    Loads all student data from Firestore into memory for fast comparison.
    
    Returns:
        - session_id: Unique identifier for this session
        - total_students: Number of students loaded
        - students: List of student info
    """
    try:
        logger.info(f"Starting attendance session for {session_data.batch} - {session_data.faculty}")
        
        # Query Firestore for students from the 'users' collection
        users_ref = db.collection('users')
        
        # Query for students with matching department and year, and role = student
        query = users_ref.where('role', '==', 'student') \
                        .where('department', '==', session_data.faculty) \
                        .where('year', '==', int(session_data.batch))
        
        students_docs = query.stream()
        
        # Load student data
        students_data = []
        for doc in students_docs:
            student = doc.to_dict()
            student['id'] = doc.id
            
            # Validate student has embeddings
            if 'embeddings' not in student or not student.get('embeddings'):
                logger.warning(f"Student {doc.id} ({student.get('fullName', 'Unknown')}) has no embeddings, skipping")
                continue
            
            students_data.append(student)
        
        if len(students_data) == 0:
            raise HTTPException(
                status_code=404,
                detail=f"No students found for year {session_data.batch} and department {session_data.faculty}"
            )
        
        # Create session
        session_id = str(uuid.uuid4())
        
        # Store session data
        active_sessions[session_id] = {
            'session_id': session_id,
            'batch': session_data.batch,
            'faculty': session_data.faculty,
            'class_name': session_data.class_name,
            'students': students_data,
            'marked_present': set(),
            'start_time': datetime.now(),
            'webcam': None
        }
        
        # Save session to Firestore
        session_doc = {
            'session_id': session_id,
            'year': int(session_data.batch),  # Academic year (1-4)
            'department': session_data.faculty,
            'class_name': session_data.class_name or 'N/A',
            'total_students': len(students_data),
            'created_at': firestore.SERVER_TIMESTAMP,
            'status': 'active',
            'created_by': session_data.created_by,
            'created_by_name': session_data.created_by_name or 'Unknown'
        }
        db.collection(config.SESSIONS_COLLECTION).document(session_id).set(session_doc)
        
        logger.info(f"Session {session_id} created with {len(students_data)} students")
        
        background_tasks.add_task(trigger_hardware_scan_loop, session_id)

        return {
            "success": True,
            "session_id": session_id,
            "total_students": len(students_data),
            "batch": session_data.batch,
            "faculty": session_data.faculty,
            "message": "Attendance session started successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error starting attendance: {traceback.format_exc()}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to start attendance session: {str(e)}"
        )
@app.post("/camera/pan_capture")
async def receive_pan_capture(request: Request):
    """
    Receives 4 photos from ESP32-CAM pan scan.
    Tracks which students are detected in which loop.
    Does NOT mark attendance — that happens after all 6 loops complete.
    """
    try:
        form = await request.form()
        room_id = form.get("room_id", "unknown")
        num_photos = int(form.get("num_photos", 0))

        logger.info(f"{'='*55}")
        logger.info(f"📷 RECEIVED {num_photos} PHOTOS FROM ESP32-CAM ({room_id})")
        logger.info(f"{'='*55}")

        if not active_sessions:
            logger.warning("No active session — ignoring photos")
            return {"success": False, "message": "No active session"}

        # Get the current active session
        session_id = list(active_sessions.keys())[-1]
        session = active_sessions[session_id]
        current_loop = session.get('current_loop', 1)
        tracker = session.get('detection_tracker', {})

        logger.info(f"Processing for Loop {current_loop}/{session.get('total_loops', 6)}")

        # This loop's results
        loop_faces_detected = 0
        loop_students_found = []

        for i in range(num_photos):
            photo_b64 = form.get(f"photo_{i}")
            if not photo_b64:
                continue

            # Decode image
            img_array = decode_base64_image(photo_b64)
            bgr_frame = cv2.cvtColor(img_array, cv2.COLOR_RGB2BGR)

            

            # Detect faces with InsightFace
            faces = face_app.get(bgr_frame)
            loop_faces_detected += len(faces)
            logger.info(f"  Photo {i+1}/{num_photos}: {len(faces)} faces detected")

            # Match each face against registered students
            for face in faces:
                emb = face.embedding
                norm = np.linalg.norm(emb)
                if norm > 0:
                    emb = emb / norm

                best_match = None
                best_score = 0

                for student in session.get('students', []):
                    stored_flat = student.get('embeddings', [])
                    if len(stored_flat) != 2560:
                        continue

                    stored_embs = [stored_flat[j:j+512] for j in range(0, 2560, 512)]
                    sims = []
                    for stored_embedding in stored_embs:
                        stored_np = np.array(stored_embedding)
                        n = np.linalg.norm(stored_np)
                        if n > 0:
                            stored_np = stored_np / n
                        sims.append(float(np.dot(emb, stored_np)))

                    avg_sim = sum(sorted(sims, reverse=True)[:3]) / 3

                    if avg_sim > config.FACE_RECOGNITION_TOLERANCE and avg_sim > best_score:
                        best_score = avg_sim
                        best_match = student

                if best_match:
                    student_id = best_match['id']
                    student_name = best_match.get('fullName', 'Unknown')
                    student_roll = best_match.get('rollNo', 'N/A')

                    # Add to tracker (accumulate across loops)
                    if student_id not in tracker:
                        tracker[student_id] = {
                            'name': student_name,
                            'roll_no': student_roll,
                            'loops_detected': set(),
                        }

                    # Record that this student was seen in this loop
                    tracker[student_id]['loops_detected'].add(current_loop)
                    loop_students_found.append(student_roll)

                    logger.info(
                        f"  👤 {student_roll} - {student_name} "
                        f"(now seen in {len(tracker[student_id]['loops_detected'])} loops)"
                    )

        # Save this loop's summary
        loop_summary = {
            'loop': current_loop,
            'faces_detected': loop_faces_detected,
            'students_found': list(set(loop_students_found)),
        }
        session.get('loop_results', []).append(loop_summary)

        # Update tracker back into session
        session['detection_tracker'] = tracker

        # Send WebSocket update to Flutter if connected
        ws = session.get('websocket')
        if ws:
            try:
                await ws.send_json({
                    "type": "status",
                    "message": f"Loop {current_loop}/{session.get('total_loops', 6)} complete",
                    "loop": current_loop,
                    "faces_detected": loop_faces_detected,
                    "unique_students_so_far": len(tracker),
                })
            except Exception:
                pass

        logger.info(
            f"Loop {current_loop} summary: "
            f"{loop_faces_detected} faces, "
            f"{len(set(loop_students_found))} students identified, "
            f"{len(tracker)} unique students total so far"
        )

        return {
            "success": True,
            "loop": current_loop,
            "photos_processed": num_photos,
            "faces_detected": loop_faces_detected,
            "students_found_this_loop": len(set(loop_students_found)),
            "unique_students_total": len(tracker),
        }

    except Exception as e:
        logger.error(f"Error in pan_capture: {traceback.format_exc()}")
        return {"success": False, "error": str(e)}
    
@app.websocket("/ws/attendance/{session_id}")
async def websocket_attendance(websocket: WebSocket, session_id: str):
    """
    WebSocket endpoint for real-time attendance marking.
    Captures webcam video, detects faces, and marks attendance.
    """
    await websocket.accept()
    
    try:
        # Validate session exists
        if session_id not in active_sessions:
            await websocket.send_json({
                "type": "error",
                "message": f"Session {session_id} not found or expired"
            })
            await websocket.close()
            return
        
        session = active_sessions[session_id]
        logger.info(f"WebSocket connected for session {session_id}")
        
        # Send initial status
        logger.info("Sending session_started message...")
        await websocket.send_json({
            "type": "session_started",
            "session_id": session_id,
            "total_students": len(session['students']),
            "message": "Initializing webcam..."
        })
        logger.info("Session_started message sent")
        
        # Initialize webcam
        logger.info(f"Attempting to open webcam at index {config.WEBCAM_INDEX}...")
        cap = cv2.VideoCapture(config.WEBCAM_INDEX)
        logger.info(f"VideoCapture object created: {cap}")
        
        if not cap.isOpened():
            logger.error("Failed to open webcam - cap.isOpened() returned False")
            await websocket.send_json({
                "type": "error",
                "message": "Failed to open webcam. Please check webcam connection and permissions."
            })
            await websocket.close()
            return
        
        logger.info("Webcam opened successfully")
        
        # Set webcam properties
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, config.WEBCAM_WIDTH)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, config.WEBCAM_HEIGHT)
        cap.set(cv2.CAP_PROP_FPS, config.WEBCAM_FPS)
        
        logger.info(f"Webcam properties set: {config.WEBCAM_WIDTH}x{config.WEBCAM_HEIGHT} @ {config.WEBCAM_FPS}fps")
        
        session['webcam'] = cap
        
        await websocket.send_json({
            "type": "webcam_ready",
            "message": "Webcam initialized. Starting face recognition..."
        })
        
        logger.info("Webcam_ready message sent. Starting main processing loop...")
        
        frame_count = 0
        
        # Main processing loop
        while True:
            # Check for client messages (e.g., stop command)
            try:
                # Non-blocking receive with timeout
                message = await asyncio.wait_for(websocket.receive_text(), timeout=0.01)
                data = eval(message) if isinstance(message, str) else message
                
                if data.get('command') == 'stop':
                    logger.info(f"Stop command received for session {session_id}")
                    break
            except asyncio.TimeoutError:
                pass  # No message, continue processing
            except WebSocketDisconnect:
                logger.info(f"WebSocket disconnected for session {session_id}")
                break
            
            # Read frame from webcam
            ret, frame = cap.read()
            
            if not ret:
                await websocket.send_json({
                    "type": "error",
                    "message": "Failed to read frame from webcam"
                })
                break
            
            frame_count += 1
            
            # Skip frames for performance
            if frame_count % config.FRAME_SKIP != 0:
                await asyncio.sleep(0.01)  # Small delay to prevent CPU overload
                continue
            
            # Log every 30 frames (10 processed frames)
            if frame_count % (config.FRAME_SKIP * 10) == 0:
                logger.info(f"Processing frame {frame_count}...")
            
            # Convert BGR to RGB for display, but InsightFace uses BGR
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # Detect faces using InsightFace
            faces = face_app.get(frame)  # InsightFace expects BGR
            
            # Convert InsightFace results to face_locations format for drawing
            face_locations = []
            face_encodings = []
            for face in faces:
                bbox = face.bbox.astype(int)
                # InsightFace bbox: [x1, y1, x2, y2] → we need (top, right, bottom, left)
                top, right, bottom, left = bbox[1], bbox[2], bbox[3], bbox[0]
                face_locations.append((top, right, bottom, left))
                
                # Get normalized embedding
                emb = face.embedding
                norm = np.linalg.norm(emb)
                if norm > 0:
                    emb = emb / norm
                face_encodings.append(emb)
            
            if len(face_locations) > 0:
                logger.info(f"Detected {len(face_locations)} face(s) in frame {frame_count}")
            
            # Create a copy of frame for display
            display_frame = frame.copy()
            
            if len(face_locations) == 0:
                # Draw "Scanning for faces..." text on display
                cv2.putText(display_frame, "Scanning for faces...", (10, 30), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                cv2.putText(display_frame, f"Present: {len(session['marked_present'])}/{len(session['students'])}", 
                           (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
                
                # Show the frame
                cv2.imshow('Attendance System - Face Recognition (ArcFace)', display_frame)
                cv2.waitKey(1)
                
                # Send heartbeat if no faces detected
                if frame_count % (config.FRAME_SKIP * 10) == 0:
                    await websocket.send_json({
                        "type": "status",
                        "message": "Scanning for faces...",
                        "present_count": len(session['marked_present'])
                    })
                await asyncio.sleep(0.01)
                continue
            
            # Generate embeddings for detected faces → already done above
            # face_encodings are already populated from InsightFace
            
            # Track recognized students in this frame
            recognized_in_frame = {}
            
            # Compare with all registered students using cosine similarity
            for idx, face_encoding in enumerate(face_encodings):
                best_match = None
                best_match_score = 0
                
                for student in session['students']:
                    # Get student's stored embeddings (flat list of 2560 values = 5 images x 512 dims)
                    stored_embeddings_flat = student.get('embeddings', [])
                    
                    if not stored_embeddings_flat or len(stored_embeddings_flat) != 2560:
                        continue
                    
                    # Split flat list into 5 separate embeddings (5 x 512)
                    stored_embeddings = [stored_embeddings_flat[i:i+512] for i in range(0, 2560, 512)]
                    
                    # Compare against all 5 embeddings using cosine similarity
                    similarities = []
                    for stored_embedding in stored_embeddings:
                        stored_np = np.array(stored_embedding)
                        # Normalize stored embedding
                        norm = np.linalg.norm(stored_np)
                        if norm > 0:
                            stored_np = stored_np / norm
                        
                        # Cosine similarity
                        similarity = float(np.dot(face_encoding, stored_np))
                        similarities.append(similarity)
                    
                    # Average of top 3 similarities
                    top_similarities = sorted(similarities, reverse=True)[:3]
                    avg_similarity = sum(top_similarities) / len(top_similarities)
                    
                    # Threshold: 0.4 for ArcFace (higher = stricter)
                    if avg_similarity > config.FACE_RECOGNITION_TOLERANCE and avg_similarity > best_match_score:
                        best_match_score = avg_similarity
                        best_match = student
                
                # Store the recognition result for this face
                if best_match:
                    recognized_in_frame[idx] = {
                        'student': best_match,
                        'score': best_match_score,
                        'already_marked': best_match['id'] in session['marked_present']
                    }
                else:
                    recognized_in_frame[idx] = None
            
            # Draw boxes and labels on display frame
            for idx, (top, right, bottom, left) in enumerate(face_locations):
                recognition_result = recognized_in_frame.get(idx)
                
                if recognition_result and recognition_result['student']:
                    student = recognition_result['student']
                    already_marked = recognition_result['already_marked']
                    score = recognition_result.get('score', 0)
                    
                    # Green box for recognized student
                    color = (0, 255, 0) if not already_marked else (0, 200, 0)
                    cv2.rectangle(display_frame, (left, top), (right, bottom), color, 2)
                    
                    # Student info background
                    cv2.rectangle(display_frame, (left, bottom - 35), (right, bottom), color, cv2.FILLED)
                    
                    # Student name and roll number
                    name = student.get('fullName', 'Unknown')
                    roll = student.get('rollNo', 'N/A')
                    label = f"{name[:20]}"  # Truncate long names
                    status = " (PRESENT)" if already_marked else f" ({score:.0%})"
                    
                    cv2.putText(display_frame, label + status, (left + 6, bottom - 18), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
                    cv2.putText(display_frame, f"Roll: {roll}", (left + 6, bottom - 6), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 255), 1)
                    
                    # Mark attendance if not already marked
                    if not already_marked:
                        # Mark attendance in Firestore
                        attendance_doc = {
                            'student_id': student['id'],
                            'student_name': student.get('fullName', 'Unknown'),
                            'roll_no': student.get('rollNo', 'N/A'),
                            'department': student.get('department', session['faculty']),
                            'year': student.get('year', session['batch']),
                            'session_id': session_id,
                            'timestamp': firestore.SERVER_TIMESTAMP,
                            'marked_at': datetime.now().isoformat()
                        }
                        
                        db.collection(config.ATTENDANCE_COLLECTION).add(attendance_doc)
                        
                        # Add to marked present set
                        session['marked_present'].add(student['id'])
                        
                        # Send real-time update to Flutter
                        await websocket.send_json({
                            "type": "attendance_marked",
                            "student_id": student['id'],
                            "name": student.get('fullName', 'Unknown'),
                            "roll_no": student.get('rollNo', 'N/A'),
                            "timestamp": datetime.now().isoformat(),
                            "present_count": len(session['marked_present']),
                            "total_students": len(session['students'])
                        })
                        
                        logger.info(f"Marked present: {roll} - {name}")
                else:
                    # Red box for unknown face
                    cv2.rectangle(display_frame, (left, top), (right, bottom), (0, 0, 255), 2)
                    
                    # Unknown label background
                    cv2.rectangle(display_frame, (left, bottom - 25), (right, bottom), (0, 0, 255), cv2.FILLED)
                    cv2.putText(display_frame, "UNKNOWN", (left + 6, bottom - 8), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
            
            # Display statistics
            cv2.putText(display_frame, f"Present: {len(session['marked_present'])}/{len(session['students'])}", 
                       (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            cv2.putText(display_frame, f"Faces Detected: {len(face_locations)}", 
                       (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
            
            # Show the frame
            cv2.imshow('Attendance System - Face Recognition (ArcFace)', display_frame)
            
            # Check for 'q' key to quit (for manual stop)
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                logger.info("Manual stop (Q key pressed)")
                break
            
            # Small delay to prevent overwhelming the connection
            await asyncio.sleep(0.05)
        
    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected for session {session_id}")
    except Exception as e:
        logger.error(f"WebSocket error: {traceback.format_exc()}")
        try:
            await websocket.send_json({
                "type": "error",
                "message": f"Error during attendance marking: {str(e)}"
            })
        except:
            pass
    finally:
        # Cleanup
        cv2.destroyAllWindows()  # Close the webcam window
        
        if session_id in active_sessions:
            if active_sessions[session_id]['webcam'] is not None:
                active_sessions[session_id]['webcam'].release()
                logger.info(f"Webcam released for session {session_id}")
        
        try:
            await websocket.close()
        except:
            pass


@app.post("/stop_attendance/{session_id}")
async def stop_attendance(session_id: str):
    """
    Stop an attendance session and return final statistics.
    """
    try:
        if session_id not in active_sessions:
            raise HTTPException(
                status_code=404,
                detail=f"Session {session_id} not found"
            )
        
        session = active_sessions[session_id]
        
        # Release webcam if still active
        if session['webcam'] is not None:
            session['webcam'].release()
        
        total_students = len(session['students'])
        present_count = len(session['marked_present'])
        attendance_percentage = (present_count / total_students * 100) if total_students > 0 else 0
        
        # Get absent students
        absent_students = []
        for student in session['students']:
            if student['id'] not in session['marked_present']:
                absent_students.append({
                    'id': student['id'],
                    'name': student.get('fullName', 'Unknown'),
                    'roll_no': student.get('rollNo', 'N/A')
                })
        
        # Update session in Firestore
        db.collection(config.SESSIONS_COLLECTION).document(session_id).update({
            'status': 'completed',
            'end_time': firestore.SERVER_TIMESTAMP,
            'present_count': present_count,
            'attendance_percentage': attendance_percentage
        })
        
        # Remove from active sessions
        del active_sessions[session_id]
        
        logger.info(f"Session {session_id} stopped. Attendance: {present_count}/{total_students} ({attendance_percentage:.2f}%)")
        
        return {
            "success": True,
            "session_id": session_id,
            "total_students": total_students,
            "present_count": present_count,
            "absent_count": len(absent_students),
            "attendance_percentage": round(attendance_percentage, 2),
            "absent_students": absent_students,
            "message": "Attendance session completed successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error stopping attendance: {traceback.format_exc()}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to stop attendance session: {str(e)}"
        )


@app.get("/session/{session_id}/status")
async def get_session_status(session_id: str):
    """
    Get current status of an active attendance session.
    """
    try:
        if session_id not in active_sessions:
            raise HTTPException(
                status_code=404,
                detail=f"Session {session_id} not found or has ended"
            )
        
        session = active_sessions[session_id]
        
        return {
            "session_id": session_id,
            "batch": session['batch'],
            "faculty": session['faculty'],
            "total_students": len(session['students']),
            "present_count": len(session['marked_present']),
            "attendance_percentage": round(len(session['marked_present']) / len(session['students']) * 100, 2) if len(session['students']) > 0 else 0,
            "start_time": session['start_time'].isoformat(),
            "status": "active"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error retrieving session status: {str(e)}"
        )


@app.get("/attendance/sessions")
async def get_attendance_sessions(department: str, year: Optional[int] = None, subject: Optional[str] = None):
    """
    Get all attendance sessions for a department with optional filters.
    """
    try:
        query = db.collection('attendance_sessions').where('department', '==', department)
        
        if year is not None:
            query = query.where('year', '==', year)
        
        if subject:
            query = query.where('class_name', '==', subject)
        
        sessions_docs = query.stream()
        
        sessions_list = []
        for doc in sessions_docs:
            session_data = doc.to_dict()
            session_data['session_id'] = doc.id
            
            # Convert Firestore timestamp to ISO string for JSON serialization
            if 'created_at' in session_data and session_data['created_at']:
                try:
                    session_data['created_at'] = session_data['created_at'].isoformat()
                except:
                    session_data['created_at'] = str(session_data['created_at'])
            
            sessions_list.append(session_data)
        
        # Sort by created_at (newest first) - handle cases where created_at might be missing
        def get_sort_key(session):
            created_at = session.get('created_at')
            if created_at is None:
                return ''
            return created_at
        
        sessions_list.sort(key=get_sort_key, reverse=True)
        
        return {
            "success": True,
            "sessions": sessions_list,
            "count": len(sessions_list)
        }
        
    except Exception as e:
        logger.error(f"Error fetching sessions: {traceback.format_exc()}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch sessions: {str(e)}"
        )


@app.get("/attendance/session/{session_id}/details")
async def get_session_details(session_id: str):
    """
    Get detailed attendance information for a specific session.
    """
    try:
        # Get session info
        session_doc = db.collection('attendance_sessions').document(session_id).get()
        
        if not session_doc.exists:
            raise HTTPException(status_code=404, detail="Session not found")
        
        session_data = session_doc.to_dict()
        
        # Convert timestamps to ISO strings
        if 'created_at' in session_data and session_data['created_at']:
            try:
                session_data['created_at'] = session_data['created_at'].isoformat()
            except:
                session_data['created_at'] = str(session_data['created_at'])
        
        # Get attendance records
        attendance_docs = db.collection('attendance').where('session_id', '==', session_id).stream()
        
        present_students = []
        present_student_ids = set()
        
        for doc in attendance_docs:
            att_data = doc.to_dict()
            
            # Convert marked_at timestamp
            marked_at = att_data.get('marked_at')
            if marked_at:
                try:
                    marked_at = marked_at.isoformat()
                except:
                    marked_at = str(marked_at)
            
            present_students.append({
                'id': att_data.get('student_id'),
                'name': att_data.get('student_name'),
                'roll_no': att_data.get('roll_no', 'N/A'),
                'marked_at': marked_at
            })
            present_student_ids.add(att_data.get('student_id'))
        
        # Get all students for this year/department
        all_students_query = db.collection('users')\
            .where('role', '==', 'student')\
            .where('department', '==', session_data['department'])\
            .where('year', '==', session_data['year'])
        
        all_students_docs = all_students_query.stream()
        
        absent_students = []
        total_students = 0
        
        for doc in all_students_docs:
            total_students += 1
            if doc.id not in present_student_ids:
                student_data = doc.to_dict()
                absent_students.append({
                    'id': doc.id,
                    'name': student_data.get('fullName', 'Unknown'),
                    'roll_no': student_data.get('rollNo', 'N/A')
                })
        
        attendance_percentage = (len(present_students) / total_students * 100) if total_students > 0 else 0
        
        return {
            "success": True,
            "session": session_data,
            "statistics": {
                "total_students": total_students,
                "present_count": len(present_students),
                "absent_count": len(absent_students),
                "attendance_percentage": round(attendance_percentage, 2)
            },
            "present_students": present_students,
            "absent_students": absent_students
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching session details: {traceback.format_exc()}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch session details: {str(e)}"
        )


@app.get("/attendance/export/{session_id}")
async def export_session_csv(session_id: str):
    """
    Export attendance for a specific session as CSV file.
    """
    try:
        logger.info(f"Export session request - Session ID: {session_id}")
        
        # Get session details using existing endpoint logic
        session_doc = db.collection('attendance_sessions').document(session_id).get()
        
        if not session_doc.exists:
            raise HTTPException(status_code=404, detail="Session not found")
        
        session_data = session_doc.to_dict()
        
        # Get attendance records
        attendance_docs = db.collection('attendance').where('session_id', '==', session_id).stream()
        
        present_students = []
        present_student_ids = set()
        
        for doc in attendance_docs:
            att_data = doc.to_dict()
            present_students.append({
                'id': att_data.get('student_id'),
                'name': att_data.get('student_name'),
                'roll_no': att_data.get('roll_no', 'N/A'),
                'marked_at': att_data.get('marked_at')
            })
            present_student_ids.add(att_data.get('student_id'))
        
        # Get all students for this year/department
        all_students_query = db.collection('users')\
            .where('role', '==', 'student')\
            .where('department', '==', session_data['department'])\
            .where('year', '==', session_data['year'])
        
        all_students_docs = all_students_query.stream()
        
        all_students = []
        for doc in all_students_docs:
            student_data = doc.to_dict()
            all_students.append({
                'id': doc.id,
                'name': student_data.get('fullName', 'Unknown'),
                'roll_no': student_data.get('rollNo', 'N/A'),
                'status': 'Present' if doc.id in present_student_ids else 'Absent'
            })
        
        # Generate CSV content
        csv_content = io.StringIO()
        # Format the created_at timestamp for header
        created_at_str = 'N/A'
        if 'created_at' in session_data:
            created_at = session_data['created_at']
            try:
                # Handle Firestore Timestamp
                if hasattr(created_at, 'strftime'):
                    created_at_str = created_at.strftime('%Y-%m-%d %H:%M:%S')
                else:
                    # Convert to datetime if it's a Timestamp object
                    created_at_str = str(created_at)
            except Exception as e:
                logger.error(f"Error formatting created_at: {e}")
                created_at_str = str(created_at)
        
        csv_content.write(f"Attendance Report - {session_data.get('class_name', 'N/A')}\n")
        csv_content.write(f"Department: {session_data.get('department', 'N/A')}\n")
        csv_content.write(f"Year: {session_data.get('year', 'N/A')}\n")
        csv_content.write(f"Date: {created_at_str}\n")
        csv_content.write(f"Created By: {session_data.get('created_by_name', 'N/A')}\n\n")
        
        csv_content.write("Roll No,Name,Status\n")
        for student in all_students:
            csv_content.write(f"{student['roll_no']},{student['name']},{student['status']}\n")
        
        # Create response
        csv_bytes = io.BytesIO(csv_content.getvalue().encode('utf-8'))
        
        filename = f"attendance_{session_data.get('class_name', 'session')}_{session_id[:8]}.csv"
        
        return StreamingResponse(
            csv_bytes,
            media_type="text/csv",
            headers={
                "Content-Disposition": f"attachment; filename={filename}"
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error exporting CSV: {traceback.format_exc()}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to export CSV: {str(e)}"
        )


@app.get("/attendance/export_all")
async def export_all_sessions_csv(department: str, year: Optional[int] = None, subject: Optional[str] = None):
    """
    Export attendance for all sessions matching filters as CSV file.
    """
    try:
        logger.info(f"Export all request - Department: {department}, Year: {year}, Subject: {subject}")
        
        if not isinstance(department, str) or not department:
            raise HTTPException(status_code=400, detail="Invalid department parameter")
        
        query = db.collection('attendance_sessions').where('department', '==', department)
        
        if year is not None:
            query = query.where('year', '==', year)
        
        if subject:
            query = query.where('class_name', '==', subject)
        
        sessions_docs = query.stream()
        
        # Generate CSV content
        csv_content = io.StringIO()
        csv_content.write(f"Combined Attendance Report - {department}\n")
        if year:
            csv_content.write(f"Year: {year}\n")
        if subject:
            csv_content.write(f"Subject: {subject}\n")
        csv_content.write("\n")
        
        csv_content.write("Session ID,Subject,Date,Created By,Roll No,Name,Status\n")
        
        for session_doc in sessions_docs:
            session_data = session_doc.to_dict()
            session_id = session_doc.id
            
            # Get attendance for this session
            attendance_docs = db.collection('attendance').where('session_id', '==', session_id).stream()
            
            present_student_ids = set()
            for att_doc in attendance_docs:
                att_data = att_doc.to_dict()
                present_student_ids.add(att_data.get('student_id'))
            
            # Get all students for this year/department
            all_students_query = db.collection('users')\
                .where('role', '==', 'student')\
                .where('department', '==', session_data['department'])\
                .where('year', '==', session_data['year'])
            
            all_students_docs = all_students_query.stream()
            
            for student_doc in all_students_docs:
                student_data = student_doc.to_dict()
                status = 'Present' if student_doc.id in present_student_ids else 'Absent'
                
                # Format the created_at timestamp
                created_at_str = 'N/A'
                if 'created_at' in session_data:
                    created_at = session_data['created_at']
                    try:
                        # Handle Firestore Timestamp
                        if hasattr(created_at, 'strftime'):
                            created_at_str = created_at.strftime('%Y-%m-%d %H:%M:%S')
                        else:
                            created_at_str = str(created_at)
                    except Exception as e:
                        logger.error(f"Error formatting created_at: {e}")
                        created_at_str = str(created_at)
                
                csv_content.write(
                    f"{session_id[:8]},"
                    f"{session_data.get('class_name', 'N/A')},"
                    f"{created_at_str},"
                    f"{session_data.get('created_by_name', 'N/A')},"
                    f"{student_data.get('rollNo', 'N/A')},"
                    f"{student_data.get('fullName', 'Unknown')},"
                    f"{status}\n"
                )
        
        # Create response
        csv_bytes = io.BytesIO(csv_content.getvalue().encode('utf-8'))
        
        filename = f"attendance_all_{department}"
        if year:
            filename += f"_year{year}"
        if subject:
            filename += f"_{subject}"
        filename += ".csv"
        
        return StreamingResponse(
            csv_bytes,
            media_type="text/csv",
            headers={
                "Content-Disposition": f"attachment; filename={filename}"
            }
        )
        
    except Exception as e:
        logger.error(f"Error exporting all sessions CSV: {traceback.format_exc()}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to export CSV: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    logger.info(f"Starting server on {config.HOST}:{config.PORT}")
    uvicorn.run(app, host=config.HOST, port=config.PORT)
