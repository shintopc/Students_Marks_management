import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/config_provider.dart';
import '../widgets/app_footer.dart';
import '../widgets/custom_app_dialog.dart';
import 'dashboard_screen.dart';
import 'user_management_screen.dart';
import 'student_screen.dart';
import 'grade_analysis_screen.dart';
import 'marks_entry_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAdmin = user?.isAdmin ?? false;

    // Define base screens
    final List<Widget> screens = [
      DashboardScreen(
        onNavigateToStudent: () => setState(() => _selectedIndex = 1),
        onNavigateToMarksEntry: () => setState(() => _selectedIndex = 2),
      ),
      const StudentScreen(),
      const MarksEntryScreen(),
      const GradeAnalysisScreen(), // Replaced MarksViewScreen
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    // Navigation Items Definition
    final List<Map<String, dynamic>> navItems = [
      {
        'label': 'Dashboard',
        'icon': Icons.dashboard_rounded,
        'color': Colors.indigo,
      },
      {
        'label': 'Students',
        'icon': Icons.people_outline_rounded,
        'color': Colors.orange,
      },
      {
        'label': 'Enter Marks',
        'icon': Icons.edit_note_rounded,
        'color': Colors.teal,
      },
      {
        'label': 'Grade Analysis', // Replaced View Marks
        'icon': Icons.table_chart_rounded,
        'color': Colors.deepPurple,
      },

      {
        'label': 'Reports',
        'icon': Icons.analytics_outlined,
        'color': Colors.redAccent,
      },
      {
        'label': 'Settings',
        'icon': Icons.settings_outlined,
        'color': Colors.blueGrey,
      },
    ];

    if (isAdmin) {
      screens.add(const UserManagementScreen());
      navItems.add({
        'label': 'Users',
        'icon': Icons.manage_accounts_outlined,
        'color': Colors.amber[800],
      });
    }

    if (_selectedIndex >= screens.length) _selectedIndex = 0;

    return Scaffold(
      backgroundColor: Colors.grey[100], // Slight background for contrast
      body: Row(
        children: [
          // Custom Sidebar
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                // Header (Logo/Title)
                Consumer<ConfigProvider>(
                  builder: (context, config, _) {
                    final hasLogo =
                        config.logoPath.isNotEmpty &&
                        File(config.logoPath).existsSync();

                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: hasLogo
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(config.logoPath),
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(
                                  Icons.school_rounded,
                                  color: Colors.blue,
                                  size: 32,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                config.schoolName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const Text(
                                'Management System',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Navigation Items
                Expanded(
                  child: ListView.separated(
                    itemCount: navItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      final isSelected = _selectedIndex == index;
                      final color = item['color'] as Color;

                      return InkWell(
                        onTap: () => setState(() => _selectedIndex = index),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item['icon'],
                                color: isSelected
                                    ? color
                                    : Colors.grey.shade500,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                item['label'],
                                style: TextStyle(
                                  color: isSelected
                                      ? color
                                      : Colors.grey.shade700,
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Footer (Logout)
                InkWell(
                  onTap: () async {
                    final confirm = await CustomAppDialog.showConfirm(
                      context,
                      title: 'Logout',
                      message: 'Are you sure you want to logout?',
                      confirmText: 'Logout',
                    );

                    if (confirm && context.mounted) {
                      context.read<AuthProvider>().logout();
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                          size: 24,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                Expanded(child: screens[_selectedIndex]),
                const AppFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
