import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/local/database_helper.dart';
import '../../data/providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToStudent;
  final VoidCallback onNavigateToMarksEntry;

  const DashboardScreen({
    super.key,
    required this.onNavigateToStudent,
    required this.onNavigateToMarksEntry,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _studentCount = 0;
  int _subjectCount = 0;
  int _userCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = await DatabaseHelper.instance.database;

    final sCount = await db.rawQuery('SELECT COUNT(*) as count FROM students');
    final subCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM subjects',
    );
    final uCount = await db.rawQuery('SELECT COUNT(*) as count FROM users');

    if (mounted) {
      setState(() {
        _studentCount = (sCount.first['count'] as int?) ?? 0;
        _subjectCount = (subCount.first['count'] as int?) ?? 0;
        _userCount = (uCount.first['count'] as int?) ?? 0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${user?.username ?? "User"}!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),

                  // Stats Cards
                  Row(
                    children: [
                      _buildStatCard(
                        'Students',
                        _studentCount.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Subjects',
                        _subjectCount.toString(),
                        Icons.book,
                        Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      if (user?.isAdmin ?? false)
                        _buildStatCard(
                          'Users',
                          _userCount.toString(),
                          Icons.admin_panel_settings,
                          Colors.purple,
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      ElevatedButton.icon(
                        onPressed: widget.onNavigateToStudent,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Manage Students'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(20),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: widget.onNavigateToMarksEntry,
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Enter Marks'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
