
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        await _loadCurrentUser();
        // Setup notifications for authenticated user
        if (_currentUser != null) {
          await _setupNotifications();
        }
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = await _authService.getCurrentUserData();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Setup notifications for current user
  Future<void> _setupNotifications() async {
    if (_currentUser != null) {
      try {
        // Save FCM token to user document
        await NotificationService.saveTokenToDatabase(_currentUser!.uid);
        
        // Subscribe to relevant topics
        await NotificationService.subscribeUserToTopics(_currentUser!);
      } catch (e) {
        // Don't fail authentication if notification setup fails
        print('Notification setup failed: $e');
      }
    }
  }

  Future<bool> signUpStudent({
    required String fullName,
    required String email,
    required String password,
    required String rollNo,
    required Department department,
    required int year,
    required List<double> embeddings,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = await _authService.signUpStudent(
        fullName: fullName,
        email: email,
        password: password,
        rollNo: rollNo,
        department: department,
        year: year,
        embeddings: embeddings,
      );

      if (user != null) {
        _currentUser = user;
        
        // Send welcome notification to new student
        await NotificationService.sendWelcomeNotification(
          user.uid,
          user.fullName,
          user.email,
        );
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUpAdmin({
    required String fullName,
    required String email,
    required String password,
    required Department department,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = await _authService.signUpAdmin(
        fullName: fullName,
        email: email,
        password: password,
        department: department,
      );

      if (user != null) {
        _currentUser = user;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addNotice({
    required String title,
    required String body,
    required Department department,
  }) async {
    await _authService.addNotice(title: title, body: body, department: department);
    
    // Send notification to all users in the department
    await NotificationService.sendNoticeNotification(
      title,
      body,
      department,
      _currentUser?.fullName ?? 'Admin',
    );
  }

  Future<bool> editNotice({
    required String noticeId,
    required String title,
    required String body,
  }) async {
    try {
      await _authService.editNotice(noticeId: noticeId, title: title, body: body);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> deleteNotice(String noticeId) async {
    try {
      await _authService.deleteNotice(noticeId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getNoticesByDepartment() async {
    try {
      if (_currentUser == null) return [];
      return await _authService.getNoticesByDepartment(_currentUser!.department);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  // Schedule management methods
  Future<void> addSchedule({
    required String title,
    required String description,
    required String time,
    required String location,
    required int year,
    required Department department,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
  }) async {
    await _authService.addSchedule(
      title: title,
      description: description,
      time: time,
      location: location,
      year: year,
      department: department,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
    );
    
    // Send notification to users in the department and year
    await NotificationService.sendScheduleNotification(
      title,
      description,
      department,
      year,
      _currentUser?.fullName ?? 'Admin',
    );
  }

  Future<bool> editSchedule({
    required String scheduleId,
    required String title,
    required String description,
    required String time,
    required String location,
    required int year,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
  }) async {
    try {
      await _authService.editSchedule(
        scheduleId: scheduleId,
        title: title,
        description: description,
        time: time,
        location: location,
        year: year,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
      );
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> deleteSchedule(String scheduleId) async {
    try {
      await _authService.deleteSchedule(scheduleId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getSchedulesByDepartment() async {
    try {
      if (_currentUser == null) return [];
      return await _authService.getSchedulesByDepartment(_currentUser!.department);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = await _authService.signIn(
        email: email,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _authService.signOut();
      _currentUser = null;
      _error = null;
      _setLoading(false);
      // Single notifyListeners call after all state changes
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
    }
  }

  Future<bool> checkAdminExists(Department department) async {
    try {
      return await _authService.isAdminExists(department);
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> promoteStudentToCR(String studentUid) async {
    try {
      await _authService.promoteStudentToCR(studentUid);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> demoteStudentFromCR(String studentUid) async {
    try {
      await _authService.demoteStudentFromCR(studentUid);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<List<UserModel>> getStudentsByDepartmentAndYear(
    Department department,
    int? year,
  ) async {
    try {
      return await _authService.getStudentsByDepartmentAndYear(department, year);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  // CR Management Methods
  Future<bool> makeCR(String studentUid) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.promoteStudentToCR(studentUid);
      // Refresh current user data if it's the same user
      if (_currentUser?.uid == studentUid) {
        await _loadCurrentUser();
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> removeCR(String studentUid) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.demoteStudentFromCR(studentUid);
      // Refresh current user data if it's the same user
      if (_currentUser?.uid == studentUid) {
        await _loadCurrentUser();
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Notification methods
  Stream<List<Map<String, dynamic>>> getUserNotifications() {
    if (_currentUser == null) {
      return Stream.value([]);
    }
    
    return NotificationService.getUserNotifications(
      _currentUser!.uid,
      _currentUser!.department,
      _currentUser!.year,
    );
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await NotificationService.markNotificationAsRead(notificationId);
  }

  Future<void> updateNotificationPreferences(Map<String, bool> preferences) async {
    if (_currentUser != null) {
      await NotificationService.updateNotificationPreferences(_currentUser!.uid, preferences);
    }
  }

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }
}
