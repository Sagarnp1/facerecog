# Role-Based Access Control for Attendance Marking

## Overview

The attendance marking system implements role-based access control to ensure only authorized users can initiate attendance sessions.

## Access Levels

### ✅ **Admin**
- **Can start attendance:** YES
- **Can view attendance:** YES
- **Can export attendance:** YES
- **Can edit attendance:** YES
- **Role field:** `role: UserRole.admin`

### ✅ **CR (Class Representative)**
- **Can start attendance:** YES
- **Can view attendance:** YES
- **Can export attendance:** NO
- **Can edit attendance:** NO
- **Role field:** `role: UserRole.student` + `isCR: true`

### ❌ **Student**
- **Can start attendance:** NO
- **Can view attendance:** YES (their own)
- **Can export attendance:** NO
- **Can edit attendance:** NO
- **Role field:** `role: UserRole.student` + `isCR: false`

---

## Implementation

### 1. Using Permission Utility

```dart
import 'package:ioe/utils/attendance_permissions.dart';

// Check if user can start attendance
if (AttendancePermissions.canStartAttendance(user)) {
  // Show start button
} else {
  // Hide button or show message
}

// Using extension method
if (user.canStartAttendance) {
  // User is admin or CR
}
```

### 2. Using Permission Widgets

```dart
import 'package:ioe/widgets/attendance_permission_widgets.dart';

// Only show button to authorized users
AttendancePermissionGate(
  child: ElevatedButton(
    onPressed: _startAttendance,
    child: Text('Start Attendance'),
  ),
  fallback: Text('You do not have permission'),
)

// Or use the built-in button
AttendanceStartButton(
  onPressed: _startAttendance,
  label: 'Start Attendance',
)
```

### 3. Show User Role Badge

```dart
UserRoleBadge() // Shows "Admin", "CR", or "Student"
```

### 4. Show Access Denied Dialog

```dart
if (!user.canStartAttendance) {
  showAttendanceAccessDeniedDialog(context);
}
```

---

## Setting CR Status

### Option 1: Admin Dashboard

Create an admin interface to toggle CR status:

```dart
// Admin can set CR status
await FirebaseFirestore.instance
    .collection('users')
    .doc(studentId)
    .update({'isCR': true});
```

### Option 2: During Student Registration

Allow students to request CR status (requires admin approval):

```dart
// Student requests CR status
await FirebaseFirestore.instance
    .collection('cr_requests')
    .add({
  'student_id': userId,
  'batch': batch,
  'faculty': faculty,
  'status': 'pending',
  'requested_at': FieldValue.serverTimestamp(),
});

// Admin approves
await FirebaseFirestore.instance
    .collection('users')
    .doc(studentId)
    .update({'isCR': true});
```

### Option 3: Firebase Console

Manually set via Firebase Console:
1. Go to Firestore Database
2. Find the student in `users` collection
3. Edit document and set `isCR: true`

---

## Firestore Security Rules

Update your `firestore.rules` to enforce permissions:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is admin or CR
    function canStartAttendance() {
      return request.auth != null && (
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' ||
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isCR == true
      );
    }
    
    // Attendance sessions
    match /sessions/{sessionId} {
      allow read: if request.auth != null;
      allow create: if canStartAttendance();
      allow update: if canStartAttendance();
      allow delete: if request.auth != null && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Attendance records
    match /attendance/{attendanceId} {
      allow read: if request.auth != null;
      allow write: if canStartAttendance();
    }
    
    // Attendance logs
    match /attendance_logs/{logId} {
      allow read: if request.auth != null;
      allow create: if canStartAttendance();
    }
    
    // Users
    match /users/{userId} {
      allow read: if request.auth != null;
      allow update: if request.auth.uid == userId || 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      // Only admin can set isCR status
      allow update: if request.auth != null && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' &&
                       request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isCR']);
    }
  }
}
```

---

## Backend Logging

The Python backend logs who initiates each session:

```json
{
  "session_id": "uuid",
  "action": "started",
  "initiated_by": "user_uid",
  "initiated_by_name": "John Doe",
  "user_role": "admin",  // or "student"
  "is_cr": true,         // or false
  "batch": "2021",
  "faculty": "Computer Science",
  "timestamp": "2026-02-09T10:30:00"
}
```

### Query Logs

```dart
// Get all attendance sessions started by CRs
final sessions = await FirebaseFirestore.instance
    .collection('attendance_logs')
    .where('is_cr', isEqualTo: true)
    .where('action', isEqualTo: 'started')
    .orderBy('timestamp', descending: true)
    .get();

