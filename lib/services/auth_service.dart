
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ioe/utils/theme.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user data from Firestore
  Future<UserModel?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserModel.fromMap(doc.data()!);
  }

  // Check if admin exists for department (using tracking collection for better performance)
  Future<bool> isAdminExists(Department department) async {
    final doc = await _firestore
        .collection('department_admins')
        .doc(department.name)
        .get();
    return doc.exists;
  }

  // Student signup
  Future<UserModel?> signUpStudent({
    required String fullName,
    required String email,
    required String password,
    required String rollNo,
    required Department department,
    required int year,
    required List<double> embeddings,
  }) async {
    try {
      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Failed to create user');

      // Create user document in Firestore
      final userModel = UserModel(
        uid: user.uid,
        fullName: fullName,
        email: email,
        role: UserRole.student,
        department: department,
        year: year,
        rollNo: rollNo,
        isCR: false,
        embeddings: embeddings,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());

      return userModel;
    } catch (e) {
      throw Exception('Student signup failed: $e');
    }
  }

  // Admin signup
  Future<UserModel?> signUpAdmin({
    required String fullName,
    required String email,
    required String password,
    required Department department,
  }) async {
    try {
      // Check if admin already exists for this department
      if (await isAdminExists(department)) {
        throw Exception('Nice try bro, but admin already exists for ${department.displayName} department! 😎\nOnly one admin per department allowed!');
      }

      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Failed to create user');

      // Create user document in Firestore
      final userModel = UserModel(
        uid: user.uid,
        fullName: fullName,
        email: email,
        role: UserRole.admin,
        department: department,
        isCR: false,
        createdAt: DateTime.now(),
      );

      // Use batch write to ensure atomicity
      final batch = _firestore.batch();
      
      // Add user document
      batch.set(_firestore.collection('users').doc(user.uid), userModel.toMap());
      
      // Add department admin tracking document
      batch.set(_firestore.collection('department_admins').doc(department.name), {
        'adminId': user.uid,
        'department': department.name,
        'createdAt': Timestamp.now(),
      });
      
      // Commit the batch
      await batch.commit();

      return userModel;
    } catch (e) {
      throw Exception('Admin signup failed: $e');
    }
  }

  // Sign in
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Failed to sign in');

      return await getCurrentUserData();
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Promote student to CR
  Future<void> promoteStudentToCR(String studentUid) async {
    try {
      await _firestore.collection('users').doc(studentUid).update({
        'isCR': true,
      });
    } catch (e) {
      throw Exception('Failed to promote student to CR: $e');
    }
  }

  // Demote CR to regular student
  Future<void> demoteStudentFromCR(String studentUid) async {
    try {
      await _firestore.collection('users').doc(studentUid).update({
        'isCR': false,
      });
    } catch (e) {
      throw Exception('Failed to demote student from CR: $e');
    }
  }

  // Get students by department and year (for admin)
  Future<List<UserModel>> getStudentsByDepartmentAndYear(
    Department department,
    int? year,
  ) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('department', isEqualTo: department.name);

      if (year != null) {
        query = query.where('year', isEqualTo: year);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get students: $e');
    }
  }

  // Add notice to Firestore
  Future<void> addNotice({
    required String title,
    required String body,
    required Department department,
    String? postedBy,
    String? postedByName,
    String? postedByRole,
  }) async {
    final doc = _firestore.collection('notices').doc();
    await doc.set({
      'id': doc.id,
      'title': title,
      'body': body,
      'department': department.name,
      'createdAt': Timestamp.now(),
      if (postedBy != null) 'postedBy': postedBy,
      if (postedByName != null) 'postedByName': postedByName,
      if (postedByRole != null) 'postedByRole': postedByRole,
    });
  }

  // Edit notice in Firestore
  Future<void> editNotice({
    required String noticeId,
    required String title,
    required String body,
  }) async {
    await _firestore.collection('notices').doc(noticeId).update({
      'title': title,
      'body': body,
    });
  }

  // Delete notice from Firestore
  Future<void> deleteNotice(String noticeId) async {
    await _firestore.collection('notices').doc(noticeId).delete();
  }

  // Get notices by department
  Future<List<Map<String, dynamic>>> getNoticesByDepartment(Department department) async {
    final snapshot = await _firestore
        .collection('notices')
        .where('department', isEqualTo: department.name)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Schedule management methods

  // Add schedule to Firestore
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
    String? postedBy,
    String? postedByName,
    String? postedByRole,
  }) async {
    final doc = _firestore.collection('schedules').doc();
    await doc.set({
      'id': doc.id,
      'title': title,
      'description': description,
      'time': time,
      'location': location,
      'year': year,
      'department': department.name,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'postedBy': postedBy,
      'postedByName': postedByName,
      'postedByRole': postedByRole,
      'createdAt': Timestamp.now(),
    });
  }

  // Edit schedule in Firestore
  Future<void> editSchedule({
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
    await _firestore.collection('schedules').doc(scheduleId).update({
      'title': title,
      'description': description,
      'time': time,
      'location': location,
      'year': year,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    });
  }

  // Delete schedule from Firestore
  Future<void> deleteSchedule(String scheduleId) async {
    await _firestore.collection('schedules').doc(scheduleId).delete();
  }

  // Get schedules by department
  Future<List<Map<String, dynamic>>> getSchedulesByDepartment(Department department) async {
    final snapshot = await _firestore
        .collection('schedules')
        .where('department', isEqualTo: department.name)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
