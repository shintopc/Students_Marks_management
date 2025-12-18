import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/student_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/mark_model.dart';
import '../../data/logic/report_generator.dart';
import '../../data/logic/grading_engine.dart';
import '../widgets/custom_app_dialog.dart';

class GradeAnalysisScreen extends StatefulWidget {
  const GradeAnalysisScreen({super.key});

  @override
  State<GradeAnalysisScreen> createState() => _GradeAnalysisScreenState();
}

class _GradeAnalysisScreenState extends State<GradeAnalysisScreen> {
  // Selection
  String? _selectedClass;
  List<String> _classes = [];
  String? _selectedTerm;
  List<String> _terms = [];

  // Data
  List<StudentModel> _students = [];
  List<SubjectModel> _subjects = [];
  List<MarkModel> _marks = [];
  bool _isLoading = false;
  String? _currentGrade;

  // Filters
  SubjectModel? _selectedSubject;
  int _sortOption = 0; // 0=Roll, 1=Marks High-Low, 2=Marks Low-High
  bool _isDetailedView = false;

  @override
  void initState() {
    super.initState();
    _loadTerms();
    _loadClasses();
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
      if (mounted) {
        setState(() {
          // Grade Analysis only allows specific terms, not "All Terms"
          _terms = list.cast<String>();

          // Reset selected term if it's no longer in the list
          if (_selectedTerm != null && !_terms.contains(_selectedTerm)) {
            _selectedTerm = null;
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _terms = ['Term 1', 'Term 2', 'Annual'];
        });
      }
    }
  }

