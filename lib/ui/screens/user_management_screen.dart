import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/models/user_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/local/database_helper.dart';
import '../widgets/custom_app_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final List<String> _availableClasses = ['10A', '10B', '9A', '9B', '8A'];
  List<SubjectModel> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('subjects');
    setState(() {
      _subjects = res.map((e) => SubjectModel.fromJson(e)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: FutureBuilder<List<UserModel>>(
        future: context.read<AuthProvider>().getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(user.username[0].toUpperCase()),
                  ),
                  title: Text(user.username),
                  subtitle: Text(
                    '${user.role} | Classes: ${user.assignedClasses.join(", ")}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showUserDialog(user: user),
                      ),
                      if (user.username !=
                          'admin') // Prevent deleting main admin
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteUser(user.id!),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showUserDialog({UserModel? user}) {
    final usernameController = TextEditingController(text: user?.username);
    final passwordController = TextEditingController();
    String role = user?.role ?? 'teacher';
    List<String> selectedClasses = user?.assignedClasses ?? [];

    showDialog(
      context: context,
      builder: (context) {
        // Load initial assignments if editing
        Map<String, Set<int>> selectedSubjectAssignments = {};
        bool isLoadingAssignments = user != null;

        return StatefulBuilder(
          builder: (context, setState) {
            // Fetch assignments once if editing
            if (isLoadingAssignments && user != null) {
              isLoadingAssignments = false; // Prevent loop
              context.read<AuthProvider>().getTeacherAssignments(user.id!).then(
                (list) {
                  setState(() {
                    for (var row in list) {
                      final cls = row['class_identifier'] as String;
                      final subId = row['subject_id'] as int;
                      if (!selectedSubjectAssignments.containsKey(cls)) {
                        selectedSubjectAssignments[cls] = {};
                      }
                      selectedSubjectAssignments[cls]!.add(subId);
                    }
                  });
                },
              );
            }

            return AlertDialog(
              title: Text(user == null ? 'Add User' : 'Edit User'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                        ),
                        enabled: user == null,
                      ),
                      TextField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: user == null
                              ? null
                              : 'Leave empty to keep current',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: const InputDecoration(labelText: 'Role'),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: role,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Admin'),
                              ),
                              DropdownMenuItem(
                                value: 'teacher',
                                child: Text('Teacher'),
                              ),
                            ],
                            onChanged: (val) => setState(() => role = val!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (role == 'teacher') ...[
                        const Text(
                          'Assigned Classes & Subjects',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        // Expandable List for Classes
                        Container(
                          height: 300,
                          width: double.maxFinite,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: _availableClasses.map((cls) {
                              // Determine if any subject in this class is selected to show summary
                              // We need a local state structure for selections: Map<Class, Set<SubjectID>>
                              // Actually we can just build it from `selectedAssignments` set if we tracked it that way.
                              // But we re-render this builder on setState. We need a State object for the dialog or just use the parent StatefulBuilder.
                              return ExpansionTile(
                                title: Text(cls),
                                children: _subjects.map((sub) {
                                  final isSelected =
                                      selectedSubjectAssignments.containsKey(
                                        cls,
                                      ) &&
                                      selectedSubjectAssignments[cls]!.contains(
                                        sub.id,
                                      );
                                  return CheckboxListTile(
                                    title: Text(sub.name),
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          if (!selectedSubjectAssignments
                                              .containsKey(cls)) {
                                            selectedSubjectAssignments[cls] =
                                                {};
                                          }
                                          selectedSubjectAssignments[cls]!.add(
                                            sub.id!,
                                          );
                                        } else {
                                          if (selectedSubjectAssignments
                                              .containsKey(cls)) {
                                            selectedSubjectAssignments[cls]!
                                                .remove(sub.id);
                                            if (selectedSubjectAssignments[cls]!
                                                .isEmpty) {
                                              selectedSubjectAssignments.remove(
                                                cls,
                                              );
                                            }
                                          }
                                        }
                                        // Sync simple list
                                        selectedClasses.clear();
                                        selectedClasses.addAll(
                                          selectedSubjectAssignments.keys,
                                        );
                                      });
                                    },
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
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
                    if (usernameController.text.isEmpty) return;
                    if (user == null && passwordController.text.isEmpty) return;

                    try {
                      final authProvider = context.read<AuthProvider>();

                      // 1. Create/Update User
                      int? userId = user?.id;
                      if (user == null) {
                        userId = await authProvider.addUser(
                          usernameController.text,
                          passwordController.text,
                          role,
                          selectedClasses,
                        );
                      } else {
                        await authProvider.updateUser(
                          user.id!,
                          passwordController.text.isEmpty
                              ? null
                              : passwordController.text,
                          role,
                          selectedClasses,
                        );
                      }

                      // 2. Update Assignment Table (Teacher Only)
                      if (role == 'teacher' && userId != null) {
                        await authProvider.clearAssignments(userId);

                        for (var cls in selectedSubjectAssignments.keys) {
                          for (var subId in selectedSubjectAssignments[cls]!) {
                            await authProvider.assignSubject(
                              userId,
                              cls,
                              subId,
                            );
                          }
                        }
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        this.setState(() {});
                        CustomAppDialog.showSuccess(
                          context,
                          title: 'Success',
                          message: 'User saved successfully',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        CustomAppDialog.showError(
                          context,
                          title: 'Error',
                          message: 'Failed to save user: $e',
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteUser(int id) async {
    final confirm = await CustomAppDialog.showConfirm(
      context,
      title: 'Confirm Delete',
      message: 'Are you sure you want to delete this user?',
      confirmText: 'Delete',
    );

    if (confirm) {
      if (mounted) {
        try {
          await context.read<AuthProvider>().deleteUser(id);
          setState(() {});
          if (mounted) {
            CustomAppDialog.showSuccess(
              context,
              title: 'Deleted',
              message: 'User deleted successfully',
            );
          }
        } catch (e) {
          if (mounted) {
            CustomAppDialog.showError(
              context,
              title: 'Error',
              message: 'Failed to delete user: $e',
            );
          }
        }
      }
    }
  }
}
