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
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF212121),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats Cards
                  Row(
                    children: [
                      _buildStatCard(
                        'Students',
                        _studentCount.toString(),
                        Icons.people_outline_rounded,
                        const Color(0xFF1565C0), // Blue 800
                      ),
                      const SizedBox(width: 24),
                      _buildStatCard(
                        'Subjects',
                        _subjectCount.toString(),
                        Icons.menu_book_rounded,
                        const Color(0xFFE65100), // Orange 900
                      ),
                      const SizedBox(width: 24),
                      if (user?.isAdmin ?? false)
                        _buildStatCard(
                          'Users',
                          _userCount.toString(),
                          Icons.manage_accounts_rounded,
                          const Color(0xFF7B1FA2), // Purple 700
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2E3192),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: widget.onNavigateToMarksEntry,
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Enter Marks'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2E3192),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
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
      child: Container(
        height: 170, // Increased height to prevent overflow
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
            stops: const [0.2, 1.0],
          ),
          borderRadius: BorderRadius.circular(16), // Slightly less rounded
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 32, // Larger font
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
