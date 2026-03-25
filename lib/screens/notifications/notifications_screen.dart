import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Map<String, bool> notificationPreferences = {
    'notices': true,
    'schedules': true,
    'welcome': true,
    'general': true,
  };

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showNotificationSettings(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Notification preferences card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Switch(
                              value: notificationPreferences['notices'] ?? true,
                              onChanged: (value) {
                                setState(() {
                                  notificationPreferences['notices'] = value;
                                });
                                _updatePreferences();
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text('Notices'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Switch(
                              value: notificationPreferences['schedules'] ?? true,
                              onChanged: (value) {
                                setState(() {
                                  notificationPreferences['schedules'] = value;
                                });
                                _updatePreferences();
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text('Schedules'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Notifications list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: authProvider.getUserNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final notifications = snapshot.data ?? [];

                if (notifications.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No Notifications',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'You\'re all caught up!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationCard(notification, authProvider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, AuthProvider authProvider) {
    final isRead = notification['read'] ?? false;
    final createdAt = (notification['createdAt'] as Timestamp?)?.toDate();
    
    IconData iconData;
    Color iconColor;
    
    switch (notification['type']) {
      case 'notice':
        iconData = Icons.campaign;
        iconColor = Colors.orange;
        break;
      case 'schedule':
        iconData = Icons.schedule;
        iconColor = Colors.blue;
        break;
      case 'welcome':
        iconData = Icons.waving_hand;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isRead ? null : Colors.blue.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(
          notification['title'] ?? 'Notification',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['body'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatDateTime(createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        trailing: !isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          if (!isRead) {
            authProvider.markNotificationAsRead(notification['id']);
          }
          _showNotificationDetails(notification);
        },
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification['title'] ?? 'Notification'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(notification['body'] ?? ''),
              if (notification['type'] == 'notice') ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Department: ${notification['department'] ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Posted by: ${notification['postedBy'] ?? 'Unknown'}'),
              ],
              if (notification['type'] == 'schedule') ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Department: ${notification['department'] ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Year: ${notification['year'] ?? 'N/A'}'),
                Text('Posted by: ${notification['postedBy'] ?? 'Unknown'}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Notice Notifications'),
              subtitle: const Text('Get notified about new notices'),
              value: notificationPreferences['notices'] ?? true,
              onChanged: (value) {
                setState(() {
                  notificationPreferences['notices'] = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Schedule Notifications'),
              subtitle: const Text('Get notified about new schedules'),
              value: notificationPreferences['schedules'] ?? true,
              onChanged: (value) {
                setState(() {
                  notificationPreferences['schedules'] = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Welcome Messages'),
              subtitle: const Text('Receive welcome notifications'),
              value: notificationPreferences['welcome'] ?? true,
              onChanged: (value) {
                setState(() {
                  notificationPreferences['welcome'] = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('General Notifications'),
              subtitle: const Text('Other important updates'),
              value: notificationPreferences['general'] ?? true,
              onChanged: (value) {
                setState(() {
                  notificationPreferences['general'] = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updatePreferences();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _updatePreferences() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.updateNotificationPreferences(notificationPreferences);
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
