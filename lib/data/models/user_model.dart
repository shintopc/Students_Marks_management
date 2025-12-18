import 'dart:convert';

class UserModel {
  final int? id;
  final String username;
  final String role; // 'admin' or 'teacher'
  final List<String> assignedClasses;

  UserModel({
    this.id,
    required this.username,
    required this.role,
    required this.assignedClasses,
  });

  bool get isAdmin => role == 'admin';

  bool hasAccessToClass(String className) {
    if (isAdmin) return true;
    return assignedClasses.contains(className);
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      username: map['username'],
      role: map['role'],
      assignedClasses: map['assigned_classes'] != null
          ? List<String>.from(jsonDecode(map['assigned_classes']))
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'assigned_classes': jsonEncode(assignedClasses),
    };
  }
}
