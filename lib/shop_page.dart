import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class ShopProduct {
  final String id;
  final String name;
  final String emoji;
  final String category;
  final String coreBenefit;
  final String myExperience;
  final String affiliateUrl;
  final List<String> benefits;
  final bool isFeatured;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.coreBenefit,
    required this.myExperience,
    required this.affiliateUrl,
    this.benefits = const [],
    this.isFeatured = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT DATA — separated for easy future updates
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _categories = [
  'All',
  'Skincare',
  'Hair',
  'Supplements',
  'Tools',
  'Body',
];

const List<ShopProduct> _products = [
  ShopProduct(
    id: '1',
    name: 'Microfiber Cloth Towel',
    emoji: '☁️',
    category: 'Skincare',
    coreBenefit: 'Ultra-gentle on skin, prevents bacterial acne.',
    myExperience:
        'Switching to microfiber was a game-changer for my skin. Regular towels were secretly causing breakouts by harbouring bacteria—this completely eliminated that. It\'s the simplest swap you can make with the biggest payoff for clear skin.',
    affiliateUrl: 'https://amzn.to/47T0CjU',
    benefits: [
      'Zero irritation on sensitive skin',
      'Prevents bacterial buildup vs. cotton towels',
      'Crucial step for acne prevention',
      'Lasts significantly longer than regular towels',
    ],
    isFeatured: true,
  ),
  ShopProduct(
    id: '2',
    name: 'Face Wash (Oily/Acne Prone)',
    emoji: '🫧',
    category: 'Skincare',
    coreBenefit: 'Best budget face wash for acne-prone skin.',
    myExperience:
        'This has been my daily go-to for over 2 years—and nothing has come close. It controls oil without stripping your skin dry, and at this price, it\'s the best value on the market for acne-prone skin. Just make sure you follow up with a moisturizer after.',
    affiliateUrl: 'https://amzn.to/47T0CjU',
    benefits: [
      'Controls excess oil production',
      'Budget-friendly without compromising quality',
      'Gentle enough for daily use',
      'Tip: Always apply moisturizer after',
    ],
  ),
  ShopProduct(
    id: '3',
    name: 'Hydrating Cleanser (Dry to Normal)',
    emoji: '💧',
    category: 'Skincare',
    coreBenefit: 'Perfect daily cleanser for non-oily skin types.',
    myExperience:
        'I recently switched from face wash to cleansers for a gentler routine, and this instantly became my daily driver. It cleans thoroughly without that tight, stripped feeling. If you don\'t have oily skin, this is the one to go with.',
    affiliateUrl: 'https://amzn.to/4soBoRN',
    benefits: [
      'Maintains skin\'s natural moisture barrier',
      'No tight or stripped feeling after wash',
      'Ideal for dry, normal, and combination skin',
      'Perfect for a gentle daily routine',
    ],
  ),
  ShopProduct(
    id: '4',
    name: 'Adjustable Derma Stamp',
    emoji: '🔬',
    category: 'Tools',
    coreBenefit: 'Precision microneedling with adjustable depth.',
    myExperience:
        'Forget rollers—stamps are far superior for targeted treatment. This one comes with adjustable needle lengths, so you can safely use it on both your face and scalp. It\'s precise, hygienic, and the results speak for themselves.',
    affiliateUrl: 'https://amzn.to/3NUOh86',
    benefits: [
      'Far more effective than derma rollers',
      'Adjustable lengths for face & scalp',
      'Precise vertical penetration (safer)',
      'Promotes collagen production & hair growth',
    ],
    isFeatured: true,
  ),
  ShopProduct(
    id: '5',
    name: 'Benzoyl Peroxide Gel 2.5%',
    emoji: '⚡',
    category: 'Skincare',
    coreBenefit: 'The holy grail for killing acne fast.',
    myExperience:
        'I went through 6-7 different topical treatments before finding this—it\'s the ONLY one that actually worked. I still keep it on hand for spot treatment. The 2.5% concentration is the sweet spot: strong enough to kill acne, gentle enough to avoid irritation.',
    affiliateUrl: 'https://amzn.to/41WmgAa',
    benefits: [
      'Kills acne-causing bacteria on contact',
      '2.5% = effective without harsh irritation',
      'Perfect for targeted spot treatment',
      'Outperformed 6+ other topical solutions',
    ],
    isFeatured: true,
  ),
  ShopProduct(
    id: '6',
    name: 'Premium Protein Powder',
    emoji: '💪',
    category: 'Body',
    coreBenefit: 'Clean protein from a brand you can trust.',
    myExperience:
        'Don\'t gamble with cheap protein powders—many are loaded with heavy metals and fillers. This is a clean, third-party tested brand that I personally rely on to hit my daily protein goals on days when my diet falls short. Quality matters here.',
    affiliateUrl: 'https://amzn.to/4me2wBm',
    benefits: [
      'Clean formula free of heavy metals',
      'Third-party tested and trusted brand',
      'Helps hit daily protein intake targets',
      'Essential for muscle growth & recovery',
    ],
  ),
  ShopProduct(
    id: '7',
    name: 'Creatine Powder',
    emoji: '🏋️',
    category: 'Body',
    coreBenefit: 'Mandatory staple for building muscle.',
    myExperience:
        'Most creatine monohydrate is chemically the same, but I still want a brand I can trust with quality control. This is the reliable one I buy every time. If you\'re serious about building muscle, creatine is non-negotiable—it\'s the most researched supplement in fitness.',
    affiliateUrl: 'https://amzn.to/4ml8j8o',
    benefits: [
      'Most proven supplement for muscle growth',
      'Reliable brand with consistent quality',
      'Enhances strength and power output',
      'Supports faster recovery between sessions',
    ],
  ),
  ShopProduct(
    id: '8',
    name: 'Premium Sunscreen',
    emoji: '☀️',
    category: 'Skincare',
    coreBenefit: 'Your daily armor against UV damage & aging.',
    myExperience:
        'Yes, it costs more than drugstore brands—but the formula is on another level. No white cast, no greasy residue, just clean protection. Sunscreen is the single most important anti-aging product you can use, and this is the best one I\'ve ever tried.',
    affiliateUrl: 'https://amzn.to/4vlGK2R',
    benefits: [
      'Superior formula without white cast',
      'Non-greasy, lightweight finish',
      'The #1 anti-aging product you can use',
      'Daily UV protection for your face',
    ],
    isFeatured: true,
  ),
  ShopProduct(
    id: '9',
    name: 'Daily Moisturizer',
    emoji: '🧊',
    category: 'Skincare',
    coreBenefit: 'Non-greasy, pore-safe hydration at an unbeatable price.',
    myExperience:
        'Finding a moisturizer that\'s both non-greasy AND non-comedogenic at this price point is rare. Most affordable options clog your pores—this one doesn\'t. It absorbs clean, keeps skin hydrated all day, and the value is genuinely incredible.',
    affiliateUrl: 'https://amzn.to/4vo1w20',
    benefits: [
      'Strictly non-comedogenic (won\'t clog pores)',
      'Non-greasy, fast-absorbing formula',
      'Exceptional value for the quality',
      'Perfect daily hydration for all skin types',
    ],
  ),
  ShopProduct(
    id: '10',
    name: 'Rosemary Oil',
    emoji: '🌿',
    category: 'Hair',
    coreBenefit: 'Clinically backed for increasing hair density.',
    myExperience:
        'Rosemary oil is one of the most well-researched natural remedies for hair growth. It\'s cheap, effective, and easy to incorporate into any routine. I use it consistently as part of my hair density protocol—it\'s a staple you shouldn\'t skip.',
    affiliateUrl: 'https://amzn.to/3OqspS6',
    benefits: [
      'Scientifically backed for hair growth',
      'Stimulates blood flow to the scalp',
      'Budget-friendly and highly effective',
      'Essential for any hair density routine',
    ],
  ),
  ShopProduct(
    id: '11',
    name: 'Under Eye Cream',
    emoji: '👁️',
    category: 'Skincare',
    coreBenefit: 'Premium results for dark circles & puffiness.',
    myExperience:
        'This is the only eye cream I will ever recommend. Yes, it\'s a premium product—but cheap eye creams are a waste of money because they simply don\'t work. This one actually delivers visible results for dark circles and puffiness. You get what you pay for.',
    affiliateUrl: 'https://amzn.to/4twqjyR',
    benefits: [
      'Visibly reduces dark circles',
      'Targets puffiness and fine lines',
      'Premium formula that actually delivers',
      'The only eye cream worth recommending',
    ],
  ),
  ShopProduct(
    id: '12',
    name: 'NAC Supplement',
    emoji: '🧠',
    category: 'Supplements',
    coreBenefit: 'Boosts glutathione for clarity & mood support.',
    myExperience:
        'NAC (N-Acetyl Cysteine) is a powerhouse for boosting your body\'s natural glutathione—your master antioxidant. I noticed a real difference in mental clarity and mood stability after adding this to my stack. It\'s one of those supplements that works quietly but effectively.',
    affiliateUrl: 'https://amzn.to/4tzutWG',
    benefits: [
      'Boosts the body\'s natural glutathione',
      'Supports mental clarity and focus',
      'Helps with mood regulation',
      'Powerful antioxidant support',
    ],
  ),
  ShopProduct(
    id: '13',
    name: 'L-Glycine 500mg',
    emoji: '😴',
    category: 'Supplements',
    coreBenefit: 'Deep, restorative sleep for maximum recovery.',
    myExperience:
        'This was a total game-changer for my sleep quality. I fall asleep faster, sleep deeper, and wake up feeling genuinely recovered. If you\'re training hard, sleep is where your body actually grows—and glycine makes sure you\'re getting the most out of every hour.',
    affiliateUrl: 'https://amzn.to/4vkOi5Z',
    benefits: [
      'Dramatically improves deep sleep quality',
      'Maximizes overnight physical recovery',
      'Supports nervous system relaxation',
      'Enhances muscle growth during rest',
    ],
  ),
  ShopProduct(
    id: '14',
    name: 'Gua Sha',
    emoji: '💎',
    category: 'Tools',
    coreBenefit: 'Sculpt and define your facial structure naturally.',
    myExperience:
        'A proper gua sha routine is one of the best-kept secrets for facial aesthetics. It reduces puffiness, improves lymphatic drainage, and genuinely sharpens your jawline and cheekbones over time. It takes 5 minutes and the results are visible.',
    affiliateUrl: 'https://amzn.to/3OuNJ95',
    benefits: [
      'Reduces facial puffiness and water retention',
      'Improves lymphatic drainage',
      'Sharpens jawline & cheekbone definition',
      'Quick 5-minute daily routine',
    ],
  ),
  ShopProduct(
    id: '15',
    name: 'Multivitamin',
    emoji: '💊',
    category: 'Supplements',
    coreBenefit: 'Insurance policy for your daily nutrition gaps.',
    myExperience:
        'Real food always comes first—but let\'s be honest, nobody eats perfectly every single day. A quality multivitamin fills in the gaps and ensures your body has everything it needs to function at its best. Think of it as cheap insurance for your health.',
    affiliateUrl: 'https://amzn.to/48vO5D1',
    benefits: [
      'Covers daily vitamin & mineral gaps',
      'Supports immune system function',
      'Complements a whole-food diet',
      'Affordable daily health insurance',
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// THEME CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kGold = Color(0xFFFFD700);
const _kBg = Color(0xFF0A0A0A);
const _kCard = Color(0xFF141414);
const _kCardBorder = Color(0xFF1E1E1E);
const _kSurface = Color(0xFF1A1A1A);

// ─────────────────────────────────────────────────────────────────────────────
// SHOP PAGE
// ─────────────────────────────────────────────────────────────────────────────

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  List<ShopProduct> get _filtered {
    if (_selectedCategory == 'All') return _products;
    return _products.where((p) => p.category == _selectedCategory).toList();
  }

  void _showTrustModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _TrustBottomSheet(),
    );
  }

  void _openProductDetail(ShopProduct product) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ProductDetailPage(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Shop',
            style: TextStyle(
                color: _kGold, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── Trust Banner ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: _showTrustModal,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kGold.withValues(alpha: 0.15),
                        _kGold.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kGold.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kGold.withValues(alpha: 0.2),
                        ),
                        child: const Center(
                          child: Text('✅',
                              style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Why buy from us?',
                                style: TextStyle(
                                    color: _kGold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            SizedBox(height: 2),
                            Text(
                                'Personally tested. Zero sponsorships. Tap to learn more.',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: _kGold.withValues(alpha: 0.6), size: 22),
                    ],
                  ),
                ),
              ),
            ),

            // ── Category Filter ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 54,
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? _kGold : _kSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? _kGold
                                : Colors.white10,
                          ),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white54,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            )),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Product List ──────────────────────────────────────────────
            _filtered.isEmpty
                ? SliverFillRemaining(child: _buildNoneInCategory())
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = _filtered[index];
                          return _ProductCard(
                            product: product,
                            index: index,
                            onTap: () => _openProductDetail(product),
                          );
                        },
                        childCount: _filtered.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoneInCategory() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔍', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text('No $_selectedCategory products yet',
            style: const TextStyle(color: Colors.white54, fontSize: 16)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final ShopProduct product;
  final int index;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: product.isFeatured
                  ? _kGold.withValues(alpha: 0.3)
                  : _kCardBorder,
            ),
            boxShadow: product.isFeatured
                ? [
                    BoxShadow(
                      color: _kGold.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Emoji icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: product.isFeatured
                        ? _kGold.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Center(
                  child: Text(product.emoji,
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(product.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                        if (product.isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _kGold.withValues(alpha: 0.4)),
                            ),
                            child: const Text('★ TOP PICK',
                                style: TextStyle(
                                    color: _kGold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(product.coreBenefit,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12, height: 1.3)),
                    const SizedBox(height: 6),
                    Text(product.category.toUpperCase(),
                        style: TextStyle(
                            color: _kGold.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.2), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRUST BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _TrustBottomSheet extends StatelessWidget {
  const _TrustBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              children: [
                // Header
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _kGold.withValues(alpha: 0.3),
                        _kGold.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                  ),
                  child: const Center(
                    child: Text('🤝', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Transparency & Support',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Here\'s why you can trust our picks.',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 24),

                // Trust points
                _buildTrustPoint(
                  icon: '🧪',
                  title: 'Tested & Proven',
                  body:
                      'I personally use these products on a daily basis. They aren\'t just random recommendations; they are staples in my routine.',
                ),
                _buildTrustPoint(
                  icon: '🚫',
                  title: '100% Unbiased',
                  body:
                      'These are NOT sponsored. No brand paid me to list these. I recommend them simply because they actually work.',
                ),
                _buildTrustPoint(
                  icon: '💰',
                  title: 'Save Time & Money',
                  body:
                      'Skip the trial and error. I\'ve wasted money on bad products so you don\'t have to.',
                ),
                _buildTrustPoint(
                  icon: '❤️',
                  title: 'Support the App',
                  body:
                      'Clicking \'Buy Now\' redirects you to Amazon. These are affiliate links, meaning it costs you nothing extra, but we earn a small commission. Buying through these links directly supports us and keeps updates coming. Thank you!',
                  isLast: true,
                ),
              ],
            ),
          ),

          // Close button
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 4, 24, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: _kSurface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Got it',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTrustPoint({
    required String icon,
    required String title,
    required String body,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT DETAIL PAGE
// ─────────────────────────────────────────────────────────────────────────────

class _ProductDetailPage extends StatelessWidget {
  final ShopProduct product;

  const _ProductDetailPage({required this.product});

  Future<void> _openLink(BuildContext context, String url) async {
    HapticFeedback.mediumImpact();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Color(0xFF1A1A1A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(product.category.toUpperCase(),
            style: TextStyle(
                color: _kGold.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────────
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 100 + bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero section ──────────────────────────────────────────
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kCard,
                      border: Border.all(
                          color: product.isFeatured
                              ? _kGold.withValues(alpha: 0.4)
                              : _kCardBorder,
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: product.isFeatured
                              ? _kGold.withValues(alpha: 0.15)
                              : Colors.black26,
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(product.emoji,
                          style: const TextStyle(fontSize: 48)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Product name
                Center(
                  child: Text(product.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                // Core benefit
                Center(
                  child: Text(product.coreBenefit,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          height: 1.4)),
                ),
                if (product.isFeatured) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: _kGold.withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('⭐', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 6),
                          Text('TOP PICK',
                              style: TextStyle(
                                  color: _kGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // ── Benefits section ──────────────────────────────────────
                _buildSectionHeader('Key Benefits'),
                const SizedBox(height: 14),
                ...product.benefits.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _kGold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Center(
                            child: Icon(Icons.check_rounded,
                                color: _kGold, size: 15),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(entry.value,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.4)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 28),

                // ── My Experience section ─────────────────────────────────
                _buildSectionHeader('My Experience'),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kCardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kGold.withValues(alpha: 0.15),
                              border: Border.all(
                                  color: _kGold.withValues(alpha: 0.3)),
                            ),
                            child: const Center(
                              child: Icon(Icons.person,
                                  color: _kGold, size: 16),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Personal Review',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              Text('Tested & verified',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                          const Spacer(),
                          // Stars
                          Row(
                            children: List.generate(
                              5,
                              (i) => Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Icon(Icons.star_rounded,
                                    color: _kGold, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '"${product.myExperience}"',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Sticky Buy Now Button ───────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _kBg.withValues(alpha: 0),
                    _kBg.withValues(alpha: 0.9),
                    _kBg,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.3, 0.5],
                ),
              ),
              child: GestureDetector(
                onTap: () => _openLink(context, product.affiliateUrl),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFC400)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _kGold.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_rounded,
                          color: Colors.black, size: 20),
                      SizedBox(width: 10),
                      Text('Buy Now on Amazon',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      SizedBox(width: 6),
                      Icon(Icons.open_in_new_rounded,
                          color: Colors.black54, size: 16),
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

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: _kGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}