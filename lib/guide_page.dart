import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:level_maxing/guide_content.dart';
import 'billing_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  final BillingService _billingService = BillingService();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    
    // Listen for when the user buys premium so the page updates!
    _billingService.addListener(_onBillingUpdated);
  }

  // Rebuild the screen when billing state changes
  void _onBillingUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Stop listening when we leave the page
    _billingService.removeListener(_onBillingUpdated);
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _openArticle(GuideArticle article) {
    HapticFeedback.selectionClick();

    // Block premium articles if user is not premium
    if (article.isPremium && !_billingService.isPremium) {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF111111),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, color: Color(0xFFFFD700), size: 48),
              const SizedBox(height: 16),
              const Text(
                'Premium Guide',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This guide is only available for Premium members. Upgrade to unlock all expert guides.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFF0A0A0A),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => _WhyBuyPremiumSheet(billingService: _billingService),
                    );
                  },
                  child: const Text('Upgrade to Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    
                    // Only show the banner if the user is NOT premium
                    if (!_billingService.isPremium) ...[
                      _premiumBanner(),
                      const SizedBox(height: 28),
                    ],

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

                    // Premium Guides Section Header
                    _premiumSectionHeader(),
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

  Widget _premiumSectionHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.4)),
            ),
            child: const Center(
                child: Text('👑', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Guides',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Exclusive guides for premium members',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    color: Color(0xFFFFD700), size: 12),
                SizedBox(width: 4),
                Text(
                  'Locked',
                  style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumBanner() {
    // NEW: Calculate the cheapest monthly price dynamically from the yearly plan
    String startingPriceText = 'Tap to see why';
    try {
      final yearlyProduct = _billingService.products.firstWhere((p) => p.id == 'premium_yearly');
      final cheapestMonthly = yearlyProduct.rawPrice / 12;
      startingPriceText = 'From ${yearlyProduct.currencySymbol}${cheapestMonthly.toStringAsFixed(0)}/month — Tap to see why';
    } catch (e) {
      // Fallback if products haven't loaded yet from Google Play
      startingPriceText = 'View Premium Plans — Tap to see why';
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _WhyBuyPremiumSheet(billingService: _billingService),
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
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.08),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
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
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                // NEW: Use the dynamic text here!
                startingPriceText,
                style: const TextStyle(
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
    final isPremium = a.isPremium;

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
            // Premium cards get a dark gold tint background
            color: isPremium
                ? const Color(0xFF181818)
                : (_pressed ? const Color(0xFF1C1C1C) : const Color(0xFF141414)),
            borderRadius: BorderRadius.circular(16),
            // Glowing gold border for premium, subtle white for free
            border: Border.all(
              color: isPremium
                  ? const Color(0xFFFFD700).withOpacity(_pressed ? 0.8 : 0.55)
                  : Colors.white.withOpacity(_pressed ? 0.1 : 0.06),
              width: isPremium ? 1.5 : 1,
            ),
            // Glow shadow only for premium
            boxShadow: isPremium
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.06),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              // Emoji Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isPremium
                      ? const Color(0xFF222222)
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(13),
                  border: isPremium
                      ? Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.2),
                          width: 1)
                      : null,
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
                    // Premium badge above title
                    if (isPremium) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  const Color(0xFFFFD700).withOpacity(0.3),
                              width: 0.8),
                        ),
                        child: const Text(
                          '👑 PREMIUM',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                    Text(
                      a.title,
                      style: TextStyle(
                        color: isPremium
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
              Container(
                width: 32,
                height: 32,
                decoration: isPremium
                    ? BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.3)),
                      )
                    : null,
                child: Center(
                  child: Icon(
                    isPremium
                        ? Icons.lock_outline_rounded
                        : Icons.chevron_right_rounded,
                    color: isPremium
                        ? const Color(0xFFFFD700)
                        : Colors.white30,
                    size: isPremium ? 16 : 22,
                  ),
                ),
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
// WHY BUY PREMIUM SHEET (SMART VERSION)
// ─────────────────────────────────────────────────────────────────────────────

class _WhyBuyPremiumSheet extends StatefulWidget {
  final BillingService billingService;
  const _WhyBuyPremiumSheet({required this.billingService});

  @override
  State<_WhyBuyPremiumSheet> createState() => _WhyBuyPremiumSheetState();
}

class _WhyBuyPremiumSheetState extends State<_WhyBuyPremiumSheet> {
  
  @override
  void initState() {
    super.initState();
    // Listen to billing changes while the sheet is open
    widget.billingService.addListener(_onBillingUpdate);
  }

  @override
  void dispose() {
    widget.billingService.removeListener(_onBillingUpdate);
    super.dispose();
  }

  void _onBillingUpdate() {
    // If the purchase was successful, automatically close this popup!
    if (widget.billingService.isPremium && mounted) {
      Navigator.pop(context);
    }
    if (mounted) setState(() {});
  }

  ProductDetails? _getProduct(String id) {
    try {
      return widget.billingService.products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  String _getMonthlyBreakdown(ProductDetails? product, int months) {
    if (product == null) return '';
    double monthlyRaw = product.rawPrice / months;
    return '${product.currencySymbol}${monthlyRaw.toStringAsFixed(0)}/month';
  }

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

                const SizedBox(height: 24),
                
                // RESTORE PURCHASES BUTTON
                TextButton(
                  onPressed: () async {
                    try {
                      await widget.billingService.restorePurchases();
                      if (mounted) {
                        Navigator.pop(context); 
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Purchases restored successfully!'),
                            backgroundColor: Color(0xFF8BC34A),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to restore purchases.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Restore Purchases',
                    style: TextStyle(
                      color: Colors.white54,
                      decoration: TextDecoration.underline,
                      fontSize: 14,
                    ),
                  ),
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
    // Dynamically grab the real products from Google Play
    ProductDetails? monthly = _getProduct('premium_monthly');
    ProductDetails? sixMonth = _getProduct('premium_6month');
    ProductDetails? yearly = _getProduct('premium_yearly');

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
                  'Premium is upto 15× Cheaper Than Influencer Courses',
                  style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            
            const Text('Our Premium Plans:',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            
            // SMART BUTTON 1: Monthly
            _priceRow(
              monthly != null ? '${monthly.price} / month' : 'Loading price...', 
              '', 
              false,
              monthly != null ? () => widget.billingService.buySubscription(monthly) : null
            ),
            const SizedBox(height: 6),
            
            // SMART BUTTON 2: 6 Months
            _priceRow(
              sixMonth != null ? '${sixMonth.price} / 6 months' : 'Loading price...', 
              _getMonthlyBreakdown(sixMonth, 6), 
              true,
              sixMonth != null ? () => widget.billingService.buySubscription(sixMonth) : null
            ),
            const SizedBox(height: 6),
            
            // SMART BUTTON 3: Yearly
            _priceRow(
              yearly != null ? '${yearly.price} / 12 months' : 'Loading price...', 
              _getMonthlyBreakdown(yearly, 12), 
              false,
              yearly != null ? () => widget.billingService.buySubscription(yearly) : null
            ),
            
            const SizedBox(height: 10),
            const Text(
              'Tap a plan to securely subscribe via Google Play.',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
          ]),
    );
  }

  Widget _priceRow(String price, String sub, bool isBest, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
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