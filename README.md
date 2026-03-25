# IOE Student Management System

A Flutter mobile application for managing students, notices, and schedules in the Institute of Engineering (IOE) departments.

## Features

### Core Features
- **Authentication System**
  - Student signup with face registration
  - Admin signup (one admin per department)
  - Email/password authentication
  - Department-specific access control

### User Roles
- **Students**: View notices/schedules, face authentication
- **Class Representatives (CR)**: Create and manage notices/schedules
- **Admins**: Full department management, promote students to CR

### Department Support
- BEI (Electronics & Information)
- BCT (Computer)
- BCE (Civil)
- BAG (Agriculture)
- BEL (Electrical)
- BME (Mechanical)
- BAR (Architecture)

### Security Features
- Face recognition for student authentication
- Department isolation (users only see their department data)
- Role-based access control
- Firestore security rules

## Setup Instructions

### 1. Firebase Setup

1. **Create a Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project
   - Enable Authentication and Firestore Database

2. **Configure Authentication**
   - Enable Email/Password authentication
   - Configure sign-in methods

3. **Setup Firestore Database**
   - Create a Firestore database in production mode
   - Set up the following collections:
     - `users` - User profiles and face embeddings
     - `posts` - Notices and schedules

4. **Add Firebase to Flutter**
   - Follow [Firebase Flutter setup guide](https://firebase.google.com/docs/flutter/setup)
   - Download and add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

### 2. Run the Application

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Project Structure

```
lib/
├── main.dart                     # App entry point
├── models/                       # Data models
│   ├── user_model.dart          # User profile model
│   └── post_model.dart          # Notice/schedule model
├── services/                     # Business logic
│   ├── auth_service.dart        # Authentication service
│   ├── auth_provider.dart       # State management
│   ├── face_recognition_service.dart # Face recognition
│   └── post_service.dart        # Notice/schedule service
├── screens/                      # UI screens
│   ├── auth/                    # Authentication screens
│   ├── student/                 # Student screens
│   └── admin/                   # Admin screens
├── widgets/                      # Reusable widgets
│   └── face_capture_widget.dart # Face capture component
└── utils/                        # Utilities
    └── theme.dart               # Department themes
```

## Department Themes
Each department has its own color scheme:
- BEI: Blue
- BCT: Green  
- BCE: Brown
- BAG: Light Green
- BEL: Amber
- BME: Red
- BAR: Purple

## Development Status

### ✅ Completed Features
- Basic app structure and navigation
- Authentication system (email/password)
- User models and data structure
- Department-specific theming
- Face capture UI (basic implementation)
- Student and admin dashboards
- Firebase integration setup

### 🚧 Next Steps
- Complete Firebase configuration
- Implement face recognition ML
- Add notice/schedule CRUD operations
- Implement student management for admins
- Add CR promotion system

## License

This project is for educational purposes as part of IOE curriculum.
