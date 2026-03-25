import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleModel {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final String department;
  final int? year; // null means all years
  final String createdBy;
  final DateTime createdAt;

  ScheduleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.department,
    this.year,
    required this.createdBy,
    required this.createdAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': Timestamp.fromDate(dateTime),
      'department': department,
      'year': year,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore document
  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      department: map['department'] ?? '',
      year: map['year'],
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Create a copy with modifications
  ScheduleModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? department,
    int? year,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      department: department ?? this.department,
      year: year ?? this.year,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
