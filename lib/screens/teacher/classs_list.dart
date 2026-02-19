import 'dart:convert';
import 'dart:io';
import 'package:attsys/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'student_profile.dart';

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

  final TextEditingController _lrnController = TextEditingController();
  final TextEditingController _schoolIdController = TextEditingController(
    text: '',
  );
  final TextEditingController _schoolYearController = TextEditingController(
    //text: '${DateTime.now().year}-${DateTime.now().year + 1}',
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
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Configure sheet name
      excel.rename(
        'Sheet1',
        DateFormat('MMMM').format(DateTime.now()).toUpperCase(),
      );

      // Title row
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('N1'));
      var titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue(
        'School Form 2 (SF2) Daily Attendance Report of Learners',
      );
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Subtitle row
      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('N2'));
      var subtitleCell = sheet.cell(CellIndex.indexByString('A2'));
      subtitleCell.value = TextCellValue(
        '(This replaces Form 1, Form 2 & STS Form 4 - Absenteeism and Dropout Profile)',
      );
      subtitleCell.cellStyle = CellStyle(
        fontSize: 10,
        horizontalAlign: HorizontalAlign.Center,
      );

      // School info
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

      // School name
      sheet.merge(CellIndex.indexByString('A4'), CellIndex.indexByString('B4'));
      sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue(
        'Name of School',
      );
      sheet.merge(CellIndex.indexByString('C4'), CellIndex.indexByString('J4'));
      sheet.cell(CellIndex.indexByString('C4')).value = TextCellValue(
        schoolName,
      );

      // Column headers
      sheet.merge(CellIndex.indexByString('A5'), CellIndex.indexByString('B5'));
      var noHeader = sheet.cell(CellIndex.indexByString('A5'));
      noHeader.value = TextCellValue('No.');
      noHeader.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      var nameHeader = sheet.cell(CellIndex.indexByString('C5'));
      nameHeader.value = TextCellValue(
        'NAME\n(Last Name, First Name, Middle Name)',
      );
      nameHeader.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Get current month's days
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

      // Date headers (up to 20 days as in original)
      for (int day = 1; day <= daysInMonth && day <= 20; day++) {
        final date = DateTime(now.year, now.month, day);
        final colIndex = day + 3; // Start from column D (index 3)

        var dayCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 5),
        );
        dayCell.value = IntCellValue(day);
        dayCell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );

        var dowCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 6),
        );
        final dayOfWeek =
            ['M', 'T', 'W', 'TH', 'F', 'S', 'SU'][date.weekday - 1];
        dowCell.value = TextCellValue(dayOfWeek);
        dowCell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // Student rows
      for (int i = 0; i < students.length; i++) {
        final student = students[i];
        final rowIndex = i + 7;

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
        final name =
            '${student['surname'].toString().toUpperCase()}, ${student['firstname'].toString().toUpperCase()}, ${student['suffix'] ?? ''}';
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = TextCellValue(name);

        // Attendance cells (empty)
        for (int day = 1; day <= daysInMonth && day <= 20; day++) {
          final colIndex = day + 3;
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: colIndex,
                  rowIndex: rowIndex,
                ),
              )
              .value = TextCellValue('');
        }
      }

      // Column widths
      sheet.setColumnWidth(0, 5);
      sheet.setColumnWidth(1, 5);
      sheet.setColumnWidth(2, 30);
      for (int i = 3; i < 24; i++) {
        sheet.setColumnWidth(i, 5);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'SF2_${widget.className}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final fileBytes = excel.save();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        setState(() => isExporting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel exported: $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
      final pdf = pw.Document();
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

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
                      fontSize: 16,
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
                pw.SizedBox(height: 12),

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
                  ],
                ),
                pw.Text(
                  'Name of School: $schoolName',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Class: ${widget.className}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),

                // Table
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FixedColumnWidth(150),
                    ...Map.fromIterable(
                      List.generate(20, (i) => i + 2),
                      key: (i) => i,
                      value: (i) => const pw.FixedColumnWidth(20),
                    ),
                  },
                  children: [
                    // Header row - No. | NAME | 1 | 2 | ... | 20
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Center(
                            child: pw.Text(
                              'No.',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Center(
                            child: pw.Text(
                              'NAME',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        ...List.generate(
                          20,
                          (i) => pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Center(
                              child: pw.Text(
                                '${i + 1}',
                                style: pw.TextStyle(
                                  fontSize: 7,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Day of week row
                    pw.TableRow(
                      children: [
                        pw.Container(),
                        pw.Container(),
                        ...List.generate(20, (i) {
                          final date = DateTime(now.year, now.month, i + 1);
                          final dayOfWeek =
                              [
                                'M',
                                'T',
                                'W',
                                'TH',
                                'F',
                                'S',
                                'SU',
                              ][date.weekday - 1];
                          return pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Center(
                              child: pw.Text(
                                dayOfWeek,
                                style: const pw.TextStyle(fontSize: 6),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    // Student rows
                    ...students.asMap().entries.map((entry) {
                      final index = entry.key;
                      final student = entry.value;
                      final name =
                          '${student['surname'].toString().toUpperCase()}, ${student['firstname'].toString().toUpperCase()} ${student['suffix'] ?? ''}';

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
                          ...List.generate(20, (i) => pw.Container(height: 15)),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Save PDF
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'SF2_${widget.className}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      setState(() => isExporting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF exported: $fileName'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () => OpenFile.open(filePath),
          ),
        ),
      );
    } catch (e) {
      setState(() => isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
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
                          // Add student + school info card
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
                                          hintText: '2025-2026',
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
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
                                                    'Birthday: ${s['birthday']}',
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
