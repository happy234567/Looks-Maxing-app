import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// Scan Tutorial Screen — teaches users how to photograph food
// ══════════════════════════════════════════════════════════════

const _tutBg = Color(0xFF1A1A1A);
const _tutCard = Color(0xFF262626);
const _tutGold = Color(0xFFFFD700);
const _tutGreen = Color(0xFF34C759);
const _tutRed = Color(0xFFFF3B30);

class _TutorialPage {
  final String title;
  final String subtitle;
  final String correctAsset;
  final String wrongAsset;
  final String correctLabel;
  final String wrongLabel;

  const _TutorialPage({
    required this.title,
    required this.subtitle,
    required this.correctAsset,
    required this.wrongAsset,
    required this.correctLabel,
    required this.wrongLabel,
  });
}

const List<_TutorialPage> _pages = [
  _TutorialPage(
    title: 'Avoid Top-Down Shots',
    subtitle: 'Photograph your food from a 45° angle\nso the AI can identify each item clearly.',
    correctAsset: 'assets/tutorial/angle_correct.png',
    wrongAsset: 'assets/tutorial/angle_wrong.png',
    correctLabel: '45° angle — items are visible',
    wrongLabel: 'Top-down — hard to identify',
  ),
  _TutorialPage(
    title: 'Use Good Lighting',
    subtitle: 'Natural or bright lighting helps the scanner\ndetect colors, textures, and portions.',
    correctAsset: 'assets/tutorial/lighting_correct.png',
    wrongAsset: 'assets/tutorial/lighting_wrong.png',
    correctLabel: 'Well-lit — clear details',
    wrongLabel: 'Dim / dark — blurry result',
  ),
  _TutorialPage(
    title: 'Show the Full Plate',
    subtitle: 'Make sure all food items are visible\nand nothing is cropped at the edges.',
    correctAsset: 'assets/tutorial/framing_correct.png',
    wrongAsset: 'assets/tutorial/framing_wrong.png',
    correctLabel: 'Full plate in frame',
    wrongLabel: 'Cropped — items missing',
  ),
];

class ScanTutorialScreen extends StatefulWidget {
  const ScanTutorialScreen({super.key});

  @override
  State<ScanTutorialScreen> createState() => _ScanTutorialScreenState();
}

class _ScanTutorialScreenState extends State<ScanTutorialScreen> {
  final PageController _pageCtrl = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_current < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _goBack() {
    if (_current > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tutBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar with close + dots ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // Dot indicators
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_pages.length, (i) {
                      final isActive = i == _current;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? _tutGold : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // Invisible spacer to balance the close button
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── PageView ──
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPage(page);
                },
              ),
            ),

            // ── Bottom navigation ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  // Back button
                  AnimatedOpacity(
                    opacity: _current > 0 ? 1.0 : 0.3,
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _current > 0 ? _goBack : null,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Next / Done button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _goNext,
                      icon: Icon(
                        _current == _pages.length - 1
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _current == _pages.length - 1 ? 'Got It' : 'Next',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tutGold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
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

  Widget _buildPage(_TutorialPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Title
          Text(
            page.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Subtitle
          Text(
            page.subtitle,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // ── Correct image with green check ──
          Expanded(
            child: _imageCard(
              assetPath: page.correctAsset,
              label: page.correctLabel,
              badgeColor: _tutGreen,
              badgeIcon: Icons.check_rounded,
            ),
          ),
          const SizedBox(height: 14),

          // ── Wrong image with red X ──
          Expanded(
            child: _imageCard(
              assetPath: page.wrongAsset,
              label: page.wrongLabel,
              badgeColor: _tutRed,
              badgeIcon: Icons.close_rounded,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _imageCard({
    required String assetPath,
    required String label,
    required Color badgeColor,
    required IconData badgeIcon,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Card with image
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _tutCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Image area
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                  child: Image.asset(
                    assetPath,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => Container(
                      color: _tutCard,
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.white.withValues(alpha: 0.1),
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Label bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(23),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // ── Badge overlay (top-right) ──
        Positioned(
          top: -8,
          right: -8,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              badgeIcon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
