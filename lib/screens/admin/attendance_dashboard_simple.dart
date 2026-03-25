import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/python_backend_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'dart:io';

class AttendanceDashboardSimple extends StatefulWidget {
  const AttendanceDashboardSimple({Key? key}) : super(key: key);

  @override
  State<AttendanceDashboardSimple> createState() => _AttendanceDashboardSimpleState();
}

class _AttendanceDashboardSimpleState extends State<AttendanceDashboardSimple> {
  final PythonBackendService _backendService = PythonBackendService();
  
  String? _selectedSubject;
  int? _selectedYear;
  String? _userDepartment;
  
  List<dynamic> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadUserDepartment();
  }
  
  Future<void> _loadUserDepartment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data();
          final dept = data?['department'];
          print('Raw department value: $dept, Type: ${dept.runtimeType}');
          
          setState(() {
            _userDepartment = dept?.toString() ?? '';
          });
          print('Converted department: $_userDepartment');
          _fetchSessions();
        }
      }
    } catch (e) {
      print('Error loading user department: $e');
    }
  }
  
  Future<void> _fetchSessions() async {
    if (_userDepartment == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final result = await _backendService.getAttendanceSessions(
        department: _userDepartment!,
        year: _selectedYear,
        subject: _selectedSubject,
      );
      
      if (result['success'] == true) {
        setState(() {
          _sessions = result['sessions'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load sessions';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  void _clearFilters() {
    setState(() {
      _selectedSubject = null;
      _selectedYear = null;
    });
    _fetchSessions();
  }
  
  Future<void> _exportAll() async {
    if (_userDepartment == null || _userDepartment!.isEmpty) {
      print('Export failed: Department is null or empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Department not loaded. Please try again.')),
        );
      }
      return;
    }
    
    try {
      print('Exporting with department: "$_userDepartment", year: $_selectedYear, subject: $_selectedSubject');
      print('Department type: ${_userDepartment.runtimeType}');
      
      final url = _backendService.getExportAllUrl(
        department: _userDepartment!,
        year: _selectedYear,
        subject: _selectedSubject,
      );
      
      print('Export URL: $url');
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading CSV...')),
        );
      }
      
      // Download the file
      final dio = Dio();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'attendance_all_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${directory.path}/$fileName';
      
      await dio.download(url, filePath);
      
      // Share the file
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Attendance Report - All Sessions',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file downloaded successfully!')),
          );
        }
      } else {
        throw Exception('File not found after download');
      }
    } catch (e) {
      print('Error exporting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: ${e.toString()}')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Dashboard'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          // Filters Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: _selectedSubject,
                        items: [
                          'DBMS',
                          'OS',
                          'CN',
                          'AI',
                          'ML',
                          'SE',
                        ].map((subject) {
                          return DropdownMenuItem(
                            value: subject,
                            child: Text(subject),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSubject = value;
                          });
                          _fetchSessions();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: _selectedYear,
                        items: [1, 2, 3, 4].map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text('Year $year'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedYear = value;
                          });
                          _fetchSessions();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear Filters'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _exportAll,
                        icon: const Icon(Icons.download),
                        label: const Text('Export All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Sessions List
          Expanded(
            child: _buildSessionsList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSessionsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSessions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No attendance sessions found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            if (_userDepartment != null) ...[
              const SizedBox(height: 8),
              Text(
                'Department: $_userDepartment',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchSessions,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchSessions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          return _buildSessionCard(session);
        },
      ),
    );
  }
  
  Widget _buildSessionCard(Map<String, dynamic> session) {
    final sessionId = session['session_id'];
    final className = session['class_name'] ?? 'Unknown';
    final year = session['year'];
    final createdByName = session['created_by_name'] ?? 'Unknown';
    final status = session['status'] ?? 'unknown';
    
    // Parse created_at
    String dateStr = 'Unknown date';
    try {
      if (session['created_at'] != null) {
        final createdAt = session['created_at'];
        if (createdAt is Timestamp) {
          final date = createdAt.toDate();
          dateStr = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
        } else if (createdAt is String) {
          dateStr = createdAt;
        }
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          className,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text('Year $year • $dateStr'),
        trailing: Chip(
          label: Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          backgroundColor: status == 'completed' ? Colors.green : Colors.orange,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created by: $createdByName'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _viewSessionDetails(sessionId),
                        icon: const Icon(Icons.visibility),
                        label: const Text('View Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _exportSession(sessionId),
                        icon: const Icon(Icons.download),
                        label: const Text('Export CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _viewSessionDetails(String sessionId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailsScreen(sessionId: sessionId),
      ),
    );
  }
  
  Future<void> _exportSession(String sessionId) async {
    try {
      final url = _backendService.getExportSessionUrl(sessionId);
      print('Export session URL: $url');
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading CSV...')),
        );
      }
      
      // Download the file
      final dio = Dio();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'attendance_session_${sessionId.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${directory.path}/$fileName';
      
      await dio.download(url, filePath);
      
      // Share the file
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Attendance Report - Session $sessionId',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file downloaded successfully!')),
          );
        }
      } else {
        throw Exception('File not found after download');
      }
    } catch (e) {
      print('Error exporting session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: ${e.toString()}')),
        );
      }
    }
  }
}

