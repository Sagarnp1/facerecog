/// Role-Based Attendance Marking Screen
/// 
/// This screen implements attendance marking with role-based access control.
/// Only Admins and CRs (Class Representatives) can start attendance sessions.
/// 
/// Usage:
/// - Check user role before navigating to this screen
/// - Or use the built-in role check that hides the start button

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/python_backend_service.dart';
import '../services/attendance_websocket_service.dart';
import '../services/auth_provider.dart';
import '../models/user_model.dart';

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
  
  // Get current user
  UserModel? get currentUser {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.currentUser;
  }
  
  // Check if user can start attendance (Admin or CR only)
  bool get canStartAttendance {
    final user = currentUser;
    if (user == null) return false;
    
    // Admin can always start attendance
    if (user.role == UserRole.admin) return true;
    
    // CR (Class Representative) can start attendance
    if (user.isCR) return true;
    
    return false;
  }
  
  @override
  void initState() {
    super.initState();
    _backendService = PythonBackendService(
      attendanceUrl: 'http://10.172.135.246:8000',
    );
    _websocketService = AttendanceWebSocketService(
      baseUrl: 'ws://10.172.135.246:8000',
    );
    
    // Listen to WebSocket updates
    _websocketService.updateStream.listen(_handleWebSocketUpdate);
    _websocketService.connectionStream.listen(_handleConnectionStatus);
    
    // Check access on init
    if (!canStartAttendance) {
      _showAccessDeniedDialog();
    }
  }
  
  @override
  void dispose() {
    _websocketService.dispose();
    super.dispose();
  }
  
  /// Show access denied dialog for unauthorized users
  void _showAccessDeniedDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Access Denied'),
          content: const Text(
            'Only Admins and Class Representatives (CR) can start attendance marking.\n\n'
            'If you believe this is an error, please contact your administrator.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }
  
  /// Start attendance session
  Future<void> _startAttendance() async {
    // Double-check permissions
    if (!canStartAttendance) {
      _showAccessDeniedDialog();
      return;
    }
    
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
          '2. Server is accessible at http://10.172.135.246:8000\n'
          '3. Webcam is connected and available'
        );
        setState(() => _isLoading = false);
        return;
      }
      
      // Start session
      final user = currentUser;
      final result = await _backendService.startAttendanceSession(
        batch: widget.batch,
        faculty: widget.faculty,
        className: widget.className,
        createdBy: user?.uid,
        createdByName: user?.fullName,
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
      
      // Log session start
      _logAttendanceSession('started');
      
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
        // Log session end
        _logAttendanceSession('stopped', result);
        
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
  
  /// Log attendance session activity
  Future<void> _logAttendanceSession(String action, [Map<String, dynamic>? result]) async {
    try {
      final user = currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection('attendance_logs')
          .add({
        'session_id': _sessionId,
        'action': action,
        'initiated_by': user.uid,
        'initiated_by_name': user.fullName,
        'user_role': user.role.name,
        'is_cr': user.isCR,
        'batch': widget.batch,
        'faculty': widget.faculty,
        'class_name': widget.className,
        'timestamp': FieldValue.serverTimestamp(),
        if (result != null) ...{
          'total_students': result['total_students'],
          'present_count': result['present_count'],
          'attendance_percentage': result['attendance_percentage'],
        }
      });
    } catch (e) {
      print('Error logging session: $e');
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
    
    final user = currentUser;
    final userDisplayRole = user?.role == UserRole.admin 
        ? 'Admin' 
        : (user?.isCR ?? false) ? 'CR' : 'Student';
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - ${widget.batch}'),
        actions: [
          // Show user role badge
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(userDisplayRole),
                backgroundColor: user.role == UserRole.admin 
                    ? Colors.red[100] 
                    : user.isCR ? Colors.blue[100] : Colors.grey[200],
                avatar: Icon(
                  user.role == UserRole.admin 
                      ? Icons.admin_panel_settings 
                      : user.isCR ? Icons.star : Icons.person,
                  size: 18,
                ),
              ),
            ),
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
          // Access warning for non-authorized users
          if (!canStartAttendance)
            Container(
              color: Colors.orange[100],
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only Admins and CRs can start attendance',
                      style: TextStyle(color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),
          
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
      
      // Start/Stop Button (only visible to Admin and CR)
      floatingActionButton: canStartAttendance && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _isSessionActive ? _stopAttendance : _startAttendance,
              icon: Icon(_isSessionActive ? Icons.stop : Icons.play_arrow),
              label: Text(_isSessionActive ? 'Stop Attendance' : 'Start Attendance'),
              backgroundColor: _isSessionActive ? Colors.red : null,
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
/// 1. Navigation to this screen - WITH ROLE CHECK:
///    ```dart
///    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
///    
///    // Check if user can start attendance
///    if (user?.role == UserRole.admin || user?.isCR == true) {
///      Navigator.push(
///        context,
///        MaterialPageRoute(
///          builder: (context) => AttendanceMarkingScreen(
///            batch: '2021',
///            faculty: 'Computer Science',
///            className: 'Data Structures',
///          ),
///        ),
///      );
///    } else {
///      ScaffoldMessenger.of(context).showSnackBar(
///        const SnackBar(
///          content: Text('Only Admins and CRs can mark attendance'),
///          backgroundColor: Colors.red,
///        ),
///      );
///    }
///    ```
///
/// 2. Alternative: Screen handles access control internally
///    User can navigate, but screen shows access denied dialog
///    ```dart
///    Navigator.push(
///      context,
///      MaterialPageRoute(
///        builder: (context) => AttendanceMarkingScreen(
///          batch: '2021',
///          faculty: 'Computer Science',
///        ),
///      ),
///    );
///    // Screen will show access denied if user is not admin/CR
///    ```
///
/// 3. Python backend must be running on Admin/CR's laptop:
///    - Open terminal in python_backend folder
///    - Run: python main.py
///    - Ensure webcam is connected and accessible
///
/// 4. Firestore attendance_logs collection structure:
///    ```json
///    {
///      "session_id": "uuid",
///      "action": "started" | "stopped",
///      "initiated_by": "user_uid",
///      "initiated_by_name": "John Doe",
///      "user_role": "admin" | "student",
///      "is_cr": true/false,
///      "batch": "2021",
///      "faculty": "Computer Science",
///      "class_name": "Data Structures",
///      "timestamp": Timestamp,
///      "total_students": 45,      // Only on "stopped"
///      "present_count": 42,       // Only on "stopped"
///      "attendance_percentage": 93.33  // Only on "stopped"
///    }
///    ```
///
/// 5. The screen will:
///    - Check user role/CR status
///    - Show warning banner if user cannot start attendance
///    - Hide start button for unauthorized users
///    - Log who initiated each attendance session
///    - Show real-time updates as students are recognized
///    - Display attendance statistics
///    - Allow stopping the session anytime
///
/// 6. Error handling:
///    - Shows access denied dialog for unauthorized users
///    - Shows clear messages if backend not running
///    - Guides admin/CR on how to fix issues
///    - Handles WebSocket disconnections gracefully
