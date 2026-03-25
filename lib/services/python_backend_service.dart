import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service for communicating with Python backend for face recognition
class PythonBackendService {
  // For Android Emulator: use 10.0.2.2 (special alias for host machine)
  // For Physical Device on same WiFi: use PC's IP address
  // For Windows/Desktop: use localhost
  static const String defaultRegistrationUrl = 'http://10.171.194.246:8000';
  static const String defaultAttendanceUrl = 'http://10.171.194.246:8000';
  
  final Dio _dio;
  final String registrationBaseUrl;
  final String attendanceBaseUrl;
  
  PythonBackendService({
    String? registrationUrl,
    String? attendanceUrl,
  }) : 
    registrationBaseUrl = registrationUrl ?? defaultRegistrationUrl,
    attendanceBaseUrl = attendanceUrl ?? defaultAttendanceUrl,
    _dio = Dio()
  {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 60);
    
    // Add logging interceptor in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false, // Don't log base64 images
        responseBody: true,
        error: true,
      ));
    }
  }
  
  /// Register a student by sending 5 face images to Python backend
  /// Returns the embeddings if successful
  Future<Map<String, dynamic>> registerStudent({
    required String fullName,
    required String rollNo,
    required String batch,
    required String faculty,
    required List<String> base64Images,
  }) async {
    try {
      if (base64Images.length != 5) {
        throw Exception('Exactly 5 images are required for registration');
      }
      
      final requestData = {
        'full_name': fullName,
        'roll_no': rollNo,
        'batch': batch,
        'faculty': faculty,
        'images': base64Images,
      };
      
      final response = await _dio.post(
        '$registrationBaseUrl/register_student',
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['success'] == true) {
          return {
            'success': true,
            'embeddings': data['embeddings'],
            'student_info': data['student_info'],
            'message': data['message'],
          };
        } else {
          // Partial failure - some images didn't process
          return {
            'success': false,
            'embeddings': data['embeddings'] ?? [],
            'errors': data['errors'] ?? [],
            'message': data['message'] ?? 'Failed to process all images',
          };
        }
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } on DioException catch (e) {
      return _handleDioError(e, 'registration');
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error: ${e.toString()}',
        'errors': [e.toString()],
      };
    }
  }
  
  /// Start an attendance session
  Future<Map<String, dynamic>> startAttendanceSession({
    required String batch,
    required String faculty,
    String? className,
    String? createdBy,
    String? createdByName,
  }) async {
    try {
      final requestData = {
        'batch': batch,
        'faculty': faculty,
        if (className != null) 'class_name': className,
        if (createdBy != null) 'created_by': createdBy,
        if (createdByName != null) 'created_by_name': createdByName,
      };
      
      final response = await _dio.post(
        '$attendanceBaseUrl/start_attendance',
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': data['success'] ?? true,
          'session_id': data['session_id'],
          'total_students': data['total_students'],
          'batch': data['batch'],
          'faculty': data['faculty'],
          'message': data['message'],
        };
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } on DioException catch (e) {
      return _handleDioError(e, 'start attendance');
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error: ${e.toString()}',
      };
    }
  }
  
  /// Stop an attendance session
  Future<Map<String, dynamic>> stopAttendanceSession(String sessionId) async {
    try {
      final response = await _dio.post(
        '$attendanceBaseUrl/stop_attendance/$sessionId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': data['success'] ?? true,
          'session_id': data['session_id'],
          'total_students': data['total_students'],
          'present_count': data['present_count'],
          'absent_count': data['absent_count'],
          'attendance_percentage': data['attendance_percentage'],
          'absent_students': data['absent_students'] ?? [],
          'message': data['message'],
        };
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } on DioException catch (e) {
      return _handleDioError(e, 'stop attendance');
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error: ${e.toString()}',
      };
    }
  }
  
  /// Get current session status
  Future<Map<String, dynamic>> getSessionStatus(String sessionId) async {
    try {
      final response = await _dio.get(
        '$attendanceBaseUrl/session/$sessionId/status',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          ...response.data,
        };
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } on DioException catch (e) {
      return _handleDioError(e, 'get session status');
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error: ${e.toString()}',
      };
    }
  }
  
  /// Test connection to the backend server
  Future<Map<String, dynamic>> testConnection({bool isAttendance = false}) async {
    try {
      final baseUrl = isAttendance ? attendanceBaseUrl : registrationBaseUrl;
      final response = await _dio.get(
        '$baseUrl/',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Successfully connected to Python backend',
          'server_info': response.data,
        };
      } else {
        return {
          'success': false,
          'message': 'Server returned status ${response.statusCode}',
        };
      }
    } on DioException catch (e) {
      return _handleDioError(e, 'test connection');
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection failed: ${e.toString()}',
      };
    }
  }
  
  /// Convert image file to base64 string
  static Future<String> imageFileToBase64(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      throw Exception('Failed to convert image to base64: ${e.toString()}');
    }
  }
  
  /// Convert multiple image files to base64
  static Future<List<String>> imageFilesToBase64(List<String> filePaths) async {
    final List<String> base64Images = [];
    
    for (int i = 0; i < filePaths.length; i++) {
      try {
        final base64 = await imageFileToBase64(filePaths[i]);
        base64Images.add(base64);
      } catch (e) {
        throw Exception('Failed to convert image ${i + 1}: ${e.toString()}');
      }
    }
    
    return base64Images;
  }
  
  /// Handle Dio errors and return user-friendly messages
  Map<String, dynamic> _handleDioError(DioException e, String operation) {
    String message;
    
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        message = 'Connection timeout. Please check if the Python backend is running.';
        break;
      case DioExceptionType.sendTimeout:
        message = 'Send timeout. The request took too long to send.';
        break;
      case DioExceptionType.receiveTimeout:
        message = 'Receive timeout. The server took too long to respond.';
        break;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        
        if (statusCode == 404) {
          message = 'Endpoint not found. Please check the server URL.';
        } else if (statusCode == 500) {
          message = responseData?['detail'] ?? 'Internal server error occurred.';
        } else {
          message = responseData?['detail'] ?? 'Server error (${statusCode ?? 'unknown'})';
        }
        break;
      case DioExceptionType.connectionError:
        message = 'Cannot connect to server. Please ensure:\n'
            '1. Python backend is running\n'
            '2. Server URL is correct\n'
            '3. Network connection is active';
        break;
      case DioExceptionType.badCertificate:
        message = 'SSL certificate error. Check server security settings.';
        break;
      case DioExceptionType.cancel:
        message = 'Request was cancelled.';
        break;
      default:
        message = 'Network error during $operation: ${e.message}';
    }
    
    return {
      'success': false,
      'message': message,
      'error_type': e.type.toString(),
    };
  }
  
  /// Get all attendance sessions for a department
  Future<Map<String, dynamic>> getAttendanceSessions({
    required String department,
    int? year,
    String? subject,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'department': department,
      };
      
      if (year != null) {
        queryParams['year'] = year;
      }
      
      if (subject != null && subject.isNotEmpty) {
        queryParams['subject'] = subject;
      }
      
      final response = await _dio.get(
        '$attendanceBaseUrl/attendance/sessions',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'sessions': response.data['sessions'],
          'count': response.data['count'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['detail'] ?? 'Failed to fetch sessions',
        };
      }
    } on DioException catch (e) {
      return _handleDioError(e, 'fetch sessions');
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error: ${e.toString()}',
      };
    }
  }
  
  /// Get detailed attendance information for a specific session
  Future<Map<String, dynamic>> getSessionDetails(String sessionId) async {
    try {
      final response = await _dio.get(
        '$attendanceBaseUrl/attendance/session/$sessionId/details',
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {
          'success': true,
          'session': response.data['session'],
          'statistics': response.data['statistics'],
          'present_students': response.data['present_students'],
          'absent_students': response.data['absent_students'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['detail'] ?? 'Failed to fetch session details',
        };
      }
    } on DioException catch (e) {
      return _handleDioError(e, 'fetch session details');
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error: ${e.toString()}',
      };
    }
  }
  
  /// Get CSV export URL for a specific session
  String getExportSessionUrl(String sessionId) {
    return '$attendanceBaseUrl/attendance/export/$sessionId';
  }
  
  /// Get CSV export URL for all sessions with filters
  String getExportAllUrl({
    required String department,
    int? year,
    String? subject,
  }) {
    print('getExportAllUrl called with:');
    print('  department: "$department" (${department.runtimeType})');
    print('  year: $year');
    print('  subject: $subject');
    
    // Ensure department is a clean string
    final cleanDept = department.toString().trim();
    
    final queryParams = <String, String>{
      'department': cleanDept,
    };
    
    if (year != null) {
      queryParams['year'] = year.toString();
    }
    
    if (subject != null && subject.isNotEmpty) {
      queryParams['subject'] = subject.toString();
    }
    
    print('Query params: $queryParams');
    
    try {
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final url = '$attendanceBaseUrl/attendance/export_all?$queryString';
      print('Final URL: $url');
      
      return url;
    } catch (e) {
      print('ERROR building URL: $e');
      print('ERROR type: ${e.runtimeType}');
      rethrow;
    }
  }
}
