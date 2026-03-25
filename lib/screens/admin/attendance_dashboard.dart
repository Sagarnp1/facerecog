import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/user_model.dart';
import '../../services/auth_provider.dart';

class AttendanceDashboard extends StatefulWidget {
  const AttendanceDashboard({super.key});

  @override
  State<AttendanceDashboard> createState() => _AttendanceDashboardState();
}

class _AttendanceDashboardState extends State<AttendanceDashboard> {
  String? _selectedSubject;
  String? _selectedYear;
  DateTime? _selectedDate;
  List<String> _subjects = [];
  
  UserModel? get currentUser {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.currentUser;
  }
  
  bool get isAdmin => currentUser?.role == UserRole.admin;
  bool get canViewAttendance => isAdmin || (currentUser?.isCR == true);

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final user = currentUser;
      if (user == null) return;

      // Get unique subjects from attendance_sessions for this department
      final sessions = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .where('department', isEqualTo: user.department)
          .get();

      final subjects = <String>{};
      for (var doc in sessions.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final className = data['class_name'] as String?;
        if (className != null && className.isNotEmpty) {
          subjects.add(className);
        }
      }

      setState(() {
        _subjects = subjects.toList()..sort();
      });
    } catch (e) {
      print('Error loading subjects: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canViewAttendance) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Attendance Dashboard'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Only Admins and CRs can view attendance'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Dashboard'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: 'Export All Attendance',
              onPressed: _exportAllAttendance,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Subject Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubject,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Subjects'),
                          ),
                          ..._subjects.map((subject) => DropdownMenuItem(
                                value: subject,
                                child: Text(subject),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedSubject = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Year Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All Years')),
                          DropdownMenuItem(value: '1', child: Text('Year 1')),
                          DropdownMenuItem(value: '2', child: Text('Year 2')),
                          DropdownMenuItem(value: '3', child: Text('Year 3')),
                          DropdownMenuItem(value: '4', child: Text('Year 4')),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedYear = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Date Filter
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _selectedDate == null
                          ? 'All Dates'
                          : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                    ),
                  ),
                ),
                if (_selectedDate != null || _selectedSubject != null || _selectedYear != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedSubject = null;
                          _selectedYear = null;
                          _selectedDate = null;
                        });
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear Filters'),
                    ),
                  ),
              ],
            ),
          ),
          
          // Attendance Sessions List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getAttendanceSessionsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('Stream error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                print('Received ${snapshot.data?.docs.length ?? 0} sessions');

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No attendance sessions found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Department: ${currentUser?.department ?? "Unknown"}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  );
                }

                final sessions = snapshot.data!.docs.toList();
                
                print('DEBUG: Total sessions received: ${sessions.length}');
                for (var i = 0; i < sessions.length; i++) {
                  try {
                    final data = sessions[i].data() as Map<String, dynamic>;
                    print('DEBUG: Session $i - ID: ${sessions[i].id}');
                    print('DEBUG: Session $i - Data: $data');
                  } catch (e) {
                    print('DEBUG: Error reading session $i: $e');
                  }
                }
                
                // Sort sessions by created_at timestamp (newest first)
                sessions.sort((a, b) {
                  try {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = (aData['created_at'] as Timestamp?)?.toDate();
                    final bTime = (bData['created_at'] as Timestamp?)?.toDate();
                    
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    
                    return bTime.compareTo(aTime); // Descending order (newest first)
                  } catch (e) {
                    print('DEBUG: Error sorting sessions: $e');
                    return 0;
                  }
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final data = session.data() as Map<String, dynamic>;
                    return _buildSessionCard(session.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getAttendanceSessionsStream() {
    final user = currentUser;
    if (user == null) return const Stream.empty();

    Query query = FirebaseFirestore.instance
        .collection('attendance_sessions')
        .where('department', isEqualTo: user.department);

    // Apply filters
    if (_selectedYear != null) {
      query = query.where('year', isEqualTo: int.parse(_selectedYear!));
    }

    if (_selectedSubject != null) {
      query = query.where('class_name', isEqualTo: _selectedSubject);
    }

    return query.snapshots();
  }

  Widget _buildSessionCard(String sessionId, Map<String, dynamic> data) {
    final className = data['class_name'] ?? 'N/A';
    final year = data['year']?.toString() ?? 'N/A';
    final timestamp = (data['created_at'] as Timestamp?)?.toDate();
    final createdBy = data['created_by_name'] ?? 'Unknown';
    final status = data['status'] ?? 'unknown';

    // Filter by date if selected
    if (_selectedDate != null && timestamp != null) {
      if (!_isSameDay(timestamp, _selectedDate!)) {
        return const SizedBox.shrink();
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: status == 'active' ? Colors.green : Colors.grey,
          child: const Icon(Icons.event, color: Colors.white),
        ),
        title: Text(
          className,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Year $year • By $createdBy'),
            if (timestamp != null)
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp),
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.download, size: 20),
                tooltip: 'Export Session',
                onPressed: () => _exportSession(sessionId, data),
              ),
            Chip(
              label: Text(
                status.toUpperCase(),
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: status == 'active' ? Colors.green[100] : Colors.grey[200],
            ),
          ],
        ),
        children: [
          _buildSessionDetails(sessionId, data),
        ],
      ),
    );
  }

  Widget _buildSessionDetails(String sessionId, Map<String, dynamic> sessionData) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('session_id', isEqualTo: sessionId)
          .snapshots(),
      builder: (context, attendanceSnapshot) {
        if (!attendanceSnapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final attendanceRecords = attendanceSnapshot.data!.docs;
        final presentStudentIds = attendanceRecords
            .map((doc) => (doc.data() as Map<String, dynamic>)['student_id'] as String?)
            .where((id) => id != null)
            .toSet();

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .where('department', isEqualTo: sessionData['department'])
              .where('year', isEqualTo: sessionData['year'])
              .get(),
          builder: (context, studentsSnapshot) {
            if (!studentsSnapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final allStudents = studentsSnapshot.data!.docs;
            final totalStudents = allStudents.length;
            final presentCount = presentStudentIds.length;
            final absentCount = totalStudents - presentCount;
            final percentage = totalStudents > 0 
                ? (presentCount / totalStudents * 100).toStringAsFixed(1) 
                : '0.0';

            final presentStudents = allStudents
                .where((doc) => presentStudentIds.contains(doc.id))
                .toList();
            final absentStudents = allStudents
                .where((doc) => !presentStudentIds.contains(doc.id))
                .toList();

            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatChip('Total', totalStudents.toString(), Colors.blue),
                      _buildStatChip('Present', presentCount.toString(), Colors.green),
                      _buildStatChip('Absent', absentCount.toString(), Colors.red),
                      _buildStatChip('Rate', '$percentage%', Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Present Students
                  ExpansionTile(
                    title: Text('Present Students ($presentCount)'),
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    children: [
                      if (presentStudents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No students marked present'),
                        )
                      else
                        ...presentStudents.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final attendanceRecord = attendanceRecords
                              .firstWhere((a) => (a.data() as Map<String, dynamic>)['student_id'] == doc.id)
                              .data() as Map<String, dynamic>;
                          final markedAt = attendanceRecord['marked_at'] as String?;
                          
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.person, color: Colors.green, size: 20),
                            title: Text(data['fullName'] ?? 'Unknown'),
                            subtitle: Text(data['rollNo'] ?? 'N/A'),
                            trailing: markedAt != null 
                                ? Text(
                                    DateFormat('hh:mm a').format(DateTime.parse(markedAt)),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  )
                                : null,
                          );
                        }),
                    ],
                  ),
                  
                  const Divider(),
                  
                  // Absent Students
                  ExpansionTile(
                    title: Text('Absent Students ($absentCount)'),
                    leading: const Icon(Icons.cancel, color: Colors.red),
                    children: [
                      if (absentStudents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('All students present!'),
                        )
                      else
                        ...absentStudents.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_outline, color: Colors.red, size: 20),
                            title: Text(data['fullName'] ?? 'Unknown'),
                            subtitle: Text(data['rollNo'] ?? 'N/A'),
                          );
                        }),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _exportSession(String sessionId, Map<String, dynamic> sessionData) async {
    try {
      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get attendance records
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('session_id', isEqualTo: sessionId)
          .get();

      final presentStudentIds = attendanceSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['student_id'] as String?)
          .where((id) => id != null)
          .toSet();

      // Get all students for this session
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('department', isEqualTo: sessionData['department'])
          .where('year', isEqualTo: sessionData['year'])
          .get();

      // Create CSV data
      final List<List<dynamic>> rows = [
        ['Roll No', 'Name', 'Status', 'Time Marked'],
      ];

      for (var doc in studentsSnapshot.docs) {
        final data = doc.data();
        final isPresent = presentStudentIds.contains(doc.id);
        final attendanceRecord = isPresent
            ? attendanceSnapshot.docs.firstWhere((a) => (a.data() as Map<String, dynamic>)['student_id'] == doc.id).data() as Map<String, dynamic>
            : null;
        final markedAt = attendanceRecord?['marked_at'] as String?;

        rows.add([
          data['rollNo'] ?? 'N/A',
          data['fullName'] ?? 'Unknown',
          isPresent ? 'Present' : 'Absent',
          markedAt != null 
              ? DateFormat('hh:mm a').format(DateTime.parse(markedAt))
              : '-',
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      
      // Save and share CSV file
      final directory = await getApplicationDocumentsDirectory();
      final className = sessionData['class_name'] ?? 'attendance';
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/attendance_${className}_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csv);

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Share the file
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Attendance - $className',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Attendance exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAllAttendance() async {
    try {
      final user = currentUser;
      if (user == null) return;

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get all sessions
      Query query = FirebaseFirestore.instance
          .collection('attendance_sessions')
          .where('department', isEqualTo: user.department);

      // Apply filters
      if (_selectedYear != null) {
        query = query.where('year', isEqualTo: int.parse(_selectedYear!));
      }
      if (_selectedSubject != null) {
        query = query.where('class_name', isEqualTo: _selectedSubject);
      }

      final sessionsSnapshot = await query.get();
      
      // Sort sessions by created_at (oldest first for export)
      final sortedSessions = sessionsSnapshot.docs.toList();
      sortedSessions.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aTime = (aData['created_at'] as Timestamp?)?.toDate();
        final bTime = (bData['created_at'] as Timestamp?)?.toDate();
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        return aTime.compareTo(bTime); // Ascending order (oldest first)
      });

      // Create CSV data
      final List<List<dynamic>> rows = [
        ['Date', 'Subject', 'Year', 'Roll No', 'Name', 'Status', 'Time Marked'],
      ];

      for (var sessionDoc in sortedSessions) {
        final sessionData = sessionDoc.data() as Map<String, dynamic>;
        final sessionId = sessionDoc.id;
        final className = sessionData['class_name'] ?? 'N/A';
        final year = sessionData['year']?.toString() ?? 'N/A';
        final sessionDate = (sessionData['created_at'] as Timestamp?)?.toDate();

        // Get attendance for this session
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('session_id', isEqualTo: sessionId)
            .get();

        final presentStudentIds = attendanceSnapshot.docs
            .map((doc) => (doc.data() as Map<String, dynamic>)['student_id'] as String?)
            .where((id) => id != null)
            .toSet();

        // Get all students
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .where('department', isEqualTo: sessionData['department'])
            .where('year', isEqualTo: sessionData['year'])
            .get();

        for (var studentDoc in studentsSnapshot.docs) {
          final studentData = studentDoc.data();
          final isPresent = presentStudentIds.contains(studentDoc.id);
          final attendanceRecord = isPresent
              ? attendanceSnapshot.docs
                  .firstWhere((a) => (a.data() as Map<String, dynamic>)['student_id'] == studentDoc.id)
                  .data() as Map<String, dynamic>
              : null;
          final markedAt = attendanceRecord?['marked_at'] as String?;

          rows.add([
            sessionDate != null 
                ? DateFormat('MMM dd, yyyy').format(sessionDate)
                : 'N/A',
            className,
            year,
            studentData['rollNo'] ?? 'N/A',
            studentData['fullName'] ?? 'Unknown',
            isPresent ? 'Present' : 'Absent',
            markedAt != null 
                ? DateFormat('hh:mm a').format(DateTime.parse(markedAt))
                : '-',
          ]);
        }
      }

      final csv = const ListToCsvConverter().convert(rows);
      
      // Save and share CSV file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/attendance_all_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csv);

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Share the file
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'All Attendance Records',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ All attendance exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
