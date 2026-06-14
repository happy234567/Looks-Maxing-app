import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'nutrition_db_helper.dart';
import 'food_log_page.dart';

class FoodDetailScreen extends StatefulWidget {
  final Map<String, dynamic> entry;
  final DateTime selectedDate;

  const FoodDetailScreen({
    super.key,
    required this.entry,
    required this.selectedDate,
  });

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  late Map<String, dynamic> _entry;
  late List<dynamic> _foods;
  late String _description;
  late TextEditingController _descriptionController;
  bool _isRewriting = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _foods = _entry['foods'] as List? ?? [];
    _description = _entry['description'] as String? ?? '';
    _descriptionController = TextEditingController(text: _description);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<File> _getImageFile(String path) async {
    if (path.startsWith('http')) {
      final response = await http.get(Uri.parse(path));
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_food_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(response.bodyBytes);
      return tempFile;
    } else {
      final file = File(path);
      if (await file.exists()) {
        return file;
      }
      throw Exception("Food image file not found locally.");
    }
  }

  Future<void> _rewriteMealWithAI(String newDesc) async {
    setState(() {
      _isRewriting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Please log in to use AI rewrite.");
      final token = await user.getIdToken(true);
      if (token == null) throw Exception("Authentication failed.");

      final imagePath = _entry['imagePath'] as String?;
      if (imagePath == null || imagePath.isEmpty) {
        throw Exception("Cannot rewrite: food image is required.");
      }

      final imageFile = await _getImageFile(imagePath);

      final uri = Uri.parse('https://level-maxing-backend.onrender.com/food-analyze');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['mealType'] = _entry['mealType'] ?? 'snack';
      request.fields['description'] = newDesc;
      request.fields['correction'] = newDesc;

      request.files.add(
        await http.MultipartFile.fromPath(
          'frontImage',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        try {
          final errData = jsonDecode(response.body);
          throw Exception(errData['error'] as String? ?? 'AI analysis failed.');
        } catch (_) {
          throw Exception('Server error (${response.statusCode})');
        }
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] as String? ?? 'Analysis was unsuccessful.');
      }

      final List<dynamic> foodsList = data['foods'] as List? ?? [];
      if (foodsList.isEmpty) {
        throw Exception('No food detected. Please check your description.');
      }

      final List<Map<String, dynamic>> updatedFoods = [];
      double mealPro = 0, mealCarb = 0, mealFat = 0, mealFib = 0;
      int mealCal = 0;

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

        FoodNutritionResult finalRes;

        if (cal != null || pro != null || carb != null || fat != null) {
          finalRes = FoodNutritionResult(
            foodName: name,
            grams: grams,
            calories: cal?.toInt() ?? 0,
            protein: pro?.toDouble() ?? 0.0,
            carbs: carb?.toDouble() ?? 0.0,
            fats: fat?.toDouble() ?? 0.0,
            fiber: fib?.toDouble() ?? 0.0,
            isEstimate: false,
            confidence: defaultConf,
          );
        } else {
          var lookupResult = await NutritionDB.lookup(name, grams);
          lookupResult ??= NutritionDB.getFallbackEstimate(name, grams);
          finalRes = lookupResult;
        }

        updatedFoods.add(finalRes.toMap());
        mealCal += finalRes.calories;
        mealPro += finalRes.protein;
        mealCarb += finalRes.carbs;
        mealFat += finalRes.fats;
        mealFib += finalRes.fiber;
      }

      final p = await SharedPreferences.getInstance();
      final todayStr = widget.selectedDate.toIso8601String().substring(0, 10);
      final logKey = 'food_log_${user.uid}_$todayStr';
      final logJson = p.getString(logKey);

      if (logJson != null && logJson.isNotEmpty) {
        final List<Map<String, dynamic>> logList = (jsonDecode(logJson) as List)
            .cast<Map<String, dynamic>>();

        int entryIndex = -1;
        for (int i = 0; i < logList.length; i++) {
          if (logList[i]['id'] == _entry['id'] || logList[i]['timestamp'] == _entry['timestamp']) {
            entryIndex = i;
            break;
          }
        }

        if (entryIndex != -1) {
          final updatedEntry = Map<String, dynamic>.from(logList[entryIndex]);
          updatedEntry['foods'] = updatedFoods;
          updatedEntry['totalCalories'] = mealCal;
          updatedEntry['totalProtein'] = mealPro;
          updatedEntry['totalCarbs'] = mealCarb;
          updatedEntry['totalFats'] = mealFat;
          updatedEntry['totalFiber'] = mealFib;
          updatedEntry['description'] = newDesc;
          updatedEntry['syncStatus'] = 'pending';

          logList[entryIndex] = updatedEntry;
          await p.setString(logKey, jsonEncode(logList));

          setState(() {
            _entry = updatedEntry;
            _foods = updatedFoods;
            _description = newDesc;
            _hasChanges = true;
          });

          // Trigger background update to Firestore
          _runBackgroundUpdate(
            entryId: _entry['id'] ?? '',
            timestamp: _entry['timestamp'] as num,
            uid: user.uid,
            todayStr: todayStr,
            logKey: logKey,
            updatedEntry: {
              'id': _entry['id'],
              'syncStatus': 'pending',
              'mealType': _entry['mealType'],
              'foods': updatedFoods,
              'totalCalories': mealCal,
              'totalProtein': mealPro,
              'totalCarbs': mealCarb,
              'totalFats': mealFat,
              'totalFiber': mealFib,
              'imagePath': _entry['imagePath'],
              'timestamp': _entry['timestamp'],
              'description': newDesc,
            },
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("✓ Saved & updated successfully with AI!"),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to rewrite: ${e.toString().replaceFirst('Exception: ', '')}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRewriting = false;
        });
      }
    }
  }

  Future<void> _runBackgroundUpdate({
    required String entryId,
    required num timestamp,
    required String uid,
    required String todayStr,
    required String logKey,
    required Map<String, dynamic> updatedEntry,
  }) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('food_logs')
          .where('timestamp', isEqualTo: timestamp)
          .get();

      if (query.docs.isNotEmpty) {
        for (var doc in query.docs) {
          await doc.reference.update({
            ...updatedEntry,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('food_logs')
            .add({
              ...updatedEntry,
              'createdAt': FieldValue.serverTimestamp(),
              'expiresAt': DateTime.now().add(const Duration(days: 15)),
            });
      }

      await _markEntrySyncSuccess(logKey, entryId, timestamp);
    } catch (e) {
      debugPrint('Failed to update Firestore food log: $e');
      await _markEntrySyncFailed(logKey, entryId, timestamp);
    }
  }

  Future<void> _markEntrySyncSuccess(String logKey, String entryId, num timestamp) async {
    final p = await SharedPreferences.getInstance();
    final logJson = p.getString(logKey);
    if (logJson != null && logJson.isNotEmpty) {
      try {
        final List<Map<String, dynamic>> logList = (jsonDecode(logJson) as List)
            .cast<Map<String, dynamic>>();
        for (var entry in logList) {
          if (entry['id'] == entryId || entry['timestamp'] == timestamp) {
            entry['syncStatus'] = 'synced';
            break;
          }
        }
        await p.setString(logKey, jsonEncode(logList));
        foodLogUpdateNotifier.value++;
      } catch (_) {}
    }
  }

  Future<void> _markEntrySyncFailed(String logKey, String entryId, num timestamp) async {
    final p = await SharedPreferences.getInstance();
    final logJson = p.getString(logKey);
    if (logJson != null && logJson.isNotEmpty) {
      try {
        final List<Map<String, dynamic>> logList = (jsonDecode(logJson) as List)
            .cast<Map<String, dynamic>>();
        for (var entry in logList) {
          if (entry['id'] == entryId || entry['timestamp'] == timestamp) {
            entry['syncStatus'] = 'failed';
            break;
          }
        }
        await p.setString(logKey, jsonEncode(logList));
        foodLogUpdateNotifier.value++;
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate totals for the entire meal
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFats = 0;
    double totalFiber = 0;
    int totalGrams = 0;

    for (var f in _foods) {
      totalCalories += f['cal'] as num? ?? 0;
      totalProtein += f['pro'] as num? ?? 0;
      totalCarbs += f['carb'] as num? ?? 0;
      totalFats += f['fat'] as num? ?? 0;
      totalFiber += f['fib'] as num? ?? 0;
      totalGrams += (f['grams'] as num?)?.round() ?? 100;
    }

    // Calculate calories from each macro
    double proteinKcal = totalProtein * 4;
    double carbsKcal = totalCarbs * 4;
    double fatsKcal = totalFats * 9;
    double macroTotalKcal = proteinKcal + carbsKcal + fatsKcal;

    double proteinPct = macroTotalKcal > 0 ? (proteinKcal / macroTotalKcal) : 0;
    double carbsPct = macroTotalKcal > 0 ? (carbsKcal / macroTotalKcal) : 0;
    double fatsPct = macroTotalKcal > 0 ? (fatsKcal / macroTotalKcal) : 0;

    final imagePath = _entry['imagePath'] as String?;
    final hasImage = imagePath != null && imagePath.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Collapsible Header with Food Image & Parallax Effect
          SliverAppBar(
            expandedHeight: hasImage ? 360 : 160,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF0F0F0F),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFFFD700)),
                  onPressed: () => Navigator.pop(context, _hasChanges),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage) ...[
                    Hero(
                      tag: imagePath,
                      child: imagePath.startsWith('http')
                          ? Image.network(
                              imagePath,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(imagePath),
                              fit: BoxFit.cover,
                            ),
                    ),
                    // Elegant dark gradient overlays
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black54,
                            Colors.transparent,
                            Color(0xFF0F0F0F),
                          ],
                          stops: [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Abstract Premium Background if no image
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1C1A10), Color(0xFF0F0F0F)],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.restaurant_menu_rounded,
                          size: 72,
                          color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  ],
                  // Floating title bar overlay
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            "ANALYSIS COMPLETE",
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _foods.length == 1 
                              ? (_foods.first['name'] as String? ?? 'Food Details')
                              : "Meal Breakdown",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                offset: Offset(0, 2),
                                blurRadius: 10,
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Summary Section
                  _buildSummarySection(
                    totalCalories.round(),
                    totalGrams,
                    proteinPct,
                    carbsPct,
                    fatsPct,
                  ),
                  const SizedBox(height: 28),

                  // Macronutrients Grid
                  const Text(
                    "MACRONUTRIENTS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMacrosGrid(totalProtein, totalCarbs, totalFats, totalFiber),
                  const SizedBox(height: 32),

                  // AI Description & Rewrite Section
                  _buildAIDescriptionSection(),
                  const SizedBox(height: 32),

                  // Items List Section
                  if (_foods.length > 1) ...[
                    const Text(
                      "ITEMS IN THIS MEAL",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._foods.map((f) => _buildIndividualFoodCard(f)),
                  ] else if (_foods.isNotEmpty) ...[
                    const Text(
                      "AI ESTIMATION INSIGHTS",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildEstimationInsights(_foods.first),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Summary header containing calories dial and calorie split
  Widget _buildSummarySection(
    int calories,
    int grams,
    double proteinPct,
    double carbsPct,
    double fatsPct,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Circular progress visual for calories
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: (calories / 1200).clamp(0.0, 1.0),
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "$calories",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "kcal",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),
              // Meal overview stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Total Calories",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Based on an estimated portion of ${grams}g.",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          // Calorie source split description
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Calorie Source Split",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "${(proteinPct * 100).round()}% P  ·  ${(carbsPct * 100).round()}% C  ·  ${(fatsPct * 100).round()}% F",
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Horizontal stacked bar representation
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (proteinPct > 0)
                    Expanded(
                      flex: (proteinPct * 100).round().clamp(1, 100),
                      child: Container(color: const Color(0xFF4ADE80)),
                    ),
                  if (carbsPct > 0)
                    Expanded(
                      flex: (carbsPct * 100).round().clamp(1, 100),
                      child: Container(color: const Color(0xFF60A5FA)),
                    ),
                  if (fatsPct > 0)
                    Expanded(
                      flex: (fatsPct * 100).round().clamp(1, 100),
                      child: Container(color: const Color(0xFFF87171)),
                    ),
                  if (proteinPct == 0 && carbsPct == 0 && fatsPct == 0)
                    Expanded(
                      child: Container(color: Colors.white12),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Grid layout for macro items
  Widget _buildMacrosGrid(
    double protein,
    double carbs,
    double fats,
    double fiber,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildMacroCard(
          "PROTEIN",
          protein,
          const Color(0xFF4ADE80),
          Icons.fitness_center_rounded,
        ),
        _buildMacroCard(
          "CARBS",
          carbs,
          const Color(0xFF60A5FA),
          Icons.grain_rounded,
        ),
        _buildMacroCard(
          "FATS",
          fats,
          const Color(0xFFF87171),
          Icons.opacity_rounded,
        ),
        _buildMacroCard(
          "FIBER",
          fiber,
          const Color(0xFFA78BFA),
          Icons.eco_rounded,
        ),
      ],
    );
  }

  // Individual Macro Card Component
  Widget _buildMacroCard(
    String label,
    double val,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(icon, color: color.withValues(alpha: 0.4), size: 18),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                val.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              const Text(
                "g",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (val / 100).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  // Custom visual card for foods when there are multiple items
  Widget _buildIndividualFoodCard(dynamic f) {
    final name = f['name'] as String? ?? 'Food';
    final cal = f['cal'] as num? ?? 0;
    final pro = f['pro'] as num? ?? 0;
    final carb = f['carb'] as num? ?? 0;
    final fat = f['fat'] as num? ?? 0;
    final fib = f['fib'] as num? ?? 0;
    final grams = (f['grams'] as num?)?.round() ?? 100;
    final isEst = f['isEstimate'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                "${cal.round()} kcal",
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                "${isEst ? '~' : ''}${grams}g portion size",
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              if (isEst) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "ESTIMATE",
                    style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          // Individual food mini macro bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniMacroText("P", pro, const Color(0xFF4ADE80)),
              _miniMacroText("C", carb, const Color(0xFF60A5FA)),
              _miniMacroText("F", fat, const Color(0xFFF87171)),
              _miniMacroText("Fb", fib, const Color(0xFFA78BFA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMacroText(String label, num val, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        Text(
          "${val.toStringAsFixed(1)}g",
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Display AI insights card for single food items
  Widget _buildEstimationInsights(dynamic f) {
    final isEst = f['isEstimate'] == true;
    final confidence = f['confidence'] as num? ?? 0.8;
    String confStr = "HIGH";
    Color confColor = const Color(0xFF4ADE80);

    if (confidence < 0.6) {
      confStr = "LOW";
      confColor = const Color(0xFFF87171);
    } else if (confidence < 0.9) {
      confStr = "MEDIUM";
      confColor = const Color(0xFF60A5FA);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.query_stats_rounded, color: const Color(0xFFFFD700).withValues(alpha: 0.8), size: 20),
              const SizedBox(width: 10),
              const Text(
                "AI Recognition Quality",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _insightRow(
            "Confidence Match", 
            confStr,
            badgeColor: confColor.withValues(alpha: 0.15),
            textColor: confColor,
          ),
          const SizedBox(height: 12),
          _insightRow(
            "Volume Estimation", 
            isEst ? "3D Mesh Fallback" : "Standardized Database Match",
            textColor: Colors.white70,
          ),
          const SizedBox(height: 12),
          _insightRow(
            "Nutritional Standard", 
            "USDA",
            textColor: Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _insightRow(
    String title, 
    String value, {
    Color? badgeColor, 
    required Color textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: badgeColor != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                ),
        ),
      ],
    );
  }

  Widget _buildAIDescriptionSection() {
    final bool isToday = _isToday(widget.selectedDate);

    if (!isToday && _description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFFD700),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "AI Description & Insights",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Edit this to recalculate calories & macros",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (isToday) ...[
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "e.g., Cooked rice 150g, chicken curry 100g, added 1 tsp olive oil",
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                filled: true,
                fillColor: const Color(0xFF0F0F0F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFFFD700),
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (val) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isRewriting
                    ? null
                    : () {
                        final newDesc = _descriptionController.text.trim();
                        if (newDesc.isNotEmpty) {
                          _rewriteMealWithAI(newDesc);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                  disabledForegroundColor: Colors.white30,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isRewriting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Rewrite & Recalculate with AI",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ] else ...[
            Text(
              _description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
