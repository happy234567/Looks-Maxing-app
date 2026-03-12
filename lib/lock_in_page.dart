import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _weekDayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const List<String> _weekDayShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
];


// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedProgressBar extends StatefulWidget {
  final double value;
  final Color color;
  final double height;
  final Duration duration;
  const _AnimatedProgressBar({
    required this.value, required this.color,
    this.height = 6, this.duration = const Duration(milliseconds: 800),
  });
  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_AnimatedProgressBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(begin: _anim.value, end: widget.value)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl..reset()..forward();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => ClipRRect(
      borderRadius: BorderRadius.circular(widget.height),
      child: LinearProgressIndicator(
        value: _anim.value,
        backgroundColor: Colors.white10,
        valueColor: AlwaysStoppedAnimation(widget.color),
        minHeight: widget.height,
      ),
    ),
  );
}

class _AnimatedScoreCircle extends StatefulWidget {
  final double value;
  final Color color;
  final double size;
  const _AnimatedScoreCircle({required this.value, required this.color, this.size = 56});
  @override
  State<_AnimatedScoreCircle> createState() => _AnimatedScoreCircleState();
}

class _AnimatedScoreCircleState extends State<_AnimatedScoreCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_AnimatedScoreCircle old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(begin: _anim.value, end: widget.value)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl..reset()..forward();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Stack(alignment: Alignment.center, children: [
      SizedBox(
        width: widget.size, height: widget.size,
        child: CircularProgressIndicator(
          value: _anim.value, backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation(widget.color), strokeWidth: 5,
        ),
      ),
      Text('${(_anim.value * 100).round()}%',
          style: TextStyle(color: widget.color, fontWeight: FontWeight.bold,
              fontSize: widget.size * 0.22)),
    ]),
  );
}

class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressableCard({required this.child, VoidCallback? onTap}) : onTap = onTap;
  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.forward(),
    onTapUp: (_) async {
      await _ctrl.reverse();
      widget.onTap?.call();
    },
    onTapCancel: () => _ctrl.reverse(),
    child: AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: widget.child,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class MandatoryConfig {
  // Fixed limits — user cannot change these
  static const int stepsMin = 8000;
  static const int stepsMax = 30000;
  static const int proteinMin = 50;
  static const int proteinMax = 200;
  static const int sleepMin = 7;
  static const int sleepMax = 11;

  int stepsTarget;
  int proteinTarget;
  double sleepTarget;

  MandatoryConfig({
    this.stepsTarget = 10000,
    this.proteinTarget = 100,
    this.sleepTarget = 8.0,
  });

  Map<String, dynamic> toJson() => {
    'stepsTarget': stepsTarget,
    'proteinTarget': proteinTarget,
    'sleepTarget': sleepTarget,
  };

  factory MandatoryConfig.fromJson(Map<String, dynamic> j) => MandatoryConfig(
    stepsTarget: j['stepsTarget'] ?? 10000,
    proteinTarget: j['proteinTarget'] ?? 100,
    sleepTarget: (j['sleepTarget'] ?? 8.0).toDouble(),
  );

  MandatoryConfig copy() => MandatoryConfig(
    stepsTarget: stepsTarget,
    proteinTarget: proteinTarget,
    sleepTarget: sleepTarget,
  );
}

// weekdayTasks[0] = Monday tasks, [1] = Tuesday ... [6] = Sunday
class WeeklyConfig {
  MandatoryConfig mandatory;
  List<List<String>> weekdayTasks; // 7 days, each a list of custom tasks

  WeeklyConfig({
    MandatoryConfig? mandatory,
    List<List<String>>? weekdayTasks,
  })  : mandatory = mandatory ?? MandatoryConfig(),
        weekdayTasks = weekdayTasks ?? List.generate(7, (_) => []);

  Map<String, dynamic> toJson() => {
    'mandatory': mandatory.toJson(),
    'weekdayTasks': weekdayTasks,
  };

  factory WeeklyConfig.fromJson(Map<String, dynamic> j) => WeeklyConfig(
    mandatory: MandatoryConfig.fromJson(j['mandatory'] ?? {}),
    weekdayTasks: (j['weekdayTasks'] as List?)
        ?.map((d) => List<String>.from(d))
        .toList() ?? List.generate(7, (_) => []),
  );
}

class DayLog {
  final int dayNumber;
  final DateTime date;
  bool stepsCompleted, proteinCompleted, sleepCompleted;
  List<bool> customCompleted;

  DayLog({
    required this.dayNumber, required this.date,
    this.stepsCompleted = false, this.proteinCompleted = false,
    this.sleepCompleted = false, List<bool>? customCompleted,
  }) : customCompleted = customCompleted ?? [];

  // weekday index 0=Mon..6=Sun
  int get weekdayIndex => (date.weekday - 1) % 7;

  double completionRate(int customTaskCount) {
    final total = 3 + customTaskCount;
    if (total == 0) return 0;
    final done = (stepsCompleted ? 1 : 0) + (proteinCompleted ? 1 : 0) +
        (sleepCompleted ? 1 : 0) + customCompleted.where((c) => c).length;
    return done / total;
  }

  Map<String, dynamic> toJson() => {
    'dayNumber': dayNumber, 'date': date.toIso8601String(),
    'stepsCompleted': stepsCompleted, 'proteinCompleted': proteinCompleted,
    'sleepCompleted': sleepCompleted, 'customCompleted': customCompleted,
  };

  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
    dayNumber: j['dayNumber'] ?? 1,
    date: DateTime.parse(j['date']),
    stepsCompleted: j['stepsCompleted'] ?? false,
    proteinCompleted: j['proteinCompleted'] ?? false,
    sleepCompleted: j['sleepCompleted'] ?? false,
    customCompleted: List<bool>.from(j['customCompleted'] ?? []),
  );
}

