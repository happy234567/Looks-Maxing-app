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
    with SingleTickerProviderStateMixin {
  List<ScanHistory> _history = [];
  bool _loading = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadHistory();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await ScanHistory.getHistory();
    setState(() {
      _history = history;
      _loading = false;
    });
    _fadeCtrl.forward();
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
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}  ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Stats computed from history
  int get _bestScore {
    if (_history.isEmpty) return 0;
    return _history.map((s) => s.scores['overall'] as int? ?? 0).reduce((a, b) => a > b ? a : b);
  }

  int get _latestScore {
    if (_history.isEmpty) return 0;
    return _history.first.scores['overall'] as int? ?? 0;
  }

  double get _avgScore {
    if (_history.isEmpty) return 0;
    final sum = _history.fold<int>(0, (acc, s) => acc + (s.scores['overall'] as int? ?? 0));
    return sum / _history.length;
  }

  int get _improvement {
    if (_history.length < 2) return 0;
    final latest = _history.first.scores['overall'] as int? ?? 0;
    final oldest = _history.last.scores['overall'] as int? ?? 0;
    return latest - oldest;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Progress', style: TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() {
                _loading = true;
                _history = [];
                _fadeCtrl.reset();
                _loadHistory();
              }),
              child: const Icon(Icons.refresh, color: Colors.white38),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)))
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
          const Icon(Icons.bar_chart, color: Colors.white12, size: 80),
          const SizedBox(height: 20),
          const Text('No scans yet',
              style: TextStyle(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Go to Face Rating and scan your face\nto start tracking your progress.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats banner ────────────────────────────────────────────────
          _buildStatsBanner(),
          const SizedBox(height: 20),

          // ── Score trend chart ────────────────────────────────────────────
          if (_history.length >= 2) ...[
            _buildTrendChart(),
            const SizedBox(height: 20),
          ],

          // ── Best score breakdown ─────────────────────────────────────────
          _buildBestBreakdown(),
          const SizedBox(height: 20),

          // ── Scan history list ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Scan History',
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${_history.length} scan${_history.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ..._history.asMap().entries.map((e) => _buildScanCard(e.value, e.key)),
        ],
      ),
    );
  }

  // ── Stats banner ──────────────────────────────────────────────────────────
  Widget _buildStatsBanner() {
    final imp = _improvement;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A00), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Column(children: [
        Row(children: [
          // Latest score circle
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _getScoreColor(_latestScore), width: 3),
              color: const Color(0xFF1A1A1A),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$_latestScore',
                  style: TextStyle(color: _getScoreColor(_latestScore),
                      fontSize: 26, fontWeight: FontWeight.bold)),
              Text(_getScoreLabel(_latestScore),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 8)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Latest Score', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              _statChip('🏆 Best', '$_bestScore', const Color(0xFFFFD700)),
              const SizedBox(width: 8),
              _statChip('📊 Avg', _avgScore.toStringAsFixed(1), const Color(0xFF7B68EE)),
            ]),
            const SizedBox(height: 8),
            if (_history.length >= 2)
              Row(children: [
                Icon(imp >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: imp >= 0 ? const Color(0xFF8BC34A) : Colors.redAccent, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${imp >= 0 ? '+' : ''}$imp from first scan',
                  style: TextStyle(
                      color: imp >= 0 ? const Color(0xFF8BC34A) : Colors.redAccent,
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ]),
          ])),
        ]),
        const SizedBox(height: 14),
        // Progress bar to next level
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Progress to next tier',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            Text(_getNextTier(_latestScore),
                style: TextStyle(color: _getScoreColor(_latestScore), fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          _AnimatedBar(value: _tierProgress(_latestScore), color: _getScoreColor(_latestScore)),
        ]),
      ]),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ]),
    );
  }

  String _getNextTier(int score) {
    if (score >= 90) return '🏅 Elite tier';
    if (score >= 80) return 'Next: Elite (90+)';
    if (score >= 70) return 'Next: High Attractive (80+)';
    if (score >= 60) return 'Next: Strong (70+)';
    if (score >= 50) return 'Next: Attractive (60+)';
    return 'Next: Developing (50+)';
  }

  double _tierProgress(int score) {
    if (score >= 90) return 1.0;
    final tiers = [50, 60, 70, 80, 90];
    for (int i = 0; i < tiers.length - 1; i++) {
      if (score < tiers[i + 1]) {
        return (score - tiers[i]) / (tiers[i + 1] - tiers[i]);
      }
    }
    return (score - 40) / 10;
  }

  // ── Score trend chart ─────────────────────────────────────────────────────
  Widget _buildTrendChart() {
    // Show last 10 scans reversed (oldest → newest)
    final data = _history.reversed.take(10).toList();
    final maxScore = data.map((s) => s.scores['overall'] as int? ?? 0).reduce((a, b) => a > b ? a : b);
    final minScore = data.map((s) => s.scores['overall'] as int? ?? 0).reduce((a, b) => a < b ? a : b);
    final range = (maxScore - minScore).clamp(10, 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Score Trend', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.asMap().entries.map((e) {
              final score = e.value.scores['overall'] as int? ?? 0;
              // Max bar height = 96, leaves room for label (14) + gap (2) + number (12) + gap (4) = 32. Total = 128 < 150
              final barHeight = ((score - minScore + 5) / (range + 5)) * 96 + 8;
              final isLatest = e.key == data.length - 1;
              final color = _getScoreColor(score);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 14,
                        child: isLatest
                            ? FittedBox(
                                child: Text('$score',
                                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)))
                            : null,
                      ),
                      const SizedBox(height: 2),
                      _AnimatedBar(
                        value: 1.0,
                        color: color,
                        heightOverride: barHeight,
                        borderRadius: 6,
                        delay: e.key * 60,
                      ),
                      const SizedBox(height: 4),
                      Text('${e.key + 1}',
                          style: const TextStyle(color: Colors.white24, fontSize: 9)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        const Text('← Oldest scans   Newest →',
            style: TextStyle(color: Colors.white24, fontSize: 10)),
      ]),
    );
  }

  // ── Best score breakdown ──────────────────────────────────────────────────
  Widget _buildBestBreakdown() {
    final best = _history.reduce((a, b) =>
        (a.scores['overall'] as int? ?? 0) > (b.scores['overall'] as int? ?? 0) ? a : b);
    final scores = best.scores;

    final categories = [
      ('Skin', scores['skin'] as int? ?? 0),
      ('Cheekbones', scores['cheekbones'] as int? ?? 0),
      ('Jawline', scores['jawline'] as int? ?? 0),
      ('Eyes', scores['eyes'] as int? ?? 0),
      ('Symmetry', scores['symmetry'] as int? ?? 0),
      ('Neck', scores['neck'] as int? ?? 0),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🏆 Best Scan Breakdown',
              style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(_formatDate(best.date),
              style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ]),
        const SizedBox(height: 14),
        ...categories.map((cat) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(cat.$1, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text('${cat.$2}', style: TextStyle(
                  color: _getScoreColor(cat.$2), fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            _AnimatedBar(value: cat.$2 / 100, color: _getScoreColor(cat.$2), height: 6),
          ]),
        )),
      ]),
    );
  }

  // ── Scan history card ─────────────────────────────────────────────────────
  Widget _buildScanCard(ScanHistory scan, int index) {
    final overall = scan.scores['overall'] as int? ?? 0;
    final isLatest = index == 0;
    final prevScore = index < _history.length - 1
        ? (_history[index + 1].scores['overall'] as int? ?? 0)
        : null;
    final diff = prevScore != null ? overall - prevScore : null;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ScanDetailScreen(scan: scan))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isLatest ? const Color(0xFF1A1500) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLatest
                ? const Color(0xFFFFD700).withOpacity(0.4)
                : Colors.white12,
          ),
        ),
        child: Row(children: [
          // Photo thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: scan.imagePath != null && File(scan.imagePath!).existsSync()
                ? Image.file(File(scan.imagePath!), width: 58, height: 58, fit: BoxFit.cover)
                : Container(
                    width: 58, height: 58,
                    color: const Color(0xFF2A2A2A),
                    child: const Icon(Icons.face, color: Colors.white38, size: 28)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_formatDate(scan.date),
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              if (isLatest) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('LATEST',
                      style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Text('$overall',
                  style: TextStyle(color: _getScoreColor(overall),
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('/100', style: TextStyle(color: Colors.white38, fontSize: 13)),
              const SizedBox(width: 8),
              Text(_getScoreLabel(overall),
                  style: TextStyle(color: _getScoreColor(overall), fontSize: 12)),
              const Spacer(),
              if (diff != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (diff >= 0 ? const Color(0xFF8BC34A) : Colors.redAccent)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (diff >= 0 ? const Color(0xFF8BC34A) : Colors.redAccent)
                          .withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    '${diff >= 0 ? '+' : ''}$diff',
                    style: TextStyle(
                        color: diff >= 0 ? const Color(0xFF8BC34A) : Colors.redAccent,
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            _AnimatedBar(value: overall / 100, color: _getScoreColor(overall), height: 4),
          ])),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ]),
      ),
    );
  }
}

// ── Animated bar widget ───────────────────────────────────────────────────────

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
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 200 + widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_AnimatedBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(begin: _anim.value, end: widget.value)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl..reset()..forward();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.heightOverride != null) {
      // Vertical bar for chart
      return AnimatedBuilder(
        animation: _anim,
        builder: (_, _) => Container(
          height: widget.heightOverride! * _anim.value,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.8),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => ClipRRect(
        borderRadius: BorderRadius.circular(widget.height),
        child: LinearProgressIndicator(
          value: _anim.value,
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation(widget.color),
          minHeight: widget.height,
        ),
      ),
    );
  }
}