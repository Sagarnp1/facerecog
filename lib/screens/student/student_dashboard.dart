import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_provider.dart';
import '../../models/user_model.dart';
import '../../utils/theme.dart';
import '../admin/add_notice_screen.dart';
import '../admin/add_schedule_screen.dart';
import '../notifications/notifications_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text('${user.department.name} Dashboard'),
        actions: [
          // Notification bell with badge
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: authProvider.getUserNotifications(),
            builder: (context, snapshot) {
              final notifications = snapshot.data ?? [];
              final unreadCount = notifications.where((n) => !(n['read'] ?? false)).length;
              
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          _SafePopupMenuButton(
            icon: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user.fullName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            items: [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
                onTap: () {
                  // TODO: Navigate to profile
                },
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
                onTap: () {
                  if (!_isDisposed && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_isDisposed && mounted) {
                        authProvider.signOut();
                      }
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(user),
          _buildNoticesTab(user),
          _buildSchedulesTab(user),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedules',
          ),
        ],
      ),
      floatingActionButton: user.isCR && _currentIndex != 0
          ? FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => _currentIndex == 1
                  ? const AddNoticeScreen()
                  : const AddScheduleScreen(),
            ),
          );
          if (result == true) {
            setState(() {});
          }
        },
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  Widget _buildHomeTab(UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          user.fullName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${user.fullName}!',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${user.department.displayName} Department',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            if (user.year != null)
                              Text(
                                'Year ${user.year}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (user.isCR)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'CR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Quick Actions for CR
          if (user.isCR) ...[
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.add,
                    title: 'Create Notice',
                    subtitle: 'Post new notice',
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddNoticeScreen(),
                        ),
                      );
                      if (result == true) {
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.calendar_today,
                    title: 'Add Schedule',
                    subtitle: 'Create new schedule',
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddScheduleScreen(),
                        ),
                      );
                      if (result == true) {
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Department Info
          const Text(
            'Department Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.school,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(user.department.displayName),
              subtitle: const Text('Institute of Engineering (IOE)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticesTab(UserModel user) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: authProvider.getNoticesByDepartment(),
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

        final notices = snapshot.data ?? [];

        if (notices.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No Notices',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'No notices from your department yet.\nPull down to refresh.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notices.length,
              itemBuilder: (context, index) {
                final notice = notices[index];
                final createdAt = (notice['createdAt'] as Timestamp?)?.toDate();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                notice['title'] ?? 'No Title',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Show edit/delete options for CR
                            if (user.isCR && notice['postedByRole'] == 'cr')
                              _SafePopupMenuButton(
                                items: [
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.edit, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                    onTap: () {
                                      if (!_isDisposed && mounted) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (!_isDisposed && mounted) {
                                            _showEditNoticeDialog(notice);
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete'),
                                      ],
                                    ),
                                    onTap: () {
                                      if (!_isDisposed && mounted) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (!_isDisposed && mounted) {
                                            _deleteNotice(notice['id']);
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notice['body'] ?? 'No content',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        if (createdAt != null)
                          Text(
                            'Posted: ${createdAt.day}/${createdAt.month}/${createdAt.year} at ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ));
      },
    );
  }

  Widget _buildSchedulesTab(UserModel user) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getSchedulesWithCleanup(authProvider),
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

        final schedules = snapshot.data ?? [];

        if (schedules.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No Schedules',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'No schedules from your department yet.\nPull down to refresh.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final schedule = schedules[index];
                final createdAt = (schedule['createdAt'] as Timestamp?)?.toDate();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                schedule['title'] ?? 'No Title',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Show edit/delete options for CR
                            if (user.isCR && schedule['postedByRole'] == 'cr')
                              _SafePopupMenuButton(
                                items: [
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.edit, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                    onTap: () {
                                      if (!_isDisposed && mounted) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (!_isDisposed && mounted) {
                                            _showEditScheduleDialog(schedule);
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete'),
                                      ],
                                    ),
                                    onTap: () {
                                      if (!_isDisposed && mounted) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (!_isDisposed && mounted) {
                                            _deleteSchedule(schedule['id']);
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          schedule['description'] ?? 'No description',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        if (schedule['time'] != null)
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Time: ${schedule['time']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        if (schedule['location'] != null)
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Location: ${schedule['location']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        if (schedule['year'] != null)
                          Row(
                            children: [
                              const Icon(Icons.school, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Year: ${schedule['year']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        if (createdAt != null)
                          Text(
                            'Posted: ${createdAt.day}/${createdAt.month}/${createdAt.year} at ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ));
      },
    );
  }

  // Helper method to cleanup old schedules and then fetch current ones
  Future<List<Map<String, dynamic>>> _getSchedulesWithCleanup(AuthProvider authProvider) async {
    // try {
    //   // First, cleanup old schedules (runs in background)
    //   await authProvider.cleanupOldSchedules();
    // } catch (e) {
    //   // Don't fail the whole operation if cleanup fails
    //   print('Cleanup failed: $e');
    // }
    
    // Then fetch current schedules
    return await authProvider.getSchedulesByDepartment();
  }

  // Helper methods for editing and deleting notices and schedules
  void _showEditNoticeDialog(Map<String, dynamic> notice) {
    showDialog(
      context: context,
      builder: (context) => _NoticeDialog(notice: notice, onSaved: () => setState(() {})),
    );
  }

  void _showEditScheduleDialog(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      builder: (context) => _ScheduleDialog(schedule: schedule, onSaved: () => setState(() {})),
    );
  }

  void _deleteNotice(String noticeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: const Text('Are you sure you want to delete this notice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.deleteNotice(noticeId);
        
        if (mounted) {
          if (success) {
            setState(() {}); // Refresh the view
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notice deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete notice: ${authProvider.error}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting notice: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _deleteSchedule(String scheduleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.deleteSchedule(scheduleId);
        
        if (mounted) {
          if (success) {
            setState(() {}); // Refresh the view
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Schedule deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete schedule: ${authProvider.error}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting schedule: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// Notice Dialog Widget for editing
class _NoticeDialog extends StatefulWidget {
  final Map<String, dynamic>? notice;
  final VoidCallback onSaved;

  const _NoticeDialog({this.notice, required this.onSaved});

  @override
  State<_NoticeDialog> createState() => _NoticeDialogState();
}

class _NoticeDialogState extends State<_NoticeDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.notice != null) {
      _titleController.text = widget.notice!['title'] ?? '';
      _bodyController.text = widget.notice!['body'] ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.notice != null;
    
    return AlertDialog(
      title: Text(isEditing ? 'Edit Notice' : 'Add Notice'),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.4, // Limit height
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a message';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveNotice,
                child: Text(isEditing ? 'Update' : 'Create'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveNotice() async {
    if (_formKey.currentState!.validate()) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        if (widget.notice != null) {
          // Edit existing notice
          final success = await authProvider.editNotice(
            noticeId: widget.notice!['id'],
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
          );
          
          if (success) {
            if (mounted) {
              Navigator.pop(context);
              widget.onSaved();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notice updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update notice: ${authProvider.error}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving notice: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// Schedule Dialog Widget for editing
class _ScheduleDialog extends StatefulWidget {
  final Map<String, dynamic>? schedule;
  final VoidCallback onSaved;

  const _ScheduleDialog({this.schedule, required this.onSaved});

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int? _selectedYear;
  String _selectedDay = 'Sunday';
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);

  final List<String> _daysOfWeek = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.schedule != null) {
      _titleController.text = widget.schedule!['title'] ?? '';
      _descriptionController.text = widget.schedule!['description'] ?? '';
      _locationController.text = widget.schedule!['location'] ?? '';
      _selectedYear = widget.schedule!['year'];
      _selectedDay = widget.schedule!['dayOfWeek'] ?? 'Sunday';

      // Parse startTime/endTime "HH:mm"
      final st = widget.schedule!['startTime'] as String?;
      final et = widget.schedule!['endTime'] as String?;
      if (st != null && st.contains(':')) {
        final parts = st.split(':');
        _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (et != null && et.contains(':')) {
        final parts = et.split(':');
        _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String _fmt24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) setState(() => _endTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.schedule != null;
    
    return AlertDialog(
      title: Text(isEditing ? 'Edit Schedule' : 'Add Schedule'),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7, // Limit height
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDay,
                  decoration: const InputDecoration(
                    labelText: 'Day of Week',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  items: _daysOfWeek.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => _selectedDay = v!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickStart,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(_fmt(_startTime)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: _pickEnd,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Time',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time_filled),
                          ),
                          child: Text(_fmt(_endTime)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                  ),
                  items: [1, 2, 3, 4].map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text('Year $year'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedYear = value),
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a year';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveSchedule,
                child: Text(isEditing ? 'Update' : 'Create'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _saveSchedule() async {
    if (_formKey.currentState!.validate()) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        if (widget.schedule != null) {
          // Edit existing schedule
          final computedTime =
              '$_selectedDay ${_fmt(_startTime)} - ${_fmt(_endTime)}';
          final success = await authProvider.editSchedule(
            scheduleId: widget.schedule!['id'],
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            time: computedTime,
            location: _locationController.text.trim(),
            year: _selectedYear!,
            dayOfWeek: _selectedDay,
            startTime: _fmt24(_startTime),
            endTime: _fmt24(_endTime),
          );
          
          if (success) {
            if (mounted) {
              Navigator.pop(context);
              widget.onSaved();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Schedule updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update schedule: ${authProvider.error}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving schedule: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// Safe PopupMenuButton that handles widget lifecycle properly
class _SafePopupMenuButton extends StatefulWidget {
  final Widget? icon;
  final List<PopupMenuEntry> items;

  const _SafePopupMenuButton({
    this.icon,
    required this.items,
  });

  @override
  State<_SafePopupMenuButton> createState() => _SafePopupMenuButtonState();
}

class _SafePopupMenuButtonState extends State<_SafePopupMenuButton> {
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: widget.icon,
      itemBuilder: (context) {
        if (_isDisposed || !mounted) {
          return <PopupMenuEntry>[];
        }
        return widget.items;
      },
    );
  }
}
