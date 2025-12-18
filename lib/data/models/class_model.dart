class ClassModel {
  final int? id;
  final String grade; // e.g., "10"
  final String division; // e.g., "A"
  final String classIdentifier; // e.g., "10A" - Unique

  ClassModel({
    this.id,
    required this.grade,
    required this.division,
    required this.classIdentifier,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'],
      grade: json['grade'],
      division: json['division'],
      classIdentifier: json['class_identifier'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grade': grade,
      'division': division,
      'class_identifier': classIdentifier,
    };
  }

  // Helper to generate identifier
  static String generateIdentifier(String grade, String division) {
    return '$grade$division'.toUpperCase();
  }
}
