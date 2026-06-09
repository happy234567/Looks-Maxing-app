import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import 'profile_screen.dart';
import 'food_scan_service.dart';
import 'nutrition_db_helper.dart';
import 'billing_service.dart';
import 'ad_service.dart';
import 'scan_tutorial_screen.dart';

class DietPlan {
  final int calories, protein, carbs, fats, fiber;
  final String summary;
  DietPlan({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fiber,
    required this.summary,
  });
  Map<String, dynamic> toMap() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fats': fats,
    'fiber': fiber,
    'summary': summary,
  };
}

class DietCalculator {
  static DietPlan calculate({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
    required String activityLevel,
    required String workoutsPerWeek,
    required String workoutIntensity,
    required String dailySteps,
    required String goal,
    required String metabolism,
  }) {
    double bmrM = 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    double bmrF = 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    double bmr = gender.toLowerCase() == 'male'
        ? bmrM
        : gender.toLowerCase() == 'female'
        ? bmrF
        : (bmrM + bmrF) / 2;
    const am = {
      'sedentary': 1.2,
      'lightly_active': 1.375,
      'moderately_active': 1.55,
      'very_active': 1.725,
      'athlete': 1.9,
    };
    double tdee = bmr * (am[activityLevel] ?? 1.2);
    const sb = {'<2k': 0, '2-5k': 50, '5-8k': 100, '8-12k': 150, '12k+': 200};
    tdee += (sb[dailySteps] ?? 0).toDouble();
    const wm = {'0': 0.0, '1-2': 1.5, '3-4': 3.5, '5-6': 5.5, '7+': 7.0};
    const ib = {'low': 100.0, 'normal': 200.0, 'hard': 350.0};
    tdee +=
        (ib[workoutIntensity] ?? 200.0) * (wm[workoutsPerWeek] ?? 0.0) / 7.0;
    const mm = {'slow': 0.95, 'normal': 1.0, 'fast': 1.05};
    tdee *= (mm[metabolism] ?? 1.0);
    const ga = {
      'lose_fat': -450,
      'build_muscle': 200,
      'gain_weight_muscle': 500,
      'body_recomposition': -100,
      'maintain_tone': 0,
      'eat_cleaner': 0,
      'maximize_performance': 300,
    };
    int calories = (((tdee + (ga[goal] ?? 0)) / 50).round() * 50).clamp(
      1200,
      9999,
    );
    const pm = {
      'lose_fat': 2.2,
      'build_muscle': 2.4,
      'gain_weight_muscle': 2.2,
      'body_recomposition': 2.6,
      'maintain_tone': 2.0,
      'eat_cleaner': 1.8,
      'maximize_performance': 2.2,
    };
    const fp = {
      'lose_fat': 0.25,
      'build_muscle': 0.25,
      'gain_weight_muscle': 0.30,
      'body_recomposition': 0.28,
      'maintain_tone': 0.30,
      'eat_cleaner': 0.30,
      'maximize_performance': 0.25,
    };
    double protein = weightKg * (pm[goal] ?? 2.0);
    double fats = calories * (fp[goal] ?? 0.25) / 9;
    double carbs = ((calories - protein * 4 - fats * 9) / 4).clamp(50, 9999);
    double fiber = (calories / 1000 * 14).clamp(20, 50).toDouble();
    const gl = {
      'lose_fat': 'fat loss',
      'build_muscle': 'muscle building',
      'gain_weight_muscle': 'weight & muscle gain',
      'body_recomposition': 'body recomposition',
      'maintain_tone': 'maintenance & toning',
      'eat_cleaner': 'clean eating',
      'maximize_performance': 'peak performance',
    };
    return DietPlan(
      calories: calories,
      protein: protein.round(),
      carbs: carbs.round(),
      fats: fats.round(),
      fiber: fiber.round(),
      summary:
          'High-protein plan at $calories kcal targeting ${gl[goal] ?? goal}',
    );
  }
}

// ── UID-scoped storage ──
String? get _uid => FirebaseAuth.instance.currentUser?.uid;
String _dk(String k) => 'diet_${_uid}_$k';
String _flk([DateTime? date]) {
  final d = date ?? DateTime.now();
  return 'food_log_${_uid}_${d.toIso8601String().substring(0, 10)}';
}

Future<void> _savePlanCloud(
  Map<String, dynamic> plan,
  String goal,
  String activity,
) async {
  final u = _uid;
  if (u == null) return;
  try {
    await FirebaseFirestore.instance.collection('users').doc(u).set({
      'dietPlan': {
        ...plan,
        'goal': goal,
        'activity': activity,
        'createdDate': DateTime.now().toIso8601String(),
      },
    }, SetOptions(merge: true));
  } catch (_) {}
}

Future<Map<String, dynamic>?> _loadPlanCloud() async {
  final u = _uid;
  if (u == null) return null;
  try {
    final d = await FirebaseFirestore.instance.collection('users').doc(u).get();
    return d.data()?['dietPlan'] as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

const _bg = Color(0xFF1A1A1A);
const _card = Color(0xFF262626);
const _gold = Color(0xFFFFD700);

Route _slideRoute(Widget page) => MaterialPageRoute(builder: (_) => page);

Widget _goldButton(String text, VoidCallback? onTap) {
  final e = onTap != null;
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: e ? _gold : Colors.white.withValues(alpha: 0.15),
        foregroundColor: e ? Colors.black : Colors.white38,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
  );
}

Widget _stepBar(double v) => TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: v),
  duration: const Duration(milliseconds: 500),
  curve: Curves.easeOutCubic,
  builder: (c, v, _) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(
      value: v,
      minHeight: 4,
      backgroundColor: Colors.white12,
      valueColor: const AlwaysStoppedAnimation(_gold),
    ),
  ),
);

BoxDecoration _cardDeco({bool selected = false}) => BoxDecoration(
  color: selected ? _gold.withValues(alpha: 0.08) : _card,
  borderRadius: BorderRadius.circular(24.0),
  border: Border.all(
    color: selected ? _gold : Colors.white.withValues(alpha: 0.06),
    width: selected ? 2 : 1,
  ),
);

AppBar _stepAppBar(BuildContext ctx, String title) => AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_rounded, color: _gold),
    onPressed: () => Navigator.pop(ctx),
  ),
  title: Text(
    title,
    style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
  ),
);

// ══════════════════════════════════════════════════════════════
// SCREEN A - Food Log Home
// ══════════════════════════════════════════════════════════════
class FoodLogPage extends StatefulWidget {
  const FoodLogPage({super.key});
  @override
  State<FoodLogPage> createState() => _FoodLogPageState();
}

