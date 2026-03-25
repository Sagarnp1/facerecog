import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

enum PostType { notice, schedule }

class PostModel {
  final String id;
  final String title;
  final String content;
  final Department department;
  final String? year; // "all" or specific year like "2"
  final PostType type;
  final String createdBy; // "admin" or CR user ID
  final DateTime createdAt;
  final DateTime? updatedAt;

  PostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.department,
    this.year = "all",
    required this.type,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'department': department.name,
      'year': year,
      'type': type.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create from Firestore document
  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      department: Department.values.firstWhere(
        (e) => e.name == map['department'],
        orElse: () => Department.BCT,
      ),
      year: map['year'] ?? "all",
      type: PostType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PostType.notice,
      ),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  PostModel copyWith({
    String? id,
    String? title,
    String? content,
    Department? department,
    String? year,
    PostType? type,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      department: department ?? this.department,
      year: year ?? this.year,
      type: type ?? this.type,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