class LockInData {
  final DateTime startDate;
  WeeklyConfig config;
  List<DayLog> days;

  DateTime? premiumStartDate;
  DateTime? premiumExpireDate;
  bool isPremiumUser;
  int premiumCompletedDays;

  LockInData({
    required this.startDate,
    required this.config,
    List<DayLog>? days,
    this.premiumStartDate,
    this.premiumExpireDate,
    this.isPremiumUser = false,
    this.premiumCompletedDays = 0,
  }) : days = days ?? [];

  int get currentDayNumber => calculateLockInDay();

  int calculateLockInDay() {
    final today = DateTime.now();
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(startDate.year, startDate.month, startDate.day))
        .inDays;
    return diff + 1;
  }

  DateTime calculatePremiumStartDate(DateTime purchaseTime) {
    final endOfDay = DateTime(purchaseTime.year, purchaseTime.month, purchaseTime.day, 23, 59, 59);
    final remainingHours = endOfDay.difference(purchaseTime).inMinutes / 60.0;
    if (remainingHours < 3) {
      return DateTime(purchaseTime.year, purchaseTime.month, purchaseTime.day).add(const Duration(days: 1));
    } else {
      return DateTime(purchaseTime.year, purchaseTime.month, purchaseTime.day);
    }
  }

  int calculatePremiumDay() {
    if (premiumStartDate == null) return 0;
    final today = DateTime.now();
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(premiumStartDate!.year, premiumStartDate!.month, premiumStartDate!.day))
        .inDays;
    return diff + 1;
  }

  int calculateCompletedPremiumDays() {
    if (premiumStartDate == null) return 0;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    int completed = 0;
    for (var d in days) {
      final dDate = DateTime(d.date.year, d.date.month, d.date.day);
      if (dDate.isBefore(today) && (dDate.isAfter(premiumStartDate!) || dDate.isAtSameMomentAs(premiumStartDate!))) {
        final tasks = tasksForDay(d.dayNumber);
        if (d.completionRate(tasks.length) >= 1.0) {
          completed++;
        }
      }
    }
    return completed;
  }

  double calculatePercentage(int completed, int totalPast) {
    if (totalPast <= 0) return 0.0;
    return completed / totalPast;
  }

  String getAuraLevel() {
    final lockInDay = calculateLockInDay();
    if (lockInDay >= 60) return "Legendary Aura 🟣";
    if (lockInDay >= 30) return "Diamond Aura 🔵";
    if (lockInDay >= 7) return "Gold Aura 🟡";
    return "Green Aura 🟢";
  }

  Color getAuraColor() {
    final lockInDay = calculateLockInDay();
    if (lockInDay >= 60) return const Color(0xFF9C27B0); // Purple
    if (lockInDay >= 30) return Colors.blue;           // Blue
    if (lockInDay >= 7) return const Color(0xFFFFD700);  // Gold
    return const Color(0xFF4CAF50);                      // Green
  }

  DateTime dateForDay(int dayNum) =>
      startDate.add(Duration(days: dayNum - 1));

  List<String> tasksForDay(int dayNum) {
    final d = dateForDay(dayNum);
    final idx = (d.weekday - 1) % 7;
    return config.weekdayTasks[idx];
  }

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    'config': config.toJson(),
    'days': days.map((d) => d.toJson()).toList(),
    'premiumStartDate': premiumStartDate?.toIso8601String(),
    'premiumExpireDate': premiumExpireDate?.toIso8601String(),
    'isPremiumUser': isPremiumUser,
    'premiumCompletedDays': premiumCompletedDays,
  };

  factory LockInData.fromJson(Map<String, dynamic> j) => LockInData(
    startDate: DateTime.parse(j['startDate']),
    config: WeeklyConfig.fromJson(j['config']),
    days: (j['days'] as List).map((d) => DayLog.fromJson(d)).toList(),
    premiumStartDate: j['premiumStartDate'] != null ? DateTime.parse(j['premiumStartDate']) : null,
    premiumExpireDate: j['premiumExpireDate'] != null ? DateTime.parse(j['premiumExpireDate']) : null,
    isPremiumUser: j['isPremiumUser'] ?? false,
    premiumCompletedDays: j['premiumCompletedDays'] ?? 0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STORAGE — Firestore (cloud) with local SharedPreferences fallback
// ─────────────────────────────────────────────────────────────────────────────

const _kKey = 'lock_in_data_v2';

String? get _uid => FirebaseAuth.instance.currentUser?.uid;

DocumentReference? get _doc => _uid == null
    ? null
    : FirebaseFirestore.instance.collection('users').doc(_uid).collection('data').doc('lock_in');

Future<LockInData?> _load() async {
  // Try Firestore first
  try {
    if (_doc != null) {
      final snap = await _doc!.get();
      if (snap.exists) {
        final raw = (snap.data() as Map<String, dynamic>)['lock_in_data'];
        if (raw != null) {
          return LockInData.fromJson(jsonDecode(raw));
        }
      }
    }
  } catch (_) {}

  // Fallback to local
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return null;
    final data = LockInData.fromJson(jsonDecode(raw));
    // Migrate local data up to Firestore
    await _save(data);
    return data;
  } catch (_) { return null; }
}

Future<void> _save(LockInData data) async {
  final encoded = jsonEncode(data.toJson());

  // Save to Firestore (cloud)
  try {
    if (_doc != null) {
      await _doc!.set({
        'lock_in_data': encoded,
        'updatedAt': FieldValue.serverTimestamp(),
        'startDate': data.startDate.toIso8601String(),
        'totalDays': data.days.length,
      }, SetOptions(merge: true));
    }
  } catch (_) {}

  // Also save locally as backup
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, encoded);
  } catch (_) {}
}

