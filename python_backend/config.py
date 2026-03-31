"""
Configuration settings for the Face Recognition Attendance System Backend
"""
import os
from dotenv import load_dotenv

load_dotenv()

# Firebase Configuration
# Can be either a file path or JSON string from environment variable
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "serviceAccountKey.json")
FIREBASE_CREDENTIALS = os.getenv("FIREBASE_CREDENTIALS")  # JSON string for cloud deployment

# Server Configuration
HOST = os.getenv("HOST", "10.172.135.246")
PORT = int(os.getenv("PORT", 8000))

# Face Recognition Settings (InsightFace ArcFace - cosine similarity threshold)
# Higher = stricter matching. Recommended: 0.35-0.45 for ArcFace
FACE_RECOGNITION_TOLERANCE = float(os.getenv("FACE_RECOGNITION_TOLERANCE", 0.4))
FRAME_SKIP = int(os.getenv("FRAME_SKIP", 3))

# Auto-Scheduler Capture Settings
AUTO_CAPTURES_PER_CLASS = int(os.getenv("AUTO_CAPTURES_PER_CLASS", 10))  # Number of captures during class
CAPTURE_DURATION_SECONDS = int(os.getenv("CAPTURE_DURATION_SECONDS", 5))  # How long to capture each time

# Firestore Collections
STUDENTS_COLLECTION = os.getenv("STUDENTS_COLLECTION", "students")
ATTENDANCE_COLLECTION = os.getenv("ATTENDANCE_COLLECTION", "attendance")
SESSIONS_COLLECTION = os.getenv("SESSIONS_COLLECTION", "attendance_sessions")

# Request Timeouts
REGISTRATION_TIMEOUT = 60  # seconds
ATTENDANCE_TIMEOUT = 300   # seconds

# Webcam Settings
WEBCAM_INDEX = 0
WEBCAM_WIDTH = 640
WEBCAM_HEIGHT = 480
WEBCAM_FPS = 30
