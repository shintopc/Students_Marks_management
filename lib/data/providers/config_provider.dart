import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../local/database_helper.dart';

class ConfigProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> checkLoginStatus() async {
    // Ideally check shared preferences or session, but for this desktop app we might just start at login every time.
    _isLoggedIn = false;
    await loadSchoolProfile(); // Load branding data
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    final db = await DatabaseHelper.instance.database;
    final userRow = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: ['auth_user'],
    );

    final passRow = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: ['auth_pass'],
    );

    String? storedUser;
    String? storedPassHash;

    if (userRow.isNotEmpty) storedUser = userRow.first['value'] as String;
    if (passRow.isNotEmpty) storedPassHash = passRow.first['value'] as String;

    // Default credentials if not set
    if (storedUser == null || storedPassHash == null) {
      // Initialize default: admin / admin123
      final defaultUser = 'admin';
      final defaultPass = 'admin123';
      final defaultHash = sha256.convert(utf8.encode(defaultPass)).toString();

      await db.insert('config', {'key': 'auth_user', 'value': defaultUser});
      await db.insert('config', {'key': 'auth_pass', 'value': defaultHash});

      storedUser = defaultUser;
      storedPassHash = defaultHash;

      await _seedDefaults(db);
    }

    final inputHash = sha256.convert(utf8.encode(password)).toString();

    if (username == storedUser && inputHash == storedPassHash) {
      _isLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    notifyListeners();
  }

  // School Profile Data
  String _schoolName = "Student Marks Management System";
  String _logoPath = "";

  String get schoolName => _schoolName;
  String get logoPath => _logoPath;

  Future<void> loadSchoolProfile() async {
    final db = await DatabaseHelper.instance.database;
    final profileRow = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: ['school_profile'],
    );
    if (profileRow.isNotEmpty) {
      final profile = jsonDecode(profileRow.first['value'] as String);
      _schoolName = profile['school_name'] ?? "Student Marks Management System";
      if (_schoolName.isEmpty) _schoolName = "Student Marks Management System";
      _logoPath = profile['logo_path'] ?? "";
      notifyListeners();
    }
  }

  Future<void> _seedDefaults(Database db) async {
    // 1. Kerala Grading System
    final gradingSystem = [
      {"min": 90, "max": 100, "grade": "A+", "gp": 9},
      {"min": 80, "max": 89, "grade": "A", "gp": 8},
      {"min": 70, "max": 79, "grade": "B+", "gp": 7},
      {"min": 60, "max": 69, "grade": "B", "gp": 6},
      {"min": 50, "max": 59, "grade": "C+", "gp": 5},
      {"min": 40, "max": 49, "grade": "C", "gp": 4},
      {"min": 30, "max": 39, "grade": "D+", "gp": 3},
      {"min": 20, "max": 29, "grade": "D", "gp": 2},
      {"min": 0, "max": 19, "grade": "E", "gp": 1},
    ];

    await db.insert('config', {
      'key': 'grading_rules',
      'value': jsonEncode(gradingSystem),
    });

    // 2. School Profile
    final schoolProfile = {
      "school_name": "My School",
      "address": "Kerala, India",
      "academic_year": "2024-2025",
      "logo_path": "",
    };

    await db.insert('config', {
      'key': 'school_profile',
      'value': jsonEncode(schoolProfile),
    });

    // Load initial values
    // Note: We can't call loadSchoolProfile here easily because this runs during db creation/seeding.
    // Instead loadSchoolProfile will be called by consumers or main init.
  }
}
