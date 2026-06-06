import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// LiveNutrientProgressBar — animated horizontal progress bar
// with rolling text counter for nutrient tracking
// ══════════════════════════════════════════════════════════════

class LiveNutrientProgressBar extends StatefulWidget {
  /// Current intake value (e.g. grams eaten so far).
  final double currentValue;

  /// Daily target value (e.g. 200g protein goal).
  final double targetValue;

  /// Label shown to the left of the bar (e.g. "Protein").
  final String label;

  /// Fill color of the progress bar.
  final Color barColor;

  /// Optional unit suffix for the counter text (default: "g").
  final String unit;

  /// Optional height of the progress bar (default: 10).
  final double barHeight;

  /// Optional border radius of the bar (default: 6).
  final double barRadius;

  /// Optional duration for the animation (default: 1200ms).
  final Duration duration;

  const LiveNutrientProgressBar({
    super.key,
    required this.currentValue,
    required this.targetValue,
    required this.label,
    required this.barColor,
    this.unit = 'g',
    this.barHeight = 10,
    this.barRadius = 6,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<LiveNutrientProgressBar> createState() =>
      _LiveNutrientProgressBarState();
}

class _LiveNutrientProgressBarState extends State<LiveNutrientProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _valueAnim;
  double _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _valueAnim = Tween<double>(begin: 0, end: widget.currentValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant LiveNutrientProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentValue != widget.currentValue) {
      _oldValue = oldWidget.currentValue;
      _valueAnim = Tween<double>(
        begin: _oldValue,
        end: widget.currentValue,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.targetValue;
    final bool hasTarget = target > 0;

    return AnimatedBuilder(
      animation: _valueAnim,
      builder: (context, _) {
        final animVal = _valueAnim.value;
        final displayVal = animVal.round();
        final fraction = hasTarget ? (animVal / target).clamp(0.0, 1.0) : 0.0;
        final isOver = hasTarget && animVal > target;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Label row ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _RollingCounter(
                  value: displayVal,
                  target: target.round(),
                  unit: widget.unit,
                  color: isOver ? Colors.redAccent : widget.barColor,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Progress bar ──
            ClipRRect(
              borderRadius: BorderRadius.circular(widget.barRadius),
              child: SizedBox(
                height: widget.barHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    // Track
                    Container(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    // Fill
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fraction,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              (isOver ? Colors.redAccent : widget.barColor)
                                  .withValues(alpha: 0.7),
                              isOver ? Colors.redAccent : widget.barColor,
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(widget.barRadius),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Rolling counter text ──
// Animates digits vertically when the value changes.
class _RollingCounter extends StatelessWidget {
  final int value;
  final int target;
  final String unit;
  final Color color;

  const _RollingCounter({
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = '$value / $target$unit';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 4 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Text(
        text,
        key: ValueKey(value),
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
