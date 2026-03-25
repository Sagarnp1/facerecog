import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize notification service
  static Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted permission');
      }
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      if (kDebugMode) {
        print('User granted provisional permission');
      }
    } else {
      if (kDebugMode) {
        print('User declined or has not accepted permission');
      }
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
      }

      if (message.notification != null) {
        if (kDebugMode) {
          print('Message also contained a notification: ${message.notification}');
        }
      }
    });

    // Handle when user taps on notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('A new onMessageOpenedApp event was published!');
      }
      // Handle navigation based on notification data
      _handleNotificationTap(message);
    });
  }

  // Get FCM token for current device
  static Future<String?> getToken() async {
    try {
      String? token = await _messaging.getToken();
      if (kDebugMode) {
        print('FCM Token: $token');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }

  // Save FCM token to user document
  static Future<void> saveTokenToDatabase(String userId) async {
    try {
      String? token = await getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) {
          print('FCM token saved for user: $userId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token: $e');
      }
    }
  }

  // Subscribe to department-specific topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to topic: $e');
      }
    }
  }

  // Unsubscribe from department-specific topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from topic: $e');
      }
    }
  }

  // Subscribe user to appropriate topics based on their profile
  static Future<void> subscribeUserToTopics(UserModel user) async {
    try {
      // Subscribe to department topic
      await subscribeToTopic('department_${user.department.name.toLowerCase()}');
      
      // Subscribe to year-specific topic if user has year
      if (user.year != null) {
        await subscribeToTopic('year_${user.year}');
      }
      
      // Subscribe to CR topic if user is CR
      if (user.isCR) {
        await subscribeToTopic('cr_notifications');
      }
      
      // Subscribe to general notifications
      await subscribeToTopic('general_notifications');
      
      if (kDebugMode) {
        print('User subscribed to relevant topics');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing user to topics: $e');
      }
    }
  }

  // Send notification when new student is created
  static Future<void> sendWelcomeNotification(String userId, String userName, String email) async {
    try {
      // Create notification document in Firestore
      await _firestore.collection('notifications').add({
        'type': 'welcome',
        'title': 'Welcome to IOE Student Management!',
        'body': 'Hello $userName, your account has been created successfully. You can now access notices and schedules.',
        'userId': userId,
        'data': {
          'type': 'welcome',
          'email': email,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (kDebugMode) {
        print('Welcome notification created for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending welcome notification: $e');
      }
    }
  }

  // Send notification when new notice is posted
  static Future<void> sendNoticeNotification(String title, String body, Department department, String postedBy) async {
    try {
      // Get all users in the department
      final usersSnapshot = await _firestore
          .collection('users')
          .where('department', isEqualTo: department.name)
          .where('role', isEqualTo: 'student')
          .get();

      // Create individual notification for each user in the department
      final batch = _firestore.batch();
      
      for (final userDoc in usersSnapshot.docs) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': userDoc.id,
          'type': 'notice',
          'title': 'New Notice Posted',
          'body': title,
          'department': department.name,
          'postedBy': postedBy,
          'data': {
            'type': 'notice',
            'department': department.name,
            'noticeTitle': title,
            'noticeBody': body,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      // Execute batch write
      await batch.commit();

      if (kDebugMode) {
        print('Notice notifications created for ${usersSnapshot.docs.length} users in department: ${department.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notice notification: $e');
      }
    }
  }

  // Send notification when new schedule is posted
  static Future<void> sendScheduleNotification(String title, String description, Department department, int year, String postedBy) async {
    try {
      // Get all users in the department and specific year
      final usersSnapshot = await _firestore
          .collection('users')
          .where('department', isEqualTo: department.name)
          .where('role', isEqualTo: 'student')
          .where('year', isEqualTo: year)
          .get();

      // Create individual notification for each user in the department and year
      final batch = _firestore.batch();
      
      for (final userDoc in usersSnapshot.docs) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': userDoc.id,
          'type': 'schedule',
          'title': 'New Schedule Added',
          'body': '$title - Year $year',
          'department': department.name,
          'year': year,
          'postedBy': postedBy,
          'data': {
            'type': 'schedule',
            'department': department.name,
            'year': year,
            'scheduleTitle': title,
            'scheduleDescription': description,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      // Execute batch write
      await batch.commit();

      if (kDebugMode) {
        print('Schedule notifications created for ${usersSnapshot.docs.length} users in department: ${department.name}, year: $year');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending schedule notification: $e');
      }
    }
  }

  // Get user notifications
  static Stream<List<Map<String, dynamic>>> getUserNotifications(String userId, Department department, int? year) {
    Query query = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
    }
  }

  // Update user notification preferences
  static Future<void> updateNotificationPreferences(String userId, Map<String, bool> preferences) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'notificationPreferences': preferences,
        'preferencesUpdatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        print('Notification preferences updated for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating notification preferences: $e');
      }
    }
  }

  // Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    // TODO: Implement navigation based on notification type
    if (kDebugMode) {
      print('Notification tapped: ${message.data}');
    }
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
    print("Message data: ${message.data}");
    print("Message notification: ${message.notification?.title}");
  }
}
