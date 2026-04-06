import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'camera_screen.dart';
import 'dart:io';
import 'dart:math' as math;

class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> scores;
  final List<String> imagePaths;
  const ResultsScreen({super.key, required this.scores, this.imagePaths = const []});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> with TickerProviderStateMixin {
  String _gender = 'Male';
  final PageController _photoCtrl = PageController();
  int _curPhoto = 0;
  late AnimationController _scoreCtrl, _staggerCtrl;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _loadGender();
    _scoreCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    final overall = widget.scores['overall'] as int? ?? 0;
    _scoreAnim = Tween<double>(begin: 0, end: overall.toDouble())
        .animate(CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) { _scoreCtrl.forward(); _staggerCtrl.forward(); }
    });
  }

  @override
  void dispose() { _scoreCtrl.dispose(); _staggerCtrl.dispose(); super.dispose(); }

  Future<void> _loadGender() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _gender = p.getString('gender') ?? 'Male');
  }

  Color _scoreColor(int s) {
    if (s >= 90) return const Color(0xFF39FF14);
    if (s >= 80) return const Color(0xFF00C853);
    if (s >= 70) return const Color(0xFF8BC34A);
    if (s >= 60) return const Color(0xFFFFEA00);
    if (s >= 50) return const Color(0xFFFFD700);
    return const Color(0xFF9E9E9E);
  }

  String _scoreLabel(int s) {
    if (s >= 90) return 'Elite';
    if (s >= 80) return 'Highly Attractive';
    if (s >= 70) return 'Attractive';
    if (s >= 60) return 'Above Average';
    if (s >= 50) return 'Average';
    return 'Below Average';
  }

  String _tier(int s) {
    if (s >= 90) return '🏆 Top 1%';
    if (s >= 80) return '⭐ Top 10%';
    if (s >= 70) return '✨ Top 25%';
    if (s >= 60) return '👍 Top 40%';
    if (s >= 50) return '📊 Average';
    return '📈 Room to grow';
  }

  void _openFs(List<String> p, int i) => Navigator.push(context,
    MaterialPageRoute(builder: (_) => _FsViewer(photos: p, initialIndex: i, labels: const ['Front','Right','Left'])));

  @override
  Widget build(BuildContext context) {
    final sc = widget.scores;
    final overall = sc['overall'] as int? ?? 0;
    final gl = _gender == 'Female' ? 'Femininity' : 'Masculinity';
    final sColor = _scoreColor(overall);
    final photos = widget.imagePaths.where((p) => File(p).existsSync()).toList();

    final items = [
      ('Skin Quality', sc['skin'] as int? ?? 0, Icons.auto_awesome),
      ('Cheekbones', sc['cheekbones'] as int? ?? 0, Icons.face_retouching_natural),
      ('Jawline', sc['jawline'] as int? ?? 0, Icons.diamond_outlined),
      ('Neck', sc['neck'] as int? ?? 0, Icons.straighten),
      (gl, sc['masculinityFemininity'] as int? ?? 0, Icons.bolt),
      ('Eyes', sc['eyes'] as int? ?? 0, Icons.visibility_outlined),
      ('Facial Symmetry', sc['symmetry'] as int? ?? 0, Icons.balance),
      ('Max Potential', sc['maxPotential'] as int? ?? 0, Icons.rocket_launch),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFF0A0A0A), floating: true, automaticallyImplyLeading: false,
          title: const Text('Your Results', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (photos.isNotEmpty) _photoCarousel(photos),
          _overallHero(overall, sColor),
          const SizedBox(height: 8),
          _sectionHead('Score Breakdown'),
          const SizedBox(height: 12),
          // Score cards in 2-column grid
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final (label, score, icon) = items[i];
                return _scoreCard(label, score, icon, i * 80);
              },
            ),
          ),
          const SizedBox(height: 24),
          _sectionHead('Face Analysis'),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.7,
              children: [
                _detailCard(Icons.face, 'Face Shape', sc['faceShape'] as String? ?? 'Unknown'),
                _detailCard(Icons.open_in_full, 'Canthal Tilt', sc['canthalTilt'] as String? ?? 'Unknown'),
                _detailCard(Icons.visibility, 'Eye Shape', sc['eyeShape'] as String? ?? 'Unknown'),
                _detailCard(Icons.center_focus_strong, 'Eye Type', sc['eyeType'] as String? ?? 'Unknown'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
            child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Scan Again', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
            )),
          ),
        ])),
      ]),
    );
  }

  Widget _sectionHead(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    child: Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
    ]),
  );

  Widget _overallHero(int overall, Color sc) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A1A), sc.withValues(alpha:0.08)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sc.withValues(alpha:0.3), width: 1.5),
        boxShadow: [BoxShadow(color: sc.withValues(alpha:0.1), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Row(children: [
        AnimatedBuilder(animation: _scoreAnim, builder: (_, _) {
          final d = _scoreAnim.value.round();
          return SizedBox(
            width: 100, height: 100,
            child: CustomPaint(
              painter: _RingPainter(progress: _scoreAnim.value / 100, color: sc),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$d', style: TextStyle(color: sc, fontSize: 36, fontWeight: FontWeight.bold, height: 1.0)),
                const Text('/100', style: TextStyle(color: Colors.white38, fontSize: 10)),
              ])),
            ),
          );
        }),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OVERALL SCORE', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(_scoreLabel(overall), style: TextStyle(color: sc, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: sc.withValues(alpha:0.1), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sc.withValues(alpha:0.3))),
            child: Text(_tier(overall), style: TextStyle(color: sc, fontSize: 11)),
          ),
        ])),
      ]),
    );
  }

  Widget _scoreCard(String label, int score, IconData icon, int delayMs) {
    final c = _scoreColor(score);
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _staggerCtrl,
        curve: Interval((delayMs / 2000).clamp(0, 0.9), ((delayMs + 450) / 2000).clamp(0, 1), curve: Curves.easeOut))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha:0.15)),
          boxShadow: [BoxShadow(color: c.withValues(alpha:0.05), blurRadius: 12)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: c.withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: c, size: 16),
            ),
            Text('$score', style: TextStyle(color: c, fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: _AnimBar(value: score / 100, color: c, delay: delayMs + 350)),
        ]),
      ),
    );
  }

  Widget _detailCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha:0.1)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFFFD700).withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFFFFD700), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ])),
      ]),
    );
  }

  Widget _photoCarousel(List<String> photos) {
    const labels = ['Front', 'Right', 'Left'];
    return SizedBox(height: 230, child: Stack(children: [
      PageView.builder(
        controller: _photoCtrl, itemCount: photos.length,
        onPageChanged: (i) => setState(() => _curPhoto = i),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _openFs(photos, i),
          child: Container(margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ClipRRect(borderRadius: BorderRadius.circular(20),
              child: Stack(fit: StackFit.expand, children: [
                Image.file(File(photos[i]), fit: BoxFit.cover),
                Positioned(bottom: 0, left: 0, right: 0, height: 60,
                  child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha:0.55)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
                Positioned(bottom: 12, left: 12, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text(i < labels.length ? labels[i] : '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
                Positioned(bottom: 10, right: 10, child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 16))),
              ]))),
        ),
      ),
      if (photos.length > 1) Positioned(bottom: 0, left: 0, right: 0,
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(photos.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _curPhoto == i ? 20 : 6, height: 6,
            decoration: BoxDecoration(
              color: _curPhoto == i ? const Color(0xFFFFD700) : Colors.white24,
              borderRadius: BorderRadius.circular(3)),
          )))),
    ]));
  }
}

