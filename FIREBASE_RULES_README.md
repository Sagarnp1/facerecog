# Firebase Security Rules - IOE Student Management System

## Overview
These Firestore security rules ensure that:
1. Only admins and Class Representatives (CRs) can create, edit, and delete notices
2. Notices are only visible to students from the same department
3. Users can only access their own profile data
4. Proper data validation and security constraints

## Rules Structure

### Users Collection (`/users/{userId}`)
- **Read**: Users can only read their own profile data
- **Create**: Users can create their own profile during signup
  - **Admin Constraint**: Only one admin allowed per department
- **Update**: Only admins can update user data (for promoting/demoting CRs)
  - **Role Protection**: Cannot change user roles to/from admin
- **Delete**: No deletion allowed for user data

### Department Admins Collection (`/department_admins/{department}`)
- **Read**: Anyone can check if admin exists for a department
- **Create**: Only when creating a new admin account
- **Update/Delete**: Not allowed (admins are permanent)

### Notices Collection (`/notices/{noticeId}`)
- **Read**: Only users from the same department can view notices
- **Create**: Only admins and CRs can create notices for their own department
- **Update**: Only admins and CRs from the same department can edit notices
- **Delete**: Only admins and CRs from the same department can delete notices

## Key Security Features

### One Admin Per Department
```javascript
function adminExistsForDepartment(departmentName) {
  return exists(/databases/$(database)/documents/department_admins/$(departmentName));
}
```
Ensures only one admin can exist per department using a tracking collection.

### Department Isolation
```javascript
function isSameDepartment(departmentName) {
  return request.auth != null && getUserData().department == departmentName;
}
```
Ensures users can only access notices from their own department.

### Role-Based Access Control
```javascript
function isAdminOrCR() {
  return isAdmin() || isCR();
}
```
Only admins and Class Representatives can manage notices.

### Data Validation
- Ensures required fields are present in notice documents
- Prevents department changes when updating notices
- Validates that notice creators belong to the same department

## Deployment Instructions

### Method 1: Using Firebase CLI
1. Install Firebase CLI if not already installed:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize Firebase in your project (if not done already):
   ```bash
   firebase init firestore
   ```

4. Deploy the rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

### Method 2: Using Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to Firestore Database
4. Go to "Rules" tab
5. Copy and paste the content from `firestore.rules`
6. Click "Publish"

## Testing the Rules

### Test Scenarios
1. **Admin creates notice**: Should succeed
2. **CR creates notice**: Should succeed  
3. **Regular student creates notice**: Should fail
4. **Student from different department reads notice**: Should fail
5. **Admin edits notice from their department**: Should succeed
6. **Admin edits notice from different department**: Should fail

### Test Commands (using Firebase CLI)
```bash
# Test notice creation by admin
firebase firestore:rules-test --collection=notices --operation=create --user-uid=admin-uid

# Test notice reading by student from same department
firebase firestore:rules-test --collection=notices --operation=read --user-uid=student-uid
```

## Important Notes

1. **Department Matching**: The rules enforce strict department isolation. Users can only manage notices within their own department.

2. **Role Verification**: The system checks both admin status and CR status from the user's profile in Firestore.

3. **One Admin Per Department**: Enforces that only one admin can exist per department using a tracking collection.

4. **Role Protection**: Prevents changing user roles to/from admin to maintain the one-admin-per-department constraint.

5. **Data Integrity**: Rules prevent changing the department of a notice after creation to maintain data consistency.

6. **Atomic Operations**: Uses Firestore batch writes to ensure data consistency when creating admins.

7. **Security by Default**: Any operation not explicitly allowed is denied by the final catch-all rule.

## Troubleshooting

### Common Issues
1. **Permission Denied**: Check if user has correct role (admin/CR) and belongs to the right department
2. **Rules Deployment Failed**: Ensure you're authenticated with Firebase CLI and have proper project permissions
3. **Test Failures**: Verify that user documents have correct `role`, `department`, and `isCR` fields

### Debug Tips
- Use Firebase Console's Rules Playground to test specific scenarios
- Check Firebase logs for detailed error messages
- Ensure user data structure matches the expected format in rules
