class StudentModel {
  final int? id;
  final String admissionNo;
  final String name;
  final String className;
  final int rollNo;

  StudentModel({
    this.id,
    required this.admissionNo,
    required this.name,
    required this.className,
    required this.rollNo,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      admissionNo: json['admission_no'],
      name: json['name'],
      className: json['class_name'],
      rollNo: json['roll_no'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admission_no': admissionNo,
      'name': name,
      'class_name': className,
      'roll_no': rollNo,
    };
  }
}
