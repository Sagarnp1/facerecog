# Quick Start Guide - Face Recognition Attendance System

Get your system up and running in under 10 minutes!

## Prerequisites Checklist

- ✅ Python 3.8+ installed
- ✅ Flutter SDK installed
- ✅ Firebase project created
- ✅ Webcam connected to computer

## Step 1: Python Backend Setup (5 minutes)

### Windows:
```bash
cd python_backend
setup.bat
```

### Mac/Linux:
```bash
cd python_backend
chmod +x setup.sh
./setup.sh
```

### Download Firebase Credentials:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Your Project → ⚙️ Project Settings → Service Accounts
3. Click **"Generate New Private Key"**
4. Save as `python_backend/serviceAccountKey.json`

### Start the Server:
```bash
cd python_backend
python main.py
```

✅ **Success:** Browser shows API docs at http://localhost:8000

---

## Step 2: Flutter Setup (2 minutes)

### Install Dependencies:
```bash
flutter pub get
```

### Update Backend URL (if needed):

**For Registration (optional - if server on different machine):**
Edit the registration service initialization to use network IP:
```dart
PythonBackendService(
  registrationUrl: 'http://192.168.1.XXX:8000', // Replace with your IP
)
```

**For Attendance (leave as localhost):**
```dart
PythonBackendService(
  attendanceUrl: 'http://localhost:8000',
)
```

---

## Step 3: Quick Test (3 minutes)

### Test 1: Backend Health Check

Open browser: http://localhost:8000

Expected response:
```json
{
  "status": "running",
  "service": "Face Recognition Attendance System"
}
```

### Test 2: API Documentation

Open: http://localhost:8000/docs

You should see interactive Swagger UI with all endpoints.

### Test 3: Webcam Test

Run this Python script:
```python
import cv2
cap = cv2.VideoCapture(0)
ret, frame = cap.read()
if ret:
    print("✅ Webcam working!")
else:
    print("❌ Webcam not detected")
cap.release()
```

---

## Integration Steps

### For Student Registration:

1. **Import the service:**
```dart
import 'package:ioe/services/python_backend_service.dart';
```

2. **Use in registration screen:**
```dart
final backendService = PythonBackendService();

// Convert captured images to base64
final base64Images = await PythonBackendService.imageFilesToBase64(imagePaths);

// Send to backend
final result = await backendService.registerStudent(
  fullName: nameController.text,
  rollNo: rollNoController.text,
  batch: batchController.text,
  faculty: facultyController.text,
  base64Images: base64Images,
);

// Save embeddings to Firestore
if (result['success']) {
  await FirebaseFirestore.instance
    .collection('students')
    .doc(userId)
    .set({
      'full_name': nameController.text,
      'roll_no': rollNoController.text,
      'batch': batchController.text,
      'faculty': facultyController.text,
      'face_embeddings': result['embeddings'],
      'registration_date': FieldValue.serverTimestamp(),
    });
}
```

### For Attendance Marking:

See complete example: `lib/examples/attendance_screen_example.dart`

Or copy this minimal code:

```dart
import 'package:ioe/services/python_backend_service.dart';
import 'package:ioe/services/attendance_websocket_service.dart';

class AttendanceScreen extends StatefulWidget {
  // ... your code
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _backend = PythonBackendService();
  final _websocket = AttendanceWebSocketService();
  
  Future<void> startAttendance() async {
    // Start session
    final result = await _backend.startAttendanceSession(
      batch: '2021',
      faculty: 'Computer Science',
    );
    
    // Connect WebSocket
    await _websocket.connect(result['session_id']);
    
    // Listen for updates
    _websocket.updateStream.listen((update) {
      if (update.isAttendanceMarked) {
        print('Marked: ${update.name}');
        // Update UI
      }
    });
  }
}
```

---

## Common First-Time Issues

### ❌ "Cannot connect to Python backend"
**Fix:** Ensure Python server is running:
```bash
cd python_backend
python main.py
```

### ❌ "Firebase connection failed"
**Fix:** Check `serviceAccountKey.json` is in `python_backend/` folder

### ❌ "Webcam not opening"
**Fix:** Close other apps using webcam (Zoom, Teams, etc.)

### ❌ "face_recognition module not found"
**Fix:**
```bash
pip install face-recognition
```

### ❌ Flutter build errors
**Fix:**
```bash
flutter clean
flutter pub get
```

---

## Verification Checklist

Before going into production, verify:

- [ ] Python backend starts without errors
- [ ] http://localhost:8000 is accessible
- [ ] Firebase credentials are valid
- [ ] Webcam is detected by Python
- [ ] Flutter app builds successfully
- [ ] Test student registration works
- [ ] Embeddings saved to Firestore
- [ ] Attendance session starts successfully
- [ ] WebSocket connection establishes
- [ ] Face recognition detects test student
- [ ] Attendance record saved to Firestore

---

## File Structure Overview

```
ioe/
├── python_backend/
│   ├── main.py                  ⭐ Main backend application
│   ├── config.py                ⚙️ Configuration
│   ├── requirements.txt         📦 Python dependencies
│   ├── serviceAccountKey.json   🔑 Firebase credentials (create this)
│   └── README.md                📖 Backend docs
│
├── lib/
│   ├── services/
│   │   ├── python_backend_service.dart         🔌 Backend communication
│   │   └── attendance_websocket_service.dart   📡 Real-time updates
│   │
│   └── examples/
│       ├── registration_integration_guide.dart  📘 Registration guide
│       └── attendance_screen_example.dart       📘 Attendance example
│
├── SETUP_GUIDE.md               📚 Comprehensive setup guide
├── IMPLEMENTATION_SUMMARY.md    📋 Technical summary
└── QUICK_START.md              ⚡ This file
```

---

## What's Next?

1. ✅ **Read:** `SETUP_GUIDE.md` for detailed instructions
2. ✅ **Review:** `lib/examples/` for integration code
3. ✅ **Implement:** Modify your registration and attendance screens
4. ✅ **Test:** With real students and webcam
5. ✅ **Deploy:** Follow deployment section in SETUP_GUIDE.md

---

## Get Help

**Issues?** Check these in order:

1. 📖 Read `SETUP_GUIDE.md` → Troubleshooting section
2. 🔍 Check Python backend logs in terminal
3. 🌐 Test API at http://localhost:8000/docs
4. 🐛 Enable debug logging in Flutter
5. 🔥 Check Firebase Console for data

---

## Success! 🎉

You should now have:

- ✅ Python backend running and accessible
- ✅ Flutter app connected to backend
- ✅ Face embeddings being generated
- ✅ Real-time attendance marking working

**Ready to Mark Attendance!**

Run Flutter app → Start Attendance → Stand in front of webcam → ✨ Attendance Marked!

---

**Last Updated:** February 9, 2026  
**Version:** 1.0.0