// Get sessions started by specific user
final userSessions = await FirebaseFirestore.instance
    .collection('attendance_logs')
    .where('initiated_by', isEqualTo: userId)
    .get();
```

---

## UI Patterns

### Pattern 1: Hide Button Completely

```dart
if (user.canStartAttendance) {
  FloatingActionButton(
    onPressed: _startAttendance,
    child: Icon(Icons.play_arrow),
  )
}
```

### Pattern 2: Disable Button with Tooltip

```dart
FloatingActionButton(
  onPressed: user.canStartAttendance ? _startAttendance : null,
  child: Icon(Icons.play_arrow),
  tooltip: user.canStartAttendance 
      ? 'Start Attendance' 
      : 'Only Admins and CRs can start attendance',
)
```

### Pattern 3: Show Warning Banner

```dart
if (!user.canStartAttendance)
  Container(
    color: Colors.orange[100],
    padding: EdgeInsets.all(16),
    child: Row(
      children: [
        Icon(Icons.warning, color: Colors.orange),
        SizedBox(width: 8),
        Text('Only Admins and CRs can start attendance'),
      ],
    ),
  )
```

---

## Testing

### Test Scenarios

1. **Admin starts attendance:**
   - ✅ Should succeed
   - ✅ Should log with `user_role: "admin"`

2. **CR starts attendance:**
   - ✅ Should succeed
   - ✅ Should log with `is_cr: true`

3. **Regular student starts attendance:**
   - ❌ Should show access denied
   - ❌ Button should be hidden

4. **Toggle CR status:**
   - ✅ Admin changes `isCR` to `true`
   - ✅ Student can now start attendance
   - ✅ Admin changes back to `false`
   - ❌ Student loses permission

---

## Best Practices

### 1. Check Permission Early

```dart
// Before navigating to attendance screen
if (!user.canStartAttendance) {
  showAttendanceAccessDeniedDialog(context);
  return;
}

Navigator.push(context, MaterialPageRoute(
  builder: (context) => AttendanceMarkingScreen(...),
));
```

### 2. Double-Check in Screen

```dart
@override
void initState() {
  super.initState();
  if (!canStartAttendance) {
    _showAccessDeniedDialog();
  }
}
```

### 3. Validate on Backend (Future Enhancement)

```python
# In Python backend
def verify_user_permission(user_id):
    user_doc = db.collection('users').document(user_id).get()
    user_data = user_doc.to_dict()
    
    is_admin = user_data.get('role') == 'admin'
    is_cr = user_data.get('isCR', False)
    
    return is_admin or is_cr
```

---

## Common Issues

### Issue: CR button not showing
**Solution:** Check that `isCR` field is set to `true` in Firestore

### Issue: Access denied despite being admin
**Solution:** Verify `role` field is set to `'admin'` (string) not `UserRole.admin`

### Issue: Permission check not working
**Solution:** Ensure AuthProvider is properly configured and user is loaded

---

## Migration Guide

If you have existing users without `isCR` field:

```dart
// Add isCR field to all existing students
final batch = FirebaseFirestore.instance.batch();
final users = await FirebaseFirestore.instance.collection('users').get();

for (var doc in users.docs) {
  if (!doc.data().containsKey('isCR')) {
    batch.update(doc.reference, {'isCR': false});
  }
}

await batch.commit();
```

---

## Summary

✅ Only **Admins** and **CRs** can start attendance  
✅ Use `AttendancePermissions` utility for checks  
✅ Use provided widgets for UI  
✅ Sessions are logged with initiator details  
✅ Firestore rules enforce permissions  
✅ Easy to toggle CR status via admin interface
