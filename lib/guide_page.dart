import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:level_maxing/guide_content.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GUIDE PAGE UI
// ─────────────────────────────────────────────────────────────────────────────

class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _openArticle(GuideArticle article) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => _ArticleScreen(article: article),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🔒', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Text('Premium Content',
              style: TextStyle(color: Colors.white, fontSize: 18)),
        ]),
        content: const Text(
          'This guide is available for premium members.\n\nUpgrade to unlock all guides, advanced routines, and expert tips.',
          style: TextStyle(color: Colors.white54, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Upgrade',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Simple Title Header ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Center(
                    child: Text(
                      'Guide',
                      style: TextStyle(
                        color: const Color(0xFFFFD700),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Body content ──────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Premium Banner
                    _premiumBanner(),
                    const SizedBox(height: 28),

                    // Free Guides Section
                    _sectionHeader(
                      tag: 'FREE',
                      title: 'Free Guides',
                      isPremium: false,
                    ),
                    const SizedBox(height: 12),
                    ...freeArticles.map((a) => _ArticleCard(
                          article: a,
                          onTap: () => _openArticle(a),
                        )),

                    const SizedBox(height: 28),

                    // Premium Guides Section
                    _sectionHeader(
                      tag: '👑',
                      title: 'Premium Guides',
                      isPremium: true,
                      showComingSoon: true,
                    ),
                    const SizedBox(height: 12),
                    ...premiumArticles.map((a) => _ArticleCard(
                          article: a,
                          onTap: () => _openArticle(a),
                        )),

                    const SizedBox(height: 24),
                    _comingSoonCard(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _premiumBanner() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _WhyBuyPremiumSheet(),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1200),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.5),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('👑', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WHY BUY PREMIUM?',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '33 expert guides · Progress tracking · Daily Lock-In · Rewards',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFFFD700), size: 22),
              ],
            ),
            const SizedBox(height: 14),
            // CTA Button
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'From ₹249/month — Tap to see why',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String tag,
    required String title,
    required bool isPremium,
    bool showComingSoon = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isPremium)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          )
        else
          Text(tag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        if (showComingSoon) ...[
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1200),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.4)),
            ),
            child: const Text(
              'Coming Soon',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const Spacer(),
        Container(height: 1, width: 40, color: Colors.white10),
      ],
    );
  }

  Widget _comingSoonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        const Text('📚', style: TextStyle(fontSize: 28)),
        const SizedBox(height: 12),
        const Text(
          'More Looksmaxing Course Knowledge',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'COMING SOON',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'New expert guides added regularly.\nStay consistent and check back soon.',
          textAlign: TextAlign.center,
          style:
              TextStyle(color: Colors.white30, fontSize: 12.5, height: 1.6),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ARTICLE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ArticleCard extends StatefulWidget {
  final GuideArticle article;
  final VoidCallback onTap;

  const _ArticleCard({required this.article, required this.onTap});

  @override
  State<_ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<_ArticleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.article;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _pressed
                ? const Color(0xFF1C1C1C)
                : const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(_pressed ? 0.1 : 0.06),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              // Emoji Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(a.emoji,
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: TextStyle(
                        color: a.isPremium
                            ? const Color(0xFFFFD700)
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Arrow or Lock
              Icon(
                a.isPremium
                    ? Icons.lock_outline_rounded
                    : Icons.chevron_right_rounded,
                color: a.isPremium
                    ? const Color(0xFFFFD700).withOpacity(0.6)
                    : Colors.white30,
                size: a.isPremium ? 20 : 22,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ARTICLE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _ArticleScreen extends StatefulWidget {
  final GuideArticle article;
  const _ArticleScreen({required this.article});

  @override
  State<_ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<_ArticleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFFFFD700), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.article.title,
            style:
                const TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(widget.article.emoji,
                style: const TextStyle(fontSize: 44)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.article.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            height: 1.2)),
                    const SizedBox(height: 5),
                    Text(widget.article.subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 14)),
                  ]),
            ),
          ]),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white10),
          const SizedBox(height: 20),
          ...widget.article.sections.map((s) => _buildSection(s)),
          if (widget.article.keyRule != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD700).withOpacity(0.13),
                    const Color(0xFFFFD700).withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.35)),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔑', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Key Rule',
                                style: TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            Text(widget.article.keyRule!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    height: 1.7)),
                          ]),
                    ),
                  ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(GuideSection s) {
    final lines = s.body.split('\n');
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(s.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.title,
                    style: TextStyle(
                        color: s.accentColor,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 4),
            Container(
              height: 2,
              width: 40,
              decoration: BoxDecoration(
                color: s.accentColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            ...lines.where((l) => l.isNotEmpty).map((line) {
              if (line.startsWith('🛒')) {
                final text = line.substring(2).trim();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12, top: 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            const Color(0xFFFFD700).withOpacity(0.4)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🛒',
                            style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(child: _styledText(text)),
                      ]),
                );
              }
              if (line.startsWith('* ') || line.startsWith('- ')) {
                final text = line.substring(2);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(
                              top: 8, right: 10),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: s.accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(child: _styledText(text)),
                      ]),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _styledText(line),
              );
            }),
          ]),
    );
  }

  Widget _styledText(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, m.start),
          style: const TextStyle(
              color: Colors.white70, fontSize: 16, height: 1.7),
        ));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1.75),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last),
        style: const TextStyle(
            color: Colors.white70, fontSize: 16, height: 1.7),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WHY BUY PREMIUM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _WhyBuyPremiumSheet extends StatelessWidget {
  const _WhyBuyPremiumSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              const Text('👑', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'WHY BUY PREMIUM?',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Container(
              height: 1,
              color: Colors.white10,
              margin: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8)),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                _premiumBlock(
                  emoji: '🚀',
                  title: 'Unlock Your Full Potential',
                  body:
                      'Get the knowledge, tools, and tracking system designed to help you improve consistently and see real progress.',
                ),
                _pricingBlock(),
                _premiumBlock(
                  emoji: '📚',
                  title: 'Course-Level Guides',
                  body: 'Premium gives you structured guides covering:',
                  bullets: [
                    'Facial improvement strategies',
                    'Skincare & grooming routines',
                    'Fitness & body improvement habits',
                    'Confidence & mindset development',
                    'Lifestyle habits that improve attractiveness',
                  ],
                  footer:
                      'Instead of buying many expensive courses, everything is organized in one app.',
                ),
                _premiumBlock(
                  emoji: '📈',
                  title: 'Track Your Real Progress',
                  body:
                      'Most courses only give advice. Our Face Scan system shows if you are actually improving.',
                  bullets: [
                    'Weekly face scans',
                    'Real improvement score',
                    'Progress charts over time',
                  ],
                  footer: 'See your real progress instead of guessing.',
                ),
                _premiumBlock(
                  emoji: '🎯',
                  title: 'Daily Lock-In System',
                  body:
                      'Build discipline with the Daily To-Do / Lock-In system.',
                  bullets: [
                    'Create your own improvement tasks',
                    'Stay consistent with routines',
                    'Track your streaks and habits',
                  ],
                  footer: 'Available for both free and premium users.',
                ),
                _rewardsBlock(),
                _premiumBlock(
                  emoji: '⭐',
                  title: 'Why Users Choose Premium',
                  body: '',
                  bullets: [
                    'Influencer-level knowledge',
                    'Real weekly progress tracking',
                    'Structured improvement system',
                    'Growing library of guides',
                    'Reward opportunities for consistency',
                  ],
                  footer: 'Everything you need in one place.',
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(children: [
                    Text('🔓', style: TextStyle(fontSize: 32)),
                    SizedBox(height: 8),
                    Text(
                      'Start Improving Today',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your progress starts the moment you begin.\nUpgrade to Premium and start your journey. 🚀',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _premiumBlock({
    required String emoji,
    required String title,
    required String body,
    List<String>? bullets,
    String? footer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(body,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5)),
            ],
            if (bullets != null) ...[
              const SizedBox(height: 8),
              ...bullets.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('✔ ',
                              style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          Expanded(
                              child: Text(b,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.4))),
                        ]),
                  )),
            ],
            if (footer != null) ...[
              const SizedBox(height: 8),
              Text(footer,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontStyle: FontStyle.italic)),
            ],
          ]),
    );
  }

  Widget _pricingBlock() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withOpacity(0.12),
            const Color(0xFFFF8C00).withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.4)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Text('💰', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Premium is 15× Cheaper Than Influencer Courses',
                  style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            const Text('Typical influencer course:',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const Text('₹4,500 / month',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 15,
                    decoration: TextDecoration.lineThrough)),
            const SizedBox(height: 10),
            const Text('Our Premium Plans:',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _priceRow('₹299 / month', '', false),
            const SizedBox(height: 6),
            _priceRow('₹1499 / 6 months', '₹249/month', true),
            const SizedBox(height: 6),
            _priceRow('₹2799 / 12 months', '₹233/month', false),
            const SizedBox(height: 10),
            const Text(
              'Get the same core knowledge without spending thousands.',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
          ]),
    );
  }

  Widget _priceRow(String price, String sub, bool isBest) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isBest
            ? const Color(0xFFFFD700).withOpacity(0.15)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBest
              ? const Color(0xFFFFD700).withOpacity(0.7)
              : Colors.white12,
          width: isBest ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            price,
            style: TextStyle(
              color: isBest ? const Color(0xFFFFD700) : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (sub.isNotEmpty)
          Text(sub,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 12)),
        if (isBest) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '⭐ Most Popular',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _rewardsBlock() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Text('🏆', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '150-Day Consistency Challenge',
                  style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Users with 6-Month or 12-Month Premium can join the 150-Day Challenge. Stay consistent and get a chance to win:',
              style: TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 10),
            ...[
              '🎁  Amazon vouchers worth up to ₹2,000',
              '🎁  Free products',
              '🎁  Protein powder',
              '🎁  Creatine supplements',
              '🎁  Chance to become the face of our app on social media',
              '🎁  Opportunity to work with our team',
            ].map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(r,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4)),
                )),
            const SizedBox(height: 8),
            const Text(
              'Your consistency can earn real rewards.',
              style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic),
            ),
          ]),
    );
  }
}