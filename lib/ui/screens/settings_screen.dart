import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../data/local/database_helper.dart';
import '../../data/providers/config_provider.dart';
import '../../data/logic/grading_engine.dart';
import '../widgets/custom_app_dialog.dart';
import 'academic_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _schoolNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _academicYearController = TextEditingController();
  String _logoPath = '';

  List<Map<String, dynamic>> _gradingRules = [];
  bool _isLoading = true;

  // Multi-grade support
  String _selectedGradeKey = 'default';
  List<String> _availableGrades = ['default'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Auto-refresh grades when switching to Grading Rules tab
    _tabController.addListener(() {
      if (_tabController.index == 2 && !_tabController.indexIsChanging) {
        _refreshAvailableGrades();
      }
    });

    _loadSettings();
  }

  Future<void> _refreshAvailableGrades() async {
    final db = await DatabaseHelper.instance.database;
    final gradeRows = await db.rawQuery(
      'SELECT DISTINCT grade FROM classes ORDER BY grade',
    );
    final dbGrades = gradeRows.map((r) => r['grade'] as String).toList();

    await GradingEngine().initialize();
    final engineKeys = GradingEngine().getAllRules().keys.toList();

    final Set<String> allGrades = {'default'};
    allGrades.addAll(dbGrades);
    allGrades.addAll(engineKeys);

    if (mounted) {
      setState(() {
        _availableGrades = allGrades.toList();
        _availableGrades.sort();
        // Ensure selected is valid
        if (!_availableGrades.contains(_selectedGradeKey)) {
          _selectedGradeKey = 'default';
        }
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    // Load available grades from classes table
    final gradeRows = await db.rawQuery(
      'SELECT DISTINCT grade FROM classes ORDER BY grade',
    );
    final dbGrades = gradeRows.map((r) => r['grade'] as String).toList();

    // Load School Profile
    final profileRow = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: ['school_profile'],
    );
    if (profileRow.isNotEmpty) {
      final profile = jsonDecode(profileRow.first['value'] as String);
      _schoolNameController.text = profile['school_name'] ?? '';
      _addressController.text = profile['address'] ?? '';
      _academicYearController.text = profile['academic_year'] ?? '';
      _logoPath = profile['logo_path'] ?? '';
    }

    // Load Grading Rules via Engine
    await GradingEngine().initialize();

    // Merge DB classes with already configured keys from Engine
    final engineKeys = GradingEngine().getAllRules().keys.toList();
    final Set<String> allGrades = {'default'};
    allGrades.addAll(dbGrades);
    allGrades.addAll(engineKeys);

    _availableGrades = allGrades.toList();
    _availableGrades.sort(); // Optional sorting

    // Ensure selected is valid
    if (!_availableGrades.contains(_selectedGradeKey)) {
      _selectedGradeKey = 'default';
    }

    _loadRulesForSelectedKey();

    setState(() => _isLoading = false);
  }

  void _loadRulesForSelectedKey() {
    setState(() {
      _gradingRules = List.from(GradingEngine().getRulesFor(_selectedGradeKey));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'School Profile'),
            Tab(text: 'Academic'), // Combined Classes/Subjects/Terms
            Tab(text: 'Grading Rules'),
            Tab(text: 'Maintenance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSchoolProfileTab(),
                const AcademicManagementScreen(),
                _buildGradingRulesTab(),
                _buildMaintenanceTab(),
              ],
            ),
    );
  }

  Widget _buildSchoolProfileTab() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _schoolNameController,
            decoration: const InputDecoration(
              labelText: 'School Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _academicYearController,
            decoration: const InputDecoration(
              labelText: 'Academic Year',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.image),
                label: const Text('Select Logo'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _logoPath.isEmpty ? 'No logo selected' : _logoPath,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSchoolProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
              child: const Text('Save Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradingRulesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Grading System:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // presets
                  ToggleButtons(
                    isSelected: [
                      _selectedGradeKey == '8',
                      _selectedGradeKey == '9' ||
                          _selectedGradeKey == 'default', // Group 9/10/Default
                    ],
                    onPressed: (index) {
                      setState(() {
                        // Auto-save current temporarily?
                        GradingEngine().setRulesFor(
                          _selectedGradeKey,
                          _gradingRules,
                        );

                        if (index == 0) {
                          _selectedGradeKey = '8';
                        } else {
                          _selectedGradeKey =
                              '9'; // Representative for the group
                        }
                        _loadRulesForSelectedKey();
                      });
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Std 8'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Std 9 & 10'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadRulesForSelectedKey,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Configure Grading Ranges (9-Point Scale)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: _gradingRules.length,
            itemBuilder: (context, index) {
              final rule = _gradingRules[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${rule['min']}% - ${rule['max']}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(child: Text('Grade: ${rule['grade']}')),
                      Expanded(child: Text('GP: ${rule['gp']}')),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showRuleDialog(index: index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRule(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRuleDialog(), // Add
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Rule'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetToDefaults,
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset to Default'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveGradingRules,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
              child: const Text('Save All Grading Rules'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _performFactoryReset() async {
    final confirm = await CustomAppDialog.show(
      context,
      title: 'Factory Reset',
      message:
          'WARNING: This will DELETE ALL students, marks, subjects, and classes.\n\n'
          'Admin accounts and School Profile will be preserved.\n\n'
          'This action CANNOT be undone.',
      type: DialogType.warning,
      confirmText: 'RESET EVERYTHING',
      cancelText: 'Cancel',
    );

    if (confirm == true) {
      await DatabaseHelper.instance.resetDatabase();
      if (mounted) {
        CustomAppDialog.showSuccess(
          context,
          title: 'Reset Complete',
          message: 'Factory Reset Complete. Data Wiped.',
        );
      }
    }
  }

  Widget _buildMaintenanceTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storage, size: 64, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'Database Maintenance',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Backup, Restore, or Reset application data.'),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _backupDatabase,
                icon: const Icon(Icons.upload),
                label: const Text('Backup Database'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                ),
              ),
              const SizedBox(width: 24),
              ElevatedButton.icon(
                onPressed: _restoreDatabase,
                icon: const Icon(Icons.download),
                label: const Text('Restore Database'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _performFactoryReset,
            icon: const Icon(Icons.delete_forever),
            label: const Text('Factory Reset'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _backupDatabase() async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Backup Database',
      fileName: 'marks_system_backup.db',
    );

    if (outputFile != null) {
      await DatabaseHelper.instance.backupDatabase(outputFile);
      if (mounted) {
        CustomAppDialog.showSuccess(
          context,
          title: 'Backup Successful',
          message: 'Database backup saved successfully.',
        );
      }
    }
  }

  Future<void> _restoreDatabase() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      final path = result.files.single.path!;

      if (!mounted) return;

      final confirm = await CustomAppDialog.showConfirm(
        context,
        title: 'Confirm Restore',
        message:
            'WARNING: This will overwrite all current data with the selected backup. The app needs to be restarted.',
        confirmText: 'Restore',
      );

      if (confirm) {
        await DatabaseHelper.instance.restoreDatabase(path);
        if (mounted) {
          await CustomAppDialog.showSuccess(
            context,
            title: 'Restore Successful',
            message: 'Database restored successfully. Please Restart App.',
          );
        }
      }
    }
  }

  Future<void> _pickLogo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _logoPath = result.files.single.path!;
      });
    }
  }

  Future<void> _saveSchoolProfile() async {
    final profile = {
      "school_name": _schoolNameController.text,
      "address": _addressController.text,
      "academic_year": _academicYearController.text,
      "logo_path": _logoPath,
    };

    final db = await DatabaseHelper.instance.database;
    await db.insert('config', {
      'key': 'school_profile',
      'value': jsonEncode(profile),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Refresh ConfigProvider
    await context.read<ConfigProvider>().loadSchoolProfile();

    if (mounted) {
      CustomAppDialog.showSuccess(
        context,
        title: 'Saved',
        message: 'School Profile Saved Successfully',
      );
    }
  }

  void _deleteRule(int index) {
    setState(() {
      _gradingRules.removeAt(index);
    });
  }

  void _showRuleDialog({int? index}) {
    final isEditing = index != null;
    final rule = isEditing ? _gradingRules[index!] : null;

    final minController = TextEditingController(
      text: isEditing ? rule!['min'].toString() : '',
    );
    final maxController = TextEditingController(
      text: isEditing ? rule!['max'].toString() : '',
    );
    final gradeController = TextEditingController(
      text: isEditing ? rule!['grade'] : '',
    );
    final gpController = TextEditingController(
      text: isEditing ? rule!['gp'].toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Grade Rule' : 'Add Grade Rule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minController,
                    decoration: const InputDecoration(labelText: 'Min %'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: maxController,
                    decoration: const InputDecoration(labelText: 'Max %'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: gradeController,
                    decoration: const InputDecoration(labelText: 'Grade'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: gpController,
                    decoration: const InputDecoration(labelText: 'Grade Point'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
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
              final min = int.tryParse(minController.text) ?? 0;
              final max = int.tryParse(maxController.text) ?? 0;
              final grade = gradeController.text.trim();
              final gp = double.tryParse(gpController.text) ?? 0.0;

              if (grade.isEmpty) return;

              setState(() {
                final newRule = {
                  'min': min,
                  'max': max,
                  'grade': grade,
                  'gp': gp,
                };

                if (isEditing) {
                  _gradingRules[index!] = newRule;
                } else {
                  _gradingRules.add(newRule);
                }

                // Re-sort
                _gradingRules.sort(
                  (a, b) => (b['min'] as int).compareTo(a['min'] as int),
                );
              });
              Navigator.pop(context);
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGradingRules() async {
    // Update engine with current view
    GradingEngine().setRulesFor(_selectedGradeKey, _gradingRules);

    // If "9" is selected, we assume it's the "Std 9 & 10" group
    // So distinct keys '9', '10' and 'default' should all start using these rules.
    // NOTE: If user explicitly selected '10' via 'Other', we only save to '10'.
    // But our UI logic now hides '10' from 'Other' usually.
    if (_selectedGradeKey == '9') {
      // The representative key
      GradingEngine().setRulesFor('10', _gradingRules);
      GradingEngine().setRulesFor('default', _gradingRules);
    }

    final db = await DatabaseHelper.instance.database;
    await db.insert('config', {
      'key': 'grading_rules',
      'value': jsonEncode(GradingEngine().getAllRules()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    if (mounted) {
      CustomAppDialog.showSuccess(
        context,
        title: 'Saved',
        message: 'Grading Rules Saved Successfully',
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await CustomAppDialog.showConfirm(
      context,
      title: 'Reset Rules?',
      message:
          'This will replace current rules with the standard default rules for this grade. Unsaved changes will be lost.',
      confirmText: 'Reset',
    );

    if (confirm) {
      setState(() {
        _gradingRules = GradingEngine().getDefaultRulesFor(_selectedGradeKey);
      });
      if (mounted) {
        CustomAppDialog.showInfo(
          context,
          title: 'Reset',
          message: 'Rules reset to default. Click Save to apply.',
        );
      }
    }
  }
}
