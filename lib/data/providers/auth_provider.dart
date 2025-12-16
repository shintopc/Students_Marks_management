import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../local/database_helper.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _currentUser;
  bool get isLoggedIn => _currentUser != null;
  UserModel? get currentUser => _currentUser;

  Future<bool> login(String username, String password) async {
    final db = await DatabaseHelper.instance.database;

    // Check if any users exist, if not seed admin
    final resultCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM users',
    );
    final count = resultCount.isNotEmpty
        ? (resultCount.first['count'] as int)
        : 0;
    if (count == 0) {
      await _seedDefaultAdmin(db);
    }

    final inputHash = sha256.convert(utf8.encode(password)).toString();

    final result = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, inputHash],
    );

    if (result.isNotEmpty) {
      _currentUser = UserModel.fromMap(result.first);
      notifyListeners();
      return true;
    }
    return false;
  }

  // --- Assignment Management ---

  Future<void> assignSubject(
    int userId,
    String classIdentifier,
    int subjectId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    try {
      await db.insert('teacher_assignments', {
        'user_id': userId,
        'class_identifier': classIdentifier,
        'subject_id': subjectId,
      });
      notifyListeners();
    } catch (e) {
      // Ignore unique constraint/errors
    }
  }

  Future<void> removeAssignment(
    int userId,
    String classIdentifier,
    int subjectId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'teacher_assignments',
      where: 'user_id = ? AND class_identifier = ? AND subject_id = ?',
      whereArgs: [userId, classIdentifier, subjectId],
    );
    notifyListeners();
  }

  Future<void> clearAssignments(int userId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'teacher_assignments',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getTeacherAssignments(int userId) async {
    final db = await DatabaseHelper.instance.database;
    // Join with subjects to get names
    return await db.rawQuery(
      '''
      SELECT ta.*, s.name as subject_name 
      FROM teacher_assignments ta
      JOIN subjects s ON ta.subject_id = s.id
      WHERE ta.user_id = ?
    ''',
      [userId],
    );
  }

  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _seedDefaultAdmin(Database db) async {
    final defaultPass = 'admin123';
    final defaultHash = sha256.convert(utf8.encode(defaultPass)).toString();

    await db.insert('users', {
      'username': 'admin',
      'password_hash': defaultHash,
      'role': 'admin',
      'assigned_classes': jsonEncode([]), // Admin access not restricted by list
    });
  }

  // User Management Methods

  Future<List<UserModel>> getAllUsers() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users');
    return result.map((e) => UserModel.fromMap(e)).toList();
  }

  Future<int> addUser(
    String username,
    String password,
    String role,
    List<String> classes,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('users', {
      'username': username,
      'password_hash': _hashPassword(password),
      'role': role,
      'assigned_classes': jsonEncode(classes),
    });
    notifyListeners();
    return id;
  }

  Future<void> updateUser(
    int id,
    String? password,
    String role,
    List<String> classes,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final Map<String, dynamic> data = {
      'role': role,
      'assigned_classes': jsonEncode(classes),
    };
    if (password != null && password.isNotEmpty) {
      data['password_hash'] = sha256.convert(utf8.encode(password)).toString();
    }

    await db.update('users', data, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> deleteUser(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
}
