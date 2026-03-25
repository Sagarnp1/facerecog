# Face Recognition Attendance System - Python Backend

This Python backend provides face recognition capabilities for the Flutter-based attendance system using FastAPI, face_recognition library, and Firebase Admin SDK.

## Features

- **Student Registration**: Process face images and generate 128-dimensional embeddings
- **Real-time Attendance Marking**: WebSocket-based webcam attendance with live updates
- **Firebase Integration**: Seamless integration with Firestore for data storage
- **CORS Support**: Cross-origin requests for Flutter web apps

## Prerequisites

- Python 3.8 or higher
- Webcam (for attendance marking)
- Firebase service account credentials JSON file

## Installation

1. **Install Python dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Download Firebase Service Account Key**:
   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save the JSON file as `serviceAccountKey.json` in this directory

3. **Configure environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env and update FIREBASE_CREDENTIALS_PATH if needed
   ```

## Running the Server

### For Student Registration (Network Accessible)

Run the server so it's accessible to student devices on your network:

```bash
python main.py
```

Or using uvicorn directly:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The server will be accessible at:
- Local: http://localhost:8000
- Network: http://[your-ip-address]:8000

### For Teacher Attendance Marking (Localhost)

Teachers should run the same server on their laptop:

```bash
python main.py
```

Flutter app will connect to http://localhost:8000 for attendance marking.

## API Endpoints

### 1. Register Student
**POST** `/register_student`

Processes 5 face images and returns embeddings.

Request body:
```json
{
  "full_name": "John Doe",
  "roll_no": "2021CS001",
  "batch": "2021",
  "faculty": "Computer Science",
  "images": ["base64_image1", "base64_image2", "base64_image3", "base64_image4", "base64_image5"]
}
```

Response:
```json
{
  "success": true,
  "embeddings": [[128 floats], [128 floats], [128 floats], [128 floats], [128 floats]],
  "student_info": {...}
}
```

### 2. Start Attendance Session
**POST** `/start_attendance`

Initialize an attendance session for a specific batch/faculty.

Request body:
```json
{
  "batch": "2021",
  "faculty": "Computer Science"
}
```

Response:
```json
{
  "session_id": "uuid",
  "total_students": 45,
  "message": "Session started"
}
```

### 3. WebSocket Attendance Marking
**WebSocket** `/ws/attendance/{session_id}`

Real-time attendance marking via webcam.

Messages sent to client:
```json
{
  "type": "attendance_marked",
  "student_id": "doc_id",
  "name": "John Doe",
  "roll_no": "2021CS001",
  "timestamp": "2026-02-09T10:30:00"
}
```

### 4. Stop Attendance Session
**POST** `/stop_attendance/{session_id}`

End session and get statistics.

Response:
```json
{
  "session_id": "uuid",
  "total_students": 45,
  "present_count": 42,
  "attendance_percentage": 93.33,
  "absent_students": [...]
}
```

## Testing

Test the API using the interactive documentation:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Troubleshooting

### Webcam Issues
- Ensure no other application is using the webcam
- Check webcam permissions on Windows/Mac/Linux
- Try changing `WEBCAM_INDEX` in config.py (0, 1, 2, etc.)

### Face Recognition Issues
- Ensure good lighting conditions
- Faces should be clearly visible and frontal
- Adjust `FACE_RECOGNITION_TOLERANCE` (lower = stricter matching)

### Firebase Connection Issues
- Verify `serviceAccountKey.json` is in the correct location
- Check Firebase project permissions
- Ensure Firestore is enabled in Firebase Console

## Performance Tips

- Adjust `FRAME_SKIP` to process fewer frames if performance is slow
- Use a dedicated GPU if available (dlib supports CUDA)
- Reduce webcam resolution in config.py if needed

## Security Notes

- **Never commit** `serviceAccountKey.json` to version control
- Use environment variables for sensitive configuration
- In production, implement proper authentication and authorization
- Use HTTPS in production environments
