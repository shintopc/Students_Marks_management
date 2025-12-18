import 'dart:convert';
import '../local/database_helper.dart';

class GradingEngine {
  // Singleton pattern
  static final GradingEngine _instance = GradingEngine._internal();
  factory GradingEngine() => _instance;
  GradingEngine._internal();

  Map<String, List<Map<String, dynamic>>> _allRules = {};

  // Default Kerala Syllabus rules
  final List<Map<String, dynamic>> _defaultRules = [
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

  final List<Map<String, dynamic>> _std8Rules = [
    {
      "min": 80,
      "max": 100,
      "grade": "A",
      "gp": 8,
    }, // Above 80% (assuming max 100% scale internally)
    {"min": 60, "max": 79, "grade": "B", "gp": 6},
    {"min": 40, "max": 59, "grade": "C", "gp": 4},
    {"min": 30, "max": 39, "grade": "D", "gp": 3},
    {"min": 0, "max": 29, "grade": "E", "gp": 1}, // Below 30%
  ];

  // Load rules from DB
  Future<void> initialize() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: ['grading_rules'],
    );

    if (rows.isNotEmpty) {
      final jsonStr = rows.first['value'] as String;
      final dynamic decoded = jsonDecode(jsonStr);

      if (decoded is List) {
        // Migration: Old format was just a list. Wrap it in 'default'.
        _allRules = {'default': List<Map<String, dynamic>>.from(decoded)};
      } else if (decoded is Map) {
        // New format
        _allRules = {};
        decoded.forEach((key, value) {
          _allRules[key] = List<Map<String, dynamic>>.from(value);
        });
      }
    } else {
      // Fallback
      _allRules = {'default': _defaultRules};
    }

    // Ensure all sorted
    for (var key in _allRules.keys) {
      _allRules[key]!.sort(
        (a, b) => (b['min'] as int).compareTo(a['min'] as int),
      );
    }

    // Seed Defaults for 8, 9, 10 if missing
    if (!_allRules.containsKey('8')) _allRules['8'] = List.from(_std8Rules);
    if (!_allRules.containsKey('9')) _allRules['9'] = List.from(_defaultRules);
    if (!_allRules.containsKey('10'))
      _allRules['10'] = List.from(_defaultRules);
    // Also seed default if missing
    if (!_allRules.containsKey('default'))
      _allRules['default'] = List.from(_defaultRules);
  }

  Map<String, dynamic> calculate(
    double marksObtained,
    double maxMarks, {
    String? grade,
  }) {
    if (maxMarks == 0) return {'percentage': 0.0, 'grade': '?', 'gp': 0.0};

    double percentage = (marksObtained / maxMarks) * 100;
    // Audit fix: Round to 1 decimal to match standard rules (e.g. 89.95 -> 90.0) or ceil?
    // Standard is usually half-up at 0.5.
    // Let's use string fixed to ensure precision stability.
    percentage = double.parse(percentage.toStringAsFixed(1));

    // Determine which rules to use
    // 1. Try specific grade rule (e.g. "10")
    // 2. Try 'default'
    // 3. Fallback to hardcoded default
    List<Map<String, dynamic>> rules =
        _allRules[grade] ?? _allRules['default'] ?? _defaultRules;

    // Find rule
    for (var rule in rules) {
      if (percentage >= (rule['min'] as int)) {
        return {
          'percentage': percentage,
          'grade': rule['grade'],
          'gp': (rule['gp'] as num).toDouble(),
        };
      }
    }

    return {
      'percentage': percentage,
      'grade': 'E',
      'gp': 0.0,
    }; // Default fail if below min
  }

  // Helper to get hardcoded default rules (for reset functionality)
  List<Map<String, dynamic>> getDefaultRulesFor(String gradeKey) {
    if (gradeKey == '8') {
      return List<Map<String, dynamic>>.from(
        _std8Rules.map((e) => Map<String, dynamic>.from(e)),
      );
    } else {
      // 9, 10, default all use the standard A+ to E scale
      return List<Map<String, dynamic>>.from(
        _defaultRules.map((e) => Map<String, dynamic>.from(e)),
      );
    }
  }

  // Helper to get rule set for UI editing
  List<Map<String, dynamic>> getRulesFor(String gradeKey) {
    return _allRules[gradeKey] ?? List.from(_defaultRules);
  }

  // Helper to save rules (memory only, caller saves to DB)
  void setRulesFor(String gradeKey, List<Map<String, dynamic>> newRules) {
    _allRules[gradeKey] = newRules;
  }

  Map<String, List<Map<String, dynamic>>> getAllRules() => _allRules;
}
