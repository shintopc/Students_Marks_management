import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/student_model.dart';
import '../widgets/custom_app_dialog.dart';

class BulkStudentEntryScreen extends StatefulWidget {
  final String classIdentifier;

  const BulkStudentEntryScreen({super.key, required this.classIdentifier});

  @override
  State<BulkStudentEntryScreen> createState() => _BulkStudentEntryScreenState();
}

class _BulkStudentEntryScreenState extends State<BulkStudentEntryScreen> {
  // Each row has a map of controllers
  final List<Map<String, TextEditingController>> _rows = [];
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addNewRow(); // Start with one row
  }

  @override
  void dispose() {
    for (var row in _rows) {
      for (var controller in row.values) {
        controller.dispose();
      }
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _addNewRow() {
    setState(() {
      _rows.add({
        'name': TextEditingController(),
        'roll_no': TextEditingController(),
      });
    });
    // Scroll to bottom after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return; // Keep at least one
    setState(() {
      final row = _rows.removeAt(index);
      for (var c in row.values) {
        c.dispose();
      }
    });
  }

  Future<void> _saveAll() async {
    // Confirm
    final confirm = await CustomAppDialog.showConfirm(
      context,
      title: 'Save All',
      message: 'Are you sure you want to save these students?',
      confirmText: 'Save',
    );

    if (!confirm) return;

    setState(() => _isSaving = true);
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    int saveCount = 0;

    for (var row in _rows) {
      final name = row['name']!.text.trim();
      final rollNoStr = row['roll_no']!.text.trim();

      if (name.isEmpty || rollNoStr.isEmpty) continue; // Skip incomplete

      final rollNo = int.tryParse(rollNoStr);
      if (rollNo == null) continue; // Skip invalid roll no

      final student = StudentModel(
        // Auto-ID
        admissionNo:
            DateTime.now().millisecondsSinceEpoch.toString() +
            saveCount.toString(), // Ensure unique if fast
        name: name,
        className: widget.classIdentifier,
        rollNo: rollNo,
      );

      batch.insert('students', student.toJson());
      saveCount++;
    }

    if (saveCount > 0) {
      await batch.commit(noResult: true);
      if (mounted) {
        await CustomAppDialog.showSuccess(
          context,
          title: 'Success',
          message: 'Saved $saveCount students successfully!',
        );
        Navigator.pop(context, true); // Return true to refresh
      }
    } else {
      if (mounted) {
        CustomAppDialog.showError(
          context,
          title: 'Validation Error',
          message: 'No valid rows to save (Name & Roll No required).',
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bulk Entry - Class ${widget.classIdentifier}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveAll,
            tooltip: 'Save All',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Fill in the student details below. Name and Roll No are required.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addNewRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Row'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Roll No *')),
                    DataColumn(label: Text('Name *')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: _rows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: row['roll_no'],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: '101',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: TextField(
                              controller: row['name'],
                              decoration: const InputDecoration(
                                hintText: 'John Doe',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.grey),
                            onPressed: () => _removeRow(index),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          if (_isSaving) const LinearProgressIndicator(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveAll,
        child: const Icon(Icons.check),
      ),
    );
  }
}
