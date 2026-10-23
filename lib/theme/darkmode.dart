import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  APP THEME NOTIFIER
//  Central dark-mode state for the entire app.
//  Wrap your MaterialApp (or its parent) with a ThemeNotifierProvider and call
//  ThemeNotifier.of(context).toggle() from any page.
// ══════════════════════════════════════════════════════════════════════════════

const String _kPrefKey = 'isDarkMode';

/// Holds the single source-of-truth for dark / light mode.
/// Changes are automatically persisted to SharedPreferences and
/// broadcast to every listener via ChangeNotifier.
class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode;

  ThemeNotifier({bool initialValue = true}) : _isDarkMode = initialValue;

  bool get isDarkMode => _isDarkMode;

  bool? get isDark => null;

  /// Toggle between dark and light mode, then persist.
  Future<void> toggle() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, _isDarkMode);
  }

  /// Force-set a value (used by pages that need to sync on init).
  Future<void> setDark(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, _isDarkMode);
  }

  /// Load the persisted value from SharedPreferences.
  /// Call this once near app start (e.g. in [ThemeNotifierProvider.initState]).
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_kPrefKey) ?? true; // default dark
    notifyListeners();
  }
}

// ── InheritedWidget wrapper ───────────────────────────────────────────────────

class ThemeNotifierProvider extends StatefulWidget {
  final Widget child;
  final ThemeNotifier notifier;

  const ThemeNotifierProvider({
    super.key,
    required this.child,
    required this.notifier,
  });

  @override
  State<ThemeNotifierProvider> createState() => _ThemeNotifierProviderState();
}

class _ThemeNotifierProviderState extends State<ThemeNotifierProvider> {
  @override
  void initState() {
    super.initState();
    // Load persisted preference on startup
    widget.notifier.loadFromPrefs();
    widget.notifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return _ThemeInheritedWidget(
      notifier: widget.notifier,
      isDarkMode: widget.notifier.isDarkMode,
      child: widget.child,
    );
  }
}

class _ThemeInheritedWidget extends InheritedWidget {
  final ThemeNotifier notifier;
  final bool isDarkMode;

  const _ThemeInheritedWidget({
    required this.notifier,
    required this.isDarkMode,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ThemeInheritedWidget old) =>
      old.isDarkMode != isDarkMode;

  static _ThemeInheritedWidget? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ThemeInheritedWidget>();
}

// ── Convenient extension ──────────────────────────────────────────────────────

extension ThemeNotifierContext on BuildContext {
  /// Read the current dark-mode state (subscribes to changes).
  bool get isDarkMode {
    final w = _ThemeInheritedWidget.maybeOf(this);
    assert(w != null,
        'No ThemeNotifierProvider found in the widget tree. '
        'Wrap your app or page with ThemeNotifierProvider.');
    return w?.notifier.isDarkMode ?? true;
  }

  /// Returns the [ThemeNotifier] so you can call .toggle() etc.
  ThemeNotifier get themeNotifier {
    final w = _ThemeInheritedWidget.maybeOf(this);
    assert(w != null,
        'No ThemeNotifierProvider found in the widget tree. '
        'Wrap your app or page with ThemeNotifierProvider.');
    return w!.notifier;
  }
}
