import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../models/user_model.dart';
import '../../utils/theme.dart';
import 'add_notice_screen.dart';
import '../../examples/attendance_screen_with_roles.dart';
import 'attendance_dashboard_simple.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  int _totalStudents = 0;
  int _totalNotices = 0;
  int _totalCRs = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final department = authProvider.currentUser!.department;
      
      // Get all students in the department (across all years)
      List<UserModel> allStudents = [];
      for (int year = 1; year <= 4; year++) {
        final yearStudents = await authProvider.getStudentsByDepartmentAndYear(department, year);
        allStudents.addAll(yearStudents);
      }
      
      // Count CRs from all students
      final crCount = allStudents.where((student) => student.isCR).length;
      
      // Get notices count
      final notices = await authProvider.getNoticesByDepartment();
      
      setState(() {
        _totalStudents = allStudents.length;
        _totalNotices = notices.length;
        _totalCRs = crCount;
        _isLoadingStats = false;
      });
    } catch (e) {
      print('Error loading statistics: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text('${user.department.name} Admin'),
        actions: [
          PopupMenuButton(
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
            itemBuilder: (context) => [
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
                  // Use Future.delayed to ensure popup is fully closed before sign out
                  Future.delayed(const Duration(milliseconds: 300), () {
                    authProvider.signOut();
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardTab(user),
          _buildStudentsTab(user),
          _buildNoticesTab(user),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Students',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notices',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Department Admin',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              user.fullName,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user.department.displayName,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Department Statistics with refresh button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Department Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(_isLoadingStats ? Icons.hourglass_empty : Icons.refresh),
                onPressed: _isLoadingStats ? null : _loadStatistics,
                tooltip: 'Refresh Statistics',
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Department Statistics
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.people,
                  title: 'Total Students',
                  value: _isLoadingStats ? '...' : _totalStudents.toString(),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.notifications,
                  title: 'Notices',
                  value: _isLoadingStats ? '...' : _totalNotices.toString(),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.star,
                  title: 'Class Reps',
                  value: _isLoadingStats ? '...' : _totalCRs.toString(),
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              // Empty space for balance
              Expanded(child: Container()),
            ],
          ),
          const SizedBox(height: 20),

          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.add,
                  title: 'Create Notice',
                  subtitle: 'Post new notice',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddNoticeScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.people_alt,
                  title: 'Manage Students',
                  subtitle: 'View and manage students',
                  onTap: () => setState(() => _currentIndex = 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.analytics,
                  title: 'View Attendance',
                  subtitle: 'Attendance reports & export',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AttendanceDashboardSimple(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.star,
                  title: 'Promote CR',
                  subtitle: 'Make class representative',
                  color: Colors.orange,
                  onTap: () {
                    // TODO: Navigate to promote CR
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: color ?? Theme.of(context).primaryColor,
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
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttendanceDialog(UserModel user) {
    final TextEditingController classNameController = TextEditingController();
    int? selectedYear;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.how_to_reg, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text('Start Attendance Session'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Year *',
                  prefixIcon: Icon(Icons.school),
                  border: OutlineInputBorder(),
                ),
                value: selectedYear,
                items: [1, 2, 3, 4].map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text('Year $year'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedYear = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: classNameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name (Optional)',
                  hintText: 'e.g., A, B',
                  prefixIcon: Icon(Icons.class_),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Faculty: ${user.department.displayName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedYear == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a year'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceMarkingScreen(
                      batch: selectedYear.toString(),
                      faculty: user.department.name,
                      className: classNameController.text.isNotEmpty 
                          ? classNameController.text 
                          : null,
                    ),
                  ),
                );
              },
              child: const Text('Start Session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTab(UserModel user) {
    return DefaultTabController(
      length: 5, // All, Year 1, Year 2, Year 3, Year 4
      child: Column(
        children: [
          // Year Filter Tabs
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              isScrollable: false,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Year 1'),
                Tab(text: 'Year 2'),
                Tab(text: 'Year 3'),
                Tab(text: 'Year 4'),
              ],
            ),
          ),
          // Students List
          Expanded(
            child: TabBarView(
              children: [
                _buildStudentsList(user, null), // All students
                _buildStudentsList(user, 1),    // Year 1
                _buildStudentsList(user, 2),    // Year 2
                _buildStudentsList(user, 3),    // Year 3
                _buildStudentsList(user, 4),    // Year 4
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList(UserModel admin, int? year) {
    return FutureBuilder<List<UserModel>>(
      future: Provider.of<AuthProvider>(context, listen: false)
          .getStudentsByDepartmentAndYear(admin.department, year),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading students'),
                Text('${snapshot.error}', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final students = snapshot.data ?? [];
        if (students.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  year == null ? 'No students found' : 'No Year $year students found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Students will appear here once they register',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Find current CR (if any)
        UserModel? crStudent;
        try {
          crStudent = students.firstWhere((s) => s.isCR);
        } catch (e) {
          crStudent = null;
        }

        return Column(
          children: [
            // Stats Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatsCard(
                      'Total Students', 
                      students.length.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatsCard(
                      'Class Rep', 
                      crStudent?.fullName.split(' ').first ?? 'None',
                      Icons.star,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
            // Students List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: students.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final student = students[index];
                  return Card(
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: student.isCR ? Colors.purple : Theme.of(context).primaryColor,
                        child: Text(
                          student.fullName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(student.fullName)),
                          if (student.isCR)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'CR',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('📧 ${student.email}'),
                          if (student.uid.isNotEmpty) Text('� ID: ${student.uid.substring(0, 8)}...'),
                          if (student.year != null) Text('📚 Year ${student.year}'),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          if (!student.isCR && crStudent == null)
                            PopupMenuItem(
                              child:  Row(
                                children: [
                                  Icon(Icons.star, color: Colors.purple),
                                  SizedBox(width: 8),
                                  Text('Make CR'),
                                ],
                              ),
                              onTap: () => _makeCR(student),
                            ),
                          if (student.isCR)
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.star_border, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text('Remove CR'),
                                ],
                              ),
                              onTap: () => _removeCR(student),
                            ),
                          PopupMenuItem(
                            child:  Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('View Details'),
                              ],
                            ),
                            onTap: () => _showStudentDetails(student),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _makeCR(UserModel student) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.makeCR(student.uid);
      setState(() {}); // Refresh the view
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${student.fullName} is now the Class Representative'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to make CR: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeCR(UserModel student) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.removeCR(student.uid);
      setState(() {}); // Refresh the view
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${student.fullName} is no longer the Class Representative'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove CR: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showStudentDetails(UserModel student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(student.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', student.email),
            _buildDetailRow('User ID', student.uid),
            _buildDetailRow('Department', student.department.displayName),
            if (student.year != null) _buildDetailRow('Year', student.year.toString()),
            _buildDetailRow('Role', student.isCR ? 'Class Representative' : 'Student'),
            _buildDetailRow('Joined', student.createdAt.toString().split(' ')[0]),
          ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildNoticesTab(UserModel user) {
    return Column(
      children: [
        // Header with Add Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notice Management',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Text(
                      'Create and manage notices for ${user.department.displayName}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddNoticeDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Notice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Notices List
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getNotices(user.department),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Error loading notices'),
                      Text('${snapshot.error}', style: TextStyle(color: Colors.grey)),
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No Notices Yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Create your first notice to inform students',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showAddNoticeDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Notice'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notice = notices[index];
                  // Handle Firestore Timestamp conversion
                  DateTime? createdAt;
                  if (notice['createdAt'] != null) {
                    if (notice['createdAt'] is DateTime) {
                      createdAt = notice['createdAt'] as DateTime;
                    } else {
                      // Assume it's a Firestore Timestamp
                      final timestamp = notice['createdAt'];
                      createdAt = timestamp.toDate();
                    }
                  }
                  
                  return Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notice['title'] ?? 'Untitled',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.edit, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                    onTap: () => _showEditNoticeDialog(notice),
                                  ),
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete'),
                                      ],
                                    ),
                                    onTap: () => _deleteNotice(notice['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notice['body'] ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                createdAt != null 
                                  ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                                  : 'Unknown date',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  user.department.displayName,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper methods for notices
  Future<List<Map<String, dynamic>>> _getNotices(Department department) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return await authProvider.getNoticesByDepartment();
  }

  void _showAddNoticeDialog() {
    showDialog(
      context: context,
      builder: (context) => _NoticeDialog(),
    );
  }

  void _showEditNoticeDialog(Map<String, dynamic> notice) {
    showDialog(
      context: context,
      builder: (context) => _NoticeDialog(notice: notice),
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
      } catch (e) {
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

// Notice Dialog Widget
class _NoticeDialog extends StatefulWidget {
  final Map<String, dynamic>? notice;

  const _NoticeDialog({this.notice});

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
      content: Form(
        key: _formKey,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveNotice,
          child: Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  void _saveNotice() async {
    if (_formKey.currentState!.validate()) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUser = authProvider.currentUser!;
        
        if (widget.notice != null) {
          // Edit existing notice
          final success = await authProvider.editNotice(
            noticeId: widget.notice!['id'],
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
          );
          
          if (success) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notice updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update notice: ${authProvider.error}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // Create new notice
          await authProvider.addNotice(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            department: currentUser.department,
          );
          
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notice created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
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
