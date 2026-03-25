import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class NoticeModel {
  final String id;
  final String title;
  final String body;
  final Department department;
  final DateTime createdAt;

  NoticeModel({
    required this.id,
    required this.title,
    required this.body,
    required this.department,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'department': department.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NoticeModel.fromMap(Map<String, dynamic> map) {
    return NoticeModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      department: Department.values.firstWhere(
        (e) => e.name == map['department'],
        orElse: () => Department.BCT,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
