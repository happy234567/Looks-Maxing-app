import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'camera_screen.dart';
import 'dart:io';

class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> scores;
  final List<String> imagePaths;
  const ResultsScreen({super.key, required this.scores, this.imagePaths = const []});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  String _gender = 'Male';
  final PageController _pageController = PageController();
  final PageController _photoController = PageController();
  int _currentPage = 0;
  int _currentPhoto = 0;

  @override
  void initState() {
    super.initState();
    _loadGender();
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

  Widget _buildScoreRow(String label, int score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14)),
              Row(
                children: [
                  Text(_getScoreLabel(score),
                      style: TextStyle(
                          color: _getScoreColor(score), fontSize: 12)),
                  const SizedBox(width: 8),
                  Text('$score',
                      style: TextStyle(
                          color: _getScoreColor(score),
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white12,
              valueColor:
                  AlwaysStoppedAnimation(_getScoreColor(score)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCarousel(List<String> photos, List<String> labels) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          PageView.builder(
            controller: _photoController,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _currentPhoto = i),
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () => _openFullscreen(photos, i),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(photos[i]), fit: BoxFit.cover),
                        // Label badge
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              i < labels.length ? labels[i] : '',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                        // Tap hint
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.fullscreen,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Dot indicators
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
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPhoto == i ? 18 : 6,
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

  Widget _buildDetailCard(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scores = widget.scores;
    final overall = scores['overall'] as int? ?? 0;
    final genderLabel = _gender == 'Female' ? 'Femininity' : 'Masculinity';

    final faceShape = scores['faceShape'] as String? ?? 'Unknown';
    final canthalTilt = scores['canthalTilt'] as String? ?? 'Unknown';
    final eyeShape = scores['eyeShape'] as String? ?? 'Unknown';
    final eyeType = scores['eyeType'] as String? ?? 'Unknown';
    final photos = widget.imagePaths
        .where((p) => File(p).existsSync())
        .toList();
    final photoLabels = ['Front', 'Right', 'Left'];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Your Results',
            style: TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Photo carousel
          if (photos.isNotEmpty)
            _buildPhotoCarousel(photos, photoLabels),

          // Overall score - always visible at top
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _getScoreColor(overall), width: 4),
                    color: const Color(0xFF1A1A1A),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$overall',
                          style: TextStyle(
                              color: _getScoreColor(overall),
                              fontSize: 42,
                              fontWeight: FontWeight.bold)),
                      Text(_getScoreLabel(overall),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overall Score',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_getScoreLabel(overall),
                        style: TextStyle(
                            color: _getScoreColor(overall),
                            fontSize: 14)),
                    const SizedBox(height: 8),
                    // Page indicators
                    Row(
                      children: List.generate(
                        2,
                        (i) => Container(
                          margin:
                              const EdgeInsets.only(right: 6),
                          width: _currentPage == i ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? const Color(0xFFFFD700)
                                : Colors.white24,
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Swipeable pages
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) =>
                  setState(() => _currentPage = i),
              children: [
                // PAGE 1 — Score Breakdown
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text('Score Breakdown',
                            style: TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildScoreRow('Skin Quality',
                            scores['skin'] as int? ?? 0),
                        _buildScoreRow('Cheekbones',
                            scores['cheekbones'] as int? ?? 0),
                        _buildScoreRow('Jawline',
                            scores['jawline'] as int? ?? 0),
                        _buildScoreRow('Neck',
                            scores['neck'] as int? ?? 0),
                        _buildScoreRow(genderLabel,
                            scores['masculinityFemininity']
                                    as int? ??
                                0),
                        _buildScoreRow('Eyes',
                            scores['eyes'] as int? ?? 0),
                        _buildScoreRow('Facial Symmetry',
                            scores['symmetry'] as int? ?? 0),
                        _buildScoreRow('Maximum Potential',
                            scores['maxPotential'] as int? ?? 0),
                      ],
                    ),
                  ),
                ),

                // PAGE 2 — Face Analysis Details
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text('Face Analysis',
                          style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.95,
                        children: [
                          _buildDetailCard('🧑', 'Face Shape',
                              faceShape),
                          _buildDetailCard('⚖️', 'Canthal Tilt',
                              canthalTilt),
                          _buildDetailCard('👁️', 'Eye Shape',
                              eyeShape),
                          _buildDetailCard('👀', 'Eye Type',
                              eyeType),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Swipe hint
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _currentPage == 0
                  ? 'Swipe left for face analysis →'
                  : '← Swipe right for scores',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12),
            ),
          ),

          // Scan again button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CameraScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Scan Again',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  State<_FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
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
            child: Text(
              '${_current + 1} / ${widget.photos.length}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
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
                child: Image.file(
                  File(widget.photos[i]),
                  fit: BoxFit.contain,
                ),
              ),
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