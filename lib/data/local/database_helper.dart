import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('marks_system.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    sqfliteFfiInit();
    var databaseFactory = databaseFactoryFfi;

    // Use Application Support Directory to ensure write access on Windows
    final appDir = await getApplicationSupportDirectory();
    final dbPath = appDir.path;
    final path = join(dbPath, filePath);

    // Ensure directory exists
    try {
      if (!await Directory(dbPath).exists()) {
        await Directory(dbPath).create(recursive: true);
      }
    } catch (_) {}

    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1, onCreate: _createDB),
    );

    // Migration for Phase 6 (Classes Table)
    // Run this safely every time
    await db.execute('''
      CREATE TABLE IF NOT EXISTS classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade TEXT NOT NULL,
        division TEXT NOT NULL,
        class_identifier TEXT NOT NULL UNIQUE
      )
    ''');

    // Migration for Written/Practical Marks
    try {
      await db.execute(
        'ALTER TABLE marks ADD COLUMN written_marks REAL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE marks ADD COLUMN practical_marks REAL DEFAULT 0',
      );
    } catch (e) {
      // Columns likely already exist
    }

    // Migration for Subject Max Written/Practical
    try {
      await db.execute(
        'ALTER TABLE subjects ADD COLUMN max_written_marks REAL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE subjects ADD COLUMN max_practical_marks REAL DEFAULT 0',
      );
    } catch (e) {
      // Columns likely already exist
    }

    // Migration to remove parent_name, phone, address
    try {
      await db.execute('ALTER TABLE students DROP COLUMN parent_name');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE students DROP COLUMN phone');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE students DROP COLUMN address');
    } catch (_) {}

    // Migration for Teacher Assignments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teacher_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        class_identifier TEXT NOT NULL,
        subject_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE,
        UNIQUE(user_id, class_identifier, subject_id)
      )
    ''');

    return db;
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    // 1. Students Table
    await db.execute('''
CREATE TABLE students (
  id $idType,
  admission_no $textType UNIQUE,
  name $textType,
  class_name $textType,
  roll_no $intType
)
''');

    // 2. Subjects Table
    await db.execute('''
CREATE TABLE subjects (
  id $idType,
  name $textType UNIQUE,
  max_marks $realType,
  max_written_marks $realType,
  max_practical_marks $realType
)
''');

    // 3. Marks Table
    // UPSERT is supported in newer SQLite versions, but we can standard insert/replace.
    // However, user asked for UPSERT specifically or batch handling.
    // UNIQUE constraint on student_id, subject_id, term.
    await db.execute('''
CREATE TABLE marks (
  id $idType,
  student_id $intType,
  subject_id $intType,
  term $textType,
  marks_obtained $realType,
  written_marks $realType,
  practical_marks $realType,
  FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
  FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE,
  UNIQUE(student_id, subject_id, term)
)
''');

    // 4. Config Table
    await db.execute('''
CREATE TABLE config (
  key $textType UNIQUE,
  value $textType
)
''');

    // 5. Logs Table
    await db.execute('''
CREATE TABLE logs (
  id $idType,
  action $textType,
  timestamp $textType,
  details $textType
)
''');

    // 6. Users Table (New in Phase 2)
    await db.execute('''
CREATE TABLE users (
  id $idType,
  username $textType UNIQUE,
  password_hash $textType,
  role $textType,
  assigned_classes $textType
)
''');

    // 7. Classes Table (New in Phase 6)
    await db.execute('''
CREATE TABLE classes (
  id $idType,
  grade $textType,
  division $textType,
  class_identifier $textType UNIQUE
)
''');

    // 8. Teacher Assignments Table (New in Phase 7)
    await db.execute('''
CREATE TABLE teacher_assignments (
  id $idType,
  user_id $intType,
  class_identifier $textType,
  subject_id $intType,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE,
  UNIQUE(user_id, class_identifier, subject_id)
)
''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> backupDatabase(String destinationPath) async {
    final appDir = await getApplicationSupportDirectory();
    final dbPath = appDir.path;
    final path = join(dbPath, 'marks_system.db');
    final file = File(path);

    await file.copy(destinationPath);
  }

  Future<void> restoreDatabase(String sourcePath) async {
    final appDir = await getApplicationSupportDirectory();
    final dbPath = appDir.path;
    final path = join(dbPath, 'marks_system.db');
    final file = File(sourcePath);

    // Close existing connection
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    await file.copy(path);
    // User must restart app or we force reload
  }

  Future<void> resetDatabase() async {
    final db = await instance.database;

    // Clear academic data tables
    await db.delete('marks');
    await db.delete('students');
    await db.delete('subjects');
    await db.delete('classes');
    await db.delete('teacher_assignments');
    await db.delete('logs');

    // NOTE: We do NOT clear 'users' (to keep admin login)
    // and 'config' (to keep school profile/rules) by default.
    // If a full wipe is needed, include those too.
  }
}
