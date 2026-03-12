import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class ShopProduct {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String category;
  final String affiliateUrl;
  final String? price;
  final String? brand;
  final bool isFeatured;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.category,
    required this.affiliateUrl,
    this.price,
    this.brand,
    this.isFeatured = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORIES — add your products here later
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _categories = [
  'All',
  'Skincare',
  'Supplements',
  'Grooming',
  'Hair',
  'Tools',
];

// Add products here when ready:
// const List<ShopProduct> _products = [
//   ShopProduct(
//     id: '1',
//     name: 'Product Name',
//     description: 'Short description',
//     emoji: '💊',
//     category: 'Supplements',
//     affiliateUrl: 'https://your-affiliate-link.com',
//     price: '\$29.99',
//     brand: 'Brand Name',
//     isFeatured: true,
//   ),
// ];
const List<ShopProduct> _products = [];

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
        vsync: this, duration: const Duration(milliseconds: 400));
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

  Future<void> _openLink(String url) async {
    HapticFeedback.selectionClick();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Shop', style: TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          // Category filter chips
          if (_products.isNotEmpty) ...[
            SizedBox(
              height: 52,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFD700)
                              : Colors.white12,
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
          ],

          // Content
          Expanded(
            child: _products.isEmpty
                ? _buildEmptyState()
                : (_filtered.isEmpty
                    ? _buildNoneInCategory()
                    : _buildProductGrid()),
          ),
        ]),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1A1A),
                border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.3), width: 2),
              ),
              child: const Center(
                child: Text('🛍️', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Products Coming Soon',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Curated looksmaxing products\nwill appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            // Category preview chips
            Wrap(
              spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: ['Skincare', 'Supplements', 'Grooming', 'Hair', 'Tools']
                  .map((cat) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFFD700).withOpacity(0.2)),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                color: const Color(0xFFFFD700).withOpacity(0.6),
                                fontSize: 12)),
                      ))
                  .toList(),
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

  // ── Product grid ────────────────────────────────────────────────────────────
  Widget _buildProductGrid() {
    final featured = _filtered.where((p) => p.isFeatured).toList();
    final regular = _filtered.where((p) => !p.isFeatured).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (featured.isNotEmpty) ...[
          const Text('⭐ Featured',
              style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 10),
          ...featured.map((p) => _buildFeaturedCard(p)),
          const SizedBox(height: 16),
        ],
        if (regular.isNotEmpty) ...[
          if (featured.isNotEmpty)
            const Text('All Products',
                style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          if (featured.isNotEmpty) const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: regular.length,
            itemBuilder: (_, i) => _buildProductCard(regular[i]),
          ),
        ],
      ],
    );
  }

  // ── Featured card (full width) ──────────────────────────────────────────────
  Widget _buildFeaturedCard(ShopProduct product) {
    return GestureDetector(
      onTap: () => _openLink(product.affiliateUrl),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A00), Color(0xFF1A1A1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
        ),
        child: Row(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(product.emoji,
                    style: const TextStyle(fontSize: 32))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (product.brand != null)
                Text(product.brand!,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              Text(product.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 4),
              Text(product.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              if (product.price != null) ...[
                const SizedBox(height: 6),
                Text(product.price!,
                    style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Buy',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  // ── Regular product card ────────────────────────────────────────────────────
  Widget _buildProductCard(ShopProduct product) {
    return GestureDetector(
      onTap: () => _openLink(product.affiliateUrl),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity, height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
                child: Text(product.emoji,
                    style: const TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 10),
          if (product.brand != null)
            Text(product.brand!,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          Text(product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 4),
          Text(product.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (product.price != null)
                Text(product.price!,
                    style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 13))
              else
                const SizedBox(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Buy',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}