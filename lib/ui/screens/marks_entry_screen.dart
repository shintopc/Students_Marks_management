import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../data/models/student_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/mark_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/local/database_helper.dart';
import '../../data/logic/grading_engine.dart';
import '../widgets/custom_app_dialog.dart';

class MarksControllers {
  final TextEditingController written = TextEditingController(); // TE
  final ValueNotifier<String?> writtenError = ValueNotifier<String?>(null);

  final TextEditingController teGrade = TextEditingController();

  final TextEditingController practical = TextEditingController(); // CE
  final ValueNotifier<String?> practicalError = ValueNotifier<String?>(null);

  final TextEditingController ceGrade = TextEditingController();
  final TextEditingController total = TextEditingController();
  final TextEditingController finalGrade = TextEditingController();

  void dispose() {
    written.dispose();
    writtenError.dispose();
    teGrade.dispose();
    practical.dispose();
    practicalError.dispose();
    ceGrade.dispose();
    total.dispose();
    finalGrade.dispose();
  }
}

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  bool _isLoading = false;

  // Selection
  String? _selectedClass;
  List<String> _classes = [];
  String? _selectedTerm;
  List<String> _terms = [];
  SubjectModel? _selectedSubject;
  List<SubjectModel> _availableSubjects = [];

  // Data
  List<StudentModel> _students = [];

  // State: StudentID -> Controllers
  final Map<int, MarksControllers> _controllers = {};
  String? _currentGrade;

  @override
  void initState() {
    super.initState();
    GradingEngine().initialize(); // Ensure rules are loaded
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final db = await DatabaseHelper.instance.database;

    // Load Terms
    final termRow = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: ['academic_terms'],
    );
    if (termRow.isNotEmpty) {
      final List<dynamic> list = jsonDecode(termRow.first['value'] as String);
      if (mounted) {
        setState(() => _terms = list.cast<String>());
      }
    }

    _loadData();
  }

  Future<void> _loadData() async {
    // 1. Load Classes (filtered by assignments logic handled in AuthProvider or simple check here?)
    // Actually simpler: Load all classes, but when picking Subject, filter.
    // Or simpler: Load Assigned Classes for the user directly.

    // BUT we already loaded `_classes` in init.
    // Let's refine `_classes` loading first.

    if (_selectedClass == null) {
      // Load Class List
      // If Admin: All Classes via DB.
      // If Teacher: Assigned Classes via AuthProvider.
      // Implementation Note: User `assigned_classes` (the string list) is nice for this.

      final db = await DatabaseHelper.instance.database;
      final user = context.read<AuthProvider>().currentUser;

      if (user?.isAdmin == true) {
        final rows = await db.query('classes', orderBy: 'class_identifier');
        setState(() {
          _classes = rows.map((e) => e['class_identifier'] as String).toList();
        });
      } else if (user != null) {
        // Use the simple list for Class Dropdown
        // Even if we have subject-specific assignments, the class itself is "assigned".
        setState(() {
          _classes = user.assignedClasses;
        });
      }
      return;
    }

    // 2. Load Subjects (Filtered)
    if (_availableSubjects.isEmpty && _selectedClass != null) {
      final user = context.read<AuthProvider>().currentUser;
      final db = await DatabaseHelper.instance.database;

      List<SubjectModel> allSubjects = [];
      final subRows = await db.query('subjects');
      allSubjects = subRows.map((e) => SubjectModel.fromJson(e)).toList();

      if (user?.isAdmin == true) {
        setState(() => _availableSubjects = allSubjects);
      } else if (user != null) {
        // Fetch assignments
        final assignments = await context
            .read<AuthProvider>()
            .getTeacherAssignments(user.id!);
        // Filter: Assignments where class == selectedClass
        final assignedSubjectIds = assignments
            .where((a) => a['class_identifier'] == _selectedClass)
            .map((a) => a['subject_id'] as int)
            .toSet();

        setState(() {
          _availableSubjects = allSubjects
              .where((s) => assignedSubjectIds.contains(s.id))
              .toList();
        });
      }
    }

    // 3. Load Students & Marks
    if (_selectedClass == null ||
        _selectedTerm == null ||
        _selectedSubject == null) {
      return;
    }

    setState(() => _isLoading = true);
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    // Fetch Grade for selected class
    final classRow = await db.query(
      'classes',
      columns: ['grade'],
      where: 'class_identifier = ?',
      whereArgs: [_selectedClass],
    );
    if (classRow.isNotEmpty) {
      _currentGrade = classRow.first['grade'] as String;
    } else {
      _currentGrade = 'default';
    }

    // Fetch Students
    final studentRows = await db.query(
      'students',
      where: 'class_name = ?',
      whereArgs: [_selectedClass],
      orderBy: 'roll_no',
    );
    _students = studentRows.map((e) => StudentModel.fromJson(e)).toList();

    // Fetch Marks for filtered students + selected subject + term
    if (_students.isNotEmpty) {
      final studentIds = _students.map((e) => e.id).join(',');
      final marksRows = await db.rawQuery(
        'SELECT * FROM marks WHERE term = ? AND subject_id = ? AND student_id IN ($studentIds)',
        [_selectedTerm, _selectedSubject!.id],
      );

      // Populate Controllers
      _controllers.clear();
      for (var s in _students) {
        final ctrls = MarksControllers();

        // Add listeners for auto-calculation
        void updateSum() {
          final wText = ctrls.written.text.trim();
          final pText = ctrls.practical.text.trim();

          final w = double.tryParse(wText) ?? 0.0;
          final p = double.tryParse(pText) ?? 0.0;

          // Validation
          if (w > _selectedSubject!.maxWrittenMarks) {
            ctrls.writtenError.value =
                'Max: ${_selectedSubject!.maxWrittenMarks}';
          } else {
            ctrls.writtenError.value = null;
          }

          if (p > _selectedSubject!.maxPracticalMarks) {
            ctrls.practicalError.value =
                'Max: ${_selectedSubject!.maxPracticalMarks}';
          } else {
            ctrls.practicalError.value = null;
          }

          // Calculate Grades
          // Calculate Grades
          final teRes = GradingEngine().calculate(
            w,
            _selectedSubject!.maxWrittenMarks,
            grade: _currentGrade,
          );
          final ceRes = GradingEngine().calculate(
            p,
            _selectedSubject!.maxPracticalMarks,
            grade: _currentGrade,
          );

          final totalVal = w + p;
          final totalRes = GradingEngine().calculate(
            totalVal,
            _selectedSubject!.maxMarks,
            grade: _currentGrade,
          );

          ctrls.teGrade.text = teRes['grade'];
          ctrls.ceGrade.text = ceRes['grade'];
          ctrls.total.text = totalVal.toStringAsFixed(1);
          ctrls.finalGrade.text = totalRes['grade'];
        }

        ctrls.written.addListener(updateSum);
        ctrls.practical.addListener(updateSum);

        _controllers[s.id!] = ctrls;
      }

      for (var row in marksRows) {
        final m = MarkModel.fromJson(row);
        if (_controllers.containsKey(m.studentId)) {
          final ctrls = _controllers[m.studentId]!;
          ctrls.written.text = m.writtenMarks == 0 && m.marksObtained != 0
              ? ""
              : m.writtenMarks.toString();
          ctrls.practical.text = m.practicalMarks.toString();
          // Total/Grades auto-update via listener? No, need to trigger manually or ensure listeners fire.
          // Listeners fire on .text change.
        }
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marks Entry')),
      body: Column(
        children: [
          // Top Bar: Selection
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedClass,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      border: OutlineInputBorder(),
                    ),
                    items: _classes
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedClass = val);
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedTerm,
                    decoration: const InputDecoration(
                      labelText: 'Term',
                      border: OutlineInputBorder(),
                    ),
                    items: _terms
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedTerm = val);
                      _loadData(); // Will just clear grid if no subject selected yet
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<SubjectModel>(
                    initialValue: _selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableSubjects
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.name)),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedSubject = val);
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _saveMarks,
                  icon: const Icon(Icons.save),
                  label: const Text('Save All Marks'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Grid
          // Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedClass == null ||
                      _selectedTerm == null ||
                      _selectedSubject == null
                ? const Center(
                    child: Text(
                      'Select Class, Term and Subject to view marks grid',
                    ),
                  )
                : _students.isEmpty
                ? const Center(child: Text('No students found in this class.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('Roll No')),
                          const DataColumn(label: Text('Student Name')),
                          // Single Subject Columns
                          DataColumn(
                            label: Text(
                              'TE (Max: ${_selectedSubject!.maxWrittenMarks})',
                            ),
                          ),
                          const DataColumn(label: Text('Grade')),
                          DataColumn(
                            label: Text(
                              'CE (Max: ${_selectedSubject!.maxPracticalMarks})',
                            ),
                          ),
                          const DataColumn(label: Text('Grade')),
                          DataColumn(
                            label: Text(
                              'Total (Max: ${_selectedSubject!.maxMarks})',
                            ),
                          ),
                          const DataColumn(label: Text('Final Grd')),
                        ],
                        rows: _students.map((student) {
                          final ctrls = _controllers[student.id];
                          return DataRow(
                            cells: [
                              DataCell(Text(student.rollNo.toString())),
                              DataCell(Text(student.name)),
                              // 1. TE
                              DataCell(
                                SizedBox(
                                  width: 100, // Increased width for error text
                                  child: ValueListenableBuilder<String?>(
                                    valueListenable: ctrls!.writtenError,
                                    builder: (context, error, child) {
                                      return TextField(
                                        controller: ctrls.written,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          errorText: error,
                                          isDense: true,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // 2. TE Gr
                              DataCell(
                                SizedBox(
                                  width: 50,
                                  child: TextField(
                                    controller: ctrls.teGrade,
                                    readOnly: true,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Colors.black12,
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              // 3. CE
                              DataCell(
                                SizedBox(
                                  width: 100, // Increased width
                                  child: ValueListenableBuilder<String?>(
                                    valueListenable: ctrls.practicalError,
                                    builder: (context, error, child) {
                                      return TextField(
                                        controller: ctrls.practical,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          errorText: error,
                                          isDense: true,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // 4. CE Gr
                              DataCell(
                                SizedBox(
                                  width: 50,
                                  child: TextField(
                                    controller: ctrls.ceGrade,
                                    readOnly: true,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Colors.black12,
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              // 5. Total
                              DataCell(
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: ctrls.total,
                                    readOnly: true,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Colors.black12,
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              // 6. Final Grd
                              DataCell(
                                SizedBox(
                                  width: 50,
                                  child: TextField(
                                    controller: ctrls.finalGrade,
                                    readOnly: true,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Colors.black12,
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMarks() async {
    if (_selectedClass == null ||
        _selectedTerm == null ||
        _selectedSubject == null) {
      return;
    }

    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    // 1. Check for Validation Errors
    for (var ctrls in _controllers.values) {
      if (ctrls.writtenError.value != null ||
          ctrls.practicalError.value != null) {
        if (mounted) {
          CustomAppDialog.showError(
            context,
            title: 'Validation Error',
            message: 'Please fix validation errors before saving.',
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }

    // 2. Confirm Save
    final confirm = await CustomAppDialog.showConfirm(
      context,
      title: 'Save Marks',
      message:
          'Are you sure you want to save marks for ${_students.length} students?\n\nExisting marks for this Subject and Term will be overwritten.',
      confirmText: 'Save',
    );

    if (!confirm) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final batch = db.batch();

    for (var student in _students) {
      final ctrls = _controllers[student.id];
      if (ctrls == null) continue;

      final wText = ctrls.written.text.trim();
      final pText = ctrls.practical.text.trim();

      if (wText.isNotEmpty || pText.isNotEmpty) {
        final w = double.tryParse(wText) ?? 0.0;
        final p = double.tryParse(pText) ?? 0.0;
        final total = w + p;

        // Double check validation (redundant but safe)
        if (w > _selectedSubject!.maxWrittenMarks ||
            p > _selectedSubject!.maxPracticalMarks) {
          continue; // Skip invalid rows if somehow passed
        }

        batch.insert('marks', {
          'student_id': student.id,
          'subject_id': _selectedSubject!.id,
          'term': _selectedTerm,
          'marks_obtained': total,
          'written_marks': w,
          'practical_marks': p,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    await batch.commit(noResult: true);

    if (mounted) {
      setState(() => _isLoading = false);
      CustomAppDialog.showSuccess(
        context,
        title: 'Success',
        message: 'Marks Saved Successfully',
      );
    }
  }
}
