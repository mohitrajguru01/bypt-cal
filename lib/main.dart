import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry point of the application.
/// Sets up global app error handling (optional) and launches the app.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/// Root widget of the calculator app.
/// Configures theme, color scheme, and routes.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define brand colors as specified
    const Color foreground = Color(0xFF073654); // #073654
    const Color background = Color(0xFFFCF6EA); // #FCF6EA

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: foreground,
      primary: foreground,
      onPrimary: background,
      background: background,
      surface: Colors.white,
      onSurface: foreground,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'BYPT Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.background,
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: TextTheme(
          displaySmall: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: TextStyle(color: scheme.onSurface),
          bodyLarge: TextStyle(color: scheme.onSurface),
          bodyMedium: TextStyle(color: scheme.onSurface.withOpacity(0.9)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: const CalculatorScreen(),
    );
  }
}

/// Calculator screen providing responsive layout for mobile and web.
/// Includes a basic keypad and an expandable scientific panel.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  // Text controllers for expression input and result display
  final TextEditingController _expressionController = TextEditingController();
  final FocusNode _expressionFocus = FocusNode();

  String _result = '0';
  bool _showScientific = false; // Toggles scientific panel visibility
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // History state
  static const String _prefsHistoryKey = 'calc_history_v1';
  List<CalcHistoryItem> _history = <CalcHistoryItem>[];
  static const int _historyMax = 100;

  // Simple animation controller for reveal/hide of scientific area
  late final AnimationController _revealController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  // Allowed key inputs for keyboard support (web/desktop)
  static const Set<String> _allowedKeys = {
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '.',
    '+',
    '-',
    '*',
    '/',
    '%',
    '(',
    ')',
  };

  @override
  void initState() {
    super.initState();
    // Listen for keyboard inputs for better web/desktop UX
    // HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _loadHistory();
  }

  @override
  void dispose() {
    // HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _revealController.dispose();
    _expressionController.dispose();
    _expressionFocus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_prefsHistoryKey) ?? <String>[];
    final List<CalcHistoryItem> items = <CalcHistoryItem>[];
    for (final String raw in rawList) {
      try {
        final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
        items.add(CalcHistoryItem.fromJson(map));
      } catch (_) {}
    }
    setState(() {
      _history = items;
    });
  }

  Future<void> _saveHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rawList = _history
        .map((e) => jsonEncode(e.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_prefsHistoryKey, rawList);
  }

  Future<void> _appendHistory(String expression, String result) async {
    if (result == 'Error') return;
    final CalcHistoryItem item = CalcHistoryItem(
      expression: expression,
      result: result,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() {
      // Avoid consecutive duplicates
      if (_history.isNotEmpty &&
          _history.first.expression == item.expression &&
          _history.first.result == item.result) {
        _history[0] = item; // refresh timestamp
      } else {
        _history.insert(0, item);
      }
      if (_history.length > _historyMax) {
        _history = _history.sublist(0, _historyMax);
      }
    });
    await _saveHistory();
  }

  Future<void> _clearHistory() async {
    setState(() {
      _history.clear();
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsHistoryKey);
  }

  void _restoreFromHistory(CalcHistoryItem item) {
    _expressionController.text = item.expression;
    _expressionController.selection = TextSelection.fromPosition(
      TextPosition(offset: _expressionController.text.length),
    );
    setState(() {
      _result = item.result;
    });
    _scaffoldKey.currentState?.closeEndDrawer();
  }

  /// Global keyboard handler to capture digits, operators, Enter, and Backspace.
  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final String? char = event.character;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _evaluate();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (char != null && _allowedKeys.contains(char)) {
      _append(char);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Appends a token to the expression input safely.
  void _append(String token) {
    final String current = _expressionController.text;
    _expressionController.text = current + token;
    _expressionController.selection = TextSelection.fromPosition(
      TextPosition(offset: _expressionController.text.length),
    );
    setState(() {});
  }

  /// Clears the entire expression and result.
  void _clearAll() {
    _expressionController.clear();
    setState(() {
      _result = '0';
    });
  }

  /// Deletes one character from the expression.
  void _backspace() {
    final String text = _expressionController.text;
    if (text.isEmpty) return;
    _expressionController.text = text.substring(0, text.length - 1);
    _expressionController.selection = TextSelection.fromPosition(
      TextPosition(offset: _expressionController.text.length),
    );
    setState(() {});
  }

  /// Evaluates the current expression using math_expressions.
  /// Supports basic ops and scientific functions (sin, cos, tan, log, ln, sqrt, pow).
  void _evaluate() {
    final String raw = _expressionController.text.trim();
    if (raw.isEmpty) {
      setState(() => _result = '0');
      return;
    }
    try {
      // Replace percentage shorthand: e.g., 50% -> (50/100)
      final String normalized = raw.replaceAll('%', '/100');

      final Parser parser = Parser();
      final Expression exp = parser.parse(normalized);
      final ContextModel cm = ContextModel();
      final double value = exp.evaluate(EvaluationType.REAL, cm);

      // Format result to avoid trailing .0 and to cap precision
      final String formatted = _formatNumber(value);
      setState(() => _result = formatted);
      _appendHistory(raw, formatted);
    } catch (e) {
      setState(() => _result = 'Error');
    }
  }

  /// Formats a double into a concise string while preserving precision.
  String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) return value.toString();
    // Use up to 12 significant digits, then trim trailing zeros
    String s = value.toStringAsPrecision(12);
    if (s.contains('e')) return s; // scientific notation as-is
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r"\.0+"), '');
      s = s.replaceFirst(RegExp(r"(\.\d*?[1-9])0+"), r"$1");
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Toggles the scientific functions panel with animation.
  void _toggleScientific() {
    setState(() {
      _showScientific = !_showScientific;
      if (_showScientific) {
        _revealController.forward();
      } else {
        _revealController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return GestureDetector(
      // Dismiss keyboard when tapping outside of input
      onTap: () => _expressionFocus.unfocus(),
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App logo from assets with graceful fallback on load error
              Image.asset(
                'assets/logo1.png',
                width: 150,
                height: 150,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
              // const SizedBox(width: 8),
              // const Text('Calculator'),
            ],
          ),
          centerTitle: true,
          backgroundColor: scheme.primary.withOpacity(0.06),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'History',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              icon: Icon(
                Icons.history_rounded,
                color: scheme.primary,
              ),
            ),
            IconButton(
              tooltip: _showScientific ? 'Hide scientific' : 'Show scientific',
              onPressed: _toggleScientific,
              icon: AnimatedRotation(
                duration: const Duration(milliseconds: 250),
                turns: _showScientific ? 0.25 : 0,
                child: Icon(
                  Icons.science_rounded,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
        endDrawer: _buildHistoryDrawer(context),
        endDrawerEnableOpenDragGesture: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive layout: on wide screens, place scientific keys on the left;
            // on narrow screens, stack with an animated expand/collapse.
            final bool isWide = constraints.maxWidth >= 720;

            final Widget displayArea = _buildDisplayArea(context);
            final Widget basicPad = _buildBasicPad(context, isWide);
            final Widget sciPad = _buildScientificPad(context);

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Scientific column (always visible on wide screens)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: _showScientific ? 280 : 0,
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        right: BorderSide(
                          color: scheme.primary.withOpacity(0.08),
                        ),
                      ),
                    ),
                    child: _showScientific
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: sciPad,
                          )
                        : null,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: displayArea,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: basicPad,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Narrow: stack display, scientific (animated), then basic pad
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: displayArea,
                ),
                SizeTransition(
                  sizeFactor: CurvedAnimation(
                    parent: _revealController,
                    curve: Curves.easeOutCubic,
                  ),
                  axisAlignment: -1.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _showScientific
                          ? Container(
                              key: const ValueKey('sci'),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: sciPad,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: basicPad,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Drawer(
      width: 340,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'History',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Clear history',
                    onPressed: _history.isEmpty ? null : _clearHistory,
                    icon: Icon(Icons.delete_sweep_rounded, color: scheme.primary),
                  )
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _history.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No history yet',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        final CalcHistoryItem item = _history[index];
                        final DateTime dt =
                            DateTime.fromMillisecondsSinceEpoch(item.timestampMs);
                        final String timeLabel = _formatTimestamp(dt);
                        return InkWell(
                          onTap: () => _restoreFromHistory(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: scheme.primary.withOpacity(0.03),
                              border: Border.all(color: scheme.primary.withOpacity(0.08)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  item.expression,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: scheme.onSurface.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        timeLabel,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item.result,
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: _history.length,
                    ),
            )
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final two = (int n) => n.toString().padLeft(2, '0');
    final time = '${two(dt.hour)}:${two(dt.minute)}';
    if (isToday) return 'Today, $time';
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}  $time';
  }

  /// Builds the display area with expression input and animated result.
  Widget _buildDisplayArea(BuildContext context) {
    final theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _expressionController,
            focusNode: _expressionFocus,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Enter expression',
              hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
              border: InputBorder.none,
              isDense: true,
            ),
            keyboardType: TextInputType.none, // manage via buttons/keyboard
            textAlign: TextAlign.right,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Align(
                    key: ValueKey(_result),
                    alignment: Alignment.centerRight,
                    child: Text(
                      _result,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 42,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Clear all',
                onPressed: _clearAll,
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.primary.withOpacity(0.06),
                  ),
                ),
                icon: Icon(Icons.clear_all_rounded,
                    color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the basic calculator keypad with digits and arithmetic operators.
  Widget _buildBasicPad(BuildContext context, bool isWide) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // Define basic keys layout
    final List<List<_KeySpec>> rows = [
      [
        _KeySpec(label: '7'),
        _KeySpec(label: '8'),
        _KeySpec(label: '9'),
        _KeySpec(label: '÷', onTap: () => _append('/'), isAccent: true),
      ],
      [
        _KeySpec(label: '4'),
        _KeySpec(label: '5'),
        _KeySpec(label: '6'),
        _KeySpec(label: '×', onTap: () => _append('*'), isAccent: true),
      ],
      [
        _KeySpec(label: '1'),
        _KeySpec(label: '2'),
        _KeySpec(label: '3'),
        _KeySpec(label: '−', onTap: () => _append('-'), isAccent: true),
      ],
      [
        _KeySpec(label: '0'),
        _KeySpec(label: '.'),
        _KeySpec(label: '%'),
        _KeySpec(label: '+', isAccent: true),
      ],
    ];

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 5 : 1,
            ),
            itemCount: rows.expand((r) => r).length,
            itemBuilder: (context, index) {
              final flat = rows.expand((r) => r).toList();
              final _KeySpec spec = flat[index];
              return _CalcKey(
                label: spec.label,
                onTap: spec.onTap ?? () => _append(spec.label),
                isAccent: spec.isAccent,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionKey(
                label: '⌫',
                onTap: _backspace,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionKey(
                label: '=',
                filled: true,
                onTap: _evaluate,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the scientific keypad with common functions.
  Widget _buildScientificPad(BuildContext context) {
    final List<_KeySpec> keys = [
      _KeySpec(label: '(',),
      _KeySpec(label: ')',),
      _KeySpec(label: 'π', onTap: () => _append('${math.pi}')),
      _KeySpec(label: 'e', onTap: () => _append('${math.e}')),
      _KeySpec(label: 'sin', onTap: () => _append('sin('), isAccent: true),
      _KeySpec(label: 'cos', onTap: () => _append('cos('), isAccent: true),
      _KeySpec(label: 'tan', onTap: () => _append('tan('), isAccent: true),
      _KeySpec(label: 'log', onTap: () => _append('log('), isAccent: true),
      _KeySpec(label: 'ln', onTap: () => _append('ln('), isAccent: true),
      _KeySpec(label: '√', onTap: () => _append('sqrt('), isAccent: true),
      _KeySpec(label: '^', onTap: () => _append('^'), isAccent: true),
      _KeySpec(label: 'x²', onTap: () => _append('^2'), isAccent: true),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (context, index) {
        final k = keys[index];
        return _CalcKey(
          label: k.label,
          onTap: k.onTap ?? () => _append(k.label),
          isAccent: k.isAccent,
        );
      },
    );
  }
}

/// History item model
class CalcHistoryItem {
  final String expression;
  final String result;
  final int timestampMs;

  CalcHistoryItem({required this.expression, required this.result, required this.timestampMs});

  Map<String, dynamic> toJson() => {
        'expression': expression,
        'result': result,
        'ts': timestampMs,
      };

  static CalcHistoryItem fromJson(Map<String, dynamic> map) => CalcHistoryItem(
        expression: map['expression'] as String? ?? '',
        result: map['result'] as String? ?? '',
        timestampMs: (map['ts'] as num?)?.toInt() ?? 0,
      );
}

/// Compact specification for a keypad key.
class _KeySpec {
  final String label;
  final VoidCallback? onTap;
  final bool isAccent;

  const _KeySpec({required this.label, this.onTap, this.isAccent = false});
}

/// Visual widget for a calculator key with hover/tap animations.
class _CalcKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAccent;

  const _CalcKey({
    required this.label,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  State<_CalcKey> createState() => _CalcKeyState();
}

class _CalcKeyState extends State<_CalcKey> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color base = widget.isAccent
        ? scheme.primary.withOpacity(0.08)
        : scheme.primary.withOpacity(0.03);
    final Color hover = widget.isAccent
        ? scheme.primary.withOpacity(0.14)
        : scheme.primary.withOpacity(0.08);
    final Color press = widget.isAccent
        ? scheme.primary.withOpacity(0.20)
        : scheme.primary.withOpacity(0.14);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _pressed
                ? press
                : _hovered
                    ? hover
                    : base,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.primary.withOpacity(widget.isAccent ? 0.18 : 0.10),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
      ),
    );
  }
}

/// Wide action button (e.g., backspace and equals) used in the basic pad bottom row.
class _ActionKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ActionKey({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              filled ? scheme.primary : scheme.primary.withOpacity(0.06),
          foregroundColor: filled ? Colors.white : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.primary.withOpacity(0.12)),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
            color: filled ? Colors.white : scheme.primary
              ),
        ),
      ),
    );
  }
}
