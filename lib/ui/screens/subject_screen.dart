import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/subject_model.dart';
import '../widgets/custom_app_dialog.dart';

class SubjectScreen extends StatefulWidget {
  const SubjectScreen({super.key});

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  List<SubjectModel> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('subjects', orderBy: 'name');
    setState(() {
      _subjects = result.map((e) => SubjectModel.fromJson(e)).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Managed Subjects',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showSubjectDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Subject'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _subjects.isEmpty
              ? const Center(child: Text('No subjects found.'))
              : ListView.builder(
                  itemCount: _subjects.length,
                  itemBuilder: (context, index) {
                    final subject = _subjects[index];
                    return ListTile(
                      title: Text(subject.name),
                      subtitle: Text(
                        'Total: ${subject.maxMarks} (W: ${subject.maxWrittenMarks}, P: ${subject.maxPracticalMarks})',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSubject(subject.id!),
                      ),
                      onTap: () => _showSubjectDialog(subject: subject),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showSubjectDialog({SubjectModel? subject}) {
    final nameController = TextEditingController(text: subject?.name);
    final marksController = TextEditingController(
      text: subject?.maxMarks.toString() ?? '100', // Default total 100
    );
    final writtenMarksController = TextEditingController(
      text: subject?.maxWrittenMarks.toString() ?? '80',
    );
    final practicalMarksController = TextEditingController(
      text: subject?.maxPracticalMarks.toString() ?? '20',
    );

    // Auto-update total
    void updateTotal() {
      final w = double.tryParse(writtenMarksController.text) ?? 0.0;
      final p = double.tryParse(practicalMarksController.text) ?? 0.0;
      marksController.text = (w + p).toStringAsFixed(1);
    }

    writtenMarksController.addListener(updateTotal);
    practicalMarksController.addListener(updateTotal);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(subject == null ? 'Add Subject' : 'Edit Subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Subject Name'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: writtenMarksController,
                    decoration: const InputDecoration(
                      labelText: 'Max TE (Terminal Exam)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: practicalMarksController,
                    decoration: const InputDecoration(
                      labelText: 'Max CE (Continuous Eval)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            TextField(
              controller: marksController,
              decoration: const InputDecoration(
                labelText: 'Total Max Marks (Auto)',
                filled: true,
                fillColor: Colors.black12,
              ),
              keyboardType: TextInputType.number,
              readOnly: true, // Auto-calculated
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
              if (nameController.text.isEmpty) return;

              final w = double.tryParse(writtenMarksController.text) ?? 80.0;
              final p = double.tryParse(practicalMarksController.text) ?? 20.0;
              final total = w + p;

              final newSubject = SubjectModel(
                id: subject?.id,
                name: nameController.text,
                maxMarks: total,
                maxWrittenMarks: w,
                maxPracticalMarks: p,
              );

              final db = await DatabaseHelper.instance.database;
              try {
                if (subject == null) {
                  await db.insert('subjects', newSubject.toJson());
                } else {
                  await db.update(
                    'subjects',
                    newSubject.toJson(),
                    where: 'id = ?',
                    whereArgs: [subject.id],
                  );
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadSubjects();
                }
              } catch (e) {
                if (context.mounted) {
                  CustomAppDialog.showError(
                    context,
                    title: 'Error',
                    message:
                        'Failed to save subject. Name must be unique.\nDetailed error: $e',
                  );
                }
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
      title: 'Confirm Delete',
      message: 'Delete this subject? This might affect existing marks.',
      confirmText: 'Delete',
    );

    if (confirm) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
      _loadSubjects();
    }
  }
}
