import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'scan_history.dart';
import 'lock_in_page.dart';
class ScanDetailScreen extends StatefulWidget {
  final ScanHistory scan;
  const ScanDetailScreen({super.key, required this.scan});

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  String _gender = '';
  int _currentPhoto = 0;
  final PageController _photoController = PageController();

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
    if (score >= 80) return 'High Attractive';
    if (score >= 70) return 'Strong';
    if (score >= 60) return 'Attractive';
    if (score >= 50) return 'Developing';
    return 'Below Average';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildAnalysisTag(String label, String value) {
    final hasValue = value.isNotEmpty && value != 'Not analysed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValue
              ? const Color(0xFFFFD700).withOpacity(0.35)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            hasValue ? value : 'Not analysed',
            style: TextStyle(
              color: hasValue ? const Color(0xFFFFD700) : Colors.white30,
              fontSize: 14,
              fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceAnalysisSection(Map<String, dynamic> scores) {
    final faceShape = (scores['faceShape'] as String?)?.isNotEmpty == true
        ? scores['faceShape'] as String : 'Not analysed';
    final canthalTilt = (scores['canthalTilt'] as String?)?.isNotEmpty == true
        ? scores['canthalTilt'] as String : 'Not analysed';
    final eyeShape = (scores['eyeShape'] as String?)?.isNotEmpty == true
        ? scores['eyeShape'] as String : 'Not analysed';
    final eyeType = (scores['eyeType'] as String?)?.isNotEmpty == true
        ? scores['eyeType'] as String : 'Not analysed';

    final fields = [
      ('Face Shape', faceShape),
      ('Canthal Tilt', canthalTilt),
      ('Eye Shape', eyeShape),
      ('Eye Type', eyeType),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🔍', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'Face Analysis',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: fields
                .map((f) => _buildAnalysisTag(f.$1, f.$2))
                .toList(),
          ),
        ],
      ),
    );
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
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
              valueColor: AlwaysStoppedAnimation(_getScoreColor(score)),
              minHeight: 8,
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

  Widget _buildPhotoSection() {
    final photos = widget.scan.imagePaths
        .where((p) => File(p).existsSync())
        .toList();
    const photoLabels = ['Front', 'Right', 'Left'];

    if (photos.isEmpty) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Icon(Icons.face, color: Colors.white38, size: 80),
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          PageView.builder(
            controller: _photoController,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _currentPhoto = i),
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () => _openFullscreen(photos, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(photos[i]), fit: BoxFit.cover),
                      // Label badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            i < photoLabels.length ? photoLabels[i] : '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      // Fullscreen icon hint
                      Positioned(
                        bottom: 18,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.fullscreen,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      // Swipe hint on first photo
                      if (photos.length > 1 && i == 0)
                        Positioned(
                          bottom: 18,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.swipe,
                                    color: Colors.white54, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${photos.length} photos',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Dot indicators
          if (photos.length > 1)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  photos.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPhoto == i ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _currentPhoto == i
                          ? const Color(0xFFFFD700)
                          : Colors.white24,
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

  @override
  Widget build(BuildContext context) {
    final scores = widget.scan.scores;
    final overall = scores['overall'] as int? ?? 0;
    final genderLabel = _gender == 'Female' ? 'Femininity' : 'Masculinity';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Scan Details',
            style: TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Photo section with carousel
            _buildPhotoSection(),
            const SizedBox(height: 20),

            // Date
            Text(_formatDate(widget.scan.date),
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 20),

            // Overall score circle
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: _getScoreColor(overall), width: 4),
                color: const Color(0xFF1A1A1A),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$overall',
                      style: TextStyle(
                          color: _getScoreColor(overall),
                          fontSize: 46,
                          fontWeight: FontWeight.bold)),
                  Text(_getScoreLabel(overall),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text('Overall Score',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            // Score breakdown
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Score Breakdown',
                      style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildScoreRow('Skin Quality', scores['skin'] as int? ?? 0),
                  _buildScoreRow(
                      'Cheekbones', scores['cheekbones'] as int? ?? 0),
                  _buildScoreRow('Jawline', scores['jawline'] as int? ?? 0),
                  _buildScoreRow('Neck', scores['neck'] as int? ?? 0),
                  _buildScoreRow(genderLabel,
                      scores['masculinityFemininity'] as int? ?? 0),
                  _buildScoreRow('Eyes', scores['eyes'] as int? ?? 0),
                  _buildScoreRow(
                      'Facial Symmetry', scores['symmetry'] as int? ?? 0),
                  _buildScoreRow(
                      'Maximum Potential', scores['maxPotential'] as int? ?? 0),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Face Analysis section
            _buildFaceAnalysisSection(scores),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ─── Full-screen photo viewer ─────────────────────────────────────────────────

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
              bottom: 24,
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