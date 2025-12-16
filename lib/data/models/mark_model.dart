class MarkModel {
  final int? id;
  final int studentId;
  final int subjectId;
  final String term;
  final double marksObtained;
  final double writtenMarks;
  final double practicalMarks;

  MarkModel({
    this.id,
    required this.studentId,
    required this.subjectId,
    required this.term,
    required this.marksObtained,
    this.writtenMarks = 0.0,
    this.practicalMarks = 0.0,
  });

  factory MarkModel.fromJson(Map<String, dynamic> json) {
    return MarkModel(
      id: json['id'],
      studentId: json['student_id'],
      subjectId: json['subject_id'],
      term: json['term'],
      marksObtained: json['marks_obtained'],
      writtenMarks: (json['written_marks'] ?? 0).toDouble(),
      practicalMarks: (json['practical_marks'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'subject_id': subjectId,
      'term': term,
      'marks_obtained': marksObtained,
      'written_marks': writtenMarks,
      'practical_marks': practicalMarks,
    };
  }
}
