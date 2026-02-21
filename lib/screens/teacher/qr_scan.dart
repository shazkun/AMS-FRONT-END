import 'package:attsys/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

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
  MobileScannerController? controller;

  /// Returns true if the current platform supports camera-based QR scanning.
  /// Web and Windows are NOT supported — show the info screen instead.
  bool get _isScanSupported {
    if (kIsWeb) {
      return true;
    } else {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return false;
      }
      return true; // Android, iOS
    }
  }

  /// Maps to in the last accepted LRN → timestamp for client-side cooldown.
  final Map<String, DateTime> _lastAcceptedAt = {};
  static const Duration _cooldownDuration = Duration(seconds: 10);

  bool _isProcessing = false;
  String? _lastScannedStudent;
  int _successCount = 0;

  @override
  void initState() {
    super.initState();
    if (_isScanSupported) {
      controller = MobileScannerController(
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  bool _isOnCooldown(String lrn) {
    final last = _lastAcceptedAt[lrn];
    if (last == null) return false;
    return DateTime.now().difference(last) < _cooldownDuration;
  }

  void _markScanned(String lrn) {
    _lastAcceptedAt[lrn] = DateTime.now();
    _lastAcceptedAt.removeWhere(
      (_, ts) => DateTime.now().difference(ts) > _cooldownDuration * 3,
    );
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

  // ── Scan logic ───────────────────────────────────────────────────────────────

  void _processBarcode(String rawValue) {
    final parts = rawValue.split('|');
    if (parts.length != 3) return;

    final namePart = parts[0];
    final lrnPart = parts[1];
    final classPart = parts[2];

    if (!lrnPart.startsWith('lrn:') || !classPart.startsWith('class:')) return;

    final names = namePart.split(',');
    if (names.length != 2) return;

    final surname = names[0].trim();
    final firstname = names[1].trim();
    final lrn = lrnPart.substring(4).trim();
    final scannedClassId = classPart.substring(6).trim();

    if (lrn.length != 12 || !RegExp(r'^\d{12}$').hasMatch(lrn)) {
      _showMessage('Invalid LRN in QR code', isError: true);
      return;
    }

    if (scannedClassId != widget.classId) {
      _showMessage('QR code is for a different class', isError: true);
      return;
    }

    if (_isOnCooldown(lrn)) {
      debugPrint('Cooldown active for LRN $lrn — skipping');
      return;
    }

    if (_isProcessing) return;

    _markScanned(lrn);
    _recordAttendance(lrn, surname, firstname);
  }

  Future<void> _recordAttendance(
    String lrn,
    String surname,
    String firstname,
  ) async {
    setState(() => _isProcessing = true);

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
        final studentName = data['student'] as String? ?? 'Student';
        setState(() {
          _lastScannedStudent = studentName;
          _successCount++;
        });
        _showMessage('✓ $studentName marked present', isError: false);
      } else if (response.statusCode == 429) {
        _markScanned(lrn);
        final msg =
            json.decode(response.body)['message'] as String? ??
            'Already scanned recently';
        _showMessage(msg, isError: true);
      } else if (response.statusCode == 409) {
        _markScanned(lrn);
        final studentName =
            json.decode(response.body)['student'] as String? ?? lrn;
        _showMessage(
          '$studentName — attendance already recorded today',
          isError: true,
        );
      } else {
        final err =
            json.decode(response.body)['message'] as String? ?? 'Unknown error';
        _showMessage('Failed: $err', isError: true);
        _lastAcceptedAt.remove(lrn);
      }
    } catch (e) {
      _showMessage('Network error: $e', isError: true);
      _lastAcceptedAt.remove(lrn);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return _isScanSupported ? _buildScannerView() : _buildUnsupportedView();
  }

  // ── Unsupported platform screen ──────────────────────────────────────────────

  Widget _buildUnsupportedView() {
    return Scaffold(
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
              // Back button row
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 72,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Title
                        const Text(
                          'QR Scanning Not Available',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'QR code scanning requires a camera and is only supported on mobile devices (Android & iOS).\n\n'
                            'To scan student attendance, please use the mobile app on your phone or tablet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Platform chips
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _platformChip(
                              Icons.android,
                              'Android',
                              Colors.green.shade400,
                              supported: true,
                            ),
                            _platformChip(
                              Icons.apple,
                              'iOS',
                              Colors.green.shade400,
                              supported: true,
                            ),
                            _platformChip(
                              Icons.computer_rounded,
                              'Windows',
                              Colors.red.shade300,
                              supported: false,
                            ),
                            _platformChip(
                              Icons.web_rounded,
                              'Web',
                              Colors.green.shade400,
                              supported: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Back button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text(
                              'Go Back',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF667eea),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
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

  Widget _platformChip(
    IconData icon,
    String label,
    Color color, {
    required bool supported,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.8), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            supported ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: color,
          ),
        ],
      ),
    );
  }

  // ── Camera scanner view (mobile only) ────────────────────────────────────────

  Widget _buildScannerView() {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
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
                controller: controller!,
                onDetect: (capture) {
                  if (_isProcessing) return;
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
                          _isProcessing
                              ? const Color(0xFFFF9800)
                              : const Color(0xFF4CAF50),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child:
                      _isProcessing
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

              // Header overlay
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
                          controller!.torchEnabled
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => controller!.toggleTorch(),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => controller!.switchCamera(),
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
                              '$_successCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_lastScannedStudent != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last: $_lastScannedStudent',
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

              // Bottom instructions
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
                        _isProcessing
                            ? Icons.hourglass_empty_rounded
                            : Icons.qr_code_scanner_rounded,
                        color: Colors.white.withOpacity(0.85),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isProcessing
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
    controller?.dispose();
    super.dispose();
  }
}
