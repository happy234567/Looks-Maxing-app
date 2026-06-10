import 'dart:io';
import 'package:flutter/material.dart';

class FoodDetailScreen extends StatelessWidget {
  final List<dynamic> foods;
  final String? imagePath;

  const FoodDetailScreen({
    super.key,
    required this.foods,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate totals for the entire meal
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFats = 0;
    double totalFiber = 0;
    int totalGrams = 0;

    for (var f in foods) {
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

    final hasImage = imagePath != null && imagePath!.isNotEmpty;

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
                  onPressed: () => Navigator.pop(context),
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
                      tag: imagePath!,
                      child: Image.file(
                        File(imagePath!),
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
                          foods.length == 1 
                              ? (foods.first['name'] as String? ?? 'Food Details')
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

                  // Items List Section
                  if (foods.length > 1) ...[
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
                    ...foods.map((f) => _buildIndividualFoodCard(f)),
                  ] else if (foods.isNotEmpty) ...[
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
                    _buildEstimationInsights(foods.first),
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
            "USDA / Indian Food Composition Tables",
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
}
