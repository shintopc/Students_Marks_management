import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/student_model.dart';
import '../../data/models/class_model.dart';
import '../../data/providers/auth_provider.dart';
import '../widgets/custom_app_dialog.dart';
import 'bulk_student_entry_screen.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  // State
  List<ClassModel> _classes = [];
  List<StudentModel> _students = [];
  ClassModel? _selectedClass;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _admissionNoController = TextEditingController();
  final _rollNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('classes', orderBy: 'class_identifier');

    final allAllClasses = rows.map((e) => ClassModel.fromJson(e)).toList();

    // Filter for Teacher
    if (!mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && !user.isAdmin) {
      // assigned_classes is ["10A", "9B"]
      // Filter _classes where classIdentifier is in assigned_classes
      final assigned = user.assignedClasses; // List<String>
      _classes = allAllClasses
          .where((c) => assigned.contains(c.classIdentifier))
          .toList();
    } else {
      _classes = allAllClasses;
    }

    // Do NOT select first class default.
    // Explicitly set null logic is implicit since _selectedClass is initialized null.

    setState(() => _isLoading = false);

    // If we have a selected class (retained state), load students for it
    if (_selectedClass != null) {
      await _loadStudents();
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedClass == null) return;

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'students',
      where: 'class_name = ?',
      whereArgs: [_selectedClass!.classIdentifier],
      orderBy: 'roll_no',
    );

    if (mounted) {
      setState(() {
        _students = rows.map((e) => StudentModel.fromJson(e)).toList();
        _isLoading = false;
      });
    }
  }

  void _onClassChanged(ClassModel? newClass) {
    if (newClass != null) {
      setState(() {
        _selectedClass = newClass;
        _isLoading = true;
      });
      _loadStudents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Students')),
      body: Column(
        children: [
          // Top Bar: Class Selection and Add Button
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Select Class',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ClassModel>(
                        value: _selectedClass,
                        isExpanded: true,
                        items: _classes.map((cls) {
                          return DropdownMenuItem<ClassModel>(
                            value: cls,
                            child: Text(
                              'Class ${cls.classIdentifier}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: _onClassChanged,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _selectedClass == null
                      ? null
                      : () => _showStudentDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Student'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _selectedClass == null
                      ? null
                      : () async {
                          final refresh = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BulkStudentEntryScreen(
                                classIdentifier:
                                    _selectedClass!.classIdentifier,
                              ),
                            ),
                          );
                          if (refresh == true) {
                            _loadStudents();
                          }
                        },
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Bulk Add'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _selectedClass == null ? null : _importFromExcel,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import Excel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _selectedClass == null ? null : _exportToExcel,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Excel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content: Student List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedClass == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.class_, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Please select a class to view students',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _students.isEmpty
                ? const Center(
                    child: Text(
                      "No students found in this class.",
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey.shade200,
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Roll No',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Actions',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: _students.map((student) {
                          return DataRow(
                            cells: [
                              DataCell(Text(student.rollNo.toString())),
                              DataCell(
                                Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () =>
                                          _showStudentDialog(student: student),
                                      tooltip: 'Edit',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _deleteStudent(student.id!),
                                      tooltip: 'Delete',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
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

  void _showStudentDialog({StudentModel? student}) {
    // Pre-fill
    if (student != null) {
      _nameController.text = student.name;
      _admissionNoController.text = student.admissionNo;
      _rollNoController.text = student.rollNo.toString();
      _rollNoController.text = student.rollNo.toString();
    } else {
      _nameController.clear();
      _admissionNoController.clear();
      _rollNoController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          student == null
              ? 'Add Student to ${_selectedClass!.classIdentifier}'
              : 'Edit Student',
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /*
                  TextFormField(
                    controller: _admissionNoController,
                    decoration: const InputDecoration(
                      labelText: 'Admission No',
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  */
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _rollNoController,
                    decoration: const InputDecoration(labelText: 'Roll No'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _saveStudent(student),
            child: Text(student == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveStudent(StudentModel? existing) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClass == null) return;

    final student = StudentModel(
      id: existing?.id,
      // Auto-generate admission no if not editing one, or keep existing.
      // If new, use timestamp or uuid.
      admissionNo:
          existing?.admissionNo ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      className:
          _selectedClass!.classIdentifier, // Locked to current class view
      rollNo: int.parse(_rollNoController.text),
    );

    final db = await DatabaseHelper.instance.database;
    try {
      if (existing == null) {
        await db.insert('students', student.toJson());
      } else {
        await db.update(
          'students',
          student.toJson(),
          where: 'id = ?',
          whereArgs: [existing.id],
        );
      }
      if (mounted) {
        Navigator.pop(context);
        _loadStudents();
        CustomAppDialog.showSuccess(
          context,
          title: 'Success',
          message: 'Student Saved Successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomAppDialog.showError(
          context,
          title: 'Error',
          message: 'Failed to save student: $e',
        );
      }
    }
  }

  Future<void> _deleteStudent(int id) async {
    final confirm = await CustomAppDialog.showConfirm(
      context,
      title: 'Delete Student',
      message: 'Are you sure you want to delete this student?',
      confirmText: 'Delete',
    );

    if (confirm) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('students', where: 'id = ?', whereArgs: [id]);
      _loadStudents();
    }
  }

  String _getCellValue(dynamic cellValue) {
    if (cellValue == null) return '';
    try {
      // Access .value dynamically to avoid type issues with different Excel versions
      final val = (cellValue as dynamic).value;
      if (val == null) return '';

      if (val is String) return val;
      if (val is int || val is double) return val.toString();

      // Handle TextSpan (if present in this version of excel pkg)
      try {
        final text = (val as dynamic).text;
        if (text is String) return text;
      } catch (_) {}

      return val.toString();
    } catch (e) {
      // If no .value or other error, fallback to toString of the cell itself
      return cellValue.toString();
    }
  }

  int? _getIntValue(dynamic cellValue) {
    if (cellValue == null) return null;
    if (cellValue is IntCellValue) return cellValue.value;
    if (cellValue is DoubleCellValue) return cellValue.value.toInt();
    if (cellValue is TextCellValue) {
      var s = _getCellValue(cellValue);
      return int.tryParse(s);
    }
    return int.tryParse(cellValue.toString());
  }

  Future<void> _importFromExcel() async {
    if (_selectedClass == null) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        setState(() => _isLoading = true);

        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        int importedCount = 0;
        final db = await DatabaseHelper.instance.database;
        final batch = db.batch();

        for (var table in excel.tables.keys) {
          // Assume first sheet
          var sheet = excel.tables[table];
          if (sheet == null) continue;

          // Skip header row (maximize row index 0)
          for (int i = 1; i < sheet.maxRows; i++) {
            var row = sheet.rows[i];
            if (row.isEmpty) continue;

            // Expected Columns:
            // 0: Roll No (int)
            // 1: Name (String)
            // 2: Parent Name (String)
            // 3: Phone (String)
            // 4: Address (String)

            var rollNoVal = row.isNotEmpty ? row[0]?.value : null;
            var nameVal = row.length > 1 ? row[1]?.value : null;

            int? rollNo = _getIntValue(rollNoVal);
            if (rollNo == null) continue;

            String name = _getCellValue(nameVal);
            if (name.isEmpty) continue;

            final student = StudentModel(
              admissionNo:
                  DateTime.now().millisecondsSinceEpoch.toString() +
                  importedCount.toString(),
              name: name,
              className: _selectedClass!.classIdentifier,
              rollNo: rollNo,
            );

            batch.insert('students', student.toJson());
            importedCount++;
          }
          // Just process first table/sheet
          break;
        }

        if (importedCount > 0) {
          await batch.commit(noResult: true);
          if (mounted) {
            CustomAppDialog.showSuccess(
              context,
              title: 'Import Successful',
              message: 'Successfully imported $importedCount students.',
            );
          }
        } else {
          if (mounted) {
            CustomAppDialog.showInfo(
              context,
              title: 'No Data',
              message: 'No valid student data found in Excel.',
            );
            setState(() => _isLoading = false);
          }
        }

        _loadStudents(); // Reload list
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomAppDialog.showError(
          context,
          title: 'Import Failed',
          message: 'Error importing file: $e',
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_selectedClass == null || _students.isEmpty) {
      CustomAppDialog.showInfo(
        context,
        title: 'Export',
        message: 'No students to export',
      );
      return;
    }

    try {
      var excel = Excel.createExcel();
      // Rename default sheet
      String sheetName = 'Class ${_selectedClass!.classIdentifier}';
      Sheet sheetObject = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // Header Row
      sheetObject.appendRow([TextCellValue('Roll No'), TextCellValue('Name')]);

      // Data Rows
      for (var s in _students) {
        sheetObject.appendRow([IntCellValue(s.rollNo), TextCellValue(s.name)]);
      }

      // Save
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Student List',
        fileName: 'students_${_selectedClass!.classIdentifier}.xlsx',
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        // Ensure extension
        if (!outputFile.endsWith('.xlsx')) outputFile += '.xlsx';

        var fileBytes = excel.save();
        if (fileBytes != null) {
          File(outputFile)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);

          if (mounted) {
            CustomAppDialog.showSuccess(
              context,
              title: 'Export Successful',
              message: 'Student list exported to $outputFile',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomAppDialog.showError(
          context,
          title: 'Export Failed',
          message: 'Error exporting file: $e',
        );
      }
    }
  }
}
