import 'package:flutter/material.dart';
import '../models/user_model.dart';

// Simple authentication provider without Firebase for testing
class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  // Mock sign up student
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

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      // Create mock user
      _currentUser = UserModel(
        uid: 'student_${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName,
        email: email,
        role: UserRole.student,
        department: department,
        year: year,
        isCR: false,
        embeddings: embeddings,
        createdAt: DateTime.now(),
      );

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Mock sign up admin
  Future<bool> signUpAdmin({
    required String fullName,
    required String email,
    required String password,
    required Department department,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      // Create mock user
      _currentUser = UserModel(
        uid: 'admin_${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName,
        email: email,
        role: UserRole.admin,
        department: department,
        isCR: false,
        createdAt: DateTime.now(),
      );

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Mock sign in
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Mock successful login - create a test user
      if (email.contains('admin')) {
        _currentUser = UserModel(
          uid: 'admin_test',
          fullName: 'Test Admin',
          email: email,
          role: UserRole.admin,
          department: Department.BCT,
          isCR: false,
          createdAt: DateTime.now(),
        );
      } else {
        _currentUser = UserModel(
          uid: 'student_test',
          fullName: 'Test Student',
          email: email,
          role: UserRole.student,
          department: Department.BCT,
          year: 3,
          isCR: false,
          embeddings: List.filled(512, 0.5),
          createdAt: DateTime.now(),
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Mock sign out
  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }

  // Mock check admin exists
  Future<bool> checkAdminExists(Department department) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Return false to allow admin creation for testing
    return false;
  }

  // Mock promote student to CR
  Future<bool> promoteStudentToCR(String studentUid) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Mock demote student from CR
  Future<bool> demoteStudentFromCR(String studentUid) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Mock get students by department and year
  Future<List<UserModel>> getStudentsByDepartmentAndYear(
    Department department,
    int? year,
  ) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      return []; // Return empty list for now
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

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }
}
