import 'dart:convert';
import 'dart:io';
import 'package:attsys/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dltype/file_download_mobile.dart';
import 'student_profile.dart';

import 'dart:typed_data';

class ClassStudentsScreen extends StatefulWidget {
  final String classId;
  final String className;

  const ClassStudentsScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  List<dynamic> students = [];
  bool isLoading = true;
  String? errorMessage;
  bool isExporting = false;
  bool isImporting = false;

  final TextEditingController _lrnController = TextEditingController();
  final TextEditingController _schoolIdController = TextEditingController(
    text: '',
  );
  final TextEditingController _schoolYearController = TextEditingController(
    text: '',
  );
  final TextEditingController _schoolNameController = TextEditingController(
    text: '',
  );

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadStudents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await _getToken();
      final res = await http
          .get(
            Uri.parse(ApiConfig.teacherClassStudents(widget.classId)),
            headers: ApiConfig.headers(token),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        setState(() {
          students = json.decode(res.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load students (${res.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _addStudent() async {
    final lrn = _lrnController.text.trim();
    if (lrn.isEmpty || lrn.length != 12 || !RegExp(r'^\d{12}$').hasMatch(lrn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 12-digit LRN'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final token = await _getToken();
      final res = await http
          .post(
            Uri.parse(ApiConfig.teacherClassStudents(widget.classId)),
            headers: ApiConfig.headers(token),
            body: json.encode({'lrn': lrn}),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 201) {
        final data = json.decode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${data['studentName']} added to class'),
            backgroundColor: Colors.green,
          ),
        );
        _lrnController.clear();
        _loadStudents();
      } else {
        final err = json.decode(res.body)['message'] ?? 'Failed to add';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns only weekday (Mon–Fri) days for the current month.
  List<int> _getSchoolDays({int? month, int? year}) {
    final now = DateTime.now();
    final m = month ?? now.month;
    final y = year ?? now.year;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    return [
      for (int d = 1; d <= daysInMonth; d++)
        if (DateTime(y, m, d).weekday <= 5) d,
    ];
  }

  List<String> _getDayLabels(List<int> schoolDays, {int? month, int? year}) {
    final now = DateTime.now();
    final m = month ?? now.month;
    final y = year ?? now.year;
    const labels = ['M', 'T', 'W', 'TH', 'F'];
    return schoolDays
        .map((d) => labels[DateTime(y, m, d).weekday - 1])
        .toList();
  }

  /// Converts a status string to a single-character cell value for SF2.
  /// Present / Late → '' (blank, meaning attended)
  /// Absent         → 'A'
  /// Excused        → 'E'
  String _statusToCell(String? status) {
    switch (status) {
      case 'Present':
        return '';
      case 'Late':
        return 'L';
      case 'Absent':
        return 'A';
      case 'Excused':
        return 'E';
      default:
        return '';
    }
  }

  // ── Fetch SF2 attendance from backend ──────────────────────────────────────
  /// Returns a map of:  lrn → { dayNum(int) → status(String) }
  Future<Map<String, Map<int, String>>> _fetchSF2Attendance({
    int? month,
    int? year,
  }) async {
    final token = await _getToken();
    final url = ApiConfig.teacherSF2Attendance(
      widget.classId,
      month: month,
      year: year,
    );

    final res = await http
        .get(Uri.parse(url), headers: ApiConfig.headers(token))
        .timeout(ApiConfig.timeout);

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch attendance data (${res.statusCode})');
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    final studentsList = body['students'] as List<dynamic>;

    // Build lrn → { dayNum → status }
    final Map<String, Map<int, String>> result = {};
    for (final s in studentsList) {
      final lrn = s['lrn'] as String;
      final rawAttendance = s['attendance'] as Map<String, dynamic>? ?? {};
      result[lrn] = {
        for (final e in rawAttendance.entries)
          int.parse(e.key):
              (e.value as Map<String, dynamic>)['status'] as String,
      };
    }
    return result;
  }

  // ── Export to Excel ────────────────────────────────────────────────────────
  Future<void> _exportToExcel() async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final schoolId = _schoolIdController.text.trim();
    final schoolYear = _schoolYearController.text.trim();
    final schoolName = _schoolNameController.text.trim();

    if (schoolId.isEmpty || schoolYear.isEmpty || schoolName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in School ID, Year and Name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isExporting = true);

    try {
      final now = DateTime.now();
      // Fetch real attendance data from backend
      final attendanceData = await _fetchSF2Attendance(
        month: now.month,
        year: now.year,
      );

      final schoolDays = _getSchoolDays();
      const maxColumns = 20;
      final displayDays =
          schoolDays.length > maxColumns
              ? schoolDays.sublist(0, maxColumns)
              : schoolDays;
      final displayDow = _getDayLabels(displayDays);

      final excel = Excel.createExcel();
      excel.rename('Sheet1', DateFormat('MMMM').format(now).toUpperCase());
      final sheet = excel[DateFormat('MMMM').format(now).toUpperCase()];

      // ── Title rows ──────────────────────────────────────────────────────────
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('P1'));
      var titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue(
        'School Form 2 (SF2) Daily Attendance Report of Learners',
      );
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Center,
      );

      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('P2'));
      var subtitleCell = sheet.cell(CellIndex.indexByString('A2'));
      subtitleCell.value = TextCellValue(
        '(This replaces Form 1, Form 2 & STS Form 4 - Absenteeism and Dropout Profile)',
      );
      subtitleCell.cellStyle = CellStyle(
        fontSize: 10,
        horizontalAlign: HorizontalAlign.Center,
      );

      // ── School info rows ────────────────────────────────────────────────────
      sheet.merge(CellIndex.indexByString('A3'), CellIndex.indexByString('B3'));
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'School ID',
      );
      sheet.merge(CellIndex.indexByString('C3'), CellIndex.indexByString('F3'));
      sheet.cell(CellIndex.indexByString('C3')).value = TextCellValue(schoolId);
      sheet.merge(CellIndex.indexByString('G3'), CellIndex.indexByString('I3'));
      sheet.cell(CellIndex.indexByString('G3')).value = TextCellValue(
        'School Year',
      );
      sheet.merge(CellIndex.indexByString('J3'), CellIndex.indexByString('M3'));
      sheet.cell(CellIndex.indexByString('J3')).value = TextCellValue(
        schoolYear,
      );

      sheet.merge(CellIndex.indexByString('A4'), CellIndex.indexByString('B4'));
      sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue(
        'Name of School',
      );
      sheet.merge(CellIndex.indexByString('C4'), CellIndex.indexByString('J4'));
      sheet.cell(CellIndex.indexByString('C4')).value = TextCellValue(
        schoolName,
      );

      sheet.merge(CellIndex.indexByString('A5'), CellIndex.indexByString('B5'));
      sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue(
        'Grade/Section',
      );
      sheet.merge(CellIndex.indexByString('C5'), CellIndex.indexByString('J5'));
      sheet.cell(CellIndex.indexByString('C5')).value = TextCellValue(
        widget.className,
      );

      sheet.merge(CellIndex.indexByString('K5'), CellIndex.indexByString('L5'));
      sheet.cell(CellIndex.indexByString('K5')).value = TextCellValue('Month');
      sheet.merge(CellIndex.indexByString('M5'), CellIndex.indexByString('P5'));
      sheet.cell(CellIndex.indexByString('M5')).value = TextCellValue(
        DateFormat('MMMM yyyy').format(now),
      );

      // ── Column headers row 6 ────────────────────────────────────────────────
      // No. | NAME | SEX | day1 | day2 | ... | dayN
      // Col 0: No.   Col 1: (merged)   Col 2: Name   Col 3: Sex   Col 4+: Days
      final int dayColStart = 4;

      sheet.merge(CellIndex.indexByString('A6'), CellIndex.indexByString('B6'));
      _headerCell(sheet, 'A6', 'No.');
      _headerCell(sheet, 'C6', 'NAME\n(Last Name, First Name, Middle Name)');
      _headerCell(sheet, 'D6', 'SEX');

      for (int i = 0; i < displayDays.length; i++) {
        final colIdx = dayColStart + i;
        // Day number row
        final dayCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: 5),
        );
        dayCell.value = IntCellValue(displayDays[i]);
        dayCell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
        // Day-of-week row
        final dowCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: 6),
        );
        dowCell.value = TextCellValue(displayDow[i]);
        dowCell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // ── Student rows ────────────────────────────────────────────────────────
      for (int i = 0; i < students.length; i++) {
        final student = students[i];
        final lrn = student['lrn'] as String;
        final rowIndex =
            i + 7; // rows 0-indexed; data starts at row 7 (row 8 in Excel)

        // Number
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = IntCellValue(i + 1);

        // Name
        final name = '${student['surname'].toString().toUpperCase()}, '
                '${student['firstname'].toString().toUpperCase()} '
                '${student['middlename']?.toString().toUpperCase() ?? ''} '
                '${student['suffix'] ?? ''}'
            .trim()
            .replaceAll(RegExp(r' +'), ' ');
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = TextCellValue(name);

        // Sex
        final sexVal = student['sex'] as String? ?? '';
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = TextCellValue(sexVal);

        // Attendance cells — populate from fetched data
        final studentAttendance = attendanceData[lrn] ?? {};
        for (int j = 0; j < displayDays.length; j++) {
          final dayNum = displayDays[j];
          final colIdx = dayColStart + j;
          final status = studentAttendance[dayNum];
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: colIdx,
                  rowIndex: rowIndex,
                ),
              )
              .value = TextCellValue(_statusToCell(status));
        }
      }

