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

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    _loadTerms();
    _loadClasses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          _terms = ['All Terms', ...list.cast<String>()];
          if (_selectedTerm != null && !_terms.contains(_selectedTerm)) {
            _selectedTerm = null;
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _terms = ['All Terms', 'Term 1', 'Term 2', 'Annual'];
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
      appBar: AppBar(
        title: const Text('Report Cards'), // Relabeled
      ),
      body: Column(
        children: [
          // Common Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedClass,
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
                    value: _selectedTerm,
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
              ],
            ),
          ),

          // Search
          if (_selectedClass != null && _selectedTerm != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Student (Name or Roll No)',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
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

    final filteredStudents = _students.where((s) {
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.rollNo.toString().contains(q);
    }).toList();

    return filteredStudents.isEmpty
        ? const Center(child: Text('No students found matching search'))
        : ListView.builder(
            itemCount: filteredStudents.length,
            itemBuilder: (context, index) {
              final student = filteredStudents[index];
              return ListTile(
                title: Text('${student.rollNo}. ${student.name}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Save PDF
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf),
                      tooltip: 'Save Report Card PDF',
                      onPressed: () async {
                        final targetSubjects = _subjects;

                        final pdfBytes = await ReportGenerator()
                            .generateReportCardPdf(
                              student: student,
                              subjects: targetSubjects,
                              marks: _marks,
                              grade: _currentGrade,
                            );

                        String fileName = '${student.name}_ReportCard.pdf';
                        String? outputFile = await FilePicker.platform.saveFile(
                          dialogTitle: 'Save Report Card',
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
                    // View In-App Dialog
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      tooltip: 'View Report Card',
                      onPressed: () => _showReportCardDialog(student),
                    ),
                  ],
                ),
              );
            },
          );
  }

  void _showReportCardDialog(StudentModel student) {
    // 1. Filter Subjects
    final targetSubjects = _subjects;

    // 2. Group Marks by Term
    final Map<String, Map<int, MarkModel>> termMarks = {};
    for (var m in _marks) {
      if (m.studentId == student.id) {
        if (!termMarks.containsKey(m.term)) {
          termMarks[m.term] = {};
        }
        termMarks[m.term]![m.subjectId] = m;
      }
    }

    final terms = termMarks.keys.toList()..sort();

    // 3. Build Widgets
    List<Widget> contentWidgets = [];

    // Header
    contentWidgets.add(
      Text(
        'Name: ${student.name}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
    contentWidgets.add(Text('Roll No: ${student.rollNo}'));
    contentWidgets.add(Text('Class: ${student.className}'));
    contentWidgets.add(const Divider());

    if (terms.isEmpty) {
      contentWidgets.add(const Text("No marks found."));
    }

    for (var term in terms) {
      contentWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Term: $term',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );

      final Map<int, MarkModel> subjectMarks = termMarks[term]!;
      List<DataRow> rows = [];
      double totalObtained = 0;
      double totalMax = 0;

      for (var subject in targetSubjects) {
        final mark = subjectMarks[subject.id];
        double obtained = 0;
        String mGrade = '-';

        if (mark != null) {
          obtained = mark.marksObtained;
          final result = GradingEngine().calculate(
            obtained,
            subject.maxMarks,
            grade: _currentGrade,
          );
          mGrade = result['grade'];

          rows.add(
            DataRow(
              cells: [
                DataCell(Text(subject.name)),
                DataCell(Text(subject.maxMarks.toString())),
                DataCell(Text(obtained.toString())),
                DataCell(
                  Text(
                    mGrade,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );

          totalObtained += obtained;
          totalMax += subject.maxMarks;
        } else {
          // Show as -
          rows.add(
            DataRow(
              cells: [
                DataCell(Text(subject.name)),
                DataCell(Text(subject.maxMarks.toString())),
                DataCell(const Text('-')),
                DataCell(const Text('-')),
              ],
            ),
          );
          totalMax += subject.maxMarks;
        }
      }

      double percentage = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0;

      final grandRes = GradingEngine().calculate(
        totalObtained,
        totalMax,
        grade: _currentGrade,
      );

      contentWidgets.add(
        DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 40,
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Subject')),
            DataColumn(label: Text('Max')),
            DataColumn(label: Text('Obt')),
            DataColumn(label: Text('Grd')),
          ],
          rows: rows,
        ),
      );

      contentWidgets.add(const SizedBox(height: 8));
      contentWidgets.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total: $totalObtained / $totalMax',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%  (${grandRes['grade']})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
      contentWidgets.add(const Divider());
    }

    // 4. Show Dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Card Preview'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: contentWidgets,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
