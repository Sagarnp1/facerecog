import '../models/user_model.dart';

/// Utility class for checking attendance-related permissions
class AttendancePermissions {
  /// Check if a user can start attendance marking
  /// 
  /// Only Admins and Class Representatives (CR) can start attendance
  static bool canStartAttendance(UserModel? user) {
    if (user == null) return false;
    
    // Admin can always start attendance
    if (user.role == UserRole.admin) return true;
    
    // CR (Class Representative) can start attendance
    if (user.isCR) return true;
    
    return false;
  }
  
  /// Check if a user can view attendance records
  /// 
  /// All authenticated users can view attendance
  static bool canViewAttendance(UserModel? user) {
    return user != null;
  }
  
  /// Check if a user can export attendance data
  /// 
  /// Only Admins can export attendance data
  static bool canExportAttendance(UserModel? user) {
    if (user == null) return false;
    return user.role == UserRole.admin;
  }
  
  /// Check if a user can manually edit attendance records
  /// 
  /// Only Admins can manually edit attendance
  static bool canEditAttendance(UserModel? user) {
    if (user == null) return false;
    return user.role == UserRole.admin;
  }
  
  /// Get user role display name
  static String getRoleDisplayName(UserModel user) {
    if (user.role == UserRole.admin) {
      return 'Admin';
    } else if (user.isCR) {
      return 'CR';
    } else {
      return 'Student';
    }
  }
  
  /// Get access denied message for attendance marking
  static String getAccessDeniedMessage() {
    return 'Only Admins and Class Representatives (CR) can start attendance marking.\n\n'
           'If you believe this is an error, please contact your administrator.';
  }
}

/// Extension methods on UserModel for convenient permission checks
extension AttendancePermissionsExtension on UserModel {
  /// Check if this user can start attendance
  bool get canStartAttendance => AttendancePermissions.canStartAttendance(this);
  
  /// Check if this user can view attendance
  bool get canViewAttendance => AttendancePermissions.canViewAttendance(this);
  
  /// Check if this user can export attendance
  bool get canExportAttendance => AttendancePermissions.canExportAttendance(this);
  
  /// Check if this user can edit attendance
  bool get canEditAttendance => AttendancePermissions.canEditAttendance(this);
  
  /// Get display name for this user's role
  String get roleDisplayName => AttendancePermissions.getRoleDisplayName(this);
}
