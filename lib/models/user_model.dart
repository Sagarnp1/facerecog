import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, admin }

enum Department { BEI, BCT, BCE, BAG, BEL, BME, BAR }

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final UserRole role;
  final Department department;
  final int? year; // Only for students
  final String? rollNo; // Roll number for students
  final bool isCR;
  final List<double>? embeddings; // Face embeddings for students
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    required this.department,
    this.year,
    this.rollNo,
    this.isCR = false,
    this.embeddings,
    required this.createdAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role.name,
      'department': department.name,
      'year': year,
      'rollNo': rollNo,
      'isCR': isCR,
      'embeddings': embeddings,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.student,
      ),
      department: Department.values.firstWhere(
        (e) => e.name == map['department'],
        orElse: () => Department.BCT,
      ),
      year: map['year'],
      rollNo: map['rollNo'],
      isCR: map['isCR'] ?? false,
      embeddings: map['embeddings'] != null 
          ? List<double>.from(map['embeddings']) 
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    UserRole? role,
    Department? department,
    int? year,
    String? rollNo,
    bool? isCR,
    List<double>? embeddings,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      year: year ?? this.year,
      rollNo: rollNo ?? this.rollNo,
      isCR: isCR ?? this.isCR,
      embeddings: embeddings ?? this.embeddings,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