// ── Custom ring painter for overall score ──
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    // Background ring
    canvas.drawCircle(center, r, Paint()..color = Colors.white.withValues(alpha:0.08)..style = PaintingStyle.stroke..strokeWidth = 6);
    // Progress arc
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, 2 * math.pi * progress, false, paint);
    // Glow
    final glow = Paint()..color = color.withValues(alpha:0.3)..style = PaintingStyle.stroke..strokeWidth = 10..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, 2 * math.pi * progress, false, glow);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

// ── Animated score bar ──
class _AnimBar extends StatefulWidget {
  final double value;
  final Color color;
  final int delay;
  const _AnimBar({required this.value, required this.color, this.delay = 0});
  @override
  State<_AnimBar> createState() => _AnimBarState();
}

class _AnimBarState extends State<_AnimBar> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _a = Tween<double>(begin: 0, end: widget.value).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _a, builder: (_, _) => ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(value: _a.value, backgroundColor: Colors.white.withValues(alpha:0.07),
        valueColor: AlwaysStoppedAnimation(widget.color), minHeight: 5),
    ));
  }
}

// ── Fullscreen Photo Viewer ──
class _FsViewer extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final List<String> labels;
  const _FsViewer({required this.photos, required this.initialIndex, required this.labels});
  @override
  State<_FsViewer> createState() => _FsViewerState();
}

class _FsViewerState extends State<_FsViewer> {
  late PageController _c;
  late int _cur;

  @override
  void initState() {
    super.initState();
    _cur = widget.initialIndex;
    _c = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_cur < widget.labels.length ? widget.labels[_cur] : '', style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [Padding(padding: const EdgeInsets.only(right: 16),
          child: Text('${_cur + 1} / ${widget.photos.length}', style: const TextStyle(color: Colors.white54, fontSize: 14)))]),
      body: Stack(children: [
        PageView.builder(controller: _c, itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _cur = i),
          itemBuilder: (_, i) => InteractiveViewer(minScale: 0.8, maxScale: 4.0,
            child: Center(child: Image.file(File(widget.photos[i]), fit: BoxFit.contain)))),
        if (widget.photos.length > 1) Positioned(bottom: 20, left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.photos.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _cur == i ? 20 : 7, height: 7,
              decoration: BoxDecoration(
                color: _cur == i ? const Color(0xFFFFD700) : Colors.white38,
                borderRadius: BorderRadius.circular(4)))))),
      ]),
    );
  }
}