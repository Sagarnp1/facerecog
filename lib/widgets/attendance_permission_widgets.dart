import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../utils/attendance_permissions.dart';

/// Widget that shows/hides content based on attendance permissions
/// 
/// Example usage:
/// ```dart
/// AttendancePermissionGate(
///   child: ElevatedButton(
///     onPressed: _startAttendance,
///     child: Text('Start Attendance'),
///   ),
///   fallback: Text('Only Admins and CRs can start attendance'),
/// )
/// ```
class AttendancePermissionGate extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  final bool showAccessDeniedMessage;
  
  const AttendancePermissionGate({
    super.key,
    required this.child,
    this.fallback,
    this.showAccessDeniedMessage = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    
    if (!AttendancePermissions.canStartAttendance(user)) {
      if (showAccessDeniedMessage) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            border: Border.all(color: Colors.orange),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Only Admins and Class Representatives can start attendance',
                  style: TextStyle(color: Colors.orange[900]),
                ),
              ),
            ],
          ),
        );
      }
      return fallback ?? const SizedBox.shrink();
    }
    
    return child;
  }
}

/// Floating action button that only shows for authorized users
class AttendanceStartButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final bool isLoading;
  
  const AttendanceStartButton({
    super.key,
    required this.onPressed,
    this.label = 'Start Attendance',
    this.icon = Icons.play_arrow,
    this.isLoading = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    
    // Don't show button if user doesn't have permission
    if (!AttendancePermissions.canStartAttendance(user)) {
      return const SizedBox.shrink();
    }
    
    if (isLoading) {
      return FloatingActionButton(
        onPressed: null,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }
    
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

/// Badge showing user role (Admin/CR/Student)
class UserRoleBadge extends StatelessWidget {
  final bool compact;
  
  const UserRoleBadge({
    super.key,
    this.compact = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    
    if (user == null) return const SizedBox.shrink();
    
    final roleDisplay = user.roleDisplayName;
    Color? backgroundColor;
    IconData? icon;
    
    if (user.role.name == 'admin') {
      backgroundColor = Colors.red[100];
      icon = Icons.admin_panel_settings;
    } else if (user.isCR) {
      backgroundColor = Colors.blue[100];
      icon = Icons.star;
    } else {
      backgroundColor = Colors.grey[200];
      icon = Icons.person;
    }
    
    if (compact) {
      return Chip(
        label: Text(roleDisplay),
        backgroundColor: backgroundColor,
        avatar: Icon(icon, size: 18),
        visualDensity: VisualDensity.compact,
      );
    }
    
    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              roleDisplay,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog showing access denied message
void showAttendanceAccessDeniedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.block, color: Colors.red),
          SizedBox(width: 8),
          Text('Access Denied'),
        ],
      ),
      content: Text(AttendancePermissions.getAccessDeniedMessage()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Mixin for screens that require attendance permissions
mixin AttendancePermissionsMixin {
  /// Check if current user can start attendance
  bool canStartAttendance(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return AttendancePermissions.canStartAttendance(authProvider.currentUser);
  }
  
  /// Show access denied dialog if user doesn't have permission
  /// Returns true if user has permission, false otherwise
  bool checkAttendancePermission(BuildContext context) {
    if (!canStartAttendance(context)) {
      showAttendanceAccessDeniedDialog(context);
      return false;
    }
    return true;
  }
}
