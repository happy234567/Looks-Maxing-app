import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'challenge_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHALLENGE RESULT SCREEN
// Full-screen result when challenge ends:
//   • Eligible → confetti + "You're in the Giveaway!"
//   • Not eligible → accuracy comparison + "Start New Challenge"
// ─────────────────────────────────────────────────────────────────────────────

class ChallengeResultScreen extends StatefulWidget {
  final ChallengeData challenge;
  const ChallengeResultScreen({super.key, required this.challenge});

  @override
  State<ChallengeResultScreen> createState() => _ChallengeResultScreenState();
}

class _ChallengeResultScreenState extends State<ChallengeResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;
  late AnimationController _confettiCtrl;
  final List<_ConfettiParticle> _particles = [];
  final math.Random _rand = math.Random();

  bool get _isEligible => widget.challenge.isEligible;

  @override
  void initState() {
    super.initState();

    // Scale-bounce entrance
    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut));

    // Confetti for eligible users
    _confettiCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6));

    if (_isEligible) {
      _initParticles();
      _confettiCtrl.addListener(_updateParticles);
      _confettiCtrl.forward();
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _scaleCtrl.forward();
    });
  }

  void _initParticles() {
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFF4081),
      const Color(0xFF9C27B0),
      const Color(0xFFFF9800),
      const Color(0xFF00BCD4),
      const Color(0xFFE91E63),
    ];

    for (int i = 0; i < 180; i++) {
      _particles.add(_ConfettiParticle(
        x: _rand.nextDouble() * 500,
        y: -_rand.nextDouble() * 900 - 60,
        size: _rand.nextDouble() * 9 + 4,
        speed: _rand.nextDouble() * 4 + 1.5,
        rotation: _rand.nextDouble() * math.pi * 2,
        rotationSpeed: (_rand.nextDouble() - 0.5) * 0.15,
        color: colors[_rand.nextInt(colors.length)],
        drift: (_rand.nextDouble() - 0.5) * 1.8,
        opacity: _rand.nextDouble() * 0.4 + 0.6,
      ));
    }
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.y += p.speed;
      p.x += p.drift + math.sin(p.y * 0.02) * 0.5; // slight sway
      p.rotation += p.rotationSpeed;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = (widget.challenge.calculatedAccuracy * 100).round();
    const primaryColor = Color(0xFFFFD700);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // ── Background radial glow ──
          if (_isEligible)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      primaryColor.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          // ── Confetti layer ──
          if (_isEligible)
            Positioned.fill(
              child: CustomPaint(painter: _ConfettiPainter(_particles)),
            ),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 40),

                      // Emoji
                      Text(
                        _isEligible ? '🎉' : '😔',
                        style: const TextStyle(fontSize: 80),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        _isEligible ? 'You Made It!' : 'Almost There',
                        style: TextStyle(
                          color: _isEligible ? primaryColor : Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Subtitle
                      Text(
                        _isEligible
                            ? 'You\'re in the Giveaway! 🎁\nYou completed the ${widget.challenge.totalDays}-day challenge with $accuracy% accuracy.'
                            : 'You needed 80% accuracy but achieved $accuracy%.\nDon\'t give up — start again!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Stats card ──
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statColumn(
                                '📅',
                                'Days',
                                '${widget.challenge.completedDays}/${widget.challenge.totalDays}'),
                            Container(
                                width: 1,
                                height: 40,
                                color: Colors.white.withValues(alpha: 0.1)),
                            _statColumn('🎯', 'Accuracy', '$accuracy%'),
                            Container(
                                width: 1,
                                height: 40,
                                color: Colors.white.withValues(alpha: 0.1)),
                            _statColumn(
                                '🔥', 'Best Streak', '${widget.challenge.streak}'),
                          ],
                        ),
                      ),

                      // ── Accuracy comparison (for not eligible) ──
                      if (!_isEligible) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252)
                                .withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: const Color(0xFFFF5252)
                                    .withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _comparisonCol('Required', '80%',
                                  const Color(0xFF4CAF50)),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                                child: const Icon(Icons.arrow_forward,
                                    color: Colors.white24, size: 20),
                              ),
                              _comparisonCol('Achieved', '$accuracy%',
                                  const Color(0xFFFF5252)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // ── CTA Button ──
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isEligible
                                ? primaryColor
                                : const Color(0xFF2196F3),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            elevation: 8,
                            shadowColor: (_isEligible
                                    ? primaryColor
                                    : const Color(0xFF2196F3))
                                .withValues(alpha: 0.4),
                          ),
                          child: Text(
                            _isEligible ? '🏆 Awesome!' : '🔄 Back to Lock In',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String emoji, String label, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _comparisonCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 28, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFETTI PARTICLE SYSTEM
// ─────────────────────────────────────────────────────────────────────────────

class _ConfettiParticle {
  double x, y, size, speed, rotation, rotationSpeed, drift, opacity;
  Color color;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.drift,
    this.opacity = 1.0,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Skip particles that are well off-screen
      if (p.y > size.height + 30 || p.y < -60) continue;
      if (p.x < -30 || p.x > size.width + 30) continue;

      final paint = Paint()..color = p.color.withValues(alpha: p.opacity);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      // Draw a small rectangle (confetti piece)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1.5),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
