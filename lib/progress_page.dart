import 'package:flutter/material.dart';
import 'dart:io';
import 'scan_history.dart';
import 'scan_detail_screen.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage>
    with TickerProviderStateMixin {
  List<ScanHistory> _history = [];
  bool _loading = true;

  late AnimationController _fadeCtrl;
  late AnimationController _staggerCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadHistory();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await ScanHistory.getHistory();
    setState(() {
      _history = history;
      _loading = false;
    });
    _fadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _staggerCtrl.forward();
    });
  }

  void _refresh() {
    setState(() {
      _loading = true;
      _history = [];
    });
    _fadeCtrl.reset();
    _staggerCtrl.reset();
    _loadHistory();
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

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}  ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  int get _bestScore {
    if (_history.isEmpty) return 0;
    return _history
        .map((s) => s.scores['overall'] as int? ?? 0)
        .reduce((a, b) => a > b ? a : b);
  }

  int get _latestScore {
    if (_history.isEmpty) return 0;
    return _history.first.scores['overall'] as int? ?? 0;
  }

  double get _avgScore {
    if (_history.isEmpty) return 0;
    final sum = _history.fold<int>(
        0, (acc, s) => acc + (s.scores['overall'] as int? ?? 0));
    return sum / _history.length;
  }

  int get _improvement {
    if (_history.length < 2) return 0;
    final latest = _history.first.scores['overall'] as int? ?? 0;
    final oldest = _history.last.scores['overall'] as int? ?? 0;
    return latest - oldest;
  }

  String _getNextTier(int score) {
    if (score >= 90) return 'Elite tier reached 🏅';
    if (score >= 80) return 'Next: Elite (90+)';
    if (score >= 70) return 'Next: Highly Attractive (80+)';
    if (score >= 60) return 'Next: Attractive (70+)';
    if (score >= 50) return 'Next: Above Average (60+)';
    return 'Next: Average (50+)';
  }

  double _tierProgress(int score) {
    if (score >= 90) return 1.0;
    final tiers = [0, 50, 60, 70, 80, 90];
    for (int i = 0; i < tiers.length - 1; i++) {
      if (score < tiers[i + 1]) {
        return (score - tiers[i]) / (tiers[i + 1] - tiers[i]);
      }
    }
    return 1.0;
  }

  // Helper: staggered animation interval for an item index
  Animation<double> _staggerOpacity(int index) {
    final start = (index * 120 / 2200).clamp(0.0, 0.85);
    final end = (start + 0.25).clamp(0.0, 1.0);
    return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _staggerCtrl,
            curve: Interval(start, end, curve: Curves.easeOut)));
  }

  Animation<Offset> _staggerSlide(int index) {
    final start = (index * 120 / 2200).clamp(0.0, 0.85);
    final end = (start + 0.25).clamp(0.0, 1.0);
    return Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _staggerCtrl,
            curve: Interval(start, end, curve: Curves.easeOut)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Progress',
            style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: _refresh,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.refresh,
                  color: Colors.white38, size: 22),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFFFD700)))
          : FadeTransition(
              opacity: _fadeAnim,
              child: _history.isEmpty
                  ? _buildEmpty()
                  : _buildContent(),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: const Icon(Icons.bar_chart,
                color: Colors.white24, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('No scans yet',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'Scan your face in the Face Rating tab\nto start tracking your progress.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats Banner ──
          SlideTransition(
              position: _staggerSlide(0),
              child: FadeTransition(
                  opacity: _staggerOpacity(0),
                  child: _buildStatsBanner())),
          const SizedBox(height: 16),

          // ── Trend Chart ──
          if (_history.length >= 2) ...[
            SlideTransition(
                position: _staggerSlide(1),
                child: FadeTransition(
                    opacity: _staggerOpacity(1),
                    child: _buildTrendChart())),
            const SizedBox(height: 16),
          ],

          // ── Best Breakdown ──
          SlideTransition(
              position: _staggerSlide(2),
              child: FadeTransition(
                  opacity: _staggerOpacity(2),
                  child: _buildBestBreakdown())),
          const SizedBox(height: 20),

          // ── Scan History Header ──
          SlideTransition(
            position: _staggerSlide(3),
            child: FadeTransition(
              opacity: _staggerOpacity(3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                        width: 3,
                        height: 16,
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    const Text('Scan History',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ]),
                  Text(
                      '${_history.length} scan${_history.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Scan Cards ──
          ..._history.asMap().entries.map((e) {
            final animIndex = e.key + 4;
            return SlideTransition(
              position: _staggerSlide(animIndex),
              child: FadeTransition(
                opacity: _staggerOpacity(animIndex),
                child: _buildScanCard(e.value, e.key),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Stats Banner ────────────────────────────────────────────────────────────
  Widget _buildStatsBanner() {
    final imp = _improvement;
    final latestColor = _getScoreColor(_latestScore);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.2),
            width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Score circle
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: _AnimatedCircularBar(
                        value: _latestScore / 100,
                        color: latestColor,
                        delay: 300),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_latestScore',
                          style: TextStyle(
                              color: latestColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1)),
                      Text(_getScoreLabel(_latestScore),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 7)),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LATEST SCORE',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _statPill('🏆', '$_bestScore', 'Best',
                          const Color(0xFFFFD700)),
                      const SizedBox(width: 8),
                      _statPill('📊', _avgScore.toStringAsFixed(1),
                          'Avg', const Color(0xFF7B68EE)),
                      const SizedBox(width: 8),
                      _statPill('📋', '${_history.length}', 'Scans',
                          const Color(0xFF29B6F6)),
                    ]),
                    if (_history.length >= 2) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (imp >= 0
                                    ? const Color(0xFF8BC34A)
                                    : Colors.redAccent)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: (imp >= 0
                                        ? const Color(0xFF8BC34A)
                                        : Colors.redAccent)
                                    .withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  imp >= 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: imp >= 0
                                      ? const Color(0xFF8BC34A)
                                      : Colors.redAccent,
                                  size: 13),
                              const SizedBox(width: 4),
                              Text(
                                '${imp >= 0 ? '+' : ''}$imp from first scan',
                                style: TextStyle(
                                    color: imp >= 0
                                        ? const Color(0xFF8BC34A)
                                        : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tier progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tier Progress',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    Text(_getNextTier(_latestScore),
                        style: TextStyle(
                            color: latestColor, fontSize: 11)),
                  ]),
              const SizedBox(height: 7),
              _AnimatedBar(
                  value: _tierProgress(_latestScore),
                  color: latestColor,
                  delay: 400),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(
      String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  // ── Trend Chart ─────────────────────────────────────────────────────────────
  Widget _buildTrendChart() {
    final data = _history.reversed.take(10).toList();
    final scores =
        data.map((s) => s.scores['overall'] as int? ?? 0).toList();
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final range = (maxScore - minScore).clamp(10, 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('Score Trend',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${data.length} scans',
                style: const TextStyle(
                    color: Colors.white24, fontSize: 11)),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.asMap().entries.map((e) {
                final score = e.value.scores['overall'] as int? ?? 0;
                final barHeight =
                    ((score - minScore + 5) / (range + 5)) * 96 + 12;
                final isLatest = e.key == data.length - 1;
                final color = _getScoreColor(score);
                return Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLatest)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text('$score',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        _AnimatedBar(
                          value: 1.0,
                          color: color,
                          heightOverride: barHeight,
                          borderRadius: 6,
                          delay: 200 + e.key * 55,
                        ),
                        const SizedBox(height: 5),
                        Text('${e.key + 1}',
                            style: const TextStyle(
                                color: Colors.white24,
                                fontSize: 9)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('← Oldest',
                  style: TextStyle(
                      color: Colors.white24, fontSize: 10)),
              const Text('Newest →',
                  style: TextStyle(
                      color: Colors.white24, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Best Scan Breakdown ──────────────────────────────────────────────────────
  Widget _buildBestBreakdown() {
    final best = _history.reduce((a, b) =>
        (a.scores['overall'] as int? ?? 0) >
                (b.scores['overall'] as int? ?? 0)
            ? a
            : b);
    final sc = best.scores;

    final categories = [
      ('Skin', '✨', sc['skin'] as int? ?? 0),
      ('Cheekbones', '🦴', sc['cheekbones'] as int? ?? 0),
      ('Jawline', '💎', sc['jawline'] as int? ?? 0),
      ('Eyes', '👁️', sc['eyes'] as int? ?? 0),
      ('Symmetry', '⚖️', sc['symmetry'] as int? ?? 0),
      ('Neck', '📐', sc['neck'] as int? ?? 0),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('Best Scan Breakdown',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(_formatDate(best.date),
                style: const TextStyle(
                    color: Colors.white24, fontSize: 10)),
          ]),
          const SizedBox(height: 16),
          ...categories.asMap().entries.map((e) {
            final name = e.value.$1;
            final emoji = e.value.$2;
            final score = e.value.$3;
            final color = _getScoreColor(score);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Text(emoji,
                    style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13)),
                            Text('$score',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ]),
                      const SizedBox(height: 5),
                      _AnimatedBar(
                          value: score / 100,
                          color: color,
                          delay: 400 + e.key * 60,
                          height: 5),
                    ],
                  ),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ── Scan Card ───────────────────────────────────────────────────────────────
  Widget _buildScanCard(ScanHistory scan, int index) {
    final overall = scan.scores['overall'] as int? ?? 0;
    final isLatest = index == 0;
    final prevScore = index < _history.length - 1
        ? (_history[index + 1].scores['overall'] as int? ?? 0)
        : null;
    final diff = prevScore != null ? overall - prevScore : null;
    final color = _getScoreColor(overall);

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ScanDetailScreen(scan: scan))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isLatest
              ? const Color(0xFF141200)
              : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLatest
                ? const Color(0xFFFFD700).withOpacity(0.3)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            // Photo thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: scan.imagePath != null &&
                      File(scan.imagePath!).existsSync()
                  ? Image.file(File(scan.imagePath!),
                      width: 56, height: 56, fit: BoxFit.cover)
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.face,
                          color: Colors.white24, size: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(_formatDate(scan.date),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    if (isLatest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('LATEST',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text('$overall',
                          style: TextStyle(
                              color: color,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text('/100',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(_getScoreLabel(overall),
                          style: TextStyle(
                              color: color.withOpacity(0.8),
                              fontSize: 12)),
                      const Spacer(),
                      if (diff != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (diff >= 0
                                    ? const Color(0xFF8BC34A)
                                    : Colors.redAccent)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: (diff >= 0
                                        ? const Color(0xFF8BC34A)
                                        : Colors.redAccent)
                                    .withOpacity(0.35)),
                          ),
                          child: Text(
                            '${diff >= 0 ? '+' : ''}$diff',
                            style: TextStyle(
                                color: diff >= 0
                                    ? const Color(0xFF8BC34A)
                                    : Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _AnimatedBar(
                      value: overall / 100,
                      color: color,
                      delay: 100 + index * 50,
                      height: 4),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Animated Horizontal Bar ───────────────────────────────────────────────────

class _AnimatedBar extends StatefulWidget {
  final double value;
  final Color color;
  final double height;
  final double? heightOverride;
  final double borderRadius;
  final int delay;

  const _AnimatedBar({
    required this.value,
    required this.color,
    this.height = 8,
    this.heightOverride,
    this.borderRadius = 4,
    this.delay = 0,
  });

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar>
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
  void didUpdateWidget(_AnimatedBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(begin: _anim.value, end: widget.value)
          .animate(CurvedAnimation(
              parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.heightOverride != null) {
      return AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          height: widget.heightOverride! * _anim.value,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color.withOpacity(0.5),
                widget.color,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(widget.height),
        child: LinearProgressIndicator(
          value: _anim.value,
          backgroundColor: Colors.white.withOpacity(0.07),
          valueColor: AlwaysStoppedAnimation(widget.color),
          minHeight: widget.height,
        ),
      ),
    );
  }
}

// ── Animated Circular Bar (for stats banner score circle) ────────────────────

class _AnimatedCircularBar extends StatefulWidget {
  final double value;
  final Color color;
  final int delay;

  const _AnimatedCircularBar(
      {required this.value, required this.color, this.delay = 0});

  @override
  State<_AnimatedCircularBar> createState() =>
      _AnimatedCircularBarState();
}

class _AnimatedCircularBarState extends State<_AnimatedCircularBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
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
      builder: (_, __) => CircularProgressIndicator(
        value: _anim.value,
        strokeWidth: 4,
        backgroundColor: Colors.white10,
        valueColor: AlwaysStoppedAnimation(widget.color),
        strokeCap: StrokeCap.round,
      ),
    );
  }
}