import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/database_helper.dart';
import '../../data/models/class_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/models/user_model.dart';
import '../widgets/custom_app_dialog.dart';

class AcademicManagementScreen extends StatefulWidget {
  const AcademicManagementScreen({super.key});

  @override
  State<AcademicManagementScreen> createState() =>
      _AcademicManagementScreenState();
}

class _AcademicManagementScreenState extends State<AcademicManagementScreen> {
  // Data
  List<ClassModel> _classes = [];
  List<SubjectModel> _subjects = [];
  List<String> _terms = [];
  List<UserModel> _teachers = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadClasses(),
      _loadSubjects(),
      _loadTerms(),
      _loadTeachers(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadClasses() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('classes', orderBy: 'class_identifier');
    _classes = rows.map((json) => ClassModel.fromJson(json)).toList();
  }

  Future<void> _loadSubjects() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('subjects', orderBy: 'name');
    _subjects = rows.map((e) => SubjectModel.fromJson(e)).toList();
  }

  Future<void> _loadTerms() async {
    final db = await DatabaseHelper.instance.database;
    final row = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: ['academic_terms'],
    );
    if (row.isNotEmpty) {
      final List<dynamic> list = jsonDecode(row.first['value'] as String);
      _terms = list.cast<String>();
    } else {
      _terms = [];
    }
  }

  Future<void> _loadTeachers() async {
    final users = await context.read<AuthProvider>().getAllUsers();
    _teachers = users.where((u) => u.role == 'teacher').toList();
  }

  // --- TERMS LOGIC ---
  Future<void> _addTerm(String term) async {
    if (_terms.contains(term)) return;
    _terms.add(term);
    await _saveTerms();
    _refreshAll();
  }

  Future<void> _deleteTerm(String term) async {
    final confirm = await CustomAppDialog.showConfirm(
      context,
      title: 'Delete Term',
      message: 'Are you sure you want to delete "$term"?',
      confirmText: 'Delete',
    );

    if (confirm) {
      _terms.remove(term);
      await _saveTerms();
      _refreshAll();
    }
  }

  Future<void> _saveTerms() async {
    final db = await DatabaseHelper.instance.database;
    // UPSERT style for config
    final count = await db.update(
      'config',
      {'value': jsonEncode(_terms)},
      where: 'key = ?',
      whereArgs: ['academic_terms'],
    );
    if (count == 0) {
      await db.insert('config', {
        'key': 'academic_terms',
        'value': jsonEncode(_terms),
      });
    }
  }

  void _showAddTermDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Term'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Term Name (e.g. Term 1)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addTerm(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // --- CLASSES LOGIC ---
  void _showAddClassDialog() {
    final gradeCtrl = TextEditingController();
    final divCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gradeCtrl,
              decoration: const InputDecoration(labelText: 'Grade'),
            ),
            TextField(
              controller: divCtrl,
              decoration: const InputDecoration(labelText: 'Division'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (gradeCtrl.text.isNotEmpty && divCtrl.text.isNotEmpty) {
                final id = ClassModel.generateIdentifier(
                  gradeCtrl.text.trim(),
                  divCtrl.text.trim().toUpperCase(),
                );
                try {
                  final db = await DatabaseHelper.instance.database;
                  await db.insert('classes', {
                    'grade': gradeCtrl.text.trim(),
                    'division': divCtrl.text.trim().toUpperCase(),
                    'class_identifier': id,
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    _refreshAll();
                  }
                } catch (e) {
                  // Ignore dupe
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClass(int id) async {
    final confirm = await CustomAppDialog.showConfirm(
      context,
      title: 'Delete Class',
      message: 'Delete this class?',
      confirmText: 'Delete',
    );

    if (confirm) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('classes', where: 'id = ?', whereArgs: [id]);
      _refreshAll();
    }
  }

  // Same edit dialog as before
  Future<void> _showEditClassDialog(ClassModel cls) async {
    // 1. Current Assignments
    final Map<int, int?> currentAssignments = {};
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'teacher_assignments',
      where: 'class_identifier = ?',
      whereArgs: [cls.classIdentifier],
    );
    for (var row in rows) {
      currentAssignments[row['subject_id'] as int] = row['user_id'] as int;
    }
    final Map<int, int?> dialogAssignments = Map.from(currentAssignments);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Teachers: ${cls.classIdentifier}'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_subjects.isEmpty)
                      const Text('No Subjects Available')
                    else
                      ..._subjects.map((subject) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  subject.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<int>(
                                  initialValue: dialogAssignments[subject.id],
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  hint: const Text('Select Teacher'),
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text(
                                        'Unassigned',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    ..._teachers.map(
                                      (t) => DropdownMenuItem(
                                        value: t.id,
                                        child: Text(t.username),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) => setState(
                                    () => dialogAssignments[subject.id!] = val,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final db = await DatabaseHelper.instance.database;
                  final batch = db.batch();
                  for (var subject in _subjects) {
                    final newId = dialogAssignments[subject.id];
                    final oldId = currentAssignments[subject.id];
                    if (newId != oldId) {
                      batch.delete(
                        'teacher_assignments',
                        where: 'class_identifier = ? AND subject_id = ?',
                        whereArgs: [cls.classIdentifier, subject.id],
                      );
                      if (newId != null) {
                        batch.insert('teacher_assignments', {
                          'user_id': newId,
                          'class_identifier': cls.classIdentifier,
                          'subject_id': subject.id,
                        });
                      }
                    }
                  }
                  await batch.commit(noResult: true);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- SUBJECTS LOGIC ---
  void _showSubjectDialog({SubjectModel? subject}) {
    final nameCtrl = TextEditingController(text: subject?.name);
    final wCtrl = TextEditingController(
      text: subject?.maxWrittenMarks.toString() ?? '80',
    );
    final pCtrl = TextEditingController(
      text: subject?.maxPracticalMarks.toString() ?? '20',
    );
    final totalCtrl = TextEditingController(
      text: subject?.maxMarks.toString() ?? '100',
    );

    void updateTotal() {
      final w = double.tryParse(wCtrl.text) ?? 0.0;
      final p = double.tryParse(pCtrl.text) ?? 0.0;
      totalCtrl.text = (w + p).toStringAsFixed(1);
    }

    wCtrl.addListener(updateTotal);
    pCtrl.addListener(updateTotal);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(subject == null ? 'Add Subject' : 'Edit Subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: wCtrl,
                    decoration: const InputDecoration(labelText: 'Max TE'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: pCtrl,
                    decoration: const InputDecoration(labelText: 'Max CE'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            TextField(
              controller: totalCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Total',
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final w = double.tryParse(wCtrl.text) ?? 0.0;
              final p = double.tryParse(pCtrl.text) ?? 0.0;
              final model = SubjectModel(
                id: subject?.id,
                name: nameCtrl.text,
                maxWrittenMarks: w,
                maxPracticalMarks: p,
                maxMarks: w + p,
              );

              final db = await DatabaseHelper.instance.database;
              if (subject == null) {
                await db.insert('subjects', model.toJson());
              } else {
                await db.update(
                  'subjects',
                  model.toJson(),
                  where: 'id = ?',
                  whereArgs: [subject.id],
                );
              }
              if (context.mounted) {
                Navigator.pop(context);
                _refreshAll();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubject(int id) async {
    final confirm = await CustomAppDialog.showConfirm(
      context,
      title: 'Delete Subject',
      message: 'Delete this subject?',
      confirmText: 'Delete',
    );

    if (confirm) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
      _refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Classes Column
          Expanded(
            child: _buildColumn(
              title: 'Classes',
              onAdd: _showAddClassDialog,
              child: ListView.separated(
                itemCount: _classes.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cls = _classes[index];
                  return ListTile(
                    title: Text(cls.classIdentifier),
                    subtitle: Text('${cls.grade} - ${cls.division}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showEditClassDialog(cls),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteClass(cls.id!),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 2. Subjects Column
          Expanded(
            child: _buildColumn(
              title: 'Subjects',
              onAdd: () => _showSubjectDialog(),
              child: ListView.separated(
                itemCount: _subjects.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final sub = _subjects[index];
                  return ListTile(
                    title: Text(sub.name),
                    subtitle: Text('Max: ${sub.maxMarks}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showSubjectDialog(subject: sub),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteSubject(sub.id!),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 3. Terms Column
          Expanded(
            child: _buildColumn(
              title: 'Terms',
              onAdd: _showAddTermDialog,
              child: _terms.isEmpty
                  ? const Center(
                      child: Text(
                        'No Terms Added',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _terms.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final term = _terms[index];
                        return ListTile(
                          title: Text(term),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteTerm(term),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn({
    required String title,
    required VoidCallback onAdd,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
