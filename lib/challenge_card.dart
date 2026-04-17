import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'challenge_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHALLENGE PROGRESS RING — CustomPainter with glow effect
// ─────────────────────────────────────────────────────────────────────────────

class _ChallengeProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color secondaryColor;
  final double strokeWidth = 10;
  final double glowIntensity;

  _ChallengeProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.secondaryColor,
    this.glowIntensity = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth * 2) / 2;

    // ── Track (subtle ring) ──
    final trackPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // ── Glow behind progress arc ──
    if (progress > 0) {
      final glowPaint = Paint()
        ..color = progressColor.withValues(alpha: 0.25 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        glowPaint,
      );
    }

    // ── Progress arc with gradient ──
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: [progressColor, secondaryColor, progressColor],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );

      // ── Bright dot at the end of the arc ──
      final angle = -math.pi / 2 + 2 * math.pi * progress;
      final dotCenter = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final dotPaint = Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(dotCenter, 4, dotPaint);
      canvas.drawCircle(dotCenter, 2.5, Paint()..color = progressColor);
    }
  }

  @override
  bool shouldRepaint(covariant _ChallengeProgressPainter old) =>
      old.progress != progress ||
      old.glowIntensity != glowIntensity ||
      old.progressColor != progressColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// CHALLENGE CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class ChallengeCard extends StatefulWidget {
  final ChallengeData challenge;
  final VoidCallback? onViewResult;

  const ChallengeCard({super.key, required this.challenge, this.onViewResult});

  @override
  State<ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<ChallengeCard>
    with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Glow border animation (continuous)
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    _glowAnim = Tween<double>(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _glowCtrl.repeat(reverse: true);

    // Progress ring fill animation (one-shot)
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _progressAnim = Tween<double>(begin: 0, end: widget.challenge.progress)
        .animate(CurvedAnimation(
            parent: _progressCtrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _progressCtrl.forward();
    });

    // Pulse animation for eligible badge
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    if (widget.challenge.calculatedAccuracy >= 0.8) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ChallengeCard old) {
    super.didUpdateWidget(old);
    if (old.challenge.progress != widget.challenge.progress) {
      _progressAnim =
          Tween<double>(begin: _progressAnim.value, end: widget.challenge.progress)
              .animate(CurvedAnimation(
                  parent: _progressCtrl, curve: Curves.easeOutCubic));
      _progressCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _progressCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Theme helpers ─────────────────────────────────────────────────────────

  bool get _is350 => widget.challenge.planType == '12_month';

  List<Color> get _gradientColors => _is350
      ? [const Color(0xFF12082A), const Color(0xFF081428)]
      : [const Color(0xFF1A1800), const Color(0xFF0D1A0A)];

  Color get _primaryColor =>
      _is350 ? const Color(0xFF7B68EE) : const Color(0xFFFFD700);

  Color get _secondaryColor =>
      _is350 ? const Color(0xFF00D4FF) : const Color(0xFF4CAF50);

  Color get _borderColor =>
      _is350 ? const Color(0xFF9C27B0) : const Color(0xFFFFD700);

  Color _accuracyColor(double accuracy) {
    if (accuracy >= 0.9) return const Color(0xFF4CAF50);
    if (accuracy >= 0.8) return const Color(0xFFFFEB3B);
    return const Color(0xFFFF5252);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final accuracy = c.calculatedAccuracy;
    final accuracyPct = (accuracy * 100).round();
    final isEligible = accuracy >= 0.8;
    final challengeDay = c.challengeDay;

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color:
                    _borderColor.withValues(alpha: 0.35 * _glowAnim.value),
                blurRadius: 28 * _glowAnim.value,
                spreadRadius: 2 * _glowAnim.value,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _gradientColors,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _borderColor
                    .withValues(alpha: 0.5 + 0.5 * _glowAnim.value),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title ──
                Text(
                  _is350
                      ? '👑 350 Day Mega Challenge'
                      : '🏆 150 Day Challenge',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Complete with 80%+ accuracy to enter giveaway',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Circular Progress Ring ──
                Center(
                  child: AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (context, _) {
                      return SizedBox(
                        width: 130,
                        height: 130,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(130, 130),
                              painter: _ChallengeProgressPainter(
                                progress: _progressAnim.value,
                                progressColor: _primaryColor,
                                secondaryColor: _secondaryColor,
                                glowIntensity: _glowAnim.value,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Day $challengeDay',
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'of ${c.totalDays}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Eligibility badge
                                AnimatedBuilder(
                                  animation: _pulseAnim,
                                  builder: (context, _) {
                                    return Transform.scale(
                                      scale:
                                          isEligible ? _pulseAnim.value : 1.0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (isEligible
                                                  ? const Color(0xFF4CAF50)
                                                  : const Color(0xFFFF5252))
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: (isEligible
                                                    ? const Color(0xFF4CAF50)
                                                    : const Color(0xFFFF5252))
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Text(
                                          isEligible
                                              ? 'Eligible ✓'
                                              : 'Not Yet',
                                          style: TextStyle(
                                            color: isEligible
                                                ? const Color(0xFF4CAF50)
                                                : const Color(0xFFFF5252),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // ── Key Metrics Row ──
                Row(
                  children: [
                    Expanded(
                      child: _metricTile(
                        emoji: '🔥',
                        label: 'Streak',
                        value: '${c.streak} days',
                        color: const Color(0xFFFF6B35),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metricTile(
                        emoji: '🎯',
                        label: 'Accuracy',
                        value: '$accuracyPct%',
                        color: _accuracyColor(accuracy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Giveaway Status Section ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎁 Giveaway Status',
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _statusStat(
                            'Eligibility',
                            isEligible ? 'Yes' : 'No',
                            isEligible
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF5252),
                          ),
                          _statusStat(
                              'Days Left', '${c.daysRemaining}', _secondaryColor),
                          _statusStat(
                              'Completed', '${c.completedDays}', _primaryColor),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isEligible
                            ? '🌟 You\'re in the top 20%! Keep it going!'
                            : '💪 Complete tasks daily to reach 80% accuracy',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── View Result CTA (when challenge completed) ──
                if (c.isCompleted && !c.resultNotified) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: widget.onViewResult,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [_primaryColor, _secondaryColor]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        '🎉 View Your Result!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Metric tile ───────────────────────────────────────────────────────────

  Widget _metricTile({
    required String emoji,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Status stat column ────────────────────────────────────────────────────

  Widget _statusStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 9)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