      // ── Footer ──────────────────────────────────────────────────────────────
      final footerRow = students.length + 8;
      sheet.merge(
        CellIndex.indexByString('A$footerRow'),
        CellIndex.indexByString('D$footerRow'),
      );
      sheet.cell(CellIndex.indexByString('A$footerRow')).value = TextCellValue(
        'Total School Days: ${displayDays.length}',
      );

      // ── Column widths ───────────────────────────────────────────────────────
      sheet.setColumnWidth(0, 5);
      sheet.setColumnWidth(1, 5);
      sheet.setColumnWidth(2, 35);
      sheet.setColumnWidth(3, 8); // SEX column
      for (int i = dayColStart; i < dayColStart + displayDays.length; i++) {
        sheet.setColumnWidth(i, 6);
      }

      // ── Legend ──────────────────────────────────────────────────────────────
      final legendRow = students.length + 10;
      sheet.cell(CellIndex.indexByString('A$legendRow')).value = TextCellValue(
        'Legend: blank = Present, L = Late, A = Absent, E = Excused',
      );

      // ── Save ────────────────────────────────────────────────────────────────
      final fileBytes = excel.save();
      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('Excel save returned null or empty bytes');
      }

      final fileName =
          'SF2_${widget.className}_${DateFormat('yyyy-MM').format(now)}.xlsx';

      await downloadFile(
        Uint8List.fromList(fileBytes),
        fileName,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (mounted) {
        setState(() => isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel downloaded: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Helper: set header cell style
  void _headerCell(Sheet sheet, String address, String text) {
    final cell = sheet.cell(CellIndex.indexByString(address));
    cell.value = TextCellValue(text);
    cell.cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  // ── Export to PDF ──────────────────────────────────────────────────────────
  Future<void> _exportToPDF() async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final schoolId = _schoolIdController.text.trim();
    final schoolYear = _schoolYearController.text.trim();
    final schoolName = _schoolNameController.text.trim();

    if (schoolId.isEmpty || schoolYear.isEmpty || schoolName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in School ID, Year and Name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isExporting = true);

    try {
      final now = DateTime.now();
      // Fetch real attendance data from backend
      final attendanceData = await _fetchSF2Attendance(
        month: now.month,
        year: now.year,
      );

      final schoolDays = _getSchoolDays();
      const maxColumns = 20;
      final displayDays =
          schoolDays.length > maxColumns
              ? schoolDays.sublist(0, maxColumns)
              : schoolDays;
      final displayDow = _getDayLabels(displayDays);
      final numDayColumns = displayDays.length;

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.legal.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title
                pw.Center(
                  child: pw.Text(
                    'School Form 2 (SF2) Daily Attendance Report of Learners',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    '(This replaces Form 1, Form 2 & STS Form 4 - Absenteeism and Dropout Profile)',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.SizedBox(height: 8),

                // School info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'School ID: $schoolId',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'School Year: $schoolYear',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Month: ${DateFormat('MMMM yyyy').format(now)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Text(
                  'Name of School: $schoolName',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Grade/Section: ${widget.className}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                // Table
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(25), // No.
                    1: const pw.FixedColumnWidth(175), // Name
                    2: const pw.FixedColumnWidth(25), // Sex
                    ...{
                      for (int i = 0; i < numDayColumns; i++)
                        i + 3: const pw.FixedColumnWidth(20),
                    },
                  },
                  children: [
                    // Header row 1: labels
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        _pdfHeaderCell('No.'),
                        _pdfHeaderCell('NAME'),
                        _pdfHeaderCell('SEX'),
                        ...List.generate(
                          numDayColumns,
                          (i) => _pdfHeaderCell('${displayDays[i]}'),
                        ),
                      ],
                    ),

                    // Header row 2: day-of-week
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey100,
                      ),
                      children: [
                        pw.Container(),
                        pw.Container(),
                        pw.Container(),
                        ...List.generate(
                          numDayColumns,
                          (i) => pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Center(
                              child: pw.Text(
                                displayDow[i],
                                style: const pw.TextStyle(fontSize: 6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Student rows
                    ...students.asMap().entries.map((entry) {
                      final index = entry.key;
                      final student = entry.value;
                      final lrn = student['lrn'] as String;
                      final name = '${student['surname'].toString().toUpperCase()}, '
                              '${student['firstname'].toString().toUpperCase()} '
                              '${student['middlename']?.toString().toUpperCase() ?? ''} '
                              '${student['suffix'] ?? ''}'
                          .trim()
                          .replaceAll(RegExp(r' +'), ' ');
                      final sex = student['sex'] as String? ?? '';
                      final studentAttendance = attendanceData[lrn] ?? {};

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Center(
                              child: pw.Text(
                                '${index + 1}',
                                style: const pw.TextStyle(fontSize: 7),
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Text(
                              name,
                              style: const pw.TextStyle(fontSize: 7),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Center(
                              child: pw.Text(
                                sex,
                                style: const pw.TextStyle(fontSize: 7),
                              ),
                            ),
                          ),
                          ...List.generate(numDayColumns, (i) {
                            final dayNum = displayDays[i];
                            final status = studentAttendance[dayNum];
                            final cellText = _statusToCell(status);
                            final isAbsent = cellText == 'A';
                            return pw.Container(
                              height: 14,
                              alignment: pw.Alignment.center,
                              color: isAbsent ? PdfColors.red100 : null,
                              child: pw.Text(
                                cellText,
                                style: pw.TextStyle(
                                  fontSize: 7,
                                  color:
                                      isAbsent
                                          ? PdfColors.red
                                          : PdfColors.black,
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 8),
                pw.Text(
                  'Total School Days: $numDayColumns   |   Legend: blank = Present, L = Late, A = Absent, E = Excused',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName =
          'SF2_${widget.className}_${DateFormat('yyyy-MM').format(now)}.pdf';

      await downloadFile(pdfBytes, fileName, 'application/pdf');

      if (mounted) {
        setState(() => isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
  }

  // ── CSV / XLSX Import ───────────────────────────────────────────────────────

  /// Parses a raw string as CSV, returning a list of rows (each row = list of cells).
  /// Handles quoted fields and comma delimiters.
  List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    for (final line in content.split(RegExp(r'\r?\n'))) {
      if (line.trim().isEmpty) continue;
      final cells = <String>[];
      bool inQuotes = false;
      final buf = StringBuffer();
      for (int i = 0; i < line.length; i++) {
        final ch = line[i];
        if (ch == '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (ch == ',' && !inQuotes) {
          cells.add(buf.toString().trim());
          buf.clear();
        } else {
          buf.write(ch);
        }
      }
      cells.add(buf.toString().trim());
      rows.add(cells);
    }
    return rows;
  }

  /// Finds the column index for [header] in [headers] list (case-insensitive).
  int _colIndex(List<String> headers, String header) =>
      headers.indexWhere((h) => h.toLowerCase() == header.toLowerCase());

  /// Downloads a blank CSV template the teacher can fill in.
  Future<void> _downloadImportTemplate() async {
    const content =
        'lrn,firstname,surname,suffix,middlename,birthday,sex\n'
        '123456789012,Juan,Dela Cruz,,Santos,2010-05-15,Male\n'
        '123456789013,Maria,Reyes,Jr.,Lopez,2011-03-22,Female\n';

    await downloadFile(
      Uint8List.fromList(content.codeUnits),
      'student_import_template.csv',
      'text/csv',
    );
  }

  /// Picks a CSV or XLSX file, parses it, and bulk-enrolls students.
  Future<void> _importStudents() async {
    // Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final ext = (file.extension ?? '').toLowerCase();

    // Parse rows → [ { lrn, firstname, surname, suffix, middlename, birthday, sex } ]
    List<Map<String, String>> rows = [];
    try {
      if (ext == 'csv') {
        rows = _parseCsvBytes(bytes);
      } else {
        rows = _parseXlsxBytes(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to parse file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid rows found in file'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Confirm before importing
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Import Students'),
            content: Text(
              'Found ${rows.length} student${rows.length != 1 ? 's' : ''} in the file.\n\n'
              'Students already registered will be enrolled by LRN.\n'
              'Unregistered LRNs will be skipped.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Import'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => isImporting = true);

    int success = 0;
    int skipped = 0;
    final List<String> errors = [];

    for (final row in rows) {
      final lrn = row['lrn'] ?? '';
      if (lrn.isEmpty ||
          lrn.length != 12 ||
          !RegExp(r'^\d{12}$').hasMatch(lrn)) {
        errors.add('Invalid LRN: "$lrn"');
        continue;
      }

      try {
        final token = await _getToken();
        final res = await http
            .post(
              Uri.parse(ApiConfig.teacherClassStudents(widget.classId)),
              headers: ApiConfig.headers(token),
              body: json.encode({'lrn': lrn}),
            )
            .timeout(ApiConfig.timeout);

        if (res.statusCode == 201) {
          success++;
        } else if (res.statusCode == 409) {
          skipped++; // already enrolled
        } else {
          final msg = json.decode(res.body)['message'] ?? 'Error';
          errors.add('LRN $lrn: $msg');
        }
      } catch (e) {
        errors.add('LRN $lrn: network error');
      }
    }

    setState(() => isImporting = false);
    _loadStudents();

    if (!mounted) return;

    // Result summary dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Import Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _importResultRow(
                  Icons.check_circle,
                  Colors.green,
                  '$success student${success != 1 ? 's' : ''} enrolled',
                ),
                if (skipped > 0)
                  _importResultRow(
                    Icons.info,
                    Colors.orange,
                    '$skipped already enrolled (skipped)',
                  ),
                if (errors.isNotEmpty) ...[
                  _importResultRow(
                    Icons.error,
                    Colors.red,
                    '${errors.length} failed',
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        errors.join('\n'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
    );
  }

  Widget _importResultRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  /// Parses CSV bytes into a list of row maps.
  List<Map<String, String>> _parseCsvBytes(Uint8List bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    final allRows = _parseCsv(content);
    if (allRows.isEmpty) return [];

    // First row = headers
    final headers = allRows.first.map((h) => h.trim()).toList();
    final lrnIdx = _colIndex(headers, 'lrn');
    final firstIdx = _colIndex(headers, 'firstname');
    final surnameIdx = _colIndex(headers, 'surname');
    final suffixIdx = _colIndex(headers, 'suffix');
    final middleIdx = _colIndex(headers, 'middlename');
    final birthdayIdx = _colIndex(headers, 'birthday');
    final sexIdx = _colIndex(headers, 'sex');

    if (lrnIdx == -1) throw Exception('Missing "lrn" column');

    return allRows.skip(1).where((r) => r.isNotEmpty).map((row) {
      String cell(int idx) => idx >= 0 && idx < row.length ? row[idx] : '';
      return {
        'lrn': cell(lrnIdx),
        'firstname': cell(firstIdx),
        'surname': cell(surnameIdx),
        'suffix': cell(suffixIdx),
        'middlename': cell(middleIdx),
        'birthday': cell(birthdayIdx),
        'sex': cell(sexIdx),
      };
    }).toList();
  }

  /// Parses XLSX bytes into a list of row maps.
  List<Map<String, String>> _parseXlsxBytes(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    // Use the first sheet that has data
    Sheet? sheet;
    for (final name in excel.tables.keys) {
      final s = excel.tables[name];
      if (s != null && s.rows.isNotEmpty) {
        sheet = s;
        break;
      }
    }
    if (sheet == null) throw Exception('No sheet found in file');

    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    // First row = headers
    final headers =
        rows.first
            .map((c) => (c?.value?.toString() ?? '').trim().toLowerCase())
            .toList();

    final lrnIdx = headers.indexOf('lrn');
    final firstIdx = headers.indexOf('firstname');
    final surnameIdx = headers.indexOf('surname');
    final suffixIdx = headers.indexOf('suffix');
    final birthdayIdx = headers.indexOf('birthday');
    final sexIdx = headers.indexOf('sex');

    if (lrnIdx == -1) throw Exception('Missing "lrn" column');

    String cellVal(List<Data?> row, int idx) {
      if (idx < 0 || idx >= row.length) return '';
      final v = row[idx]?.value;
      if (v == null) return '';
      // Excel may store dates as doubles
      if (v is DateTime) return DateFormat('yyyy-MM-dd').format(v as DateTime);
      return v.toString().trim();
    }

    return rows
        .skip(1)
        .where((r) => r.isNotEmpty)
        .map(
          (row) => {
            'lrn': cellVal(row, lrnIdx),
            'firstname': cellVal(row, firstIdx),
            'surname': cellVal(row, surnameIdx),
            'suffix': cellVal(row, suffixIdx),
            'birthday': cellVal(row, birthdayIdx),
            'sex': cellVal(row, sexIdx),
          },
        )
        .where((r) => r['lrn']!.isNotEmpty)
        .toList();
  }

  // ── Export options sheet ───────────────────────────────────────────────────
  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Export SF2 Format',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose export format for ${students.length} students',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.table_chart,
                      color: Colors.green.shade700,
                    ),
                  ),
                  title: const Text('Export to Excel'),
                  subtitle: const Text('Editable spreadsheet (.xlsx)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _exportToExcel();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red.shade700,
                    ),
                  ),
                  title: const Text('Export to PDF'),
                  subtitle: const Text('Printable document (.pdf)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _exportToPDF();
                  },
                ),
                const Divider(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.download_for_offline_rounded,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  title: const Text('Download Import Template'),
                  subtitle: const Text('CSV template with correct columns'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadImportTemplate();
                  },
                ),
              ],
            ),
          ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          // Import button — always visible so teacher can import even before students are added
          IconButton(
            icon:
                isImporting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.upload_file_rounded),
            tooltip: 'Import Students (CSV / XLSX)',
            onPressed: isImporting ? null : _importStudents,
          ),
          if (!isLoading && students.isNotEmpty)
            IconButton(
              icon:
                  isExporting
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.download_rounded),
              tooltip: 'Export SF2',
              onPressed: isExporting ? null : _showExportOptions,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Class Students',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.className,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Refresh',
                      onPressed: _loadStudents,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadStudents,
                  color: const Color(0xFF667eea),
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // School info + add student card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'School Information (for SF2 export)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _schoolIdController,
                                        decoration: InputDecoration(
                                          labelText: 'School ID',
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 16,
                                                horizontal: 16,
                                              ),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _schoolYearController,
                                        decoration: InputDecoration(
                                          labelText: 'School Year',

                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 16,
                                                horizontal: 16,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                TextField(
                                  controller: _schoolNameController,
                                  decoration: InputDecoration(
                                    labelText: 'School Name',
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 16,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 16),

                                const Text(
                                  'Add Student',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _lrnController,
                                        decoration: InputDecoration(
                                          labelText: 'Enter 12-digit LRN',
                                          prefixIcon: const Icon(
                                            Icons.badge_rounded,
                                            color: Color(0xFF667eea),
                                          ),
                                          suffixIcon:
                                              _lrnController.text.isNotEmpty
                                                  ? IconButton(
                                                    icon: const Icon(
                                                      Icons.clear_rounded,
                                                    ),
                                                    onPressed: () {
                                                      _lrnController.clear();
                                                      setState(() {});
                                                    },
                                                  )
                                                  : null,
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF667eea),
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 16,
                                                horizontal: 20,
                                              ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        maxLength: 12,
                                        onChanged: (value) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton(
                                      onPressed:
                                          _lrnController.text.length == 12
                                              ? _addStudent
                                              : null,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                        backgroundColor: const Color(
                                          0xFF4CAF50,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.person_add_rounded,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Add'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Students list
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Enrolled Students',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${students.length} student${students.length != 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                if (isLoading)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF667eea),
                                    ),
                                  )
                                else if (errorMessage != null)
                                  Center(
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          size: 64,
                                          color: Colors.redAccent,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          errorMessage!,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        OutlinedButton.icon(
                                          onPressed: _loadStudents,
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                          ),
                                          label: const Text('Retry'),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: Color(0xFF667eea),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (students.isEmpty)
                                  Center(
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.people_outline_rounded,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No students enrolled yet',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add students using their LRN above',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: students.length,
                                    itemBuilder: (context, index) {
                                      final s = students[index];
                                      final name =
                                          s['full_name'] ??
                                          '${s['firstname']} ${s['suffix'] ?? ''} ${s['surname']}'
                                              .trim();
                                      final initials =
                                          '${s['firstname'][0]}${s['surname'][0]}'
                                              .toUpperCase();
                                      final sex = s['sex'] as String? ?? '';

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: const Color(
                                                0xFF667eea,
                                              ).withOpacity(0.1),
                                              child: Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: Color(0xFF667eea),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'LRN: ${s['lrn']}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                                if (s['birthday'] != null)
                                                  Text(
                                                    'Birthday: ${s['birthday']}'
                                                    '${sex.isNotEmpty ? ' · $sex' : ''}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Colors.grey,
                                            ),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          StudentProfileScreen(
                                                            lrn: s['lrn'],
                                                            classId:
                                                                widget.classId,
                                                          ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lrnController.dispose();
    _schoolIdController.dispose();
    _schoolYearController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }
}
