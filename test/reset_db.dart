import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studentmanagement/data/local/database_helper.dart';

void main() {
  test('Reset Database', () async {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Reset
    print('Resetting Database...');
    await DatabaseHelper.instance.resetDatabase();
    print('Database Reset Complete.');
  });
}
