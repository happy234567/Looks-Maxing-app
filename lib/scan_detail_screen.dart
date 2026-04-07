import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'scan_history.dart';

class ScanDetailScreen extends StatefulWidget {
  final ScanHistory scan;
  const ScanDetailScreen({super.key, required this.scan});
  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> with SingleTickerProviderStateMixin {
  String _gender = '';
  int _curPhoto = 0;
  final PageController _photoCtrl = PageController();
  late AnimationController _animCtrl;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _loadGender();
    final overall = widget.scan.scores['overall'] as int? ?? 0;
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scoreAnim = Tween<double>(begin: 0, end: overall.toDouble())
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _animCtrl.forward(); });
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

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

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year} at ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  void _openFs(List<String> p, int i) => Navigator.push(context,
    MaterialPageRoute(builder: (_) => _FsViewer(photos: p, initialIndex: i, labels: const ['Front','Right','Left'])));

  @override
  Widget build(BuildContext context) {
    final sc = widget.scan.scores;
    final overall = sc['overall'] as int? ?? 0;
    final gl = _gender == 'Female' ? 'Femininity' : 'Masculinity';
    final sColor = _scoreColor(overall);
    final photos = widget.scan.imagePaths.where((p) => p.startsWith('http') || File(p).existsSync()).toList();

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
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Scan Details', style: TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(
            children: [
              Expanded(child: AspectRatio(aspectRatio: 1, child: _squarePhotoSection(photos))),
              const SizedBox(width: 12),
              Expanded(child: AspectRatio(aspectRatio: 1, child: _squareOverallHero(overall, sColor))),
            ],
          ),
          const SizedBox(height: 12),
          Text('Scanned on ' + _fmt(widget.scan.date), style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 0.5)),
          const SizedBox(height: 24),

          // Score breakdown grid
          _sectionHead('Score Breakdown'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final (label, score, icon) = items[i];
              return _scoreCard(label, score, icon);
            },
          ),
          const SizedBox(height: 24),

          // Face analysis
          _sectionHead('Face Analysis'),
          const SizedBox(height: 12),
          _faceAnalysis(sc),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _sectionHead(String t) => Row(children: [
    Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
  ]);

  Widget _scoreCard(String label, int score, IconData icon) {
    final c = _scoreColor(score);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha:0.15)),
        boxShadow: [BoxShadow(color: c.withValues(alpha:0.05), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: c.withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: c, size: 16)),
          Text('$score', style: TextStyle(color: c, fontSize: 24, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: score / 100, backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(c), minHeight: 5)),
      ]),
    );
  }

  Widget _faceAnalysis(Map<String, dynamic> sc) {
    final fields = [
      (Icons.face, 'Face Shape', sc['faceShape'] as String? ?? 'Unknown'),
      (Icons.open_in_full, 'Canthal Tilt', sc['canthalTilt'] as String? ?? 'Unknown'),
      (Icons.visibility, 'Eye Shape', sc['eyeShape'] as String? ?? 'Unknown'),
      (Icons.center_focus_strong, 'Eye Type', sc['eyeType'] as String? ?? 'Unknown'),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.7,
      children: fields.map((f) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha:0.1))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFFD700).withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(f.$1, color: const Color(0xFFFFD700), size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(f.$2, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 2),
            Text(f.$3, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ])),
        ]),
      )).toList(),
    );
  }

  Widget _squareOverallHero(int overall, Color sc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A1A), sc.withValues(alpha:0.1)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sc.withValues(alpha:0.3), width: 1.5),
        boxShadow: [BoxShadow(color: sc.withValues(alpha:0.1), blurRadius: 20)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(animation: _scoreAnim, builder: (_, _) {
            final d = _scoreAnim.value.round();
            return SizedBox(
              width: 80, height: 80,
              child: CustomPaint(
                painter: _RingPainter(progress: _scoreAnim.value / 100, color: sc),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$d', style: TextStyle(color: sc, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                ])),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text('OVERALL', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_scoreLabel(overall), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: sc, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _squarePhotoSection(List<String> photos) {
    const labels = ['Front', 'Right', 'Left'];
    if (photos.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12, width: 1.5)),
        child: const Center(child: Icon(Icons.face, color: Colors.white38, size: 40)));
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          PageView.builder(controller: _photoCtrl, itemCount: photos.length,
            onPageChanged: (i) => setState(() => _curPhoto = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _openFs(photos, i),
              child: Stack(fit: StackFit.expand, children: [
                photos[i].startsWith('http')
                    ? CachedNetworkImage(imageUrl: photos[i], fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
                        errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white54, size: 40)))
                    : Image.file(File(photos[i]), fit: BoxFit.cover),
                Positioned(bottom: 0, left: 0, right: 0, height: 60,
                  child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha:0.55)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
              ]),
            ),
          ),
          Positioned(bottom: 12, left: 12, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
            child: Text(_curPhoto < labels.length ? labels[_curPhoto] : '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
          Positioned(bottom: 12, right: 12, child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.fullscreen, color: Colors.white, size: 16))),
          if (photos.length > 1) Positioned(top: 10, left: 0, right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(photos.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _curPhoto == i ? 16 : 6, height: 6,
                decoration: BoxDecoration(
                  color: _curPhoto == i ? const Color(0xFFFFD700) : Colors.white54,
                  borderRadius: BorderRadius.circular(3)))))),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    canvas.drawCircle(center, r, Paint()..color = Colors.white.withValues(alpha:0.08)..style = PaintingStyle.stroke..strokeWidth = 6);
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, 2 * math.pi * progress, false, paint);
    final glow = Paint()..color = color.withValues(alpha:0.3)..style = PaintingStyle.stroke..strokeWidth = 10..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, 2 * math.pi * progress, false, glow);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

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
            child: Center(child: widget.photos[i].startsWith('http')
              ? CachedNetworkImage(imageUrl: widget.photos[i], fit: BoxFit.contain,
                  placeholder: (context, url) => const CircularProgressIndicator(color: Color(0xFFFFD700)),
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white54, size: 40))
              : Image.file(File(widget.photos[i]), fit: BoxFit.contain)))),
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