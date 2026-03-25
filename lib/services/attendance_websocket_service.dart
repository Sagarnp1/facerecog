import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

/// Model for attendance update events
class AttendanceUpdate {
  final String type;
  final String? studentId;
  final String? name;
  final String? rollNo;
  final String? timestamp;
  final int? presentCount;
  final int? totalStudents;
  final String? message;
  
  AttendanceUpdate({
    required this.type,
    this.studentId,
    this.name,
    this.rollNo,
    this.timestamp,
    this.presentCount,
    this.totalStudents,
    this.message,
  });
  
  factory AttendanceUpdate.fromJson(Map<String, dynamic> json) {
    return AttendanceUpdate(
      type: json['type'] ?? 'unknown',
      studentId: json['student_id'],
      name: json['name'],
      rollNo: json['roll_no'],
      timestamp: json['timestamp'],
      presentCount: json['present_count'],
      totalStudents: json['total_students'],
      message: json['message'],
    );
  }
  
  bool get isAttendanceMarked => type == 'attendance_marked';
  bool get isError => type == 'error';
  bool get isStatus => type == 'status';
  bool get isSessionStarted => type == 'session_started';
  bool get isWebcamReady => type == 'webcam_ready';
}

/// WebSocket service for real-time attendance marking
class AttendanceWebSocketService {
  WebSocketChannel? _channel;
  final String baseUrl;
  String? _sessionId;
  
  final StreamController<AttendanceUpdate> _updateController = 
      StreamController<AttendanceUpdate>.broadcast();
  
  final StreamController<bool> _connectionController = 
      StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  
  AttendanceWebSocketService({
    this.baseUrl = 'ws://10.171.194.246:8000',
  });
  
  /// Stream of attendance updates
  Stream<AttendanceUpdate> get updateStream => _updateController.stream;
  
  /// Stream of connection status
  Stream<bool> get connectionStream => _connectionController.stream;
  
  /// Check if currently connected
  bool get isConnected => _isConnected;
  
  /// Get current session ID
  String? get sessionId => _sessionId;
  
  /// Connect to WebSocket for attendance marking
  Future<void> connect(String sessionId) async {
    try {
      if (_isConnected) {
        debugPrint('WebSocket already connected, disconnecting first');
        await disconnect();
      }
      
      _sessionId = sessionId;
      final wsUrl = '$baseUrl/ws/attendance/$sessionId';
      
      debugPrint('Connecting to WebSocket: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Listen to messages
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      
      _isConnected = true;
      _connectionController.add(true);
      
      debugPrint('WebSocket connected successfully');
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _isConnected = false;
      _connectionController.add(false);
      _updateController.add(AttendanceUpdate(
        type: 'error',
        message: 'Failed to connect: ${e.toString()}',
      ));
      rethrow;
    }
  }
  
  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    try {
      if (_channel != null) {
        // Send stop command to server
        try {
          _channel!.sink.add(jsonEncode({'command': 'stop'}));
        } catch (e) {
          debugPrint('Error sending stop command: $e');
        }
        
        await _channel!.sink.close();
        _channel = null;
      }
      
      _isConnected = false;
      _sessionId = null;
      _connectionController.add(false);
      
      debugPrint('WebSocket disconnected');
    } catch (e) {
      debugPrint('Error during WebSocket disconnect: $e');
    }
  }
  
  /// Handle incoming messages
  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final update = AttendanceUpdate.fromJson(data);
      
      debugPrint('Received WebSocket message: ${update.type}');
      
      // Emit update to stream
      _updateController.add(update);
      
      // Log important events
      if (update.isAttendanceMarked) {
        debugPrint('Attendance marked: ${update.name} (${update.rollNo})');
      } else if (update.isError) {
        debugPrint('Error received: ${update.message}');
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
      _updateController.add(AttendanceUpdate(
        type: 'error',
        message: 'Failed to parse message: ${e.toString()}',
      ));
    }
  }
  
  /// Handle WebSocket errors
  void _onError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _isConnected = false;
    _connectionController.add(false);
    
    _updateController.add(AttendanceUpdate(
      type: 'error',
      message: 'Connection error: ${error.toString()}',
    ));
  }
  
  /// Handle WebSocket connection closed
  void _onDone() {
    debugPrint('WebSocket connection closed');
    _isConnected = false;
    _connectionController.add(false);
    
    _updateController.add(AttendanceUpdate(
      type: 'status',
      message: 'Connection closed',
    ));
  }
  
  /// Send a custom message to the server
  void sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      debugPrint('Cannot send message: WebSocket not connected');
      return;
    }
    
    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Error sending message: $e');
      _updateController.add(AttendanceUpdate(
        type: 'error',
        message: 'Failed to send message: ${e.toString()}',
      ));
    }
  }
  
  /// Dispose resources
  void dispose() {
    disconnect();
    _updateController.close();
    _connectionController.close();
  }
}
