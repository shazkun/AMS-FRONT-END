import 'package:attsys/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QRScanScreen extends StatefulWidget {
  final String classId;
  final String className;

  const QRScanScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final MobileScannerController controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final Map<String, DateTime> _lastScannedLRN = {};
  static const int cooldownSeconds = 5;
  bool isProcessing = false;

  String? lastScannedStudent;
  int successCount = 0;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _recordAttendance(
    String lrn,
    String surname,
    String firstname,
  ) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);

    try {
      final token = await _getToken();
      if (token == null) {
        _showMessage('Authentication token missing', isError: true);
        return;
      }

      final payload = '$surname,$firstname|lrn:$lrn|class:${widget.classId}';

      final response = await http
          .post(
            Uri.parse(ApiConfig.teacherRecordScan),
            headers: ApiConfig.headers(token),
            body: json.encode({'payload': payload}),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final studentName = data['student'] ?? 'Student';

        setState(() {
          lastScannedStudent = studentName;
          successCount++;
        });

        _showMessage('✓ $studentName marked present', isError: false);
      } else {
        final err = json.decode(response.body)['message'] ?? 'Unknown error';
        _showMessage('Failed: $err', isError: true);
      }
    } catch (e) {
      _showMessage('Network error: $e', isError: true);
    } finally {
      setState(() => isProcessing = false);
    }
  }

  void _showMessage(String msg, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _processBarcode(String rawValue) {
    // Expected format: surname,firstname|lrn:123456789012|class:1
    final parts = rawValue.split('|');
    if (parts.length != 3) {
      debugPrint(
        'Invalid QR format: $rawValue (expected 3 parts, got ${parts.length})',
      );
      return;
    }

    final namePart = parts[0];
    final lrnPart = parts[1];
    final classPart = parts[2];

    // Validate format
    if (!lrnPart.startsWith('lrn:') || !classPart.startsWith('class:')) {
      debugPrint('Invalid QR prefixes: $rawValue');
      return;
    }

    // Extract values
    final names = namePart.split(',');
    if (names.length != 2) {
      debugPrint('Invalid name format: $namePart');
      return;
    }

    final surname = names[0].trim();
    final firstname = names[1].trim();

    final lrn = lrnPart.substring(4);
    final scannedClassId = classPart.substring(6);

    // Validate LRN
    if (lrn.length != 12 || !RegExp(r'^\d{12}$').hasMatch(lrn)) {
      _showMessage('Invalid LRN format', isError: true);
      return;
    }

    // Check if QR is for correct class
    if (scannedClassId != widget.classId) {
      _showMessage('QR code is for a different class', isError: true);
      return;
    }

    // Check cooldown
    final now = DateTime.now();
    if (_lastScannedLRN.containsKey(lrn)) {
      final diff = now.difference(_lastScannedLRN[lrn]!).inSeconds;
      if (diff < cooldownSeconds) {
        debugPrint('Cooldown active for LRN: $lrn');
        return;
      }
    }

    _lastScannedLRN[lrn] = now;
    _recordAttendance(lrn, surname, firstname);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [BackButton()]),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Camera view
              MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  if (isProcessing) return;

                  for (final barcode in capture.barcodes) {
                    final rawValue = barcode.rawValue;
                    if (rawValue != null) {
                      _processBarcode(rawValue);
                      break;
                    }
                  }
                },
              ),

              // Scanning frame overlay
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          isProcessing
                              ? const Color(0xFFFF9800)
                              : const Color(0xFF4CAF50),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child:
                      isProcessing
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF9800),
                              strokeWidth: 3,
                            ),
                          )
                          : null,
                ),
              ),

              // Corner decorations
              Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: Stack(
                    children: [
                      _buildCorner(top: 0, left: 0),
                      _buildCorner(top: 0, right: 0),
                      _buildCorner(bottom: 0, left: 0),
                      _buildCorner(bottom: 0, right: 0),
                    ],
                  ),
                ),
              ),

              // Custom header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan Attendance',
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
                        icon: Icon(
                          controller.torchEnabled
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => controller.toggleTorch(),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => controller.switchCamera(),
                      ),
                    ],
                  ),
                ),
              ),

              // Stats card
              Positioned(
                top: 100,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Scanned Today:',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$successCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (lastScannedStudent != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last: $lastScannedStudent',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Instructions at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.95),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isProcessing
                            ? Icons.hourglass_empty_rounded
                            : Icons.qr_code_scanner_rounded,
                        color: Colors.white.withOpacity(0.85),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isProcessing
                            ? 'Processing...'
                            : 'Align student QR code in the frame',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'QR codes are scanned automatically',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top:
                top != null
                    ? const BorderSide(color: Color(0xFF667eea), width: 4)
                    : BorderSide.none,
            bottom:
                bottom != null
                    ? const BorderSide(color: Color(0xFF667eea), width: 4)
                    : BorderSide.none,
            left:
                left != null
                    ? const BorderSide(color: Color(0xFF667eea), width: 4)
                    : BorderSide.none,
            right:
                right != null
                    ? const BorderSide(color: Color(0xFF667eea), width: 4)
                    : BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
