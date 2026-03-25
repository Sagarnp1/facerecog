/// Example integration code for teacher attendance marking screen with WebSocket
/// 
/// This file demonstrates how to create or modify an attendance marking screen
/// to use the Python backend with real-time WebSocket updates.
///
/// COMPLETE EXAMPLE ATTENDANCE SCREEN:

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/python_backend_service.dart';
import '../services/attendance_websocket_service.dart';

class AttendanceMarkingScreen extends StatefulWidget {
  final String batch;
  final String faculty;
  final String? className;

  const AttendanceMarkingScreen({
    super.key,
    required this.batch,
    required this.faculty,
    this.className,
  });

  @override
  State<AttendanceMarkingScreen> createState() => _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends State<AttendanceMarkingScreen> {
  late final PythonBackendService _backendService;
  late final AttendanceWebSocketService _websocketService;
  
  String? _sessionId;
  int _totalStudents = 0;
  final Set<String> _presentStudents = {};
  final Map<String, StudentInfo> _studentMap = {};
  
  bool _isLoading = false;
  bool _isSessionActive = false;
  String _statusMessage = 'Ready to start attendance';
  
  @override
  void initState() {
    super.initState();
    _backendService = PythonBackendService(
      attendanceUrl: 'http://localhost:8000',
    );
    _websocketService = AttendanceWebSocketService(
      baseUrl: 'ws://localhost:8000',
    );
    
    // Listen to WebSocket updates
    _websocketService.updateStream.listen(_handleWebSocketUpdate);
    _websocketService.connectionStream.listen(_handleConnectionStatus);
  }
  
  @override
  void dispose() {
    _websocketService.dispose();
    super.dispose();
  }
  
  /// Start attendance session
  Future<void> _startAttendance() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Starting attendance session...';
    });
    
    try {
      // Test connection first
      final connectionTest = await _backendService.testConnection(isAttendance: true);
      if (!connectionTest['success']) {
        _showErrorDialog(
          'Connection Error',
          'Cannot connect to Python backend.\n\n'
          '${connectionTest['message']}\n\n'
          'Please ensure:\n'
          '1. Python backend is running (python main.py)\n'
          '2. Server is accessible at http://localhost:8000\n'
          '3. Webcam is connected and available'
        );
        setState(() => _isLoading = false);
        return;
      }
      
      // Start session
      final result = await _backendService.startAttendanceSession(
        batch: widget.batch,
        faculty: widget.faculty,
        className: widget.className,
      );
      
      if (!result['success']) {
        _showErrorDialog('Error', result['message'] ?? 'Failed to start session');
        setState(() => _isLoading = false);
        return;
      }
      
      // Get session details
      _sessionId = result['session_id'];
      _totalStudents = result['total_students'] ?? 0;
      
      // Load student data from Firestore for display
      await _loadStudentData();
      
      // Connect WebSocket
      await _websocketService.connect(_sessionId!);
      
      setState(() {
        _isSessionActive = true;
        _isLoading = false;
        _statusMessage = 'Session active - Scanning for faces...';
      });
      
    } catch (e) {
      _showErrorDialog('Error', 'Failed to start attendance: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }
  
  /// Stop attendance session
  Future<void> _stopAttendance() async {
    if (_sessionId == null) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Stopping attendance session...';
    });
    
    try {
      // Disconnect WebSocket
      await _websocketService.disconnect();
      
      // Stop session on backend
      final result = await _backendService.stopAttendanceSession(_sessionId!);
      
      if (result['success']) {
        // Show summary dialog
        _showSummaryDialog(result);
      }
      
      setState(() {
        _isSessionActive = false;
        _isLoading = false;
        _statusMessage = 'Session ended';
      });
      
    } catch (e) {
      _showErrorDialog('Error', 'Failed to stop attendance: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }
  
  /// Load student data from Firestore
  Future<void> _loadStudentData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('batch', isEqualTo: widget.batch)
          .where('faculty', isEqualTo: widget.faculty)
          .get();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _studentMap[doc.id] = StudentInfo(
          id: doc.id,
          name: data['full_name'] ?? '',
          rollNo: data['roll_no'] ?? '',
        );
      }
      
      setState(() {});
    } catch (e) {
      print('Error loading students: $e');
    }
  }
  
  /// Handle WebSocket updates
  void _handleWebSocketUpdate(AttendanceUpdate update) {
    setState(() {
      if (update.isAttendanceMarked) {
        // Student marked present
        _presentStudents.add(update.studentId!);
        _statusMessage = 'Marked: ${update.name} (${update.rollNo})';
        
        // Show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${update.name} - ${update.rollNo}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (update.isError) {
        _statusMessage = 'Error: ${update.message}';
      } else if (update.isStatus) {
        _statusMessage = update.message ?? 'Scanning...';
      } else if (update.isSessionStarted) {
        _statusMessage = update.message ?? 'Session started';
      } else if (update.isWebcamReady) {
        _statusMessage = update.message ?? 'Webcam ready';
      }
    });
  }
  
  /// Handle connection status changes
  void _handleConnectionStatus(bool isConnected) {
    if (!isConnected && _isSessionActive) {
      setState(() {
        _statusMessage = 'Disconnected from server';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WebSocket disconnected'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  
  /// Show error dialog
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Show attendance summary dialog
  void _showSummaryDialog(Map<String, dynamic> summary) {
    final presentCount = summary['present_count'] ?? 0;
    final totalStudents = summary['total_students'] ?? 0;
    final percentage = summary['attendance_percentage'] ?? 0.0;
    final absentStudents = summary['absent_students'] as List? ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendance Summary'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Students: $totalStudents'),
              Text('Present: $presentCount'),
              Text('Absent: ${absentStudents.length}'),
              Text('Percentage: ${percentage.toStringAsFixed(2)}%'),
              const SizedBox(height: 16),
              if (absentStudents.isNotEmpty) ...[
                const Text('Absent Students:', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...absentStudents.map((student) => Text(
                  '• ${student['name']} (${student['roll_no']})'
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final attendancePercentage = _totalStudents > 0
        ? (_presentStudents.length / _totalStudents * 100)
        : 0.0;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - ${widget.batch}'),
        actions: [
          if (_isSessionActive)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _isLoading ? null : _stopAttendance,
              tooltip: 'Stop Attendance',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Card(
            margin: const EdgeInsets.all(16),
            color: _isSessionActive ? Colors.green[50] : Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _isSessionActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: _isSessionActive ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_statusMessage),
                ],
              ),
            ),
          ),
          
          // Statistics Card
          if (_totalStudents > 0)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Total',
                      _totalStudents.toString(),
                      Colors.blue,
                    ),
                    _buildStatItem(
                      'Present',
                      _presentStudents.length.toString(),
                      Colors.green,
                    ),
                    _buildStatItem(
                      'Absent',
                      (_totalStudents - _presentStudents.length).toString(),
                      Colors.red,
                    ),
                    _buildStatItem(
                      'Percentage',
                      '${attendancePercentage.toStringAsFixed(1)}%',
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Student List
          Expanded(
            child: _studentMap.isEmpty
                ? const Center(child: Text('No students loaded'))
                : ListView.builder(
                    itemCount: _studentMap.length,
                    itemBuilder: (context, index) {
                      final student = _studentMap.values.elementAt(index);
                      final isPresent = _presentStudents.contains(student.id);
                      
                      return ListTile(
                        leading: Icon(
                          isPresent ? Icons.check_circle : Icons.circle_outlined,
                          color: isPresent ? Colors.green : Colors.grey,
                        ),
                        title: Text(student.name),
                        subtitle: Text(student.rollNo),
                        trailing: isPresent
                            ? Chip(
                                label: const Text('Present'),
                                backgroundColor: Colors.green[100],
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
      
      // Start Button
      floatingActionButton: !_isSessionActive && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _startAttendance,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Attendance'),
            )
          : null,
    );
  }
  
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class StudentInfo {
  final String id;
  final String name;
  final String rollNo;
  
  StudentInfo({
    required this.id,
    required this.name,
    required this.rollNo,
  });
}

/// USAGE NOTES:
/// 
/// 1. Navigation to this screen:
///    ```dart
///    Navigator.push(
///      context,
///      MaterialPageRoute(
///        builder: (context) => AttendanceMarkingScreen(
///          batch: '2021',
///          faculty: 'Computer Science',
///          className: 'Data Structures',
///        ),
///      ),
///    );
///    ```
///
/// 2. Python backend must be running on teacher's laptop:
///    - Open terminal in python_backend folder
///    - Run: python main.py
///    - Ensure webcam is connected and accessible
///
/// 3. The screen will:
///    - Connect to http://localhost:8000 for REST API
///    - Connect to ws://localhost:8000 for WebSocket
///    - Show real-time updates as students are recognized
///    - Display attendance statistics
///    - Allow stopping the session anytime
///
/// 4. Error handling:
///    - Shows clear messages if backend not running
///    - Guides teacher on how to fix issues
///    - Handles WebSocket disconnections gracefully
