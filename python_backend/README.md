---
title: IOE Face Recognition Backend
emoji: 👤
colorFrom: blue
colorTo: green
sdk: docker
pinned: false
app_port: 8000
---

# IOE Face Recognition Attendance System Backend

FastAPI backend for face recognition attendance system using InsightFace.

## Features
- Face recognition with InsightFace ArcFace
- Real-time attendance tracking via WebSocket
- Firebase Firestore integration
- Student registration and management

## API Documentation
Once deployed, visit `/docs` for interactive API documentation.

## Environment Variables Required
- `FIREBASE_CREDENTIALS`: Your Firebase serviceAccountKey.json as single-line JSON

## Endpoints
- `GET /` - Health check
- `POST /register` - Register new student with face
- `POST /start-session` - Start attendance session
- `WebSocket /ws/attendance/{session_id}` - Real-time attendance updates
