// lib/screens/admin.dart
//
// Responsive layout strategy:
//   < 720px  → Mobile:  BottomNavigationBar, full-screen panels, floating FAB
//   ≥ 720px  → Desktop: Persistent left NavigationRail + content area side-by-side
//
// NO Platform / kIsWeb checks — resolution only via LayoutBuilder + MediaQuery.

import 'package:attsys/widgets/logout.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const _kBreakpoint = 720.0;

const _kGrad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
);

const _kAccent = Color(0xFF667eea);
const _kPurple = Color(0xFF764ba2);
const _kDanger = Color(0xFFe53935);
const _kSuccess = Color(0xFF43a047);
const _kWarn = Color(0xFFfb8c00);
const _kBg = Color(0xFFF0F2FA);
const _kCard = Colors.white;

// ─────────────────────────────────────────────────────────────────────────────
// Root Dashboard
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;

  // live stats
  int _tCount = 0, _sCount = 0, _cCount = 0;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<String?> _token() async =>
      (await SharedPreferences.getInstance()).getString('token');

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final tok = await _token();
      final rs = await Future.wait([
        http.get(
          Uri.parse(ApiConfig.adminTeachers),
          headers: ApiConfig.headers(tok),
        ),
        http.get(
          Uri.parse(ApiConfig.adminStudents),
          headers: ApiConfig.headers(tok),
        ),
        http.get(
          Uri.parse(ApiConfig.adminClasses),
          headers: ApiConfig.headers(tok),
        ),
      ]);
      setState(() {
        if (rs[0].statusCode == 200)
          _tCount = (json.decode(rs[0].body) as List).length;
        if (rs[1].statusCode == 200)
          _sCount = (json.decode(rs[1].body) as List).length;
        if (rs[2].statusCode == 200)
          _cCount = (json.decode(rs[2].body) as List).length;
        _statsLoading = false;
      });
    } catch (_) {
      setState(() => _statsLoading = false);
    }
  }

  // one panel per tab
  Widget _panel(int i) {
    return switch (i) {
      0 => TeachersPanel(onStatsChanged: _loadStats),
      1 => StudentsPanel(onStatsChanged: _loadStats),
      _ => ClassesPanel(onStatsChanged: _loadStats),
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isDesktop = constraints.maxWidth >= _kBreakpoint;
        return isDesktop
            ? _DesktopShell(
              tab: _tab,
              onTabChanged: (i) => setState(() => _tab = i),
              tCount: _tCount,
              sCount: _sCount,
              cCount: _cCount,
              statsLoading: _statsLoading,
              onRefresh: _loadStats,
              panel: _panel(_tab),
            )
            : _MobileShell(
              tab: _tab,
              onTabChanged: (i) => setState(() => _tab = i),
              tCount: _tCount,
              sCount: _sCount,
              cCount: _cCount,
              statsLoading: _statsLoading,
              onRefresh: _loadStats,
              panel: _panel(_tab),
            );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop Shell — side NavigationRail + content
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopShell extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTabChanged;
  final int tCount, sCount, cCount;
  final bool statsLoading;
  final VoidCallback onRefresh;
  final Widget panel;

  const _DesktopShell({
    required this.tab,
    required this.onTabChanged,
    required this.tCount,
    required this.sCount,
    required this.cCount,
    required this.statsLoading,
    required this.onRefresh,
    required this.panel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Row(
        children: [
          // ── Left rail ─────────────────────────────────────────────────────
          Container(
            width: 220,
            decoration: const BoxDecoration(
              gradient: _kGrad,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 20,
                  offset: Offset(4, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo area
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'Control Panel',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Stats cards
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _RailStatCard(
                          icon: Icons.school_rounded,
                          label: 'Teachers',
                          value: tCount,
                          loading: statsLoading,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(height: 6),
                        _RailStatCard(
                          icon: Icons.people_rounded,
                          label: 'Students',
                          value: sCount,
                          loading: statsLoading,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(height: 6),
                        _RailStatCard(
                          icon: Icons.class_rounded,
                          label: 'Classes',
                          value: cCount,
                          loading: statsLoading,
                          color: Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      color: Colors.white.withOpacity(0.2),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Nav items
                  ...[
                    (
                      0,
                      Icons.school_rounded,
                      Icons.school_outlined,
                      'Teachers',
                    ),
                    (1, Icons.people_rounded, Icons.people_outline, 'Students'),
                    (2, Icons.class_rounded, Icons.class_outlined, 'Classes'),
                  ].map(
                    (e) => _RailNavItem(
                      index: e.$1,
                      activeIndex: tab,
                      activeIcon: e.$2,
                      icon: e.$3,
                      label: e.$4,
                      onTap: () => onTabChanged(e.$1),
                    ),
                  ),

                  const Spacer(),

                  // Refresh + Logout
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Column(
                      children: [
                        _RailAction(
                          icon: Icons.refresh_rounded,
                          label: 'Refresh',
                          onTap: onRefresh,
                        ),
                        const SizedBox(height: 6),
                        _RailLogout(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content area ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 60,
                  color: _kCard,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        ['Teachers', 'Students', 'Classes'][tab],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1a1a2e),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Attendance Management System',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE8EAF0)),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(key: ValueKey(tab), child: panel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Shell — gradient AppBar + BottomNavigationBar
// ─────────────────────────────────────────────────────────────────────────────
class _MobileShell extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTabChanged;
  final int tCount, sCount, cCount;
  final bool statsLoading;
  final VoidCallback onRefresh;
  final Widget panel;

  const _MobileShell({
    required this.tab,
    required this.onTabChanged,
    required this.tCount,
    required this.sCount,
    required this.cCount,
    required this.statsLoading,
    required this.onRefresh,
    required this.panel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(gradient: _kGrad),
          child: SafeArea(
            child: Column(
              children: [
                // Top row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: onRefresh,
                      ),
                      _MobileLogout(),
                    ],
                  ),
                ),
                // Stat chips row
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    children: [
                      _MobileStatChip(
                        icon: Icons.school_rounded,
                        label: 'Teachers',
                        value: tCount,
                        loading: statsLoading,
                      ),
                      const SizedBox(width: 8),
                      _MobileStatChip(
                        icon: Icons.people_rounded,
                        label: 'Students',
                        value: sCount,
                        loading: statsLoading,
                      ),
                      const SizedBox(width: 8),
                      _MobileStatChip(
                        icon: Icons.class_rounded,
                        label: 'Classes',
                        value: cCount,
                        loading: statsLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(key: ValueKey(tab), child: panel),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _kCard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children:
                  [
                        (
                          0,
                          Icons.school_rounded,
                          Icons.school_outlined,
                          'Teachers',
                        ),
                        (
                          1,
                          Icons.people_rounded,
                          Icons.people_outline,
                          'Students',
                        ),
                        (
                          2,
                          Icons.class_rounded,
                          Icons.class_outlined,
                          'Classes',
                        ),
                      ]
                      .map(
                        (e) => Expanded(
                          child: InkWell(
                            onTap: () => onTabChanged(e.$1),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  tab == e.$1 ? e.$2 : e.$3,
                                  color:
                                      tab == e.$1
                                          ? _kAccent
                                          : Colors.grey.shade400,
                                  size: 22,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  e.$4,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        tab == e.$1
                                            ? FontWeight.w700
                                            : FontWeight.normal,
                                    color:
                                        tab == e.$1
                                            ? _kAccent
                                            : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rail sub-widgets (desktop only)
// ─────────────────────────────────────────────────────────────────────────────
class _RailStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final bool loading;
  final Color color;
  const _RailStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.loading,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          loading
              ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
              : Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
        ],
      ),
    );
  }
}

class _RailNavItem extends StatelessWidget {
  final int index, activeIndex;
  final IconData activeIcon, icon;
  final String label;
  final VoidCallback onTap;
  const _RailNavItem({
    required this.index,
    required this.activeIndex,
    required this.activeIcon,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final active = index == activeIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: active ? Colors.white.withOpacity(0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(active ? activeIcon : icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              if (active) ...[
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailLogout extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LogoutButton();
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile sub-widgets
// ─────────────────────────────────────────────────────────────────────────────
class _MobileStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final bool loading;
  const _MobileStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.loading,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          loading
              ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 1.5,
                ),
              )
              : Text(
                '$value $label',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
        ],
      ),
    );
  }
}

class _MobileLogout extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LogoutButton();
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────
InputDecoration _fd(String label, {IconData? icon, String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: _kAccent, size: 18) : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      isDense: true,
    );

void _snack(BuildContext ctx, String msg, {bool error = false}) {
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
        ],
      ),
      backgroundColor: error ? _kDanger : _kSuccess,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ),
  );
}

Future<bool> _confirmDelete(BuildContext ctx, String what) async =>
    await showDialog<bool>(
      context: ctx,
      builder:
          (c) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: _kDanger),
                const SizedBox(width: 8),
                const Text(
                  'Confirm Delete',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: Text('Delete $what?\nThis cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kDanger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    ) ??
    false;

// Small icon action button
class _Btn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tip;
  const _Btn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tip,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    ),
  );
}

// Dialog wrapper — adapts width to screen
class _Dlg extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final String saveLabel;
  const _Dlg({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
    required this.onSave,
    required this.onCancel,
    this.saveLabel = 'Save',
  });
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: w < _kBreakpoint ? 16 : 80,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: _kGrad,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            // actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 11,
                      ),
                    ),
                    child: Text(
                      saveLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared panel scaffold — search bar + add button + list
// Adapts padding & card layout based on available width via LayoutBuilder
// ─────────────────────────────────────────────────────────────────────────────
class _PanelScaffold extends StatelessWidget {
  final String searchHint;
  final ValueChanged<String> onSearch;
  final String addLabel;
  final Color addColor;
  final VoidCallback onAdd;
  final int itemCount;
  final String countLabel;
  final bool loading;
  final Widget Function(BuildContext, int) itemBuilder;

  const _PanelScaffold({
    required this.searchHint,
    required this.onSearch,
    required this.addLabel,
    required this.addColor,
    required this.onAdd,
    required this.itemCount,
    required this.countLabel,
    required this.loading,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final wide = constraints.maxWidth >= _kBreakpoint;
        return Column(
          children: [
            // Toolbar row
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 20 : 12,
                12,
                wide ? 20 : 12,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: onSearch,
                      decoration: _fd(searchHint, icon: Icons.search),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(
                      wide ? addLabel : 'Add',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: addColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 16 : 10,
                        vertical: 12,
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
            // Count label
            Padding(
              padding: EdgeInsets.fromLTRB(wide ? 22 : 14, 8, 0, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$itemCount $countLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // List
            Expanded(
              child:
                  loading
                      ? const Center(
                        child: CircularProgressIndicator(color: _kAccent),
                      )
                      : itemCount == 0
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              size: 56,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nothing here yet',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 20 : 12,
                          0,
                          wide ? 20 : 12,
                          24,
                        ),
                        itemCount: itemCount,
                        itemBuilder: itemBuilder,
                      ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row card — used in all three panels
// ─────────────────────────────────────────────────────────────────────────────
class _RowCard extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final List<Widget> actions;
  final VoidCallback? onTap;

  const _RowCard({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.actions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      subtitle!,
                    ],
                  ],
                ),
              ),
              ...actions.map(
                (a) =>
                    Padding(padding: const EdgeInsets.only(left: 6), child: a),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEACHERS PANEL
// ─────────────────────────────────────────────────────────────────────────────
class TeachersPanel extends StatefulWidget {
  final VoidCallback onStatsChanged;
  const TeachersPanel({super.key, required this.onStatsChanged});
  @override
  State<TeachersPanel> createState() => _TeachersPanelState();
}

class _TeachersPanelState extends State<TeachersPanel> {
  List _all = [], _filtered = [];
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _token() async =>
      (await SharedPreferences.getInstance()).getString('token');

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tok = await _token();
      final r = await http
          .get(
            Uri.parse(ApiConfig.adminTeachers),
            headers: ApiConfig.headers(tok),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 200) {
        _all = json.decode(r.body);
        _applyFilter();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _applyFilter() {
    _filtered =
        _q.isEmpty
            ? List.from(_all)
            : _all.where((t) {
              final n = '${t['firstname']} ${t['surname']}'.toLowerCase();
              return n.contains(_q.toLowerCase()) ||
                  (t['username'] ?? '').toLowerCase().contains(
                    _q.toLowerCase(),
                  );
            }).toList();
  }

  Future<void> _create() async {
    final fc = TextEditingController(),
        sc = TextEditingController(),
        uc = TextEditingController(),
        pc = TextEditingController(),
        ec = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => _Dlg(
            title: 'New Teacher',
            icon: Icons.person_add_rounded,
            iconColor: _kAccent,
            onCancel: () => Navigator.pop(ctx, false),
            onSave: () => Navigator.pop(ctx, true),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fc,
                      decoration: _fd('First Name', icon: Icons.person_outline),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: sc,
                      decoration: _fd('Surname', icon: Icons.person_outline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ec,
                decoration: _fd('Email (optional)', icon: Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: uc,
                decoration: _fd(
                  'Username',
                  icon: Icons.account_circle_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pc,
                decoration: _fd('Password', icon: Icons.lock_outline),
                obscureText: true,
              ),
            ],
          ),
    );
    if (ok != true) return;
    if (fc.text.trim().isEmpty ||
        sc.text.trim().isEmpty ||
        uc.text.trim().isEmpty ||
        pc.text.isEmpty) {
      _snack(
        context,
        'First name, surname, username and password are required',
        error: true,
      );
      return;
    }
    try {
      final tok = await _token();
      final r = await http
          .post(
            Uri.parse(ApiConfig.adminTeachers),
            headers: ApiConfig.headers(tok),
            body: json.encode({
              'firstname': fc.text.trim(),
              'surname': sc.text.trim(),
              'username': uc.text.trim(),
              'password': pc.text,
              'email': ec.text.trim().isEmpty ? null : ec.text.trim(),
            }),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 201) {
        _snack(context, 'Teacher created');
        _load();
        widget.onStatsChanged();
      } else
        _snack(
          context,
          json.decode(r.body)['message'] ?? 'Failed',
          error: true,
        );
    } catch (e) {
      _snack(context, 'Error: $e', error: true);
    }
  }

  Future<void> _edit(Map t) async {
    final fc = TextEditingController(text: t['firstname'] ?? '');
    final sc = TextEditingController(text: t['surname'] ?? '');
    final ec = TextEditingController(text: t['email'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => _Dlg(
            title: 'Edit Teacher',
            icon: Icons.edit_rounded,
            iconColor: _kWarn,
            onCancel: () => Navigator.pop(ctx, false),
            onSave: () => Navigator.pop(ctx, true),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fc,
                      decoration: _fd('First Name', icon: Icons.person_outline),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: sc,
                      decoration: _fd('Surname', icon: Icons.person_outline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ec,
                decoration: _fd('Email', icon: Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
    );
    if (ok != true) return;
    try {
      final tok = await _token();
      final r = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/api/admin/teachers/${t['id']}'),
            headers: ApiConfig.headers(tok),
            body: json.encode({
              'firstname': fc.text.trim(),
              'surname': sc.text.trim(),
              'email': ec.text.trim().isEmpty ? null : ec.text.trim(),
            }),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 200) {
        _snack(context, 'Teacher updated');
        _load();
      } else
        _snack(
          context,
          json.decode(r.body)['message'] ?? 'Failed',
          error: true,
        );
    } catch (e) {
      _snack(context, 'Error: $e', error: true);
    }
  }

  Future<void> _delete(Map t) async {
    final name = '${t['firstname']} ${t['surname']}';
    if (!await _confirmDelete(context, '"$name" and all their classes')) return;
    try {
      final tok = await _token();
      final r = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/api/admin/teachers/${t['id']}'),
            headers: ApiConfig.headers(tok),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 200 || r.statusCode == 204) {
        _snack(context, 'Teacher deleted');
        _load();
        widget.onStatsChanged();
      } else
        _snack(
          context,
          json.decode(r.body)['message'] ?? 'Failed',
          error: true,
        );
    } catch (e) {
      _snack(context, 'Error: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      searchHint: 'Search teachers…',
      onSearch:
          (v) => setState(() {
            _q = v;
            _applyFilter();
          }),
      addLabel: 'Add Teacher',
      addColor: _kAccent,
      onAdd: _create,
      itemCount: _filtered.length,
      countLabel: 'teacher${_filtered.length != 1 ? 's' : ''}',
      loading: _loading,
      itemBuilder: (ctx, i) {
        final t = _filtered[i] as Map;
        final name = '${t['firstname'] ?? ''} ${t['surname'] ?? ''}'.trim();
        return _RowCard(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: _kAccent.withOpacity(0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'T',
              style: const TextStyle(
                color: _kAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            name.isEmpty ? 'Unknown' : name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1a1a2e),
              fontSize: 14,
            ),
          ),
          subtitle: Row(
            children: [
              Icon(
                Icons.alternate_email,
                size: 12,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 3),
              Text(
                t['username'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 10),
              Icon(Icons.class_rounded, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Text(
                '${t['classes_count'] ?? 0} classes',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          actions: [
            _Btn(
              icon: Icons.edit_rounded,
              color: _kWarn,
              tip: 'Edit',
              onTap: () => _edit(t),
            ),
            _Btn(
              icon: Icons.delete_rounded,
              color: _kDanger,
              tip: 'Delete',
              onTap: () => _delete(t),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENTS PANEL
// ─────────────────────────────────────────────────────────────────────────────
class StudentsPanel extends StatefulWidget {
  final VoidCallback onStatsChanged;
  const StudentsPanel({super.key, required this.onStatsChanged});
  @override
  State<StudentsPanel> createState() => _StudentsPanelState();
}

class _StudentsPanelState extends State<StudentsPanel> {
  List _all = [], _filtered = [];
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _token() async =>
      (await SharedPreferences.getInstance()).getString('token');

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tok = await _token();
      final r = await http
          .get(
            Uri.parse(ApiConfig.adminStudents),
            headers: ApiConfig.headers(tok),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 200) {
        _all = json.decode(r.body);
        _applyFilter();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _applyFilter() {
    _filtered =
        _q.isEmpty
            ? List.from(_all)
            : _all.where((s) {
              final n = '${s['firstname']} ${s['surname']}'.toLowerCase();
              return n.contains(_q.toLowerCase()) ||
                  (s['lrn'] ?? '').contains(_q);
            }).toList();
  }

  Future<void> _create() async {
    final lrnC = TextEditingController(),
        fC = TextEditingController(),
        sC = TextEditingController(),
        sufC = TextEditingController(),
        bdC = TextEditingController(),
        uC = TextEditingController(),
        pC = TextEditingController();
    String? sex;

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx2, ss) => _Dlg(
                  title: 'New Student',
                  icon: Icons.person_add_rounded,
                  iconColor: _kSuccess,
                  onCancel: () => Navigator.pop(ctx, false),
                  onSave: () => Navigator.pop(ctx, true),
                  children: [
                    TextField(
                      controller: lrnC,
                      decoration: _fd(
                        'LRN (12 digits)',
                        icon: Icons.badge_rounded,
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fC,
                            decoration: _fd(
                              'First Name',
                              icon: Icons.person_outline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: sC,
                            decoration: _fd(
                              'Surname',
                              icon: Icons.person_outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sufC,
                            decoration: _fd('Suffix (opt.)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: sex,
                            decoration: _fd('Sex', icon: Icons.wc_rounded),
                            items: const [
                              DropdownMenuItem(
                                value: 'Male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'Female',
                                child: Text('Female'),
                              ),
                            ],
                            onChanged: (v) => ss(() => sex = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bdC,
                      decoration: _fd(
                        'Birthday (yyyy-MM-dd)',
                        icon: Icons.cake_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      'Account (optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: uC,
                      decoration: _fd(
                        'Username',
                        icon: Icons.account_circle_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: pC,
                      decoration: _fd('Password', icon: Icons.lock_outline),
                      obscureText: true,
                    ),
                  ],
                ),
          ),
    );
    if (ok != true) return;
    if (lrnC.text.length != 12 ||
        fC.text.trim().isEmpty ||
        sC.text.trim().isEmpty) {
      _snack(
        context,
        'LRN (12 digits), first name and surname are required',
        error: true,
      );
      return;
    }
    try {
      final tok = await _token();
      final body = <String, dynamic>{
        'lrn': lrnC.text.trim(),
        'firstname': fC.text.trim(),
        'surname': sC.text.trim(),
        if (sufC.text.trim().isNotEmpty) 'suffix': sufC.text.trim(),
        if (bdC.text.trim().isNotEmpty) 'birthday': bdC.text.trim(),
        if (sex != null) 'sex': sex,
      };
      if (uC.text.trim().isNotEmpty && pC.text.isNotEmpty) {
        body['username'] = uC.text.trim();
        body['password'] = pC.text;
        body['role'] = 'student';
        final r = await http
            .post(
              Uri.parse(ApiConfig.authRegister),
              headers: ApiConfig.headers(tok),
              body: json.encode(body),
            )
            .timeout(ApiConfig.timeout);
        if (r.statusCode == 201) {
          _snack(context, 'Student created with account');
          _load();
          widget.onStatsChanged();
        } else
          _snack(
            context,
            json.decode(r.body)['message'] ?? 'Failed',
            error: true,
          );
      } else {
        final r = await http
            .post(
              Uri.parse(ApiConfig.adminStudents),
              headers: ApiConfig.headers(tok),
              body: json.encode(body),
            )
            .timeout(ApiConfig.timeout);
        if (r.statusCode == 201) {
          _snack(context, 'Student created');
          _load();
          widget.onStatsChanged();
        } else
          _snack(
            context,
            json.decode(r.body)['message'] ?? 'Failed',
            error: true,
          );
      }
    } catch (e) {
      _snack(context, 'Error: $e', error: true);
    }
  }

  Future<void> _edit(Map s) async {
    final fC = TextEditingController(text: s['firstname'] ?? '');
    final sC = TextEditingController(text: s['surname'] ?? '');
    final sufC = TextEditingController(text: s['suffix'] ?? '');
    final bdC = TextEditingController(text: s['birthday'] ?? '');
    String? sex = s['sex'];

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx2, ss) => _Dlg(
                  title: 'Edit Student',
                  icon: Icons.edit_rounded,
                  iconColor: _kWarn,
                  onCancel: () => Navigator.pop(ctx, false),
                  onSave: () => Navigator.pop(ctx, true),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _kAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.badge_rounded,
                            color: _kAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LRN: ${s['lrn']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _kAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fC,
                            decoration: _fd(
                              'First Name',
                              icon: Icons.person_outline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: sC,
                            decoration: _fd(
                              'Surname',
                              icon: Icons.person_outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sufC,
                            decoration: _fd('Suffix (opt.)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: sex,
                            decoration: _fd('Sex', icon: Icons.wc_rounded),
                            items: const [
                              DropdownMenuItem(
                                value: 'Male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'Female',
                                child: Text('Female'),
                              ),
                            ],
                            onChanged: (v) => ss(() => sex = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bdC,
                      decoration: _fd(
                        'Birthday (yyyy-MM-dd)',
                        icon: Icons.cake_rounded,
                      ),
                    ),
                  ],
                ),
          ),
    );
    if (ok != true) return;
    try {
      final tok = await _token();
      final r = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/api/admin/students/${s['lrn']}'),
            headers: ApiConfig.headers(tok),
            body: json.encode({
              'firstname': fC.text.trim(),
              'surname': sC.text.trim(),
              'suffix': sufC.text.trim().isEmpty ? null : sufC.text.trim(),
              'birthday': bdC.text.trim().isEmpty ? null : bdC.text.trim(),
              'sex': sex,
            }),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 200) {
        _snack(context, 'Student updated');
        _load();
      } else
        _snack(
          context,
          json.decode(r.body)['message'] ?? 'Failed',
          error: true,
        );
    } catch (e) {
      _snack(context, 'Error: $e', error: true);
    }
  }

  Future<void> _delete(Map s) async {
    final name = '${s['firstname']} ${s['surname']}';
    if (!await _confirmDelete(context, '"$name" (LRN: ${s['lrn']})')) return;
    try {
      final tok = await _token();
      final r = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/api/admin/students/${s['lrn']}'),
            headers: ApiConfig.headers(tok),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 200 || r.statusCode == 204) {
        _snack(context, 'Student deleted');
        _load();
        widget.onStatsChanged();
      } else
        _snack(
          context,
          json.decode(r.body)['message'] ?? 'Failed',
          error: true,
        );
    } catch (e) {
      _snack(context, 'Error: $e', error: true);
    }
  }

  Color _sc(String? sex) =>
      sex == 'Male'
          ? Colors.blue.shade400
          : sex == 'Female'
          ? Colors.pink.shade400
          : Colors.grey.shade400;

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      searchHint: 'Search by name or LRN…',
      onSearch:
          (v) => setState(() {
            _q = v;
            _applyFilter();
          }),
      addLabel: 'Add Student',
      addColor: _kSuccess,
      onAdd: _create,
      itemCount: _filtered.length,
      countLabel: 'student${_filtered.length != 1 ? 's' : ''}',
      loading: _loading,
      itemBuilder: (ctx, i) {
        final s = _filtered[i] as Map;
        final name =
            '${s['firstname'] ?? ''} ${s['suffix'] ?? ''} ${s['surname'] ?? ''}'
                .trim()
                .replaceAll(RegExp(r' +'), ' ');
        final sex = s['sex'] as String?;
        return _RowCard(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: _sc(sex).withOpacity(0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: TextStyle(color: _sc(sex), fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1a1a2e),
              fontSize: 14,
            ),
          ),
          subtitle: Wrap(
            spacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.badge_rounded,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    s['lrn'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              if (sex != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: _sc(sex).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sex,
                    style: TextStyle(
                      fontSize: 11,
                      color: _sc(sex),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (s['birthday'] != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cake_rounded,
                      size: 12,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      s['birthday'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          actions: [
            _Btn(
              icon: Icons.edit_rounded,
              color: _kWarn,
              tip: 'Edit',
              onTap: () => _edit(s),
            ),
            _Btn(
              icon: Icons.delete_rounded,
              color: _kDanger,
              tip: 'Delete',
              onTap: () => _delete(s),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASSES PANEL
// ─────────────────────────────────────────────────────────────────────────────
class ClassesPanel extends StatefulWidget {
  final VoidCallback onStatsChanged;
  const ClassesPanel({super.key, required this.onStatsChanged});
  @override
  State<ClassesPanel> createState() => _ClassesPanelState();
}

class _ClassesPanelState extends State<ClassesPanel> {
  List _all = [], _filtered = [], _teachers = [];
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _token() async =>
      (await SharedPreferences.getInstance()).getString('token');

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tok = await _token();
      final rs = await Future.wait([
        http
            .get(
              Uri.parse(ApiConfig.adminClasses),
              headers: ApiConfig.headers(tok),
            )
            .timeout(ApiConfig.timeout),
        http
            .get(
              Uri.parse(ApiConfig.adminTeachers),
              headers: ApiConfig.headers(tok),
            )
            .timeout(ApiConfig.timeout),
      ]);
      if (rs[0].statusCode == 200) {
        _all = json.decode(rs[0].body);
        _applyFilter();
      }
      if (rs[1].statusCode == 200) _teachers = json.decode(rs[1].body);
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _applyFilter() {
    _filtered =
        _q.isEmpty
            ? List.from(_all)
            : _all.where((c) {
              final n = (c['name'] ?? '').toLowerCase();
              final t = (c['teacher_name'] ?? '').toLowerCase();
              return n.contains(_q.toLowerCase()) ||
                  t.contains(_q.toLowerCase());
            }).toList();
  }

  Future<void> _create() async {
    final nC = TextEditingController(),
        secC = TextEditingController(),
        syC = TextEditingController(text: '2025-2026');
    String? grade, teacherId;
    final grades = List.generate(12, (i) => '${i + 1}');

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx2, ss) => _Dlg(
                  title: 'New Class',
                  icon: Icons.class_rounded,
                  iconColor: _kAccent,
                  onCancel: () => Navigator.pop(ctx, false),
                  onSave: () => Navigator.pop(ctx, true),
                  children: [
                    TextField(
                      controller: nC,
                      decoration: _fd('Class Name', icon: Icons.class_rounded),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: grade,
                            decoration: _fd(
                              'Grade',
                              icon: Icons.school_rounded,
                            ),
                            items:
                                grades
                                    .map(
                                      (g) => DropdownMenuItem(
                                        value: g,
                                        child: Text('Grade $g'),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => ss(() => grade = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: secC,
                            decoration: _fd(
                              'Section (opt.)',
                              icon: Icons.group_rounded,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: syC,
                      decoration: _fd(
                        'School Year',
                        icon: Icons.calendar_month_rounded,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: teacherId,
                      decoration: _fd(
                        'Assign Teacher',
                        icon: Icons.person_rounded,
                      ),
                      items:
                          _teachers.map((t) {
                            final tn =
                                '${t['firstname'] ?? ''} ${t['surname'] ?? ''}'
                                    .trim();
                            return DropdownMenuItem(
                              value: t['id'].toString(),
                              child: Text(tn),
                            );
                          }).toList(),
                      onChanged: (v) => ss(() => teacherId = v),
                    ),
                  ],
                ),
          ),
    );
    if (ok != true) return;
    if (nC.text.trim().isEmpty || grade == null || teacherId == null) {
      _snack(context, 'Name, grade and teacher are required', error: true);
      return;
    }
    try {
      final tok = await _token();
      final r = await http
          .post(
            Uri.parse(ApiConfig.adminClasses),
            headers: ApiConfig.headers(tok),
            body: json.encode({
              'name': nC.text.trim(),
              'gradeLevel': grade,
              'section': secC.text.trim().isEmpty ? null : secC.text.trim(),
              'schoolYear': syC.text.trim(),
              'teacherId': int.parse(teacherId!),
            }),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 201) {
        _snack(context, 'Class created');
        _load();
        widget.onStatsChanged();
      } else
        _snack(
          context,
          json.decode(r.body)['message'] ?? 'Failed',
          error: true,
        );
    } catch (e) {
      _snack(context, 'Error: $e', error: true);
    }
  }

  Future<void> _edit(Map c) async {
    final nC = TextEditingController(text: c['name'] ?? '');
    final secC = TextEditingController(text: c['section'] ?? '');
    final syC = TextEditingController(text: c['school_year'] ?? '');
    String? grade = c['grade_level']?.toString();
    final grades = List.generate(12, (i) => '${i + 1}');

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx2, ss) => _Dlg(
                  title: 'Edit Class',
                  icon: Icons.edit_rounded,
                  iconColor: _kWarn,
                  onCancel: () => Navigator.pop(ctx, false),
                  onSave: () => Navigator.pop(ctx, true),
                  children: [
                    TextField(
                      controller: nC,
                      decoration: _fd('Class Name', icon: Icons.class_rounded),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: grade,
                            decoration: _fd(
                              'Grade',
                              icon: Icons.school_rounded,
                            ),
                            items:
                                grades
                                    .map(
                                      (g) => DropdownMenuItem(
                                        value: g,
                                        child: Text('Grade $g'),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => ss(() => grade = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: secC,
                            decoration: _fd('Section (opt.)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: syC,
                      decoration: _fd(
                        'School Year',
                        icon: Icons.calendar_month_rounded,
                      ),
                    ),
                  ],
                ),
          ),
    );
    if (ok != true) return;
    try {
      final tok = await _token();
      final r = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/api/admin/classes/${c['id']}'),
            headers: ApiConfig.headers(tok),
            body: json.encode({
              'name': nC.text.trim(),
              'gradeLevel': grade,
              'section': secC.text.trim().isEmpty ? null : secC.text.trim(),
              'schoolYear': syC.text.trim(),
            }),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 200) {
        _snack(context, 'Class updated');
        _load();
      } else
        _snack(
          context,
          json.decode(r.body)['message'] ?? 'Failed',
          error: true,
        );
    } catch (e) {
      _snack(context, 'Error: $e', error: true);
    }
  }

  Future<void> _delete(Map c) async {
    if (!await _confirmDelete(
      context,
      'class "${c['name']}" and all attendance records',
    ))
      return;
    try {
      final tok = await _token();
      final r = await http
          .delete(
            Uri.parse(ApiConfig.adminDeleteClass(c['id'].toString())),
            headers: ApiConfig.headers(tok),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 200 || r.statusCode == 204) {
        _snack(context, 'Class deleted');
        _load();
        widget.onStatsChanged();
      } else
        _snack(
          context,
          json.decode(r.body)['message'] ?? 'Failed',
          error: true,
        );
    } catch (e) {
      _snack(context, 'Error: $e', error: true);
    }
  }

  void _viewStudents(Map c) {
    showDialog(
      context: context,
      builder:
          (_) => _ClassStudentsDialog(
            classId: c['id'].toString(),
            className: c['name'],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      searchHint: 'Search by class or teacher…',
      onSearch:
          (v) => setState(() {
            _q = v;
            _applyFilter();
          }),
      addLabel: 'Add Class',
      addColor: _kPurple,
      onAdd: _create,
      itemCount: _filtered.length,
      countLabel: 'class${_filtered.length != 1 ? 'es' : ''}',
      loading: _loading,
      itemBuilder: (ctx, i) {
        final c = _filtered[i] as Map;
        return _RowCard(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kAccent, _kPurple]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.class_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            c['name'] ?? 'Unnamed',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1a1a2e),
              fontSize: 14,
            ),
          ),
          subtitle: Wrap(
            spacing: 8,
            children: [
              _Chip(
                'Grade ${c['grade_level']}${c['section'] != null ? ' · ${c['section']}' : ''}',
                Colors.indigo,
              ),
              _Chip(c['school_year'] ?? '', Colors.teal),
              _Chip('${c['student_count'] ?? 0} students', Colors.green),
              _Chip(c['teacher_name'] ?? 'Unassigned', Colors.orange),
            ],
          ),
          onTap: () => _viewStudents(c),
          actions: [
            _Btn(
              icon: Icons.people_rounded,
              color: _kAccent,
              tip: 'View Students',
              onTap: () => _viewStudents(c),
            ),
            _Btn(
              icon: Icons.edit_rounded,
              color: _kWarn,
              tip: 'Edit',
              onTap: () => _edit(c),
            ),
            _Btn(
              icon: Icons.delete_rounded,
              color: _kDanger,
              tip: 'Delete',
              onTap: () => _delete(c),
            ),
          ],
        );
      },
    );
  }
}

Widget _Chip(String label, MaterialColor color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
  decoration: BoxDecoration(
    color: color.shade50,
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text(
    label,
    style: TextStyle(
      fontSize: 11,
      color: color.shade700,
      fontWeight: FontWeight.w500,
    ),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// Class Students Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ClassStudentsDialog extends StatefulWidget {
  final String classId, className;
  const _ClassStudentsDialog({required this.classId, required this.className});
  @override
  State<_ClassStudentsDialog> createState() => _ClassStudentsDialogState();
}

class _ClassStudentsDialogState extends State<_ClassStudentsDialog> {
  List _students = [];
  List _allStudents = []; // all students for the search/add picker
  List _searchResults = []; // filtered not-yet-enrolled students
  bool _loading = true;
  bool _adding = false; // toggle add panel
  bool _searchLoading = false;
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<String?> _token() async =>
      (await SharedPreferences.getInstance()).getString('token');

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tok = await _token();
      final rs = await Future.wait([
        http
            .get(
              Uri.parse(ApiConfig.adminClassStudents(widget.classId)),
              headers: ApiConfig.headers(tok),
            )
            .timeout(ApiConfig.timeout),
        http
            .get(
              Uri.parse(ApiConfig.adminStudents),
              headers: ApiConfig.headers(tok),
            )
            .timeout(ApiConfig.timeout),
      ]);
      if (rs[0].statusCode == 200) _students = json.decode(rs[0].body);
      if (rs[1].statusCode == 200) _allStudents = json.decode(rs[1].body);
      _filterSearchResults();
    } catch (_) {}
    setState(() => _loading = false);
  }

  // Students not yet enrolled in this class
  void _filterSearchResults() {
    final enrolledLrns = _students.map((s) => s['lrn']).toSet();
    _searchResults =
        _allStudents.where((s) {
          if (enrolledLrns.contains(s['lrn'])) return false;
          if (_q.isEmpty) return true;
          final name = '${s['firstname']} ${s['surname']}'.toLowerCase();
          return name.contains(_q.toLowerCase()) ||
              (s['lrn'] ?? '').contains(_q);
        }).toList();
  }

  Future<void> _enroll(Map s) async {
    final name = '${s['firstname']} ${s['suffix'] ?? ''} ${s['surname']}'
        .trim()
        .replaceAll(RegExp(r' +'), ' ');
    try {
      final tok = await _token();
      final r = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/admin/classes/${widget.classId}/students',
            ),
            headers: ApiConfig.headers(tok),
            body: json.encode({'lrn': s['lrn']}),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 201 || r.statusCode == 200) {
        _snack(context, '$name enrolled');
        await _load();
        setState(() {
          _filterSearchResults();
        });
      } else {
        _snack(
          context,
          json.decode(r.body)['message'] ?? 'Failed to enroll',
          error: true,
        );
      }
    } catch (e) {
      _snack(context, 'Error: $e', error: true);
    }
  }

  Future<void> _remove(String lrn, String name) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Remove Student',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                content: Text('Remove "$name" from ${widget.className}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kDanger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!ok) return;
    try {
      final tok = await _token();
      final r = await http
          .delete(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/admin/classes/${widget.classId}/students/$lrn',
            ),
            headers: ApiConfig.headers(tok),
          )
          .timeout(ApiConfig.timeout);
      if (r.statusCode == 200 || r.statusCode == 204) {
        _snack(context, 'Student removed');
        await _load();
        setState(() {
          _filterSearchResults();
        });
      } else {
        _snack(context, 'Failed to remove', error: true);
      }
    } catch (e) {
      _snack(context, 'Error: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: w < _kBreakpoint ? 12 : 80,
        vertical: 28,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 660),
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              decoration: const BoxDecoration(
                gradient: _kGrad,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.className,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${_students.length} enrolled',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Toggle add panel
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color:
                          _adding
                              ? Colors.white
                              : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _adding ? Icons.close : Icons.person_add_rounded,
                        color: _adding ? _kAccent : Colors.white,
                        size: 20,
                      ),
                      tooltip: _adding ? 'Close' : 'Add student',
                      onPressed:
                          () => setState(() {
                            _adding = !_adding;
                            _q = '';
                            _searchCtrl.clear();
                            _filterSearchResults();
                          }),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Add student panel (collapsible) ───────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child:
                  _adding
                      ? Container(
                        decoration: BoxDecoration(
                          color: _kAccent.withOpacity(0.04),
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search,
                                    color: _kAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Search students to enroll',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _kAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: TextField(
                                controller: _searchCtrl,
                                autofocus: true,
                                onChanged:
                                    (v) => setState(() {
                                      _q = v;
                                      _filterSearchResults();
                                    }),
                                decoration: _fd(
                                  'Name or LRN…',
                                  icon: Icons.search,
                                ).copyWith(
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child:
                                  _searchResults.isEmpty
                                      ? Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          0,
                                          14,
                                          14,
                                        ),
                                        child: Text(
                                          _q.isEmpty
                                              ? 'All students are already enrolled or type to search.'
                                              : 'No students found for "$_q".',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      )
                                      : ListView.separated(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          10,
                                        ),
                                        itemCount: _searchResults.length,
                                        separatorBuilder:
                                            (_, __) =>
                                                const SizedBox(height: 4),
                                        itemBuilder: (ctx, i) {
                                          final s = _searchResults[i];
                                          final name =
                                              '${s['firstname']} ${s['suffix'] ?? ''} ${s['surname']}'
                                                  .trim()
                                                  .replaceAll(
                                                    RegExp(r' +'),
                                                    ' ',
                                                  );
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.04),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: ListTile(
                                              dense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 2,
                                                  ),
                                              leading: CircleAvatar(
                                                radius: 16,
                                                backgroundColor: _kSuccess
                                                    .withOpacity(0.1),
                                                child: Text(
                                                  name[0].toUpperCase(),
                                                  style: const TextStyle(
                                                    color: _kSuccess,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              title: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'LRN: ${s['lrn']}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                              trailing: InkWell(
                                                onTap: () => _enroll(s),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _kSuccess,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Enroll',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                            ),
                          ],
                        ),
                      )
                      : const SizedBox.shrink(),
            ),

            // ── Enrolled students list ─────────────────────────────────────────
            Expanded(
              child:
                  _loading
                      ? const Center(
                        child: CircularProgressIndicator(color: _kAccent),
                      )
                      : _students.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No students enrolled',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () => setState(() => _adding = true),
                              icon: const Icon(
                                Icons.person_add_rounded,
                                size: 16,
                              ),
                              label: const Text('Add students'),
                            ),
                          ],
                        ),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (ctx, i) {
                          final s = _students[i];
                          final name =
                              '${s['firstname']} ${s['suffix'] ?? ''} ${s['surname']}'
                                  .trim()
                                  .replaceAll(RegExp(r' +'), ' ');
                          final sex = s['sex'] as String?;
                          final sexColor =
                              sex == 'Male'
                                  ? Colors.blue.shade400
                                  : sex == 'Female'
                                  ? Colors.pink.shade400
                                  : Colors.grey.shade400;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _kBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: sexColor.withOpacity(0.12),
                                  child: Text(
                                    name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: sexColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            'LRN: ${s['lrn']}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          if (sex != null) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: sexColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                sex,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: sexColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _remove(s['lrn'], name),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: _kDanger.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.remove_circle_outline,
                                      color: _kDanger,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