  Future<void> _loadClasses() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('classes', orderBy: 'class_identifier');
    setState(() {
      _classes = rows.map((e) => e['class_identifier'] as String).toList();
    });
  }

  Future<void> _loadData() async {
    if (_selectedClass == null || _selectedTerm == null) return;

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

    // Students
    final sRows = await db.query(
      'students',
      where: 'class_name = ?',
      whereArgs: [_selectedClass],
      orderBy: 'roll_no',
    );
    _students = sRows.map((e) => StudentModel.fromJson(e)).toList();

    // Subjects
    final subRows = await db.query('subjects');
    _subjects = subRows.map((e) => SubjectModel.fromJson(e)).toList();

    // Auto-select first subject if none selected or invalid
    if (_subjects.isNotEmpty) {
      if (_selectedSubject == null ||
          !_subjects.any((s) => s.id == _selectedSubject!.id)) {
        _selectedSubject = _subjects.first;
      }
    } else {
      _selectedSubject = null;
    }

    // Marks
    if (_students.isNotEmpty) {
      final ids = _students.map((e) => e.id).join(',');
      final mRows = await db.rawQuery(
        'SELECT * FROM marks WHERE student_id IN ($ids)',
      );
      _marks = mRows.map((e) => MarkModel.fromJson(e)).toList();
    } else {
      _marks = [];
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grade Analysis')),
      body: Column(
        children: [
          // Common Filters
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
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<SubjectModel>(
                    initialValue: _selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Filter Subject',
                      border: OutlineInputBorder(),
                    ),
                    items: _subjects
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.name)),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedSubject = val);
                      // No reload needed, just filtering
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedClass == null || _selectedTerm == null) {
      return const Center(child: Text('Select Class and Term'));
    }
    if (_students.isEmpty) return const Center(child: Text('No Data'));

    // Process Data based on filters
    List<Map<String, dynamic>> rowsData = [];

    // Filter marks for the selected term
    final termMarks = _marks.where((m) => m.term == _selectedTerm).toList();

    for (var student in _students) {
      double totalObtained = 0;
      double totalMax = 0;

      if (_selectedSubject != null) {
        // Single Subject Mode
        final mark = termMarks.firstWhere(
          (m) =>
              m.studentId == student.id && m.subjectId == _selectedSubject!.id,
          orElse: () {
            // Return default
            return MarkModel(
              id: -1,
              studentId: student.id ?? 0,
              subjectId: _selectedSubject!.id ?? 0,
              term: '',
              marksObtained: 0,
              writtenMarks: 0,
              practicalMarks: 0,
            );
          },
        );
        totalObtained = mark.marksObtained;
        totalMax = _selectedSubject!.maxMarks;
      } else {
        // Fallback logic if needed
        for (var mark in termMarks.where((m) => m.studentId == student.id)) {
          final sub = _subjects.firstWhere(
            (s) => s.id == mark.subjectId,
            orElse: () => SubjectModel(
              id: -1,
              name: '',
              maxMarks: 0,
              maxWrittenMarks: 0,
              maxPracticalMarks: 0,
            ),
          );
          totalObtained += mark.marksObtained;
          totalMax += sub.maxMarks;
        }
      }

      final res = GradingEngine().calculate(
        totalObtained,
        totalMax,
        grade: _currentGrade,
      );

      rowsData.add({
        'student': student,
        'obtained': totalObtained,
        'max': totalMax,
        'grade': res['grade'],
        'percentage': totalMax > 0 ? (totalObtained / totalMax) * 100 : 0.0,
      });
    }

    // Sort
    if (_sortOption == 1) {
      // High to Low
      rowsData.sort(
        (a, b) => (b['obtained'] as double).compareTo(a['obtained'] as double),
      );
    } else if (_sortOption == 2) {
      // Low to High
      rowsData.sort(
        (a, b) => (a['obtained'] as double).compareTo(b['obtained'] as double),
      );
    } else if (_sortOption == 3) {
      // Grade (using percentage for sorting)
      rowsData.sort(
        (a, b) =>
            (b['percentage'] as double).compareTo(a['percentage'] as double),
      );
    }

    return Column(
      children: [
        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text('Sort By: '),
              DropdownButton<int>(
                value: _sortOption,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Roll No')),
                  DropdownMenuItem(value: 1, child: Text('Marks (High-Low)')),
                  DropdownMenuItem(value: 2, child: Text('Marks (Low-High)')),
                ],
                onChanged: (v) => setState(() => _sortOption = v!),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isDetailedView,
                    onChanged: (val) {
                      setState(() {
                        _isDetailedView = val ?? false;
                      });
                    },
                  ),
                  const Text('Detailed View'),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF'),
                onPressed: () async {
                  final targetSubjects = _selectedSubject != null
                      ? [_selectedSubject!]
                      : _subjects;

                  final title = _selectedSubject != null
                      ? 'Subject Report: ${_selectedSubject!.name}'
                      : 'Tabulation Register';

                  final sortedStudents = rowsData
                      .map((d) => d['student'] as StudentModel)
                      .toList();

                  final pdfBytes = await ReportGenerator().generateTRPdf(
                    className: _selectedClass!,
                    term: _selectedTerm!,
                    students: sortedStudents,
                    subjects: targetSubjects,
                    marks: _marks,
                    isDetailed: _isDetailedView,
                    grade: _currentGrade,
                    title: title,
                  );

                  // PDF Save Logic
                  String fileName = _selectedSubject != null
                      ? '${_selectedSubject!.name}_Report.pdf'
                      : 'TR_${_selectedClass}_$_selectedTerm.pdf';

                  String? outputFile = await FilePicker.platform.saveFile(
                    dialogTitle: 'Save PDF',
                    fileName: fileName,
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                  );

                  if (outputFile != null) {
                    if (!outputFile.toLowerCase().endsWith('.pdf')) {
                      outputFile = '$outputFile.pdf';
                    }

                    final file = File(outputFile);
                    await file.writeAsBytes(pdfBytes);

                    if (context.mounted) {
                      CustomAppDialog.showSuccess(
                        context,
                        title: 'PDF Saved',
                        message: 'Saved to $outputFile',
                      );
                    }

                    await OpenFile.open(outputFile);
                  }
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.table_chart),
                label: const Text('Excel'),
                onPressed: () async {
                  final targetSubjects = _selectedSubject != null
                      ? [_selectedSubject!]
                      : _subjects;

                  final title = _selectedSubject != null
                      ? 'Subject Report: ${_selectedSubject!.name}'
                      : 'Mark List';

                  final sortedStudents = rowsData
                      .map((d) => d['student'] as StudentModel)
                      .toList();

                  final excelBytes = ReportGenerator().generateTRExcel(
                    className: _selectedClass!,
                    term: _selectedTerm!,
                    students: sortedStudents,
                    subjects: targetSubjects,
                    marks: _marks,
                    isDetailed: _isDetailedView,
                    grade: _currentGrade,
                    title: title,
                  );

                  if (excelBytes != null) {
                    String fileName = _selectedSubject != null
                        ? '${_selectedSubject!.name}_Report.xlsx'
                        : 'TR_${_selectedClass}_$_selectedTerm.xlsx';

                    String? outputFile = await FilePicker.platform.saveFile(
                      dialogTitle: 'Save Excel',
                      fileName: fileName,
                    );

                    if (outputFile != null) {
                      final file = File(outputFile);
                      await file.writeAsBytes(excelBytes);

                      if (context.mounted) {
                        CustomAppDialog.showSuccess(
                          context,
                          title: 'Excel Saved',
                          message: 'Saved to $outputFile',
                        );
                      }

                      OpenFile.open(outputFile);
                    }
                  }
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('Roll')),
                  const DataColumn(label: Text('Name')),
                  if (_isDetailedView && _selectedSubject != null) ...[
                    const DataColumn(label: Text('TE')),
                    const DataColumn(label: Text('Grd')),
                    const DataColumn(label: Text('CE')),
                    const DataColumn(label: Text('Grd')),
                    const DataColumn(label: Text('Total')),
                    const DataColumn(label: Text('Grade')),
                    const DataColumn(label: Text('%')),
                  ] else ...[
                    const DataColumn(label: Text('Obtained')),
                    const DataColumn(label: Text('Max')),
                    const DataColumn(label: Text('%')),
                    const DataColumn(label: Text('Grade')),
                  ],
                ],
                rows: rowsData.map((d) {
                  final s = d['student'] as StudentModel;
                  final cells = <DataCell>[
                    DataCell(Text(s.rollNo.toString())),
                    DataCell(Text(s.name)),
                  ];

                  if (_selectedSubject != null) {
                    // Single Subject Display
                    final termMarks = _marks
                        .where((m) => m.term == _selectedTerm)
                        .toList();
                    final mark = termMarks.firstWhere(
                      (m) =>
                          m.studentId == s.id &&
                          m.subjectId == _selectedSubject!.id,
                      orElse: () {
                        return MarkModel(
                          id: -1,
                          studentId: s.id ?? 0,
                          subjectId: _selectedSubject!.id ?? 0,
                          term: '',
                          marksObtained: 0,
                          writtenMarks: 0,
                          practicalMarks: 0,
                        );
                      },
                    );

                    if (_isDetailedView) {
                      // Grades Calculation
                      final teRes = GradingEngine().calculate(
                        mark.writtenMarks,
                        _selectedSubject!.maxWrittenMarks,
                        grade: _currentGrade,
                      );
                      final ceRes = GradingEngine().calculate(
                        mark.practicalMarks,
                        _selectedSubject!.maxPracticalMarks,
                        grade: _currentGrade,
                      );

                      // TE / TE Grd / CE / CE Grd / Total / Grade / %
                      cells.add(
                        DataCell(Text(mark.writtenMarks.toStringAsFixed(1))),
                      );
                      cells.add(
                        DataCell(
                          Text(
                            teRes['grade'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                      cells.add(
                        DataCell(Text(mark.practicalMarks.toStringAsFixed(1))),
                      );
                      cells.add(
                        DataCell(
                          Text(
                            ceRes['grade'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                      cells.add(
                        DataCell(Text(mark.marksObtained.toStringAsFixed(1))),
                      );
                      cells.add(
                        DataCell(
                          Text(
                            d['grade'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                      cells.add(
                        DataCell(
                          Text((d['percentage'] as double).toStringAsFixed(1)),
                        ),
                      );
                    } else {
                      // Obtained / Max / % / Grade
                      cells.add(
                        DataCell(
                          Text((d['obtained'] as double).toStringAsFixed(1)),
                        ),
                      );
                      cells.add(
                        DataCell(Text((d['max'] as double).toStringAsFixed(1))),
                      );
                      cells.add(
                        DataCell(
                          Text((d['percentage'] as double).toStringAsFixed(1)),
                        ),
                      );
                      cells.add(
                        DataCell(
                          Text(
                            d['grade'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  } else {
                    // Fallback
                    cells.add(const DataCell(Text('-')));
                    cells.add(const DataCell(Text('-')));
                    cells.add(const DataCell(Text('-')));
                    cells.add(const DataCell(Text('-')));
                  }

                  return DataRow(cells: cells);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
