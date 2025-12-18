class SubjectModel {
  final int? id;
  final String name;
  final double maxMarks;
  final double maxWrittenMarks;
  final double maxPracticalMarks;

  SubjectModel({
    this.id,
    required this.name,
    required this.maxMarks,
    this.maxWrittenMarks = 0.0,
    this.maxPracticalMarks = 0.0,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'],
      name: json['name'],
      maxMarks: json['max_marks'],
      maxWrittenMarks: (json['max_written_marks'] ?? 0).toDouble(),
      maxPracticalMarks: (json['max_practical_marks'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'max_marks': maxMarks,
      'max_written_marks': maxWrittenMarks,
      'max_practical_marks': maxPracticalMarks,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubjectModel && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);
}