Future<void> _deleteSaved() async {
  try {
    if (_doc != null) await _doc!.delete();
  } catch (_) {}
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  } catch (_) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN PAGE
// ─────────────────────────────────────────────────────────────────────────────

class LockInPage extends StatefulWidget {
  const LockInPage({super.key});
  @override
  State<LockInPage> createState() => _LockInPageState();
}

class _LockInPageState extends State<LockInPage> {
  LockInData? _data;
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final d = await _load();
    setState(() { _data = d; _loading = false; });
  }

  void _onStart(WeeklyConfig config) async {
    final data = LockInData(startDate: DateTime.now(), config: config);
    setState(() => _data = data);
    await _save(data);
  }

  void _onSave() async {
    if (_data != null) { await _save(_data!); setState(() {}); }
  }

  void _onReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Reset Lock In?', style: TextStyle(color: Colors.white)),
        content: const Text('All progress will be deleted.', style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) {
      await _deleteSaved();
      setState(() => _data = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    }
    if (_data == null) return _SetupScreen(onStart: _onStart);
    return _Dashboard(data: _data!, onSave: _onSave, onReset: _onReset);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETUP SCREEN — swipeable Mon→Sun pages
// ─────────────────────────────────────────────────────────────────────────────

class _SetupScreen extends StatefulWidget {
  final void Function(WeeklyConfig) onStart;
  const _SetupScreen({required this.onStart});
  @override
  State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0; // 0 = mandatory config, 1-7 = Mon-Sun

  final _mandatory = MandatoryConfig();
  // 7 days of task lists
  final List<List<String>> _weekTasks = List.generate(7, (_) => []);
  final List<TextEditingController> _taskCtrls =
      List.generate(7, (_) => TextEditingController());

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _taskCtrls) c.dispose();
    super.dispose();
  }

  void _addTask(int dayIdx) {
    final text = _taskCtrls[dayIdx].text.trim();
    if (text.isEmpty) return;
    if (text.length > 20) { _snack('Max 20 characters per task'); return; }
    if (_weekTasks[dayIdx].length >= 17) { _snack('Max 17 custom tasks per day'); return; }
    HapticFeedback.lightImpact();
    setState(() => _weekTasks[dayIdx].add(text));
    _taskCtrls[dayIdx].clear();
  }

  void _removeTask(int dayIdx, int taskIdx) {
    setState(() => _weekTasks[dayIdx].removeAt(taskIdx));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), backgroundColor: const Color(0xFF222200)));
  }

  void _start() {
    // Check each day has at least 2 custom tasks
    List<String> missing = [];
    for (int i = 0; i < 7; i++) {
      if (_weekTasks[i].length < 2) {
        missing.add(_weekDayNames[i]);
      }
    }
    if (missing.isNotEmpty) {
      _snack('Add at least 2 tasks for: ${missing.join(', ')}');
      return;
    }
    widget.onStart(WeeklyConfig(mandatory: _mandatory, weekdayTasks: _weekTasks));
  }

  void _goToPage(int page) {
    _pageCtrl.animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  // ── Mandatory config page (page 0) ─────────────────────────────────────────
  Widget _buildMandatoryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A1A00), Color(0xFF1A1A1A)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
            ),
            child: const Column(children: [
              Text('🔒', style: TextStyle(fontSize: 32)),
              SizedBox(height: 6),
              Text('Set Mandatory Tasks', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('These apply every day. Swipe right to set custom tasks per day.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 20),

          _mandatoryCard(icon: '👟', label: 'Steps', unit: 'steps',
              min: MandatoryConfig.stepsMin, max: MandatoryConfig.stepsMax, target: _mandatory.stepsTarget,
              onChanged: (mn, mx, t) => setState(() {
                _mandatory.stepsTarget = t.clamp(MandatoryConfig.stepsMin, MandatoryConfig.stepsMax);
              })),

          _mandatoryCard(icon: '🥩', label: 'Diet — Protein', unit: 'g',
              min: MandatoryConfig.proteinMin, max: MandatoryConfig.proteinMax, target: _mandatory.proteinTarget,
              onChanged: (mn, mx, t) => setState(() {
                _mandatory.proteinTarget = t.clamp(MandatoryConfig.proteinMin, MandatoryConfig.proteinMax);
              })),

          _sleepCard(),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _goToPage(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Next → Set Daily Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Per-day task page (pages 1-7 = Mon-Sun) ────────────────────────────────
  Widget _buildDayPage(int dayIdx) {
    final tasks = _weekTasks[dayIdx];
    final ctrl = _taskCtrls[dayIdx];
    final dayName = _weekDayNames[dayIdx];
    final isLast = dayIdx == 6;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25)),
            ),
            child: Row(children: [
              const Text('📅', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${tasks.length} custom task${tasks.length == 1 ? '' : 's'} set',
                    style: TextStyle(color: tasks.isEmpty ? Colors.white38 : const Color(0xFF8BC34A), fontSize: 12)),
              ]),
              const Spacer(),
              // Mandatory reminder chips
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _miniChip('👟 Steps'),
                const SizedBox(height: 4),
                _miniChip('🥩 Protein'),
                const SizedBox(height: 4),
                _miniChip('😴 Sleep'),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          const Text('➕ Custom Tasks for this day',
              style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Max 20 chars each. Optional — you can leave days empty.',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 12),

          // Task input
          Row(children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                maxLength: 20,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. No junk food',
                  hintStyle: const TextStyle(color: Colors.white38),
                  counterText: '',
                  filled: true, fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5)),
                ),
                onSubmitted: (_) => _addTask(dayIdx),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _addTask(dayIdx),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add, color: Colors.black),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Task list
          ...tasks.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(children: [
              const Icon(Icons.drag_handle, color: Colors.white24, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 14))),
              GestureDetector(
                onTap: () => _removeTask(dayIdx, e.key),
                child: const Icon(Icons.close, color: Colors.redAccent, size: 18),
              ),
            ]),
          )),

          const SizedBox(height: 24),

          // Navigation buttons
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _goToPage(dayIdx), // dayIdx = page - 1, so page before is dayIdx
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('← Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: isLast ? _start : () => _goToPage(dayIdx + 2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLast ? const Color(0xFF39FF14) : const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(isLast ? '🔒 Start Lock In!' : 'Next: ${_weekDayNames[dayIdx + 1]} →',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _miniChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFFFD700).withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25)),
    ),
    child: Text(label, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10)),
  );

  // ── Mandatory card ──────────────────────────────────────────────────────────
  Widget _mandatoryCard({
    required String icon, required String label, required String unit,
    required int min, required int max, required int target,
    required void Function(int, int, int) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.35)),
            ),
            child: Text('Target: $target $unit', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _rangeBtn(label: 'Min', value: min),
          const SizedBox(width: 8),
          Expanded(child: Column(children: [
            GestureDetector(
              onTap: () async {
                final ctrl = TextEditingController(text: target.toString());
                final result = await showDialog<int>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1A),
                    title: const Text('Set Target', style: TextStyle(color: Colors.white)),
                    content: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                      TextButton(onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
                          child: const Text('Set', style: TextStyle(color: Color(0xFFFFD700)))),
                    ],
                  ),
                );
                if (result != null) onChanged(min, max, result.clamp(min, max));
              },
              child: Text('$target', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Slider(
              min: min.toDouble(), max: max.toDouble(),
              value: target.clamp(min, max).toDouble(),
              activeColor: const Color(0xFFFFD700), inactiveColor: Colors.white12,
              onChanged: (v) => onChanged(min, max, v.round()),
            ),
          ])),
          const SizedBox(width: 8),
          _rangeBtn(label: 'Max', value: max),
        ]),
      ]),
    );
  }

  Widget _sleepCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('😴', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          const Text('Sleep', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.35)),
            ),
            child: Text('Target: ${_mandatory.sleepTarget.toStringAsFixed(1)} hr',
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _rangeBtn(label: 'Min', value: MandatoryConfig.sleepMin),
          const SizedBox(width: 8),
          Expanded(child: Column(children: [
            GestureDetector(
              onTap: () async {
                final ctrl = TextEditingController(text: _mandatory.sleepTarget.toStringAsFixed(1));
                final result = await showDialog<double>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1A),
                    title: const Text('Set Sleep Target', style: TextStyle(color: Colors.white)),
                    content: TextField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '7.0 – 11.0',
                        hintStyle: TextStyle(color: Colors.white38),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7B68EE))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7B68EE))),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                      TextButton(onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text)),
                          child: const Text('Set', style: TextStyle(color: Color(0xFF7B68EE)))),
                    ],
                  ),
                );
                if (result != null) {
                  setState(() => _mandatory.sleepTarget =
                      result.clamp(MandatoryConfig.sleepMin.toDouble(), MandatoryConfig.sleepMax.toDouble()));
                }
              },
              child: Text('${_mandatory.sleepTarget.toStringAsFixed(1)} hr',
                  style: const TextStyle(color: Color(0xFF7B68EE), fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Slider(
              min: MandatoryConfig.sleepMin.toDouble(),
              max: MandatoryConfig.sleepMax.toDouble(),
              divisions: (MandatoryConfig.sleepMax - MandatoryConfig.sleepMin) * 2,
              value: _mandatory.sleepTarget.clamp(
                  MandatoryConfig.sleepMin.toDouble(), MandatoryConfig.sleepMax.toDouble()),
              activeColor: const Color(0xFF7B68EE), inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _mandatory.sleepTarget = (v * 2).round() / 2),
            ),
          ])),
          const SizedBox(width: 8),
          _rangeBtn(label: 'Max', value: MandatoryConfig.sleepMax),
        ]),
      ]),
    );
  }

  // Display-only range label — no tap, no keyboard
  Widget _rangeBtn({required String label, required int value}) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 4),
      Container(
        width: 58, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Text('$value', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Pages: 0 = mandatory, 1-7 = Mon-Sun
    final pageCount = 8;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          _currentPage == 0 ? 'Mandatory Tasks' : _weekDayNames[_currentPage - 1],
          style: const TextStyle(color: Color(0xFFFFD700)),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (i) => GestureDetector(
                onTap: () => _goToPage(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == i ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? const Color(0xFFFFD700) : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )),
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        onPageChanged: (i) => setState(() => _currentPage = i),
        children: [
          _buildMandatoryPage(),
          ...List.generate(7, (i) => _buildDayPage(i)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

class _Dashboard extends StatefulWidget {
  final LockInData data;
  final VoidCallback onSave, onReset;
  const _Dashboard({required this.data, required this.onSave, required this.onReset});
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _glowAnim = Tween<double>(begin: 0.2, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _glowCtrl.repeat(reverse: true);
  }

  @override
  void dispose() { 
    _fadeCtrl.dispose(); 
    _glowCtrl.dispose();
    super.dispose(); 
  }

  LockInData get data => widget.data;
  VoidCallback get onSave => widget.onSave;
  VoidCallback get onReset => widget.onReset;

  String _dayLabel(int dayNum) {
    final d = data.dateForDay(dayNum);
    final short = _weekDayShort[d.weekday - 1];
    return '$short  ${d.day}/${d.month}/${d.year}';
  }

  Color _progressColor(double r) {
    if (r >= 1.0) return const Color(0xFF39FF14);
    if (r >= 0.75) return const Color(0xFF8BC34A);
    if (r >= 0.5) return const Color(0xFFFFD700);
    if (r >= 0.25) return Colors.orange;
    return const Color(0xFF9E9E9E);
  }

  DayLog? _logForDay(int dayNum) {
    try { return data.days.firstWhere((d) => d.dayNumber == dayNum); }
    catch (_) { return null; }
  }

  Widget _buildPremiumCard(BuildContext context) {
    final pDay = data.calculatePremiumDay();
    final totalPast = pDay > 0 ? pDay - 1 : 0;
    final completed = data.calculateCompletedPremiumDays();
    final pct = data.calculatePercentage(completed, totalPast);
    final auraColor = data.getAuraColor();

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: auraColor.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: auraColor.withOpacity(0.4 * _glowAnim.value),
                blurRadius: 20 * _glowAnim.value,
                spreadRadius: 2 * _glowAnim.value,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Premium Discipline Streak 👑', style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Day $pDay', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('$completed / $totalPast days completed', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
                  const Spacer(),
                  Text('${(pct * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              _AnimatedProgressBar(
                value: pct,
                color: const Color(0xFFFFD700),
                height: 6,
              ),
            ]
          ),
        );
      }
    );
  }

  Widget _buildPremiumExpiredCard(BuildContext context) {
    final pDay = data.calculatePremiumDay();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Premium expired', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Day $pDay since Premium', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // --- TESTING OVERRIDE: FORCE PREMIUM ---
    data.isPremiumUser = true;
    data.premiumStartDate ??= DateTime.now().subtract(const Duration(days: 3));
    // ---------------------------------------

    final currentDay = data.currentDayNumber;
    final totalVisible = currentDay + 1;

    final completedDays = data.days
        .where((d) => d.dayNumber < currentDay &&
            d.completionRate(data.tasksForDay(d.dayNumber).length) >= 1.0)
        .length;
    final totalPast = currentDay - 1;
    final overallRate = totalPast > 0 ? completedDays / totalPast : 0.0;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Lock In', style: TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
      ),
      body: Column(children: [
        // Stats banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A1A00), Color(0xFF1A1A1A)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Day $currentDay', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 26, fontWeight: FontWeight.bold)),
              const Text('of your Lock In', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${(overallRate * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text('$completedDays/$totalPast days completed',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
          ]),
        ),

        // Premium Discipline Streak Card
        if (data.isPremiumUser) 
          _buildPremiumCard(context)
        else if (data.premiumStartDate != null) 
          _buildPremiumExpiredCard(context),

        // "Set Weekly Tasks" button above day list
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                _slideRoute(_EditTasksScreen(
                  config: data.config,
                  onSave: (newConfig) {
                    data.config = newConfig;
                    onSave();
                  },
                )),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25)),
              ),
              child: const Row(children: [
                Text('📋', style: TextStyle(fontSize: 18)),
                SizedBox(width: 10),
                Text('Set Weekly Tasks', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w600, fontSize: 14)),
                Spacer(),
                Icon(Icons.chevron_right, color: Colors.white38, size: 20),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Day list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: totalVisible,
            itemBuilder: (context, i) {
              final dayNum = i + 1;
              final isToday = dayNum == currentDay;
              final isLocked = dayNum > currentDay;
              final log = _logForDay(dayNum);
              final customTasks = data.tasksForDay(dayNum);
              final rate = log?.completionRate(customTasks.length) ?? 0.0;

              return GestureDetector(
                onTap: isLocked
                    ? () { HapticFeedback.lightImpact(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('🔒 Day $dayNum unlocks on ${_dayLabel(dayNum).split('  ').last}'),
                          backgroundColor: const Color(0xFF1A1A1A),
                        ));}
                    : () async {
                        HapticFeedback.selectionClick();
                        await Navigator.push(
                          context,
                          _slideRoute(_DayScreen(
                            dayNumber: dayNum,
                            dayLabel: _dayLabel(dayNum),
                            config: data.config.mandatory,
                            customTasks: customTasks,
                            lockInData: data,
                            log: log ?? DayLog(
                              dayNumber: dayNum,
                              date: data.dateForDay(dayNum),
                              customCompleted: List.filled(customTasks.length, false),
                            ),
                            isToday: isToday,
                            onSave: (updated) {
                              final idx = data.days.indexWhere((d) => d.dayNumber == dayNum);
                              if (idx >= 0) data.days[idx] = updated;
                              else data.days.add(updated);
                              onSave();
                            },
                          )));
                      },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isToday ? const Color(0xFF1A1500) : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isToday
                          ? const Color(0xFFFFD700).withOpacity(0.5)
                          : (isLocked ? Colors.white.withOpacity(0.05) : Colors.white12),
                    ),
                  ),
                  child: Row(children: [
                    // Circle
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLocked
                            ? Colors.white.withOpacity(0.05)
                            : (isToday
                                ? const Color(0xFFFFD700).withOpacity(0.18)
                                : _progressColor(rate).withOpacity(0.13)),
                        border: Border.all(
                          color: isLocked
                              ? Colors.white12
                              : (isToday ? const Color(0xFFFFD700) : _progressColor(rate)),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: isLocked
                            ? const Icon(Icons.lock, color: Colors.white24, size: 18)
                            : Text('$dayNum', style: TextStyle(
                                color: isToday ? const Color(0xFFFFD700) : _progressColor(rate),
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('Day $dayNum', style: TextStyle(
                            color: isLocked ? Colors.white24 : Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 14)),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('TODAY', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        if (log != null && log.completionRate(customTasks.length) >= 1.0) ...[
                          const SizedBox(width: 6),
                          const Text('✅', style: TextStyle(fontSize: 13)),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Text(_dayLabel(dayNum), style: TextStyle(color: isLocked ? Colors.white12 : Colors.white38, fontSize: 12)),
                      if (!isLocked) ...[
                        const SizedBox(height: 8),
                        _AnimatedProgressBar(
                          value: rate,
                          color: _progressColor(rate),
                          height: 5,
                          duration: const Duration(milliseconds: 700),
                        ),
                        const SizedBox(height: 3),
                        Text('${(rate * 100).round()}% complete',
                            style: TextStyle(color: _progressColor(rate), fontSize: 11)),
                      ],
                    ])),
                    if (!isLocked) const Icon(Icons.chevron_right, color: Colors.white24),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAY TASK SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _DayScreen extends StatefulWidget {
  final int dayNumber;
  final String dayLabel;
  final MandatoryConfig config;
  final List<String> customTasks;
  final LockInData lockInData;
  final DayLog log;
  final bool isToday;
  final void Function(DayLog) onSave;

  const _DayScreen({
    required this.dayNumber, required this.dayLabel, required this.config,
    required this.customTasks, required this.lockInData, required this.log, required this.isToday,
    required this.onSave,
  });

  @override
  State<_DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<_DayScreen> {
  late DayLog _log;

  @override
  void initState() {
    super.initState();
    _log = DayLog(
      dayNumber: widget.log.dayNumber, date: widget.log.date,
      stepsCompleted: widget.log.stepsCompleted,
      proteinCompleted: widget.log.proteinCompleted,
      sleepCompleted: widget.log.sleepCompleted,
      customCompleted: List<bool>.from(widget.log.customCompleted),
    );
    while (_log.customCompleted.length < widget.customTasks.length) {
      _log.customCompleted.add(false);
    }
  }

  double get _rate => _log.completionRate(widget.customTasks.length);

  Color _pColor(double r) {
    if (r >= 1.0) return const Color(0xFF39FF14);
    if (r >= 0.75) return const Color(0xFF8BC34A);
    if (r >= 0.5) return const Color(0xFFFFD700);
    if (r >= 0.25) return Colors.orange;
    return const Color(0xFF9E9E9E);
  }

  void _doSave() async {
    HapticFeedback.mediumImpact();
    widget.onSave(_log);

    // ── Giveaway Eligibility Check ──
    final pDay = widget.lockInData.calculatePremiumDay();
    final completedP = widget.lockInData.calculateCompletedPremiumDays();
    final totalPastP = pDay > 0 ? pDay - 1 : 0;
    final pRate = widget.lockInData.calculatePercentage(completedP, totalPastP);

    // Only run this check if they just saved Premium Day 150 (or later) and completed it.
    if (pDay >= 150 && pRate >= 0.8) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final email = FirebaseAuth.instance.currentUser?.email;

      if (uid != null) {
        // We write to the giveaway_entries collection right here.
        try {
          // Add a document (or set it so they only enter once)
          await FirebaseFirestore.instance
              .collection('giveaway_entries')
              .doc(uid)
              .set({
            'uid': uid,
            'email': email ?? 'No Email',
            'timestamp': FieldValue.serverTimestamp(),
            'completionRate': pRate,
            'premiumDaysCompleted': pDay,
            'isPremium': true,
          }, SetOptions(merge: true));

          // In-App Notification using a beautiful popup
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFFFD700), width: 2)),
                title: const Row(
                  children: [
                    Text('🎉 ', style: TextStyle(fontSize: 24)),
                    Expanded(
                      child: Text('Giveaway Entry!',
                          style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                content: Text(
                  'Congratulations! You have completed $pDay days of your Premium Discipline Streak with an excellent success rate.\n\nYou have officially been entered into the giveaway.\n\nWe will contact you at ${email ?? "your registered email"} if you win!',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context); // close the day screen
                    },
                    child: const Text('Awesome!',
                        style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
            return; // Stop early so we don't double pop the Navigator
          }
        } catch (e) {
          debugPrint('Error entering giveaway: $e');
        }
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _taskTile({
    required String icon, required String label, required String subtitle,
    required bool done, required void Function(bool) onToggle,
    bool readOnly = false,
  }) {
    return GestureDetector(
      onTap: readOnly ? null : () { HapticFeedback.selectionClick(); onToggle(!done); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: done ? const Color(0xFF8BC34A).withOpacity(0.07) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: done ? const Color(0xFF8BC34A).withOpacity(0.45) : Colors.white12),
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: Colors.white38)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: done ? const Color(0xFF8BC34A) : Colors.white54, fontSize: 12)),
          ])),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? (readOnly ? Colors.white24 : const Color(0xFF8BC34A))
                  : Colors.transparent,
              border: Border.all(
                  color: done
                      ? (readOnly ? Colors.white24 : const Color(0xFF8BC34A))
                      : Colors.white12,
                  width: 2),
            ),
            child: done ? Icon(Icons.check,
                color: readOnly ? Colors.white54 : Colors.white, size: 16) : null,
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final total = 3 + widget.customTasks.length;
    final done = (_log.stepsCompleted ? 1 : 0) + (_log.proteinCompleted ? 1 : 0) +
        (_log.sleepCompleted ? 1 : 0) + _log.customCompleted.where((c) => c).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Text('Day ${widget.dayNumber}', style: const TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        actions: [
          TextButton(onPressed: _doSave,
              child: const Text('Save', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold))),
        ],
      ),
      body: Column(children: [
        // Progress card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _pColor(_rate).withOpacity(0.35)),
          ),
          child: Column(children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.dayLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_rate >= 1.0 ? '🔥 Day Complete!' : '$done / $total tasks done',
                    style: TextStyle(color: _pColor(_rate), fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const Spacer(),
              _AnimatedScoreCircle(value: _rate, color: _pColor(_rate), size: 56),
            ]),
            const SizedBox(height: 10),
            _AnimatedProgressBar(value: _rate, color: _pColor(_rate), height: 8),
          ]),
        ),

        if (!widget.isToday)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.lock_outline, color: Colors.orange, size: 15),
                SizedBox(width: 8),
                Text('Past day — view only, no changes allowed',
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
              ]),
            ),
          ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const Text('📋 Mandatory', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _taskTile(icon: '👟', label: 'Steps',
                  subtitle: 'Target: ${cfg.stepsTarget} steps',
                  done: _log.stepsCompleted, readOnly: !widget.isToday,
                  onToggle: (v) => setState(() => _log.stepsCompleted = v)),
              _taskTile(icon: '🥩', label: 'Protein',
                  subtitle: 'Target: ${cfg.proteinTarget}g',
                  done: _log.proteinCompleted, readOnly: !widget.isToday,
                  onToggle: (v) => setState(() => _log.proteinCompleted = v)),
              _taskTile(icon: '😴', label: 'Sleep',
                  subtitle: 'Target: ${cfg.sleepTarget.toStringAsFixed(1)} hours',
                  done: _log.sleepCompleted, readOnly: !widget.isToday,
                  onToggle: (v) => setState(() => _log.sleepCompleted = v)),

              if (widget.customTasks.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('⚡ Today\'s Tasks', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ...widget.customTasks.asMap().entries.map((e) {
                  final i = e.key;
                  final isDone = i < _log.customCompleted.length ? _log.customCompleted[i] : false;
                  return _taskTile(
                    icon: '⚡', label: e.value,
                    subtitle: isDone ? 'Completed ✓' : (widget.isToday ? 'Tap to mark done' : '—'),
                    done: isDone,
                    readOnly: !widget.isToday,
                    onToggle: (v) => setState(() {
                      while (_log.customCompleted.length <= i) _log.customCompleted.add(false);
                      _log.customCompleted[i] = v;
                    }),
                  );
                }),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text('No custom tasks set for today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white24, fontSize: 13)),
                ),
              ],

              const SizedBox(height: 20),
              if (widget.isToday)
                ElevatedButton(
                  onPressed: _doSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rate >= 1.0 ? const Color(0xFF39FF14) : const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(_rate >= 1.0 ? '🔥 Day Complete — Save!' : 'Save Progress',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                )
              else
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 16)),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT TASKS SCREEN — edit weekly tasks WITHOUT resetting progress
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Route<T> _slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

class _EditTasksScreen extends StatefulWidget {
  final WeeklyConfig config;
  final void Function(WeeklyConfig) onSave;
  const _EditTasksScreen({required this.config, required this.onSave});

  @override
  State<_EditTasksScreen> createState() => _EditTasksScreenState();
}

class _EditTasksScreenState extends State<_EditTasksScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  late MandatoryConfig _mandatory;
  late List<List<String>> _weekTasks;
  final List<TextEditingController> _taskCtrls =
      List.generate(7, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _mandatory = widget.config.mandatory.copy();
    _weekTasks = widget.config.weekdayTasks
        .map((list) => List<String>.from(list))
        .toList();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _taskCtrls) c.dispose();
    super.dispose();
  }

  void _addTask(int dayIdx) {
    final text = _taskCtrls[dayIdx].text.trim();
    if (text.isEmpty) return;
    if (text.length > 20) { _snack('Max 20 characters per task'); return; }
    if (_weekTasks[dayIdx].length >= 17) { _snack('Max 17 custom tasks per day'); return; }
    HapticFeedback.lightImpact();
    setState(() => _weekTasks[dayIdx].add(text));
    _taskCtrls[dayIdx].clear();
  }

  void _removeTask(int dayIdx, int taskIdx) =>
      setState(() => _weekTasks[dayIdx].removeAt(taskIdx));

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), backgroundColor: const Color(0xFF222200)));

  void _save() {
    List<String> missing = [];
    for (int i = 0; i < 7; i++) {
      if (_weekTasks[i].length < 2) missing.add(_weekDayNames[i]);
    }
    if (missing.isNotEmpty) {
      _snack('Add at least 2 tasks for: ${missing.join(', ')}');
      return;
    }
    widget.onSave(WeeklyConfig(mandatory: _mandatory, weekdayTasks: _weekTasks));
    Navigator.pop(context);
  }

  void _goToPage(int page) => _pageCtrl.animateToPage(page,
      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

  Widget _rangeDisplay({required String label, required int value}) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 4),
      Container(
        width: 58, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Text('$value', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ]);
  }

  Widget _buildMandatoryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A1A00), Color(0xFF1A1A1A)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
          ),
          child: const Column(children: [
            Text('✏️', style: TextStyle(fontSize: 28)),
            SizedBox(height: 6),
            Text('Edit Mandatory Tasks', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Your progress is safe. Only tasks are updated.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 20),

        // Steps card
        _buildTargetCard(
          icon: '👟', label: 'Steps', unit: 'steps',
          fixedMin: MandatoryConfig.stepsMin, fixedMax: MandatoryConfig.stepsMax,
          target: _mandatory.stepsTarget,
          color: const Color(0xFFFFD700),
          onTargetChanged: (v) => setState(() => _mandatory.stepsTarget = v),
        ),

        // Protein card
        _buildTargetCard(
          icon: '🥩', label: 'Diet — Protein', unit: 'g',
          fixedMin: MandatoryConfig.proteinMin, fixedMax: MandatoryConfig.proteinMax,
          target: _mandatory.proteinTarget,
          color: const Color(0xFFFFD700),
          onTargetChanged: (v) => setState(() => _mandatory.proteinTarget = v),
        ),

        // Sleep card
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(children: [
            Row(children: [
              const Text('😴', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Text('Sleep', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B68EE).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF7B68EE).withOpacity(0.35)),
                ),
                child: Text('Target: ${_mandatory.sleepTarget.toStringAsFixed(1)} hr',
                    style: const TextStyle(color: Color(0xFF7B68EE), fontSize: 11)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _rangeDisplay(label: 'Min', value: MandatoryConfig.sleepMin),
              const SizedBox(width: 8),
              Expanded(child: Column(children: [
                GestureDetector(
                  onTap: () async {
                    final ctrl = TextEditingController(text: _mandatory.sleepTarget.toStringAsFixed(1));
                    final result = await showDialog<double>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A1A),
                        title: const Text('Set Sleep Target', style: TextStyle(color: Colors.white)),
                        content: TextField(
                          controller: ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: '7.0 – 11.0',
                            hintStyle: TextStyle(color: Colors.white38),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7B68EE))),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7B68EE))),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                          TextButton(onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text)),
                              child: const Text('Set', style: TextStyle(color: Color(0xFF7B68EE)))),
                        ],
                      ),
                    );
                    if (result != null) {
                      setState(() => _mandatory.sleepTarget =
                          result.clamp(MandatoryConfig.sleepMin.toDouble(), MandatoryConfig.sleepMax.toDouble()));
                    }
                  },
                  child: Text('${_mandatory.sleepTarget.toStringAsFixed(1)} hr',
                      style: const TextStyle(color: Color(0xFF7B68EE), fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Slider(
                  min: MandatoryConfig.sleepMin.toDouble(),
                  max: MandatoryConfig.sleepMax.toDouble(),
                  divisions: (MandatoryConfig.sleepMax - MandatoryConfig.sleepMin) * 2,
                  value: _mandatory.sleepTarget.clamp(
                      MandatoryConfig.sleepMin.toDouble(), MandatoryConfig.sleepMax.toDouble()),
                  activeColor: const Color(0xFF7B68EE), inactiveColor: Colors.white12,
                  onChanged: (v) => setState(() => _mandatory.sleepTarget = (v * 2).round() / 2),
                ),
              ])),
              const SizedBox(width: 8),
              _rangeDisplay(label: 'Max', value: MandatoryConfig.sleepMax),
            ]),
          ]),
        ),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _goToPage(1),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Next → Edit Daily Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _buildTargetCard({
    required String icon, required String label, required String unit,
    required int fixedMin, required int fixedMax, required int target,
    required Color color, required void Function(int) onTargetChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Text('Target: $target $unit', style: TextStyle(color: color, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _rangeDisplay(label: 'Min', value: fixedMin),
          const SizedBox(width: 8),
          Expanded(child: Column(children: [
            GestureDetector(
              onTap: () async {
                final ctrl = TextEditingController(text: target.toString());
                final result = await showDialog<int>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1A),
                    title: const Text('Set Target', style: TextStyle(color: Colors.white)),
                    content: TextField(
                      controller: ctrl, autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '$fixedMin – $fixedMax',
                        hintStyle: const TextStyle(color: Colors.white38),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                      TextButton(onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
                          child: Text('Set', style: TextStyle(color: color))),
                    ],
                  ),
                );
                if (result != null) onTargetChanged(result.clamp(fixedMin, fixedMax));
              },
              child: Text('$target', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Slider(
              min: fixedMin.toDouble(), max: fixedMax.toDouble(),
              value: target.clamp(fixedMin, fixedMax).toDouble(),
              activeColor: color, inactiveColor: Colors.white12,
              onChanged: (v) => onTargetChanged(v.round()),
            ),
          ])),
          const SizedBox(width: 8),
          _rangeDisplay(label: 'Max', value: fixedMax),
        ]),
      ]),
    );
  }

  Widget _buildDayPage(int dayIdx) {
    final tasks = _weekTasks[dayIdx];
    final ctrl = _taskCtrls[dayIdx];
    final isLast = dayIdx == 6;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25)),
          ),
          child: Row(children: [
            const Text('📅', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_weekDayNames[dayIdx], style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              Text('${tasks.length} task${tasks.length == 1 ? '' : 's'} • min 2 required',
                  style: TextStyle(color: tasks.length >= 2 ? const Color(0xFF8BC34A) : Colors.orange, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        const Text('➕ Custom Tasks',
            style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),

        Row(children: [
          Expanded(
            child: TextField(
              controller: ctrl, maxLength: 20,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. No junk food',
                hintStyle: const TextStyle(color: Colors.white38),
                counterText: '',
                filled: true, fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5)),
              ),
              onSubmitted: (_) => _addTask(dayIdx),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _addTask(dayIdx),
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add, color: Colors.black),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        ...tasks.asMap().entries.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(children: [
            const Icon(Icons.drag_handle, color: Colors.white24, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 14))),
            GestureDetector(
              onTap: () => _removeTask(dayIdx, e.key),
              child: const Icon(Icons.close, color: Colors.redAccent, size: 18),
            ),
          ]),
        )),

        const SizedBox(height: 24),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _goToPage(dayIdx),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54, side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('← Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLast ? _save : () => _goToPage(dayIdx + 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? const Color(0xFF39FF14) : const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(isLast ? '✅ Save Changes' : 'Next: ${_weekDayNames[dayIdx + 1]} →',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          _currentPage == 0 ? 'Mandatory Tasks' : _weekDayNames[_currentPage - 1],
          style: const TextStyle(color: Color(0xFFFFD700)),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(8, (i) => GestureDetector(
                onTap: () => _goToPage(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == i ? 20 : 7, height: 7,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? const Color(0xFFFFD700) : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )),
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        onPageChanged: (i) => setState(() => _currentPage = i),
        children: [
          _buildMandatoryPage(),
          ...List.generate(7, (i) => _buildDayPage(i)),
        ],
      ),
    );
  }
}