class SessionDetailsScreen extends StatefulWidget {
  final String sessionId;
  
  const SessionDetailsScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  final PythonBackendService _backendService = PythonBackendService();
  
  bool _isLoading = true;
  String? _errorMessage;
  
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _statistics;
  List<dynamic> _presentStudents = [];
  List<dynamic> _absentStudents = [];
  
  @override
  void initState() {
    super.initState();
    _loadSessionDetails();
  }
  
  Future<void> _loadSessionDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final result = await _backendService.getSessionDetails(widget.sessionId);
      
      if (result['success'] == true) {
        setState(() {
          _session = result['session'];
          _statistics = result['statistics'];
          _presentStudents = result['present_students'] ?? [];
          _absentStudents = result['absent_students'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load session details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Details'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportSession,
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSessionDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadSessionDetails,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatisticsCard(),
              const SizedBox(height: 16),
              _buildPresentList(),
              const SizedBox(height: 16),
              _buildAbsentList(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatisticsCard() {
    if (_statistics == null) return const SizedBox.shrink();
    
    final total = _statistics!['total_students'] ?? 0;
    final present = _statistics!['present_count'] ?? 0;
    final absent = _statistics!['absent_count'] ?? 0;
    final percentage = _statistics!['attendance_percentage'] ?? 0.0;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Attendance Statistics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', total.toString(), Colors.blue),
                _buildStatItem('Present', present.toString(), Colors.green),
                _buildStatItem('Absent', absent.toString(), Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 10,
              backgroundColor: Colors.red[100],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              '${percentage.toStringAsFixed(1)}% Attendance',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPresentList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Present (${_presentStudents.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (_presentStudents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No students marked present')),
              )
            else
              ..._presentStudents.map((student) {
                final name = student['name'] ?? 'Unknown';
                final rollNo = student['roll_no'] ?? 'N/A';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: const Icon(Icons.person, color: Colors.green),
                  ),
                  title: Text(name),
                  subtitle: Text('Roll No: $rollNo'),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAbsentList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Absent (${_absentStudents.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (_absentStudents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('All students present!')),
              )
            else
              ..._absentStudents.map((student) {
                final name = student['name'] ?? 'Unknown';
                final rollNo = student['roll_no'] ?? 'N/A';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red[100],
                    child: const Icon(Icons.person, color: Colors.red),
                  ),
                  title: Text(name),
                  subtitle: Text('Roll No: $rollNo'),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
  
  Future<void> _exportSession() async {
    try {
      final url = _backendService.getExportSessionUrl(widget.sessionId);
      print('Export session URL: $url');
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading CSV...')),
        );
      }
      
      // Download the file
      final dio = Dio();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'attendance_session_${widget.sessionId.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${directory.path}/$fileName';
      
      await dio.download(url, filePath);
      
      // Share the file
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Attendance Report - Session ${widget.sessionId}',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file downloaded successfully!')),
          );
        }
      } else {
        throw Exception('File not found after download');
      }
    } catch (e) {
      print('Error exporting session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: ${e.toString()}')),
        );
      }
    }
  }
}
