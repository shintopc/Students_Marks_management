import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import '../../data/models/student_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/mark_model.dart';
import '../../data/logic/grading_engine.dart';

class ReportGenerator {
  // Singleton
  static final ReportGenerator _instance = ReportGenerator._internal();
  factory ReportGenerator() => _instance;
  ReportGenerator._internal();

  /// Generate Tabulation Register PDF
  Future<Uint8List> generateTRPdf({
    required String className,
    required String term,
    required List<StudentModel> students,
    required List<SubjectModel> subjects,
    required List<MarkModel> marks,
    bool isDetailed = false,
    String? grade,
    String title = 'Tabulation Register',
  }) async {
    final pdf = pw.Document();

    // Group Marks by Student: StudentID -> { SubjectID -> Mark }
    final Map<int, Map<int, MarkModel>> studentMarks = {};
    for (var m in marks) {
      if (!studentMarks.containsKey(m.studentId))
        studentMarks[m.studentId] = {};
      studentMarks[m.studentId]![m.subjectId] = m;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          if (students.isEmpty) {
            return [
              pw.Center(child: pw.Text("No data available for this report.")),
            ];
          }

          final headers = <pw.Widget>[
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'Roll No',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'Name',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ];

          for (var s in subjects) {
            if (isDetailed) {
              headers.addAll([
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    '${s.name}\n(TE)',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'TE Grd',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    '${s.name}\n(CE)',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'CE Grd',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    '${s.name}\n(Total)',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Grd',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
              ]);
            } else {
              headers.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    s.name,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              );
            }
          }

          headers.addAll([
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'Total',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                '%',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'Grade',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ]);

          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  pw.Text('Class: $className | Term: $term'),
                  pw.SizedBox(height: 10),
                ],
              ),
            ),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: headers,
                ),
                // Rows
                ...students.map((student) {
                  double totalObtained = 0;
                  double totalMax = 0;

                  final rowCells = <pw.Widget>[
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        student.rollNo.toString(),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        student.name,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ];

                  for (var subject in subjects) {
                    final mark = studentMarks[student.id]?[subject.id];

                    if (isDetailed) {
                      String teText = '-';
                      String ceText = '-';
                      String totalText = '-';

                      if (mark != null) {
                        teText = mark.writtenMarks.toString();
                        ceText = mark.practicalMarks.toString();
                        totalText = mark.marksObtained.toString();

                        final teRes = GradingEngine().calculate(
                          mark.writtenMarks,
                          subject.maxWrittenMarks,
                          grade: grade,
                        );
                        final ceRes = GradingEngine().calculate(
                          mark.practicalMarks,
                          subject.maxPracticalMarks,
                          grade: grade,
                        );
                        final res = GradingEngine().calculate(
                          mark.marksObtained,
                          subject.maxMarks,
                          grade: grade,
                        );

                        // TE Grd / CE Grd / Grd logic
                        // We need ordered cells: TE, TE Grd, CE, CE Grd, Total, Grd
                        rowCells.addAll([
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              teText,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              teRes['grade'],
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              ceText,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              ceRes['grade'],
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              totalText,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              res['grade'],
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ]);

                        totalObtained += mark.marksObtained;
                      } else {
                        // Empty cells for missing marks
                        rowCells.addAll([
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              '-',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              '-',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              '-',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              '-',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              '-',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              '-',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ]);
                      }
                      totalMax += subject.maxMarks;
                    } else {
                      String cellText = '-';
                      if (mark != null) {
                        cellText = mark.marksObtained.toString();
                        totalObtained += mark.marksObtained;
                      }
                      totalMax += subject.maxMarks;

                      rowCells.add(
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            cellText,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      );
                    }
                  }

                  // Get Grade logic
                  final grandRes = GradingEngine().calculate(
                    totalObtained,
                    totalMax,
                    grade: grade,
                  );
                  double percentage = grandRes['percentage'] as double;

                  rowCells.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        totalObtained.toStringAsFixed(1),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  );
                  rowCells.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  );
                  rowCells.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        grandRes['grade'],
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );

                  return pw.TableRow(children: rowCells);
                }).toList(),
              ],
            ),
          ]; // MultiPage children
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Tabulation Register Excel
  List<int>? generateTRExcel({
    required String className,
    required String term,
    required List<StudentModel> students,
    required List<SubjectModel> subjects,
    required List<MarkModel> marks,
    bool isDetailed = false,
    String? grade,
    String title = 'Marks Report',
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Heading
    sheet.appendRow([TextCellValue("Marks Report")]);
    sheet.appendRow([
      TextCellValue("Class: $className"),
      TextCellValue("Term: $term"),
      TextCellValue("Date: ${DateTime.now().toString().split(' ')[0]}"),
    ]);
    sheet.appendRow([TextCellValue("")]); // Spacer

    // Headers
    List<CellValue> headers = [TextCellValue("Roll No"), TextCellValue("Name")];
    for (var sub in subjects) {
      if (isDetailed) {
        headers.addAll([
          TextCellValue("${sub.name} (TE)"),
          TextCellValue("TE Grd"),
          TextCellValue("${sub.name} (CE)"),
          TextCellValue("CE Grd"),
          TextCellValue("${sub.name} (Total)"),
          TextCellValue("Grd"),
        ]);
      } else {
        headers.add(TextCellValue(sub.name));
      }
    }
    headers.addAll([
      TextCellValue("Grand Total"),
      TextCellValue("Percentage"),
      TextCellValue("Grade"),
    ]);

    sheet.appendRow(headers);

    // Data Rows
    // Group Marks by Student: StudentID -> { SubjectID -> Mark }
    final Map<int, Map<int, MarkModel>> studentMarks = {};
    for (var m in marks) {
      if (!studentMarks.containsKey(m.studentId))
        studentMarks[m.studentId] = {};
      studentMarks[m.studentId]![m.subjectId] = m;
    }

    for (var student in students) {
      List<CellValue> row = [
        IntCellValue(student.rollNo),
        TextCellValue(student.name),
      ];

      double totalObtained = 0;
      double totalMax = 0;

      for (var subject in subjects) {
        if (studentMarks.containsKey(student.id) &&
            studentMarks[student.id]!.containsKey(subject.id)) {
          final mark = studentMarks[student.id]![subject.id]!;

          if (isDetailed) {
            final teRes = GradingEngine().calculate(
              mark.writtenMarks,
              subject.maxWrittenMarks,
              grade: grade,
            );
            final ceRes = GradingEngine().calculate(
              mark.practicalMarks,
              subject.maxPracticalMarks,
              grade: grade,
            );
            final res = GradingEngine().calculate(
              mark.marksObtained,
              subject.maxMarks,
              grade: grade,
            );

            row.add(DoubleCellValue(mark.writtenMarks));
            row.add(TextCellValue(teRes['grade']));
            row.add(DoubleCellValue(mark.practicalMarks));
            row.add(TextCellValue(ceRes['grade']));
            row.add(DoubleCellValue(mark.marksObtained));
            row.add(TextCellValue(res['grade']));
          } else {
            final res = GradingEngine().calculate(
              mark.marksObtained,
              subject.maxMarks,
              grade: grade,
            );
            row.add(TextCellValue("${mark.marksObtained} (${res['grade']})"));
          }

          totalObtained += mark.marksObtained;
        } else {
          if (isDetailed) {
            row.addAll([
              TextCellValue('-'),
              TextCellValue('-'),
              TextCellValue('-'),
              TextCellValue('-'),
              TextCellValue('-'),
              TextCellValue('-'),
            ]);
          } else {
            row.add(TextCellValue('-'));
          }
        }
        totalMax += subject.maxMarks;
      }

      final grandRes = GradingEngine().calculate(
        totalObtained,
        totalMax,
        grade: grade,
      );
      double percentage = grandRes['percentage'] as double;

      row.add(DoubleCellValue(double.parse(totalObtained.toStringAsFixed(1))));
      row.add(DoubleCellValue(double.parse(percentage.toStringAsFixed(1))));
      row.add(TextCellValue(grandRes['grade']));

      sheet.appendRow(row);
    }

    return excel.encode();
  }

  /// Generate Report Card PDF (Multi-Term Support)
  Future<Uint8List> generateReportCardPdf({
    required StudentModel student,
    required List<SubjectModel> subjects,
    required List<MarkModel> marks,
    String? grade,
  }) async {
    final pdf = pw.Document();

    // Group marks by Term
    final Map<String, Map<int, MarkModel>> termMarks = {};
    for (var m in marks) {
      if (m.studentId == student.id) {
        if (!termMarks.containsKey(m.term)) {
          termMarks[m.term] = {};
        }
        termMarks[m.term]![m.subjectId] = m;
      }
    }

    final terms = termMarks.keys.toList()..sort();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final List<pw.Widget> children = [];

          // Header
          children.add(
            pw.Column(
              children: [
                pw.Text(
                  'REPORT CARD',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Name: ${student.name}'),
                    pw.Text('Roll No: ${student.rollNo}'),
                    pw.Text('Class: ${student.className}'),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 10),
              ],
            ),
          );

          if (terms.isEmpty) {
            children.add(pw.Text('No marks data available.'));
          }

          for (var term in terms) {
            // Term Section
            children.add(
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                margin: const pw.EdgeInsets.only(top: 10, bottom: 5),
                child: pw.Text(
                  'Term: $term',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
            );

            // Table for this term
            final Map<int, MarkModel> subjectMarks = termMarks[term]!;
            double totalObtained = 0;
            double totalMax = 0;
            final List<Map<String, dynamic>> rows = [];

            for (var subject in subjects) {
              final mark = subjectMarks[subject.id];
              double obtained = 0;
              double written = 0;
              double practical = 0;
              String mGrade = '-';

              if (mark != null) {
                obtained = mark.marksObtained;
                written = mark.writtenMarks;
                practical = mark.practicalMarks;

                final result = GradingEngine().calculate(
                  obtained,
                  subject.maxMarks,
                  grade: grade,
                );
                mGrade = result['grade'];

                rows.add({
                  'subject': subject.name,
                  'max': subject.maxMarks,
                  'maxWritten': subject.maxWrittenMarks,
                  'maxPractical': subject.maxPracticalMarks,
                  'written': written,
                  'practical': practical,
                  'obtained': obtained,
                  'grade': mGrade,
                  'hasMark': true,
                });

                totalObtained += obtained;
                totalMax += subject.maxMarks;
              } else {
                rows.add({
                  'subject': subject.name,
                  'max': subject.maxMarks,
                  'maxWritten': subject.maxWrittenMarks,
                  'maxPractical': subject.maxPracticalMarks,
                  'written': 0.0,
                  'practical': 0.0,
                  'obtained': 0.0,
                  'grade': '-',
                  'hasMark': false,
                });
                totalMax += subject.maxMarks;
              }
            }

            double finalPercentage = totalMax > 0
                ? (totalObtained / totalMax) * 100
                : 0;
            finalPercentage = double.parse(finalPercentage.toStringAsFixed(1));

            final grandRes = GradingEngine().calculate(
              totalObtained,
              totalMax,
              grade: grade,
            );

            children.add(
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Subject',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'TE',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'CE',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Grade',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  // Rows
                  ...rows.map((r) {
                    final hasMark = r['hasMark'] as bool;
                    final maxW = r['maxWritten'];
                    final maxP = r['maxPractical'];
                    final max = r['max'];

                    String teText = '-';
                    String ceText = '-';
                    String totalText = '-';

                    if (hasMark) {
                      teText = (maxW > 0) ? '${r['written']} / $maxW' : '-';
                      ceText = (maxP > 0) ? '${r['practical']} / $maxP' : '-';
                      totalText = '${r['obtained']} / $max';
                    }

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(r['subject']),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(teText),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(ceText),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(totalText),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(r['grade']),
                        ),
                      ],
                    );
                  }).toList(),
                  // Total
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'TOTAL',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(''),
                      ), // TE Spacer
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(''),
                      ), // CE Spacer
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          '$totalObtained / $totalMax',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          '$finalPercentage% (${grandRes['grade']})',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            children.add(pw.SizedBox(height: 20));
          }

          return children;
        },
      ),
    );

    return pdf.save();
  }
}
