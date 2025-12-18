import 'dart:io';
// ignore_for_file: avoid_print
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseResetService {
  // CONSTANT VERSION - One-time reset trigger
  static const String APP_VERSION = "2.0.0";
  static const String _PREF_KEY_DB_VERSION = "db_version";

  /// Checks if the database needs to be reset based on the app version.
  /// Result:
  /// - First run / Version mismatch -> Deletes DB -> Updates Pref
  /// - Same version -> Do nothing
  static Future<void> checkAndResetDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedVersion = prefs.getString(_PREF_KEY_DB_VERSION);

      if (storedVersion == null || storedVersion != APP_VERSION) {
        // Reset Required
        await _deleteDatabase();

        // Update stored version
        await prefs.setString(_PREF_KEY_DB_VERSION, APP_VERSION);
      }
    } catch (e) {
      // Fail safely - do not crash app on reset failure
      print('Error during database reset check: $e');
    }
  }

  static Future<void> _deleteDatabase() async {
    try {
      // Use standard Windows Application Support Directory
      final appDir = await getApplicationSupportDirectory();
      final dbPath = join(appDir.path, 'marks_system.db');
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        try {
          await dbFile.delete();
          print('Database reset successful: $dbPath');
        } catch (e) {
          print('Could not delete database file (might be locked): $e');
        }
      }
    } catch (e) {
      print('Error locating database for reset: $e');
    }
  }
}
