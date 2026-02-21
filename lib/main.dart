import 'package:attsys/providers/auth_provider.dart';
import 'package:attsys/screens/admin.dart';
import 'package:attsys/screens/login.dart';
import 'package:attsys/screens/student.dart';
import 'package:attsys/screens/teacher/teacher.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(create: (_) => AuthProvider(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const _AppRoot(),
    );
  }
}

/// Root widget that:
/// 1. Loads any saved token on startup (so reload doesn't log out)
/// 2. Wraps authenticated screens with a Listener to track user activity
/// 3. Shows a dialog when the 30-min inactivity timer fires
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> with WidgetsBindingObserver {
  bool _initialized = false;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Restore saved session on startup — this is what prevents logout on reload
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.loadToken();
      setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // App coming back to foreground = treat as activity (resets timer)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthProvider>().recordActivity();
    }
  }

  void _showTimeoutDialog() {
    final auth = context.read<AuthProvider>();
    auth.clearTimeoutFlag();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.lock_clock, size: 48, color: Color(0xFF667eea)),
        title: const Text(
          'Session Expired',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You were logged out after 30 minutes of inactivity.\n\nPlease sign in again to continue.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign In Again',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show a blank screen while restoring session to avoid flash of login
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Detect inactivity timeout (was logged in, now logged out due to timer)
        if (_wasAuthenticated && !auth.isAuthenticated && auth.loggedOutDueToTimeout) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTimeoutDialog();
          });
        }
        _wasAuthenticated = auth.isAuthenticated;

        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        // Wrap all authenticated screens with a Listener to track any touch
        // and reset the 30-minute inactivity timer
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => auth.recordActivity(),
          child: _buildScreen(auth.role),
        );
      },
    );
  }

  Widget _buildScreen(String? role) {
    switch (role) {
      case 'admin':
        return const AdminDashboard();
      case 'teacher':
        return const TeacherDashboard();
      case 'student':
        return const StudentDashboard();
      default:
        return const LoginScreen();
    }
  }
}