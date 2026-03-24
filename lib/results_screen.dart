import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'camera_screen.dart';
import 'dart:io';

class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> scores;
  final List<String> imagePaths;
  const ResultsScreen(
      {super.key, required this.scores, this.imagePaths = const []});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  String _gender = 'Male';
  final PageController _photoController = PageController();
  int _currentPhoto = 0;

  late AnimationController _scoreAnimCtrl;
  late AnimationController _staggerCtrl;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _loadGender();

    _scoreAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));

    final overall = widget.scores['overall'] as int? ?? 0;
    _scoreAnim = Tween<double>(begin: 0, end: overall.toDouble()).animate(
        CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _scoreAnimCtrl.forward();
        _staggerCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _scoreAnimCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGender() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _gender = prefs.getString('gender') ?? 'Male');
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return const Color(0xFF39FF14);
    if (score >= 80) return const Color(0xFF00C853);
    if (score >= 70) return const Color(0xFF8BC34A);
    if (score >= 60) return const Color(0xFFFFEA00);
    if (score >= 50) return const Color(0xFFFFD700);
    return const Color(0xFF9E9E9E);
  }

  String _getScoreLabel(int score) {
    if (score >= 90) return 'Elite';
    if (score >= 80) return 'Highly Attractive';
    if (score >= 70) return 'Attractive';
    if (score >= 60) return 'Above Average';
    if (score >= 50) return 'Average';
    return 'Below Average';
  }

  String _getRatingTier(int score) {
    if (score >= 90) return '🏆 Top 1%';
    if (score >= 80) return '⭐ Top 10%';
    if (score >= 70) return '✨ Top 25%';
    if (score >= 60) return '👍 Top 40%';
    if (score >= 50) return '📊 Average';
    return '📈 Room to grow';
  }

  void _openFullscreen(List<String> photos, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenPhotoViewer(
          photos: photos,
          initialIndex: initialIndex,
          labels: const ['Front', 'Right', 'Left'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scores = widget.scores;
    final overall = scores['overall'] as int? ?? 0;
    final genderLabel = _gender == 'Female' ? 'Femininity' : 'Masculinity';
    final scoreColor = _getScoreColor(overall);

    final photos =
        widget.imagePaths.where((p) => File(p).existsSync()).toList();
    final photoLabels = ['Front', 'Right', 'Left'];

    final scoreItems = [
      ('Skin Quality', scores['skin'] as int? ?? 0, '✨'),
      ('Cheekbones', scores['cheekbones'] as int? ?? 0, '🦴'),
      ('Jawline', scores['jawline'] as int? ?? 0, '💎'),
      ('Neck', scores['neck'] as int? ?? 0, '📐'),
      (genderLabel, scores['masculinityFemininity'] as int? ?? 0, '⚡'),
      ('Eyes', scores['eyes'] as int? ?? 0, '👁️'),
      ('Facial Symmetry', scores['symmetry'] as int? ?? 0, '⚖️'),
      ('Max Potential', scores['maxPotential'] as int? ?? 0, '🚀'),
    ];

    final faceShape = scores['faceShape'] as String? ?? 'Unknown';
    final canthalTilt = scores['canthalTilt'] as String? ?? 'Unknown';
    final eyeShape = scores['eyeShape'] as String? ?? 'Unknown';
    final eyeType = scores['eyeType'] as String? ?? 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0A),
            floating: true,
            automaticallyImplyLeading: false,
            title: const Text('Your Results',
                style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Photo Carousel ──
                if (photos.isNotEmpty)
                  _buildPhotoCarousel(photos, photoLabels),

                // ── Overall Score Hero ──
                _buildOverallScoreSection(overall, scoreColor),

                // ── Score Breakdown ──
                _buildSectionHeader('Score Breakdown'),
                const SizedBox(height: 10),
                ...scoreItems.asMap().entries.map((e) =>
                    _buildAnimatedScoreRow(
                        e.value.$1, e.value.$2, e.value.$3, e.key * 80)),

                const SizedBox(height: 24),

                // ── Face Analysis ──
                _buildSectionHeader('Face Analysis'),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: [
                      _buildDetailCard('🧑', 'Face Shape', faceShape),
                      _buildDetailCard('⚖️', 'Canthal Tilt', canthalTilt),
                      _buildDetailCard('👁️', 'Eye Shape', eyeShape),
                      _buildDetailCard('🎯', 'Eye Type', eyeType),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Scan Again Button ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushReplacement(context,
                          MaterialPageRoute(
                              builder: (_) => const CameraScreen())),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Scan Again',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4)),
        ],
      ),
    );
  }

  Widget _buildOverallScoreSection(int overall, Color scoreColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: scoreColor.withOpacity(0.25), width: 1.5),
      ),
      child: Row(
        children: [
          // Animated circular score
          AnimatedBuilder(
            animation: _scoreAnim,
            builder: (_, __) {
              final displayScore = _scoreAnim.value.round();
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(
                      value: _scoreAnim.value / 100,
                      strokeWidth: 5,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(scoreColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$displayScore',
                          style: TextStyle(
                              color: scoreColor,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              height: 1.0)),
                      Text('/100',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OVERALL SCORE',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(_getScoreLabel(overall),
                    style: TextStyle(
                        color: scoreColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: scoreColor.withOpacity(0.3)),
                  ),
                  child: Text(_getRatingTier(overall),
                      style:
                          TextStyle(color: scoreColor, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedScoreRow(
      String label, int score, String emoji, int delayMs) {
    final color = _getScoreColor(score);
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval((delayMs / 2000).clamp(0.0, 0.9),
            ((delayMs + 450) / 2000).clamp(0.0, 1.0),
            curve: Curves.easeOut),
      )),
      child: SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(0.04, 0), end: Offset.zero)
            .animate(CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval((delayMs / 2000).clamp(0.0, 0.9),
              ((delayMs + 450) / 2000).clamp(0.0, 1.0),
              curve: Curves.easeOut),
        )),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 9),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        Row(children: [
                          Text(_getScoreLabel(score),
                              style: TextStyle(
                                  color: color.withOpacity(0.7),
                                  fontSize: 11)),
                          const SizedBox(width: 8),
                          Text('$score',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _AnimatedScoreBar(
                        value: score / 100,
                        color: color,
                        delay: delayMs + 350),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCarousel(List<String> photos, List<String> labels) {
    return SizedBox(
      height: 230,
      child: Stack(
        children: [
          PageView.builder(
            controller: _photoController,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _currentPhoto = i),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _openFullscreen(photos, i),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(photos[i]), fit: BoxFit.cover),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.55)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                              i < labels.length ? labels[i] : '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.fullscreen,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (photos.length > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  photos.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPhoto == i ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPhoto == i
                          ? const Color(0xFFFFD700)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Animated Score Bar ────────────────────────────────────────────────────────

class _AnimatedScoreBar extends StatefulWidget {
  final double value;
  final Color color;
  final int delay;

  const _AnimatedScoreBar(
      {required this.value, required this.color, this.delay = 0});

  @override
  State<_AnimatedScoreBar> createState() => _AnimatedScoreBarState();
}

class _AnimatedScoreBarState extends State<_AnimatedScoreBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: widget.value).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _anim.value,
          backgroundColor: Colors.white.withOpacity(0.07),
          valueColor: AlwaysStoppedAnimation(widget.color),
          minHeight: 6,
        ),
      ),
    );
  }
}

// ── Fullscreen Photo Viewer ───────────────────────────────────────────────────

class _FullscreenPhotoViewer extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final List<String> labels;
  const _FullscreenPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.labels,
  });

  @override
  State<_FullscreenPhotoViewer> createState() =>
      _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<_FullscreenPhotoViewer> {
  late PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _current < widget.labels.length ? widget.labels[_current] : '',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text('${_current + 1} / ${widget.photos.length}',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 14)),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                  child: Image.file(File(widget.photos[i]),
                      fit: BoxFit.contain)),
            ),
          ),
          if (widget.photos.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.photos.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _current == i ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _current == i
                          ? const Color(0xFFFFD700)
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}