import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/database_helper.dart';
import '../../data/models/class_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/models/user_model.dart';
import '../../data/models/subject_model.dart';
import '../widgets/custom_app_dialog.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final _gradeController = TextEditingController();
  final _divisionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<ClassModel> _classes = [];
  List<UserModel> _teachers = [];
  List<SubjectModel> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadTeachers();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('subjects');
    setState(() {
      _subjects = rows.map((e) => SubjectModel.fromJson(e)).toList();
    });
  }

  Future<void> _loadTeachers() async {
    Future.microtask(() async {
      final users = await context.read<AuthProvider>().getAllUsers();
      if (mounted) {
        setState(() {
          _teachers = users.where((u) => u.role == 'teacher').toList();
        });
      }
    });
  }

  Future<void> _loadClasses() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('classes', orderBy: 'class_identifier');
    if (mounted) {
      setState(() {
        _classes = rows.map((json) => ClassModel.fromJson(json)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _addClass() async {
    if (!_formKey.currentState!.validate()) return;

    final grade = _gradeController.text.trim();
    final division = _divisionController.text.trim().toUpperCase();
    final identifier = ClassModel.generateIdentifier(grade, division);

    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('classes', {
        'grade': grade,
        'division': division,
        'class_identifier': identifier,
      });

      // No teacher assignment during creation anymore

      _gradeController.clear();
      _divisionController.clear();
      _loadClasses();

      if (mounted) {
        CustomAppDialog.showSuccess(
          context,
          title: 'Success',
          message: 'Class Added Successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomAppDialog.showError(
          context,
          title: 'Error',
          message: 'Class likely exists or invalid data.',
        );
      }
    }
  }

  Future<void> _deleteClass(int id) async {
    final confirm = await CustomAppDialog.showConfirm(
      context,
      title: 'Delete Class',
      message:
          'Are you sure you want to delete this class?\nAll students in this class will be hidden or deleted.',
      confirmText: 'Delete',
    );

    if (confirm) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('classes', where: 'id = ?', whereArgs: [id]);
      _loadClasses();
    }
  }

  Future<void> _showEditClassDialog(ClassModel cls) async {
    // Load current assignments
    // Map<SubjectId, TeacherId>
    final Map<int, int?> currentAssignments = {};

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'teacher_assignments',
      where: 'class_identifier = ?',
      whereArgs: [cls.classIdentifier],
    );

    for (var row in rows) {
      final subId = row['subject_id'] as int;
      final userId = row['user_id'] as int;
      currentAssignments[subId] = userId;
    }

    // State for the dialog
    final Map<int, int?> dialogAssignments = Map.from(currentAssignments);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Manage Teachers: ${cls.classIdentifier}'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_subjects.isEmpty)
                      const Text('No Subjects Found. Add subjects first.')
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
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
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
                                  onChanged: (val) {
                                    setState(() {
                                      dialogAssignments[subject.id!] = val;
                                    });
                                  },
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

                  // For each subject, update assignment
                  for (var subject in _subjects) {
                    final newTeacherId = dialogAssignments[subject.id];
                    final oldTeacherId = currentAssignments[subject.id];

                    if (newTeacherId != oldTeacherId) {
                      // 1. Remove old assignment (if any)
                      // Strictly remove ANY assignment for this class+subject to enforce 1 teacher
                      // (Logic: DELETE WHERE class=? AND subject=?)
                      batch.delete(
                        'teacher_assignments',
                        where: 'class_identifier = ? AND subject_id = ?',
                        whereArgs: [cls.classIdentifier, subject.id],
                      );

                      // 2. Add new assignment (if not null)
                      if (newTeacherId != null) {
                        batch.insert('teacher_assignments', {
                          'user_id': newTeacherId,
                          'class_identifier': cls.classIdentifier,
                          'subject_id': subject.id,
                        });

                        // Update user's "assignedClasses" cache (legacy support)
                        // We might need to ensure the teacher has this class in their list
                        // This is deeper.
                        // For now, let's assume `teacher_assignments` is the source of truth for Marks Entry.
                        // But we should probably keep `assignedClasses` somewhat up to date for other filters?
                        // Actually, the new Marks Entry uses `teacher_assignments`.
                        // The legacy 'assignedClasses' string list might be less relevant now.
                        // Let's leave it strict to the new table.
                      }
                    }
                  }

                  await batch.commit(noResult: true);

                  if (context.mounted) {
                    Navigator.pop(context);
                    CustomAppDialog.showSuccess(
                      context,
                      title: 'Saved',
                      message: 'Teacher Assignments Updated',
                    );
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: Add Form
        Expanded(
          flex: 1,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add New Class',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gradeController,
                      decoration: const InputDecoration(
                        labelText: 'Grade (e.g. 10)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _divisionController,
                      decoration: const InputDecoration(
                        labelText: 'Division (e.g. A)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Note: You can assign teachers subject-wise after creating the class.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addClass,
                      child: const Text('Add Class'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Right: List
        Expanded(
          flex: 2,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final cls = _classes[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text(cls.grade)),
                        title: Text('Class ${cls.classIdentifier}'),
                        subtitle: Text(
                          'Grade: ${cls.grade}, Div: ${cls.division}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditClassDialog(cls),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteClass(cls.id!),
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
  }
}