class _FoodLogPageState extends State<FoodLogPage>
    with SingleTickerProviderStateMixin {
  bool _hasPlan = false;
  int _cal = 0, _pro = 0, _carb = 0, _fat = 0, _fib = 0;
  String _goal = '';
  int _tCal = 0, _tPro = 0, _tCarb = 0, _tFat = 0, _tFib = 0;
  List<Map<String, dynamic>> _logEntries = [];
  late AnimationController _pulseCtrl;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    NutritionDB.initialize();
    _refreshAll();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    if (_uid == null) {
      setState(() => _hasPlan = false);
      return;
    }
    final p = await SharedPreferences.getInstance();
    final c = p.getString(_dk('calories'));
    if (c != null && c.isNotEmpty) {
      _setLocal(p);
    } else {
      final cloud = await _loadPlanCloud();
      if (cloud != null) {
        await _cacheLocally(p, cloud);
        _setLocal(p);
      } else {
        setState(() => _hasPlan = false);
      }
    }
    await _loadFoods();
  }

  void _setLocal(SharedPreferences p) {
    setState(() {
      _hasPlan = true;
      _cal = int.tryParse(p.getString(_dk('calories')) ?? '') ?? 0;
      _pro = int.tryParse(p.getString(_dk('protein')) ?? '') ?? 0;
      _carb = int.tryParse(p.getString(_dk('carbs')) ?? '') ?? 0;
      _fat = int.tryParse(p.getString(_dk('fats')) ?? '') ?? 0;
      _fib = int.tryParse(p.getString(_dk('fiber')) ?? '') ?? 0;
      _goal = p.getString(_dk('goal')) ?? '';
    });
  }

  Future<void> _cacheLocally(
    SharedPreferences p,
    Map<String, dynamic> d,
  ) async {
    await p.setString(_dk('calories'), d['calories'].toString());
    await p.setString(_dk('protein'), d['protein'].toString());
    await p.setString(_dk('carbs'), d['carbs'].toString());
    await p.setString(_dk('fats'), d['fats'].toString());
    await p.setString(_dk('fiber'), d['fiber'].toString());
    await p.setString(_dk('summary'), d['summary']?.toString() ?? '');
    await p.setString(_dk('goal'), d['goal']?.toString() ?? '');
    await p.setString(_dk('activity'), d['activity']?.toString() ?? '');
    await p.setString(_dk('created_date'), d['createdDate']?.toString() ?? '');
  }

  Future<void> _loadFoods() async {
    final p = await SharedPreferences.getInstance();
    final j = p.getString(_flk(_selectedDate));
    if (j != null && j.isNotEmpty) {
      try {
        final list = (jsonDecode(j) as List).cast<Map<String, dynamic>>();
        int tc = 0;
        double tp = 0, tca = 0, tf = 0, tfi = 0;
        for (final entry in list) {
          tc += (entry['totalCalories'] as num?)?.toInt() ?? 0;
          tp += (entry['totalProtein'] as num?)?.toDouble() ?? 0;
          tca += (entry['totalCarbs'] as num?)?.toDouble() ?? 0;
          tf += (entry['totalFats'] as num?)?.toDouble() ?? 0;
          tfi += (entry['totalFiber'] as num?)?.toDouble() ?? 0;
        }
        setState(() {
          _logEntries = list;
          _tCal = tc;
          _tPro = tp.round();
          _tCarb = tca.round();
          _tFat = tf.round();
          _tFib = tfi.round();
        });
      } catch (_) {
        setState(() {
          _logEntries = [];
          _tCal = 0;
          _tPro = 0;
          _tCarb = 0;
          _tFat = 0;
          _tFib = 0;
        });
      }
    } else {
      setState(() {
        _logEntries = [];
        _tCal = 0;
        _tPro = 0;
        _tCarb = 0;
        _tFat = 0;
        _tFib = 0;
      });
    }
  }

  Future<void> _deleteEntry(int index) async {
    _logEntries.removeAt(index);
    final p = await SharedPreferences.getInstance();
    await p.setString(_flk(_selectedDate), jsonEncode(_logEntries));
    await _loadFoods();
  }

  Future<void> _startFoodScan(String mealType) async {
    // Show tutorial on first ever scan
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('scan_tutorial_seen') ?? false;
    if (!hasSeenTutorial && mounted) {
      await prefs.setBool('scan_tutorial_seen', true);
      if (!mounted) return;
      await Navigator.push(context, _slideRoute(const ScanTutorialScreen()));
    }

    final isPremium = BillingService().isPremium;
    final canScan = await FoodScanCountService.canScan(isPremium: isPremium);
    if (!canScan) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPremium
                  ? "Daily limit reached (10/10). Resets at midnight."
                  : "Daily limit reached (3/3) 🔒 Upgrade for 10 scans/day",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: _card,
          ),
        );
      }
      return;
    }

    // ── Show interstitial ad for free users before opening camera ──
    if (!isPremium) {
      final completer = Completer<void>();
      AdService().showFoodScanAd(
        onComplete: () {
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future;
      if (!mounted) return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 1400,
    );
    if (pickedFile == null) return;

    final originalPath = pickedFile.path;
    final file = File(originalPath);
    String finalPath = originalPath;

    final List<File> candidates = [file];

    final outPath1 = '${originalPath}_c.jpg';
    final compressed1 = await FlutterImageCompress.compressAndGetFile(
      originalPath,
      outPath1,
      quality: 75,
      minWidth: 900,
      minHeight: 900,
    );
    if (compressed1 != null) {
      candidates.add(File(compressed1.path));
    }

    final outPath2 = '${originalPath}_c2.jpg';
    final compressed2 = await FlutterImageCompress.compressAndGetFile(
      originalPath,
      outPath2,
      quality: 55,
      minWidth: 700,
      minHeight: 700,
    );
    if (compressed2 != null) {
      candidates.add(File(compressed2.path));
    }

    File? selected;
    for (final c in candidates) {
      final len = await c.length();
      if (len > 80000) {
        if (selected == null) {
          selected = c;
        } else {
          final selLen = await selected.length();
          if (len < selLen) {
            selected = c;
          }
        }
      }
    }
    selected ??= file;
    finalPath = selected.path;

    if (mounted) {
      await Navigator.push(
        context,
        _slideRoute(
          FoodScanLoadingScreen(
            imagePath: finalPath,
            mealType: mealType,
            selectedDate: _selectedDate,
          ),
        ),
      );
      _refreshAll();
    }
  }

  String get _goalLabel =>
      const {
        'lose_fat': 'Lose Fat',
        'build_muscle': 'Build Muscle',
        'gain_weight_muscle': 'Gain Weight & Muscle',
        'body_recomposition': 'Body Recomposition',
        'maintain_tone': 'Maintain & Tone',
        'eat_cleaner': 'Eat Cleaner',
        'maximize_performance': 'Maximize Performance',
      }[_goal] ??
      _goal;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: _hasPlan ? _planView() : _onboarding(),
    floatingActionButton: _hasPlan
        ? FloatingActionButton(
            backgroundColor: _gold,
            foregroundColor: Colors.black,
            tooltip: "Log Food",
            onPressed: () async {
              final mealType = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                backgroundColor: const Color(0xFF1A1A1A),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                builder: (_) => const MealTypePickerSheet(),
              );
              if (mealType != null) {
                _startFoodScan(mealType);
              }
            },
            child: const Icon(Icons.camera_alt_rounded),
          )
        : null,
  );

  Widget _onboarding() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (c, _) => Transform.scale(
              scale: 0.92 + 0.08 * _pulseCtrl.value,
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: _gold,
                size: 80,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Food Log',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track your nutrition. Fuel your glow-up.',
            style: TextStyle(color: Colors.white54, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _goldButton('Create My Diet Plan', () async {
            await Navigator.push(
              context,
              _slideRoute(const _ConfirmProfileScreen()),
            );
            _refreshAll();
          }),
          const SizedBox(height: 16),
          const Text(
            '100% local  *  No internet needed  *  2 minutes',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _simpleMacro(String label, int val, Color c) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          '${val}g',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _nutritionCard(String label, int current, int target, Color c, IconData icon) {
    double pct = target > 0 ? current / target : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: c, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$current / $target g',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealSection(String mealType, String emoji, String label) {
    final entries = _logEntries
        .where((e) => e['mealType'] == mealType)
        .toList();
    int mealKcal = 0;
    for (final e in entries) {
      mealKcal += (e['totalCalories'] as num?)?.toInt() ?? 0;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: entries.isEmpty ? () => _startFoodScan(mealType) : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entries.isEmpty
                              ? 'Tap to add'
                              : '$mealKcal kcal  ·  ${entries.length} item${entries.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: entries.isEmpty ? Colors.white30 : _gold,
                            fontSize: 13,
                            fontWeight: entries.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    entries.isEmpty
                        ? Icons.add_circle_outline_rounded
                        : Icons.chevron_right_rounded,
                    color: entries.isEmpty ? Colors.white24 : Colors.white38,
                    size: 22,
                  ),
                ],
              ),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 8),
                ...entries.map((entry) {
                  final indexInMain = _logEntries.indexOf(entry);
                  final List<dynamic> foods = entry['foods'] as List? ?? [];
                  final localImagePath = entry['imagePath'] as String?;

                  return Dismissible(
                    key: ValueKey('entry_${entry['timestamp']}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    onDismissed: (_) => _deleteEntry(indexInMain),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...foods.map((f) {
                            final name = f['name'] as String? ?? 'Food';
                            final cal = f['cal'] as num? ?? 0;
                            final grams = (f['grams'] as num?)?.round() ?? 100;
                            final isEst = f['isEstimate'] == true;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "$name (${isEst ? '~' : ''}${grams}g)",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    "${cal.round()} kcal",
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (localImagePath != null &&
                              localImagePath.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(localImagePath),
                                height: 50,
                                width: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _planView() {
    final double calPct = _cal > 0 ? (_tCal / _cal).clamp(0.0, 1.0) : 0.0;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            floating: true,
            title: const Text(
              'Food Log',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            actions: [
              IconButton(
                icon: const CircleAvatar(
                  radius: 16,
                  backgroundColor: _card,
                  child: Icon(Icons.help_outline_rounded, color: _gold, size: 18),
                ),
                tooltip: 'Scan Tips',
                onPressed: () => Navigator.push(context, _slideRoute(const ScanTutorialScreen())),
              ),
              IconButton(
                icon: const CircleAvatar(
                  radius: 16,
                  backgroundColor: _card,
                  child: Icon(Icons.autorenew_rounded, color: _gold, size: 18),
                ),
                tooltip: 'Regenerate',
                onPressed: () async {
                   await Navigator.push(context, _slideRoute(const _ConfirmProfileScreen()));
                   _refreshAll();
                },
              ),
              IconButton(
                icon: const CircleAvatar(
                  radius: 16,
                  backgroundColor: _card,
                  child: Icon(Icons.person, color: _gold, size: 18),
                ),
                onPressed: () => Navigator.push(context, _slideRoute(const ProfilePage())),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Calorie Intake Card ──
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Calorie Intake",
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TweenAnimationBuilder<int>(
                                tween: IntTween(begin: 0, end: _tCal),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                builder: (context, val, _) => Text(
                                  '$val',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 48,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'of $_cal kcal',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              SizedBox(
                                width: 70,
                                height: 70,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CircularProgressIndicator(
                                      value: calPct,
                                      strokeWidth: 8,
                                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white24),
                                    ),
                                    Center(
                                      child: Text(
                                        '${(calPct * 100).toInt()}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Daily Goal",
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _simpleMacro('Protein', _tPro, const Color(0xFF5B9BF5)),
                          _simpleMacro('Carbs', _tCarb, const Color(0xFFF5A623)),
                          _simpleMacro('Fats', _tFat, const Color(0xFF50E3C2)),
                          _simpleMacro('Fiber', _tFib, const Color(0xFF7ED321)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // ── Log Food Manually ──
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final r = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: const Color(0xFF1A1A1A),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (_) => const _AddFoodSheet(),
                      );
                      if (r == true) _loadFoods();
                    },
                    icon: const Icon(Icons.playlist_add_rounded, color: _gold, size: 20),
                    label: const Text(
                      'Log Food Manually',
                      style: TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _gold.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // ── Nutrition Summary ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Nutrition Summary",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.chevron_left, color: Colors.white60, size: 20),
                                onPressed: () {
                                  setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                                  _refreshAll();
                                },
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDate.toIso8601String().substring(0, 10) == DateTime.now().toIso8601String().substring(0, 10)
                                    ? "Today"
                                    : _selectedDate.toIso8601String().substring(5, 10),
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 16),
                              const SizedBox(width: 8),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.chevron_right, color: Colors.white60, size: 20),
                                onPressed: () {
                                  setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                                  _refreshAll();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _nutritionCard('Protein', _tPro, _pro, const Color(0xFF5B9BF5), Icons.close_rounded)),
                          const SizedBox(width: 12),
                          Expanded(child: _nutritionCard('Carbs', _tCarb, _carb, const Color(0xFFF5A623), Icons.local_fire_department_rounded)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _nutritionCard('Fats', _tFat, _fat, const Color(0xFF50E3C2), Icons.water_drop_rounded)),
                          const SizedBox(width: 12),
                          Expanded(child: _nutritionCard('Fiber', _tFib, _fib, const Color(0xFF7ED321), Icons.eco_rounded)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // ── Goal Banner ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: _gold, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Goal: $_goalLabel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final r = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: const Color(0xFF1A1A1A),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            builder: (_) => _EditPlanSheet(
                              cal: _cal,
                              pro: _pro,
                              carb: _carb,
                              fat: _fat,
                              fib: _fib,
                            ),
                          );
                          if (r == true) _refreshAll();
                        },
                        child: const Text(
                          'Edit Plan',
                          style: TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // ── Meals or Empty State ──
                if (_logEntries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: _gold,
                                child: Icon(Icons.star_rounded, color: Colors.black, size: 18),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "You're all set!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Start logging your meals to\ntrack your progress.",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.assignment_rounded, color: _gold, size: 60),
                      ],
                    ),
                  ),

                if (_logEntries.isNotEmpty) ...[
                  const Text(
                    "Meals",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _mealSection('breakfast', '🌅', 'Breakfast'),
                  _mealSection('lunch', '☀️', 'Lunch'),
                  _mealSection('dinner', '🌙', 'Dinner'),
                  _mealSection('snack', '🍎', 'Snack'),
                ],
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MealTypePickerSheet
// ══════════════════════════════════════════════════════════════
class MealTypePickerSheet extends StatelessWidget {
  const MealTypePickerSheet({super.key});

  Widget _mealCard(
    BuildContext context,
    String title,
    String emoji,
    String value,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Log Food For...',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _mealCard(
                context,
                'Breakfast',
                '🌅',
                'breakfast',
                const Color(0xFFFF8C00),
              ),
              _mealCard(
                context,
                'Lunch',
                '☀️',
                'lunch',
                const Color(0xFF4CAF50),
              ),
              _mealCard(
                context,
                'Dinner',
                '🌙',
                'dinner',
                const Color(0xFF7C4DFF),
              ),
              _mealCard(
                context,
                'Snack',
                '🍎',
                'snack',
                const Color(0xFFE91E63),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FoodScanLoadingScreen
// ══════════════════════════════════════════════════════════════
class FoodScanLoadingScreen extends StatefulWidget {
  final String imagePath;
  final String mealType;
  final DateTime selectedDate;
  const FoodScanLoadingScreen({
    super.key,
    required this.imagePath,
    required this.mealType,
    required this.selectedDate,
  });

  @override
  State<FoodScanLoadingScreen> createState() => _FoodScanLoadingScreenState();
}

class _FoodScanLoadingScreenState extends State<FoodScanLoadingScreen> {
  late List<String> _loadingTexts;
  int _currentTextIndex = 0;
  Timer? _textTimer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadingTexts = [
      "Recognising your food...",
      "Estimating portions...",
      "Looking up nutrition data...",
      "Calculating your macros...",
    ];
    _textTimer = Timer.periodic(const Duration(milliseconds: 1300), (timer) {
      if (_isDisposed) return;
      setState(() {
        _currentTextIndex = (_currentTextIndex + 1) % _loadingTexts.length;
      });
    });
    _analyzeFood();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _textTimer?.cancel();
    super.dispose();
  }

  Future<http.Response> _sendFoodRequest(String token) async {
    final uri = Uri.parse(
      'https://level-maxing-backend.onrender.com/food-analyze',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['mealType'] = widget.mealType;

    request.files.add(
      await http.MultipartFile.fromPath(
        'frontImage',
        widget.imagePath,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 120),
    );
    return await http.Response.fromStream(streamedResponse);
  }

  Future<void> _analyzeFood() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorAndPop('Please log in to scan food.');
        return;
      }
      final token = await user.getIdToken(true);
      if (token == null) {
        _showErrorAndPop('Authentication failed. Please restart the app.');
        return;
      }

      // Retry logic: Render free tier cold starts can cause the first request to
      // time out or return 503. We retry up to 2 times with increasing timeouts.
      http.Response? response;
      String? lastError;
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          response = await _sendFoodRequest(token);
          // If we got a 503 (server waking up), retry after a short delay
          if (response.statusCode == 503 && attempt < 1) {
            debugPrint(
              '[FoodScan] Server busy (503), retrying in 4s... (attempt ${attempt + 1})',
            );
            await Future.delayed(const Duration(seconds: 4));
            continue;
          }
          break; // Got a non-503 response, stop retrying
        } on TimeoutException {
          lastError = 'timeout';
          debugPrint('[FoodScan] Request timed out (attempt ${attempt + 1})');
          if (attempt < 1) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
        } on SocketException catch (e) {
          lastError = 'network';
          debugPrint('[FoodScan] Network error: $e (attempt ${attempt + 1})');
          if (attempt < 1) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
        } catch (e) {
          lastError = e.toString();
          debugPrint('[FoodScan] Request error: $e (attempt ${attempt + 1})');
          if (attempt < 1) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
        }
      }

      if (response == null) {
        if (lastError == 'timeout') {
          _showErrorAndPop(
            'Server is starting up. Please wait a moment and try again.',
          );
        } else if (lastError == 'network') {
          _showErrorAndPop(
            'No internet connection. Please check your network.',
          );
        } else {
          _showErrorAndPop('Could not reach server. Please try again.');
        }
        return;
      }

      debugPrint('[FoodScan] Response status: ${response.statusCode}');
      debugPrint(
        '[FoodScan] Response body: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}',
      );

      if (response.statusCode == 401) {
        _showErrorAndPop(
          'Session expired. Please restart the app and try again.',
        );
        return;
      }

      if (response.statusCode == 429) {
        _showErrorAndPop('Too many requests. Please wait a few minutes.');
        return;
      }

      if (response.statusCode == 503) {
        _showErrorAndPop(
          'Server is waking up. Please wait 30 seconds and try again.',
        );
        return;
      }

      if (response.statusCode != 200) {
        // Try to extract error message from response body
        try {
          final errData = jsonDecode(response.body);
          final errMsg =
              errData['error'] as String? ??
              'Server error (${response.statusCode})';
          _showErrorAndPop(errMsg);
        } catch (_) {
          _showErrorAndPop(
            'Server error (${response.statusCode}). Please try again.',
          );
        }
        return;
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        final errMsg = data['error'] as String? ?? 'Analysis was unsuccessful.';
        debugPrint('[FoodScan] Server returned success=false: $errMsg');
        _showErrorAndPop(errMsg);
        return;
      }

      final List<FoodNutritionResult> results = [];
      final foodsList = data['foods'] as List? ?? [];

      if (foodsList.isEmpty) {
        _showErrorAndPop(
          'No food detected in the photo. Try pointing the camera directly at your food.',
        );
        return;
      }

      for (final f in foodsList) {
        final name = f['name'] as String? ?? '';
        final grams = (f['estimated_grams'] as num?)?.toDouble() ?? 100.0;
        final confStr = f['confidence'] as String? ?? 'medium';
        double defaultConf = 0.8;
        if (confStr == 'high') defaultConf = 1.0;
        if (confStr == 'low') defaultConf = 0.5;

        final cal = f['calories'] as num?;
        final pro = f['protein'] as num?;
        final carb = f['carbs'] as num?;
        final fat = f['fats'] as num?;
        final fib = f['fiber'] as num?;

        if (cal != null || pro != null || carb != null || fat != null) {
          results.add(
            FoodNutritionResult(
              foodName: name,
              grams: grams,
              calories: cal?.toInt() ?? 0,
              protein: pro?.toDouble() ?? 0.0,
              carbs: carb?.toDouble() ?? 0.0,
              fats: fat?.toDouble() ?? 0.0,
              fiber: fib?.toDouble() ?? 0.0,
              isEstimate: false,
              confidence: defaultConf,
            ),
          );
          continue;
        }

        var lookupResult = await NutritionDB.lookup(name, grams);

        if (lookupResult == null) {
          final simplifiedName = name
              .replaceAll(
                RegExp(
                  r'\b(cooked|grilled|boiled|fried)\b',
                  caseSensitive: false,
                ),
                '',
              )
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (simplifiedName.isNotEmpty && simplifiedName != name) {
            lookupResult = await NutritionDB.lookup(simplifiedName, grams);
          }
        }

        lookupResult ??= NutritionDB.getFallbackEstimate(name, grams);

        if (lookupResult.isEstimate) {
          results.add(
            FoodNutritionResult(
              foodName: lookupResult.foodName,
              grams: lookupResult.grams,
              calories: lookupResult.calories,
              protein: lookupResult.protein,
              carbs: lookupResult.carbs,
              fats: lookupResult.fats,
              fiber: lookupResult.fiber,
              isEstimate: true,
              confidence: 0.5,
            ),
          );
        } else {
          results.add(
            FoodNutritionResult(
              foodName: lookupResult.foodName,
              grams: lookupResult.grams,
              calories: lookupResult.calories,
              protein: lookupResult.protein,
              carbs: lookupResult.carbs,
              fats: lookupResult.fats,
              fiber: lookupResult.fiber,
              isEstimate: false,
              confidence: defaultConf,
            ),
          );
        }
      }

      await FoodScanCountService.recordScan();

      if (!context.mounted) return;

      void proceedToResult() async {
        final res = await Navigator.push(
          context,
          _slideRoute(
            FoodScanResultScreen(
              imagePath: widget.imagePath,
              mealType: widget.mealType,
              foods: results,
              selectedDate: widget.selectedDate,
            ),
          ),
        );
        if (context.mounted) {
          var context2 = context;
          Navigator.pop(context2, res);
        }
      }

      if (!BillingService().isPremium) {
        await AdService().showFoodScanAd(onComplete: proceedToResult);
      } else {
        proceedToResult();
      }
    } on TimeoutException {
      debugPrint('[FoodScan] Final timeout');
      _showErrorAndPop(
        'Server is starting up. Please wait a moment and try again.',
      );
    } on SocketException {
      debugPrint('[FoodScan] Socket exception');
      _showErrorAndPop('No internet connection. Please check your network.');
    } on FormatException catch (e) {
      debugPrint('[FoodScan] JSON parse error: $e');
      _showErrorAndPop('Server returned invalid data. Please try again.');
    } catch (e) {
      debugPrint('[FoodScan] Unexpected error: $e');
      _showErrorAndPop('Something went wrong. Please try again.');
    }
  }

  void _showErrorAndPop(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2A2A2A),
        duration: const Duration(seconds: 4),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 240,
                  child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
                ),
              ),
              const Spacer(),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
              ),
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _loadingTexts[_currentTextIndex],
                  key: ValueKey<int>(_currentTextIndex),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FoodScanResultScreen
// ══════════════════════════════════════════════════════════════
class FoodScanResultScreen extends StatefulWidget {
  final String imagePath;
  final String mealType;
  final List<FoodNutritionResult> foods;
  final DateTime selectedDate;

  const FoodScanResultScreen({
    super.key,
    required this.imagePath,
    required this.mealType,
    required this.foods,
    required this.selectedDate,
  });

  @override
  State<FoodScanResultScreen> createState() => _FoodScanResultScreenState();
}

class _FoodScanResultScreenState extends State<FoodScanResultScreen> {
  bool _saveAsYesterday = false;

  int _targetCal = 2000;
  int _targetPro = 150;
  int _targetCarb = 200;
  int _targetFat = 70;
  int _targetFib = 30;

  int _todayCal = 0;
  double _todayPro = 0;
  double _todayCarb = 0;
  double _todayFat = 0;
  double _todayFib = 0;

  @override
  void initState() {
    super.initState();
    _loadTargetsAndToday();
  }

  Future<void> _loadTargetsAndToday() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final p = await SharedPreferences.getInstance();

    final cKey = 'diet_${uid}_calories';
    final pKey = 'diet_${uid}_protein';
    final carbKey = 'diet_${uid}_carbs';
    final fKey = 'diet_${uid}_fats';
    final fibKey = 'diet_${uid}_fiber';

    setState(() {
      _targetCal = int.tryParse(p.getString(cKey) ?? '2000') ?? 2000;
      _targetPro = int.tryParse(p.getString(pKey) ?? '150') ?? 150;
      _targetCarb = int.tryParse(p.getString(carbKey) ?? '200') ?? 200;
      _targetFat = int.tryParse(p.getString(fKey) ?? '70') ?? 70;
      _targetFib = int.tryParse(p.getString(fibKey) ?? '30') ?? 30;
    });

    final todayStr = widget.selectedDate.toIso8601String().substring(0, 10);
    final logKey = 'food_log_${uid}_$todayStr';
    final logJson = p.getString(logKey);
    if (logJson != null && logJson.isNotEmpty) {
      try {
        final list = (jsonDecode(logJson) as List).cast<Map<String, dynamic>>();
        int tc = 0;
        double tp = 0, tca = 0, tf = 0, tfi = 0;
        for (final entry in list) {
          tc += (entry['totalCalories'] as num?)?.toInt() ?? 0;
          tp += (entry['totalProtein'] as num?)?.toDouble() ?? 0;
          tca += (entry['totalCarbs'] as num?)?.toDouble() ?? 0;
          tf += (entry['totalFats'] as num?)?.toDouble() ?? 0;
          tfi += (entry['totalFiber'] as num?)?.toDouble() ?? 0;
        }
        setState(() {
          _todayCal = tc;
          _todayPro = tp;
          _todayCarb = tca;
          _todayFat = tf;
          _todayFib = tfi;
        });
      } catch (_) {}
    }
  }

  Color _getProgressColor(double pct) {
    if (pct < 0.8) return const Color(0xFFFFD700);
    if (pct <= 1.0) return Colors.amber;
    return Colors.redAccent;
  }

  Widget _macroProgressRow(
    String label,
    double current,
    int target,
    String unit,
  ) {
    final pct = target > 0 ? current / target : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                '${current.toStringAsFixed(1)} / $target $unit',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(pct)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int mealCal = 0;
    double mealPro = 0, mealCarb = 0, mealFat = 0, mealFib = 0;
    bool hasEstimate = false;

    for (final f in widget.foods) {
      mealCal += f.calories;
      mealPro += f.protein;
      mealCarb += f.carbs;
      mealFat += f.fats;
      mealFib += f.fiber;
      if (f.isEstimate) hasEstimate = true;
    }

    final String displayMealType = widget.mealType.toUpperCase();
    final String emoji = widget.mealType == 'breakfast'
        ? '🌅'
        : widget.mealType == 'lunch'
        ? '☀️'
        : widget.mealType == 'dinner'
        ? '🌙'
        : '🍎';

    final Color accentColor = widget.mealType == 'breakfast'
        ? const Color(0xFFFF8C00)
        : widget.mealType == 'lunch'
        ? const Color(0xFF4CAF50)
        : widget.mealType == 'dinner'
        ? const Color(0xFF7C4DFF)
        : const Color(0xFFE91E63);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Food Logged ✓",
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "$emoji $displayMealType",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Detected Foods",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.foods.map((f) {
                String confBadge = '';
                if (f.confidence >= 1.0) {
                  confBadge = '⚡';
                } else if (f.confidence >= 0.8) {
                  confBadge = '·';
                } else {
                  confBadge = '?';
                }

                final prefix = f.isEstimate ? '~' : '';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    "${f.foodName} ($prefix${f.grams.round()}g)  $confBadge",
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Total Nutrition",
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "🔥 Calories",
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            "${hasEstimate ? '~' : ''}$mealCal",
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            "kcal",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.06),
                    height: 24,
                  ),
                  _nutrientRow("🥩 Protein", mealPro, "g", hasEstimate),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.06),
                    height: 24,
                  ),
                  _nutrientRow("🌾 Carbs", mealCarb, "g", hasEstimate),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.06),
                    height: 24,
                  ),
                  _nutrientRow("🥑 Fats", mealFat, "g", hasEstimate),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.06),
                    height: 24,
                  ),
                  _nutrientRow("🥦 Fiber", mealFib, "g", hasEstimate),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (hasEstimate)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Some values are estimated. DB match not found.",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              "Daily Progress (Running Total)",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  _macroProgressRow(
                    "Calories",
                    (_todayCal + mealCal).toDouble(),
                    _targetCal,
                    "kcal",
                  ),
                  const SizedBox(height: 12),
                  _macroProgressRow(
                    "Protein",
                    _todayPro + mealPro,
                    _targetPro,
                    "g",
                  ),
                  const SizedBox(height: 12),
                  _macroProgressRow(
                    "Carbs",
                    _todayCarb + mealCarb,
                    _targetCarb,
                    "g",
                  ),
                  const SizedBox(height: 12),
                  _macroProgressRow(
                    "Fats",
                    _todayFat + mealFat,
                    _targetFat,
                    "g",
                  ),
                  const SizedBox(height: 12),
                  _macroProgressRow(
                    "Fiber",
                    _todayFib + mealFib,
                    _targetFib,
                    "g",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text(
                "Save as Yesterday's Food",
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              value: _saveAsYesterday,
              activeColor: const Color(0xFFFFD700),
              checkColor: Colors.black,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              side: const BorderSide(color: Colors.white54),
              onChanged: (val) {
                setState(() => _saveAsYesterday = val ?? false);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  final uid = user.uid;
                  final p = await SharedPreferences.getInstance();

                  final targetDate = _saveAsYesterday
                      ? DateTime.now().subtract(const Duration(days: 1))
                      : widget.selectedDate;
                  final todayStr = targetDate.toIso8601String().substring(
                    0,
                    10,
                  );
                  final logKey = 'food_log_${uid}_$todayStr';

                  final logJson = p.getString(logKey);
                  final List<Map<String, dynamic>> logList =
                      logJson != null && logJson.isNotEmpty
                      ? (jsonDecode(logJson) as List)
                            .cast<Map<String, dynamic>>()
                      : [];

                  String localSavedPath = widget.imagePath;
                  try {
                    final appDir = await getApplicationDocumentsDirectory();
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    final targetPath = '${appDir.path}/food_$timestamp.jpg';
                    final imageFile = File(widget.imagePath);
                    if (await imageFile.exists()) {
                      final copied = await imageFile.copy(targetPath);
                      localSavedPath = copied.path;
                    }
                  } catch (_) {}

                  final Map<String, dynamic> newEntry = {
                    'mealType': widget.mealType,
                    'foods': widget.foods
                        .map(
                          (f) => {
                            'name': f.foodName,
                            'grams': f.grams,
                            'cal': f.calories,
                            'pro': f.protein,
                            'carb': f.carbs,
                            'fat': f.fats,
                            'fib': f.fiber,
                            'isEstimate': f.isEstimate,
                          },
                        )
                        .toList(),
                    'totalCalories': mealCal,
                    'totalProtein': mealPro,
                    'totalCarbs': mealCarb,
                    'totalFats': mealFat,
                    'totalFiber': mealFib,
                    'imagePath': localSavedPath,
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                  };

                  logList.add(newEntry);
                  await p.setString(logKey, jsonEncode(logList));

                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('food_logs')
                        .add({
                          ...newEntry,
                          'logDate': todayStr,
                          'createdAt': FieldValue.serverTimestamp(),
                          'expiresAt': DateTime.now().add(
                            const Duration(days: 15),
                          ),
                        });
                  } catch (_) {}

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "✓ Saved to ${widget.mealType.substring(0, 1).toUpperCase() + widget.mealType.substring(1)}",
                        ),
                        backgroundColor: accentColor,
                      ),
                    );
                    Navigator.pop(context, true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Save to Log ✓",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _nutrientRow(String label, double val, String unit, bool hasEstimate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        Text(
          "${hasEstimate ? '~' : ''}${val.toStringAsFixed(1)} $unit",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SCREEN B - Confirm Profile (Step 1/5)
// ══════════════════════════════════════════════════════════════
class _ConfirmProfileScreen extends StatefulWidget {
  const _ConfirmProfileScreen();
  @override
  State<_ConfirmProfileScreen> createState() => _ConfirmProfileScreenState();
}

class _ConfirmProfileScreenState extends State<_ConfirmProfileScreen> {
  String _name = '', _gender = '', _height = '', _weight = '', _age = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _name = p.getString('username') ?? '';
      _gender = p.getString('gender') ?? '';
      final h = p.getDouble('height');
      _height = h != null ? h.round().toString() : '';
      final w = p.getDouble('weight');
      _weight = w != null ? w.toStringAsFixed(1) : '';
      final a = p.getInt('age');
      _age = a != null ? a.toString() : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['Name', _name],
      ['Gender', _gender],
      ['Height', _height.isNotEmpty ? '$_height cm' : ''],
      ['Weight', _weight.isNotEmpty ? '$_weight kg' : ''],
      ['Age', _age.isNotEmpty ? '$_age years' : ''],
    ];
    return Scaffold(
      backgroundColor: _bg,
      appBar: _stepAppBar(context, 'Your Profile'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepBar(0.2),
              const SizedBox(height: 24),
              const Text(
                'Your Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "We'll use this to personalise your plan",
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: _cardDeco(),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < rows.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              rows[i][0],
                              style: const TextStyle(color: Colors.white54),
                            ),
                            Text(
                              rows[i][1].isEmpty ? 'Not set' : rows[i][1],
                              style: TextStyle(
                                color: rows[i][1].isEmpty
                                    ? Colors.redAccent
                                    : _gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < rows.length - 1)
                        Divider(
                          color: Colors.white.withValues(alpha: 0.06),
                          height: 1,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Are these details correct?',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _goldButton('Yes, looks good', () {
                Navigator.push(
                  context,
                  _slideRoute(
                    _ActivityScreen(
                      name: _name,
                      gender: _gender,
                      height: _height,
                      weight: _weight,
                      age: _age,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      _slideRoute(const ProfilePage()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Edit in Profile',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SCREEN C - Activity Level (Step 2/5)
// ══════════════════════════════════════════════════════════════
class _ActivityScreen extends StatefulWidget {
  final String name, gender, height, weight, age;
  const _ActivityScreen({
    required this.name,
    required this.gender,
    required this.height,
    required this.weight,
    required this.age,
  });
  @override
  State<_ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<_ActivityScreen> {
  String? _activity, _workouts, _intensity, _steps;
  bool get _allSet =>
      _activity != null &&
      _workouts != null &&
      (_workouts == '0' || _intensity != null) &&
      _steps != null;

  Widget _actCard(String key, IconData icon, String title, String sub) {
    bool s = _activity == key;
    return GestureDetector(
      onTap: () => setState(() => _activity = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(selected: s),
        child: Row(
          children: [
            Icon(icon, color: s ? _gold : Colors.white54, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: s ? _gold : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String? cur, void Function(String) onTap) {
    bool s = cur == label;
    return GestureDetector(
      onTap: () => onTap(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        width: 60,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: s ? _gold : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: s ? _gold : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: s ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _intCard(String key, IconData icon, String label) {
    bool s = _intensity == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _intensity = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: _cardDeco(selected: s),
          child: Column(
            children: [
              Icon(icon, color: s ? _gold : Colors.white54, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: s ? _gold : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _stepAppBar(context, 'Activity Level'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stepBar(0.4),
                    const SizedBox(height: 24),
                    const Text(
                      'Activity Level',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Be honest - this directly affects your calorie target',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Overall Activity',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _actCard(
                      'sedentary',
                      Icons.chair_rounded,
                      'Sedentary',
                      'Desk job, minimal movement',
                    ),
                    _actCard(
                      'lightly_active',
                      Icons.directions_walk_rounded,
                      'Lightly Active',
                      'Light walks, some standing',
                    ),
                    _actCard(
                      'moderately_active',
                      Icons.directions_run_rounded,
                      'Moderately Active',
                      'Regular exercise or active job',
                    ),
                    _actCard(
                      'very_active',
                      Icons.bolt_rounded,
                      'Very Active',
                      'Intense training or physical job',
                    ),
                    _actCard(
                      'athlete',
                      Icons.emoji_events_rounded,
                      'Athlete',
                      'Multiple sessions daily',
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Workouts per week',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: ['0', '1-2', '3-4', '5-6', '7+']
                          .map(
                            (l) => _pill(
                              l,
                              _workouts,
                              (v) => setState(() {
                                _workouts = v;
                                if (v == '0') {
                                  _intensity = null; // Clear intensity if 0 workouts
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    if (_workouts != '0' && _workouts != null) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Workout Intensity',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _intCard('low', Icons.self_improvement_rounded, 'Low'),
                          const SizedBox(width: 10),
                          _intCard(
                            'normal',
                            Icons.fitness_center_rounded,
                            'Normal',
                          ),
                          const SizedBox(width: 10),
                          _intCard(
                            'hard',
                            Icons.local_fire_department_rounded,
                            'Hard',
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'Daily Steps',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: ['<2k', '2-5k', '5-8k', '8-12k', '12k+']
                          .map(
                            (l) => _pill(
                              l,
                              _steps,
                              (v) => setState(() => _steps = v),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _goldButton(
                'Next',
                _allSet
                    ? () {
                        Navigator.push(
                          context,
                          _slideRoute(
                            _GoalScreen(
                              name: widget.name,
                              gender: widget.gender,
                              height: widget.height,
                              weight: widget.weight,
                              age: widget.age,
                              activity: _activity!,
                              workouts: _workouts!,
                              intensity: _workouts == '0' ? 'low' : _intensity!,
                              steps: _steps!,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SCREEN D - Goal (Step 3/5)
// ══════════════════════════════════════════════════════════════
class _GoalScreen extends StatefulWidget {
  final String name,
      gender,
      height,
      weight,
      age,
      activity,
      workouts,
      intensity,
      steps;
  const _GoalScreen({
    required this.name,
    required this.gender,
    required this.height,
    required this.weight,
    required this.age,
    required this.activity,
    required this.workouts,
    required this.intensity,
    required this.steps,
  });
  @override
  State<_GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<_GoalScreen> {
  String? _goal;
  static const _goals = [
    [
      'lose_fat',
      'Lose Fat',
      'Reduce body fat while preserving muscle',
      'local_fire_department_rounded',
    ],
    [
      'build_muscle',
      'Build Muscle',
      'Gain lean muscle with controlled calories',
      'fitness_center_rounded',
    ],
    [
      'gain_weight_muscle',
      'Gain Weight & Muscle',
      'Aggressive bulk for maximum size',
      'trending_up_rounded',
    ],
    [
      'body_recomposition',
      'Body Recomposition',
      'Lose fat and build muscle simultaneously',
      'sync_rounded',
    ],
    [
      'maintain_tone',
      'Maintain & Tone',
      'Keep weight, improve definition',
      'accessibility_new_rounded',
    ],
    [
      'eat_cleaner',
      'Eat Cleaner',
      'Better nutrition habits, no specific weight goal',
      'eco_rounded',
    ],
    [
      'maximize_performance',
      'Maximize Performance',
      'Fuel athletic output and recovery',
      'rocket_launch_rounded',
    ],
  ];
  IconData _goalIcon(String k) {
    switch (k) {
      case 'local_fire_department_rounded':
        return Icons.local_fire_department_rounded;
      case 'fitness_center_rounded':
        return Icons.fitness_center_rounded;
      case 'trending_up_rounded':
        return Icons.trending_up_rounded;
      case 'sync_rounded':
        return Icons.sync_rounded;
      case 'accessibility_new_rounded':
        return Icons.accessibility_new_rounded;
      case 'eco_rounded':
        return Icons.eco_rounded;
      default:
        return Icons.rocket_launch_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _stepAppBar(context, 'Your Goal'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stepBar(0.6),
                    const SizedBox(height: 24),
                    const Text(
                      'Your Goal',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose the one that fits you best right now',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 24),
                    ..._goals.map((g) {
                      bool s = _goal == g[0];
                      return GestureDetector(
                        onTap: () => setState(() => _goal = g[0]),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: _cardDeco(selected: s),
                          child: Row(
                            children: [
                              Icon(
                                _goalIcon(g[3]),
                                color: s ? _gold : Colors.white54,
                                size: 28,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g[1],
                                      style: TextStyle(
                                        color: s ? _gold : Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      g[2],
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _goldButton(
                'Next',
                _goal != null
                    ? () {
                        Navigator.push(
                          context,
                          _slideRoute(
                            _MetabolismScreen(
                              name: widget.name,
                              gender: widget.gender,
                              height: widget.height,
                              weight: widget.weight,
                              age: widget.age,
                              activity: widget.activity,
                              workouts: widget.workouts,
                              intensity: widget.intensity,
                              steps: widget.steps,
                              goal: _goal!,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SCREEN E - Metabolism (Step 4/5)
// ══════════════════════════════════════════════════════════════
class _MetabolismScreen extends StatefulWidget {
  final String name,
      gender,
      height,
      weight,
      age,
      activity,
      workouts,
      intensity,
      steps,
      goal;
  const _MetabolismScreen({
    required this.name,
    required this.gender,
    required this.height,
    required this.weight,
    required this.age,
    required this.activity,
    required this.workouts,
    required this.intensity,
    required this.steps,
    required this.goal,
  });
  @override
  State<_MetabolismScreen> createState() => _MetabolismScreenState();
}

class _MetabolismScreenState extends State<_MetabolismScreen> {
  String? _metabolism;
  bool _infoExpanded = false;
  final _types = const [
    [
      'slow',
      'Slow',
      'I gain weight easily, even when I eat little. Losing is hard.',
    ],
    ['normal', 'Normal', 'My weight is fairly stable and predictable.'],
    ['fast', 'Fast', 'I stay lean easily. I can eat a lot without gaining.'],
  ];
  IconData _mi(String k) => k == 'slow'
      ? Icons.snooze_rounded
      : k == 'normal'
      ? Icons.balance_rounded
      : Icons.flash_on_rounded;
  Color _mc(String k, bool s) => k == 'slow' && s
      ? Colors.redAccent
      : s
      ? _gold
      : Colors.white54;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _stepAppBar(context, 'Metabolism'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stepBar(0.8),
                    const SizedBox(height: 24),
                    const Text(
                      'Your Metabolism',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Helps fine-tune your calorie estimate',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                setState(() => _infoExpanded = !_infoExpanded),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: _gold,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'What is metabolism?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: _infoExpanded ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 250),
                                    child: const Icon(
                                      Icons.expand_more,
                                      color: _gold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            child: _infoExpanded
                                ? const Padding(
                                    padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                                    child: Text(
                                      'Metabolism is how fast your body burns calories at rest. Slow = you gain weight easily. Normal = average burn rate. Fast = you stay lean easily and can eat more without gaining.',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._types.map((t) {
                      bool s = _metabolism == t[0];
                      return GestureDetector(
                        onTap: () => setState(() => _metabolism = t[0]),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDeco(selected: s),
                          child: Row(
                            children: [
                              Icon(_mi(t[0]), color: _mc(t[0], s), size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t[1],
                                      style: TextStyle(
                                        color: s ? _gold : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t[2],
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _goldButton(
                'Next',
                _metabolism != null
                    ? () {
                        Navigator.push(
                          context,
                          _slideRoute(
                            _ReviewScreen(
                              name: widget.name,
                              gender: widget.gender,
                              height: widget.height,
                              weight: widget.weight,
                              age: widget.age,
                              activity: widget.activity,
                              workouts: widget.workouts,
                              intensity: widget.intensity,
                              steps: widget.steps,
                              goal: widget.goal,
                              metabolism: _metabolism!,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SCREEN F - Review & Calculate (Step 5/5)
// ══════════════════════════════════════════════════════════════
class _ReviewScreen extends StatefulWidget {
  final String name,
      gender,
      height,
      weight,
      age,
      activity,
      workouts,
      intensity,
      steps,
      goal,
      metabolism;
  const _ReviewScreen({
    required this.name,
    required this.gender,
    required this.height,
    required this.weight,
    required this.age,
    required this.activity,
    required this.workouts,
    required this.intensity,
    required this.steps,
    required this.goal,
    required this.metabolism,
  });
  @override
  State<_ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<_ReviewScreen> {
  bool _loading = false;
  String _fmt(String k) {
    const l = {
      'sedentary': 'Sedentary',
      'lightly_active': 'Lightly Active',
      'moderately_active': 'Moderately Active',
      'very_active': 'Very Active',
      'athlete': 'Athlete',
      'lose_fat': 'Lose Fat',
      'build_muscle': 'Build Muscle',
      'gain_weight_muscle': 'Gain Weight & Muscle',
      'body_recomposition': 'Body Recomposition',
      'maintain_tone': 'Maintain & Tone',
      'eat_cleaner': 'Eat Cleaner',
      'maximize_performance': 'Maximize Performance',
      'slow': 'Slow',
      'normal': 'Normal',
      'fast': 'Fast',
      'low': 'Low',
      'hard': 'Hard',
    };
    return l[k] ?? k;
  }

  Future<void> _calculate() async {
    setState(() => _loading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(color: _gold, strokeWidth: 3),
            ),
            SizedBox(height: 20),
            Text(
              'Building your plan...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1500));
    final plan = DietCalculator.calculate(
      weightKg: double.tryParse(widget.weight) ?? 70,
      heightCm: double.tryParse(widget.height) ?? 170,
      age: int.tryParse(widget.age) ?? 25,
      gender: widget.gender,
      activityLevel: widget.activity,
      workoutsPerWeek: widget.workouts,
      workoutIntensity: widget.intensity,
      dailySteps: widget.steps,
      goal: widget.goal,
      metabolism: widget.metabolism,
    );
    final p = await SharedPreferences.getInstance();
    await p.setString(_dk('calories'), plan.calories.toString());
    await p.setString(_dk('protein'), plan.protein.toString());
    await p.setString(_dk('carbs'), plan.carbs.toString());
    await p.setString(_dk('fats'), plan.fats.toString());
    await p.setString(_dk('fiber'), plan.fiber.toString());
    await p.setString(_dk('summary'), plan.summary);
    await p.setString(_dk('created_date'), DateTime.now().toIso8601String());
    await p.setString(_dk('goal'), widget.goal);
    await p.setString(_dk('activity'), widget.activity);
    await _savePlanCloud(plan.toMap(), widget.goal, widget.activity);
    if (mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your personalised plan is ready!',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: _gold,
        ),
      );
    }
  }

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Flexible(
          child: Text(
            v,
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
  Widget _div() =>
      Divider(color: Colors.white.withValues(alpha: 0.06), height: 1);
  Widget _sec(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _stepAppBar(context, 'Review'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stepBar(1.0),
                    const SizedBox(height: 24),
                    const Text(
                      'Review Your Plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Everything looks right? Let's build it.",
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: _cardDeco(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sec('YOUR PROFILE'),
                          _row(
                            'Name',
                            widget.name.isNotEmpty ? widget.name : 'Not set',
                          ),
                          _div(),
                          _row(
                            'Gender',
                            widget.gender.isNotEmpty
                                ? widget.gender
                                : 'Not set',
                          ),
                          _div(),
                          _row(
                            'Height',
                            widget.height.isNotEmpty
                                ? '${widget.height} cm'
                                : 'Not set',
                          ),
                          _div(),
                          _row(
                            'Weight',
                            widget.weight.isNotEmpty
                                ? '${widget.weight} kg'
                                : 'Not set',
                          ),
                          _div(),
                          _row(
                            'Age',
                            widget.age.isNotEmpty
                                ? '${widget.age} years'
                                : 'Not set',
                          ),
                          _sec('ACTIVITY'),
                          _row('Activity Level', _fmt(widget.activity)),
                          _div(),
                          _row('Workouts/week', widget.workouts),
                          _div(),
                          _row('Intensity', _fmt(widget.intensity)),
                          _div(),
                          _row('Daily Steps', widget.steps),
                          _sec('GOAL'),
                          _row('Goal', _fmt(widget.goal)),
                          _sec('METABOLISM'),
                          _row('Type', _fmt(widget.metabolism)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.lock_clock_rounded,
                            color: _gold,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You can regenerate or edit your plan anytime.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _goldButton(
                'Calculate My Plan',
                _loading ? null : _calculate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SCREEN G - Edit Plan Bottom Sheet
// ══════════════════════════════════════════════════════════════
class _EditPlanSheet extends StatefulWidget {
  final int cal, pro, carb, fat, fib;
  const _EditPlanSheet({
    required this.cal,
    required this.pro,
    required this.carb,
    required this.fat,
    required this.fib,
  });
  @override
  State<_EditPlanSheet> createState() => _EditPlanSheetState();
}

class _EditPlanSheetState extends State<_EditPlanSheet> {
  late double _cal, _pro, _carb, _fat, _fib;
  @override
  void initState() {
    super.initState();
    _cal = widget.cal.toDouble();
    _pro = widget.pro.toDouble();
    _carb = widget.carb.toDouble();
    _fat = widget.fat.toDouble();
    _fib = widget.fib.toDouble();
  }

  Widget _premiumSlider(
    String label,
    double val,
    double min,
    double max,
    int div,
    Color color,
    IconData icon,
    void Function(double) fn,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '${val.round()}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: Colors.white10,
              trackHeight: 4,
              thumbColor: color,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayColor: color.withValues(alpha: 0.2),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: val.clamp(min, max),
              min: min,
              max: max,
              divisions: div,
              onChanged: fn,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic macro breakdown calculations
    final double proKcal = _pro * 4;
    final double carbKcal = _carb * 4;
    final double fatKcal = _fat * 9;
    final double totalKcal = proKcal + carbKcal + fatKcal;

    final double proPct = totalKcal > 0 ? proKcal / totalKcal : 0.0;
    final double carbPct = totalKcal > 0 ? carbKcal / totalKcal : 0.0;
    final double fatPct = totalKcal > 0 ? fatKcal / totalKcal : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Adjust Your Targets',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Changes apply immediately',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Premium Segmented Macro Breakdown Widget
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Calorie split estimate",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 10,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white10,
                        ),
                        child: Row(
                          children: [
                            if (proPct > 0)
                              Expanded(
                                flex: (proPct * 100).round(),
                                child: Container(color: const Color(0xFF5B9BF5)),
                              ),
                            if (carbPct > 0)
                              Expanded(
                                flex: (carbPct * 100).round(),
                                child: Container(color: const Color(0xFFF5A623)),
                              ),
                            if (fatPct > 0)
                              Expanded(
                                flex: (fatPct * 100).round(),
                                child: Container(color: const Color(0xFF50E3C2)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _splitLabel('Protein', '${(proPct * 100).round()}%', const Color(0xFF5B9BF5)),
                          _splitLabel('Carbs', '${(carbPct * 100).round()}%', const Color(0xFFF5A623)),
                          _splitLabel('Fats', '${(fatPct * 100).round()}%', const Color(0xFF50E3C2)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _premiumSlider(
                  'Calories',
                  _cal,
                  1200,
                  4000,
                  56,
                  _gold,
                  Icons.local_fire_department_rounded,
                  (v) => setState(() => _cal = v),
                ),
                _premiumSlider(
                  'Protein (g)',
                  _pro,
                  50,
                  300,
                  50,
                  const Color(0xFF5B9BF5),
                  Icons.fitness_center_rounded,
                  (v) => setState(() => _pro = v),
                ),
                _premiumSlider(
                  'Carbs (g)',
                  _carb,
                  50,
                  500,
                  90,
                  const Color(0xFFF5A623),
                  Icons.bolt_rounded,
                  (v) => setState(() => _carb = v),
                ),
                _premiumSlider(
                  'Fats (g)',
                  _fat,
                  20,
                  200,
                  36,
                  const Color(0xFF50E3C2),
                  Icons.water_drop_rounded,
                  (v) => setState(() => _fat = v),
                ),
                _premiumSlider(
                  'Fiber (g)',
                  _fib,
                  10,
                  60,
                  50,
                  const Color(0xFF7ED321),
                  Icons.eco_rounded,
                  (v) => setState(() => _fib = v),
                ),
                const SizedBox(height: 20),
                _goldButton('Save Changes', () async {
                  final p = await SharedPreferences.getInstance();
                  await p.setString(_dk('calories'), _cal.round().toString());
                  await p.setString(_dk('protein'), _pro.round().toString());
                  await p.setString(_dk('carbs'), _carb.round().toString());
                  await p.setString(_dk('fats'), _fat.round().toString());
                  await p.setString(_dk('fiber'), _fib.round().toString());
                  if (context.mounted) Navigator.pop(context, true);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _splitLabel(String name, String pct, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$name: ',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        Text(
          pct,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Add Food Bottom Sheet (Manual log)
// ══════════════════════════════════════════════════════════════
class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet();
  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _proCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fibCtrl = TextEditingController();
  String _selectedMealType = 'snack';

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white30),
    filled: true,
    fillColor: const Color(0xFF111111),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _gold),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    _fibCtrl.dispose();
    super.dispose();
  }

  Widget _mealChip(String value, String label) {
    bool s = _selectedMealType == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(color: s ? Colors.black : Colors.white, fontSize: 12),
      ),
      selected: s,
      selectedColor: _gold,
      backgroundColor: const Color(0xFF111111),
      onSelected: (val) {
        if (val) setState(() => _selectedMealType = value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Log Food Manually',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add what you ate',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  _mealChip('breakfast', 'Breakfast'),
                  _mealChip('lunch', 'Lunch'),
                  _mealChip('dinner', 'Dinner'),
                  _mealChip('snack', 'Snack'),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _deco('Food name (e.g. Chicken breast)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _calCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _deco('Calories'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _proCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _deco('Protein (g)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _carbCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _deco('Carbs (g)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _fatCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _deco('Fats (g)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fibCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _deco('Fiber (g) - optional'),
              ),
              const SizedBox(height: 20),
              _goldButton('Add Food', () async {
                if (_nameCtrl.text.trim().isEmpty ||
                    _calCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Name and calories are required'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                final double pro = double.tryParse(_proCtrl.text) ?? 0.0;
                final double carb = double.tryParse(_carbCtrl.text) ?? 0.0;
                final double fat = double.tryParse(_fatCtrl.text) ?? 0.0;
                final double fib = double.tryParse(_fibCtrl.text) ?? 0.0;
                final int cal = int.tryParse(_calCtrl.text) ?? 0;

                final entry = {
                  'mealType': _selectedMealType,
                  'foods': [
                    {
                      'name': _nameCtrl.text.trim(),
                      'grams': 100.0,
                      'cal': cal,
                      'pro': pro,
                      'carb': carb,
                      'fat': fat,
                      'fib': fib,
                      'isEstimate': false,
                    },
                  ],
                  'totalCalories': cal,
                  'totalProtein': pro,
                  'totalCarbs': carb,
                  'totalFats': fat,
                  'totalFiber': fib,
                  'imagePath': '',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                };

                final p = await SharedPreferences.getInstance();
                final key = _flk();
                final existing = p.getString(key);
                final list = existing != null
                    ? (jsonDecode(existing) as List)
                          .cast<Map<String, dynamic>>()
                    : <Map<String, dynamic>>[];
                list.add(entry);
                await p.setString(key, jsonEncode(list));

                if (context.mounted) Navigator.pop(context, true);
              }),
            ],
          ),
        ),
      ),
    );
  }
}
