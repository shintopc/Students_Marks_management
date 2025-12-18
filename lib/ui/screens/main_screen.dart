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
  int? _hoveredIndex;

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
        'icon': Icons.dashboard_outlined,
        'activeIcon': Icons.dashboard_rounded,
        'color': Colors.blue.shade700,
      },
      {
        'label': 'Students',
        'icon': Icons.people_outline_rounded,
        'activeIcon': Icons.people_rounded,
        'color': Colors.green.shade700,
      },
      {
        'label': 'Enter Marks',
        'icon': Icons.edit_note_rounded,
        'activeIcon': Icons.edit_note_rounded,
        'color': Colors.teal.shade700,
      },
      {
        'label': 'Grade Analysis',
        'icon': Icons.analytics_outlined,
        'activeIcon': Icons.analytics_rounded,
        'color': Colors.purple.shade700,
      },
      {
        'label': 'Reports',
        'icon': Icons.description_outlined,
        'activeIcon': Icons.description_rounded,
        'color': Colors.orange.shade800,
      },
      {
        'label': 'Settings',
        'icon': Icons.settings_outlined,
        'activeIcon': Icons.settings_rounded,
        'color': Colors.blueGrey.shade700,
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
              border: Border(
                right: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
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
                            color: Colors.blue.shade50,
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
                              : Icon(
                                  Icons.school_rounded,
                                  color: Colors.blue.shade800,
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
                              Text(
                                'Management System',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
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

                      return MouseRegion(
                        onEnter: (_) => setState(() => _hoveredIndex = index),
                        onExit: (_) => setState(() => _hoveredIndex = null),
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedIndex = index),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(
                                      0xFFFFEBEE,
                                    ) // Explicit Light Red
                                  : (_hoveredIndex == index
                                        ? Colors.grey.shade50
                                        : Colors.transparent),
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border(
                                      left: BorderSide(
                                        color: Colors.red.shade600,
                                        width: 4,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? item['activeIcon']
                                        : item['icon'],
                                    color: isSelected
                                        ? Colors.red.shade700
                                        : item['color'],
                                    size: 22,
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    item['label'],
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.red.shade900
                                          : Colors.grey.shade700,
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
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
