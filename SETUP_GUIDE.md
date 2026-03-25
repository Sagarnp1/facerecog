# Complete Face Recognition Attendance System Setup Guide

This guide walks you through setting up the entire face recognition attendance system with Python backend and Flutter frontend integration.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Python Backend Setup](#python-backend-setup)
3. [Flutter Frontend Setup](#flutter-frontend-setup)
4. [Firebase Configuration](#firebase-configuration)
5. [Testing the System](#testing-the-system)
6. [Troubleshooting](#troubleshooting)

---

## System Architecture

### Two-Phase Operation

**Phase 1: Student Registration**
- Students use Flutter app to capture 5 face images
- Images are sent to Python backend (can be on network server)
- Python generates face embeddings using face_recognition library
- Embeddings are returned to Flutter and saved in Firestore

**Phase 2: Attendance Marking**
- Python backend runs locally on teacher's laptop
- Teacher starts attendance session via Flutter app
- WebSocket connection established for real-time updates
- Python captures webcam video and recognizes faces
- Attendance records saved to Firestore with real-time UI updates

### Technology Stack

**Backend:**
- FastAPI (Python web framework)
- face_recognition library (dlib-based embeddings)
- OpenCV (webcam capture)
- Firebase Admin SDK (Firestore access)
- WebSockets (real-time communication)

**Frontend:**
- Flutter (cross-platform UI)
- Dio (HTTP client)
- web_socket_channel (WebSocket client)
- Firebase SDK (authentication & Firestore)
- Camera package (image capture)

---

## Python Backend Setup

### Prerequisites

- Python 3.8 or higher
- pip (Python package manager)
- Webcam (for attendance marking)
- Windows/Mac/Linux operating system

### Step 1: Install Python Dependencies

Navigate to the `python_backend` directory:

```bash
cd python_backend
```

Install required packages:

```bash
pip install -r requirements.txt
```

**Note:** Installing `face_recognition` may take some time as it includes dlib with compiled C++ extensions.

**Windows Users:** If you encounter issues installing dlib/face_recognition:
1. Install Visual Studio Build Tools
2. Or use pre-built wheels: `pip install face-recognition --no-cache-dir`

**Mac Users:**
```bash
brew install cmake
pip install face_recognition
```

**Linux Users:**
```bash
sudo apt-get update
sudo apt-get install build-essential cmake
sudo apt-get install libopenblas-dev liblapack-dev
pip install face_recognition
```

### Step 2: Configure Firebase

1. **Get Firebase Service Account Key:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save the JSON file as `serviceAccountKey.json` in `python_backend/` folder

2. **Update configuration:**
   ```bash
   cp .env.example .env
   ```
   
   Edit `.env` if needed:
   ```
   FIREBASE_CREDENTIALS_PATH=serviceAccountKey.json
   HOST=0.0.0.0
   PORT=8000
   FACE_RECOGNITION_TOLERANCE=0.6
   FRAME_SKIP=3
   ```

### Step 3: Test the Backend

Start the server:

```bash
python main.py
```

Or using uvicorn directly:

```bash
uvicorn main:app --reload
```

You should see:
```
INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

Open browser and visit: http://localhost:8000

You should see the API documentation.

Visit http://localhost:8000/docs for interactive Swagger UI.

---

## Flutter Frontend Setup

### Step 1: Install Dependencies

From the project root directory:

```bash
flutter pub get
```

This will install:
- `dio ^5.4.0` - HTTP client for backend communication
- `web_socket_channel ^2.4.0` - WebSocket client for real-time updates
- All existing dependencies

### Step 2: Update Registration Flow

See detailed examples in:
- `lib/examples/registration_integration_guide.dart`

**Key Changes:**

1. Import new service in your registration screen:
   ```dart
   import 'package:ioe/services/python_backend_service.dart';
   ```

2. Save captured image paths instead of generating embeddings locally

3. Send images to Python backend during registration:
   ```dart
   final base64Images = await PythonBackendService.imageFilesToBase64(imagePaths);
   final result = await pythonBackend.registerStudent(
     fullName: name,
     rollNo: rollNo,
     batch: batch,
     faculty: faculty,
     base64Images: base64Images,
   );
   ```

4. Save returned embeddings to Firestore

### Step 3: Implement Attendance Screen

See complete example in:
- `lib/examples/attendance_screen_example.dart`

You can either:
- **Option A:** Copy the example and customize it
- **Option B:** Create new attendance screen using the pattern shown

**Key Components:**

1. **PythonBackendService** - REST API communication
2. **AttendanceWebSocketService** - Real-time updates
3. **UI** - Shows students, present count, real-time updates

### Step 4: Update Firestore Security Rules

Ensure your `firestore.rules` allows:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Students collection
    match /students/{studentId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Attendance collection
    match /attendance/{attendanceId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // Sessions collection
    match /sessions/{sessionId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

---

## Firebase Configuration

### Firestore Collections Structure

**1. students collection:**
```json
{
  "full_name": "John Doe",
  "roll_no": "2021CS001",
  "batch": "2021",
  "faculty": "Computer Science",
  "email": "john@example.com",
  "face_embeddings": [
    [128 floats],  // Image 1 embedding
    [128 floats],  // Image 2 embedding
    [128 floats],  // Image 3 embedding
    [128 floats],  // Image 4 embedding
    [128 floats]   // Image 5 embedding
  ],
  "registration_date": Timestamp
}
```

**2. attendance collection:**
```json
{
  "student_id": "document_id",
  "student_name": "John Doe",
  "roll_no": "2021CS001",
  "batch": "2021",
  "faculty": "Computer Science",
  "session_id": "uuid",
  "timestamp": Timestamp,
  "marked_at": "2026-02-09T10:30:00"
}
```

**3. sessions collection:**
```json
{
  "session_id": "uuid",
  "batch": "2021",
  "faculty": "Computer Science",
  "class_name": "Data Structures",
  "total_students": 45,
  "present_count": 42,
  "attendance_percentage": 93.33,
  "start_time": Timestamp,
  "end_time": Timestamp,
  "status": "completed"
}
```

### Create Firestore Indexes

For efficient queries, create composite indexes:

1. Go to Firebase Console → Firestore → Indexes
2. Add composite index:
   - Collection: `students`
   - Fields: `batch` (Ascending), `faculty` (Ascending)

---

## Testing the System

### Test 1: Python Backend Health Check

```bash
curl http://localhost:8000/
```

Expected response:
```json
{
  "status": "running",
  "service": "Face Recognition Attendance System",
  "version": "1.0.0"
}
```

### Test 2: Student Registration

1. **Start Python backend** on registration server (can be network accessible):
   ```bash
   python main.py
   ```
   Note the IP address (e.g., `192.168.1.100:8000`)

2. **Update Flutter app** with registration server URL:
   ```dart
   PythonBackendService(
     registrationUrl: 'http://192.168.1.100:8000',
   )
   ```

3. **Run Flutter app** and register a test student with 5 face images

4. **Verify in Firestore:**
   - Check `students` collection
   - Ensure `face_embeddings` field has 5 arrays of 128 floats

### Test 3: Attendance Marking

1. **Start Python backend** on teacher's laptop:
   ```bash
   cd python_backend
   python main.py
   ```

2. **Ensure webcam is connected** and not being used by other apps

3. **Run Flutter app** on teacher's device

4. **Navigate to attendance screen** and start session:
   - Select batch and faculty
   - Click "Start Attendance"
   - Python backend will open webcam

5. **Student stands in front of webcam:**
   - Their face should be detected and recognized within 1-3 seconds
   - Flutter app shows real-time update
   - Check Firestore `attendance` collection for new record

---

## Troubleshooting

### Python Backend Issues

**Issue:** `ModuleNotFoundError: No module named 'face_recognition'`
**Solution:** 
```bash
pip install face_recognition
```

**Issue:** Webcam not opening
**Solution:**
- Close other apps using webcam (Zoom, Teams, etc.)
- Try different webcam index in `config.py`: `WEBCAM_INDEX = 1` or `2`
- Check webcam permissions on OS level

**Issue:** Firebase connection failed
**Solution:**
- Verify `serviceAccountKey.json` is in correct location
- Check JSON file is valid
- Ensure Firestore is enabled in Firebase Console

**Issue:** Face recognition too strict/lenient
**Solution:**
Adjust `FACE_RECOGNITION_TOLERANCE` in `config.py`:
- **Lower (0.5):** Stricter matching, fewer false positives
- **Higher (0.7):** More lenient, may accept similar faces

### Flutter Issues

**Issue:** Cannot connect to Python backend
**Solution:**
1. Check Python backend is running: `http://localhost:8000`
2. Verify URL in Flutter code matches server address
3. For network access, use IP address instead of localhost

**Issue:** WebSocket connection failed
**Solution:**
1. Ensure backend is running before connecting
2. Check firewall isn't blocking localhost:8000
3. Try restarting both Flutter app and Python backend

**Issue:** Images not converting to base64
**Solution:**
- Ensure captured images are saved to accessible file paths
- Check file permissions
- Verify image files exist before encoding

### Performance Issues

**Issue:** Attendance marking is slow
**Solution:**
1. Increase `FRAME_SKIP` in `config.py` (try 5 or 6)
2. Reduce webcam resolution in `config.py`
3. Ensure laptop has adequate processing power
4. Close other resource-intensive applications

**Issue:** Registration takes too long
**Solution:**
- Normal processing time: 15-30 seconds for 5 images
- Reduce image resolution before sending to backend
- Ensure good network connection to registration server

---

## Deployment Considerations

### For Production Use

1. **Backend Security:**
   - Use HTTPS instead of HTTP
   - Implement authentication for API endpoints
   - Restrict CORS to specific origins
   - Never commit `serviceAccountKey.json` to version control

2. **Network Configuration:**
   - Registration server: Deploy on school network with static IP
   - Attendance: Always runs locally on teacher laptops

3. **Scalability:**
   - For large classes (>100 students), consider batch processing
   - Optimize Firestore queries with proper indexing
   - Monitor Firebase usage and costs

4. **Data Privacy:**
   - Comply with local data protection regulations
   - Store only necessary face embedding data (not actual images)
   - Implement data retention policies
   - Obtain consent for biometric data collection

---

## Support and Further Development

### Potential Enhancements

- [ ] Manual attendance override for false negatives
- [ ] Attendance reports and analytics
- [ ] Email notifications to absent students
- [ ] Multiple face recognition models (ensemble)
- [ ] Mobile app for students to check attendance
- [ ] Integration with learning management systems

### Getting Help

- Check Python backend logs for detailed error messages
- Use Swagger UI (http://localhost:8000/docs) to test API endpoints
- Enable debug logging in Flutter app
- Refer to example code in `lib/examples/` folder

---

## Success Checklist

✅ Python backend running and accessible  
✅ Firebase service account configured  
✅ Webcam detected and functional  
✅ Flutter dependencies installed  
✅ Test registration completed successfully  
✅ Face embeddings saved to Firestore  
✅ Attendance session starts without errors  
✅ Real-time WebSocket updates working  
✅ Attendance records saved to Firestore  

**You're ready to go!** 🎉
