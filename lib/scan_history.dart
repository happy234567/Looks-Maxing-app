import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanHistory {
  final String id;
  final DateTime date;
  final Map<String, dynamic> scores;
  /// Primary image URL (Firebase Storage download URL). Never a local path.
  final String? imageUrl;
  /// All image URLs (Firebase Storage download URLs). Never local paths.
  final List<String> imageUrls;

  // Legacy fields kept for backward-compat parsing only
  final String? imagePath;
  final List<String> imagePaths;

  ScanHistory({
    required this.id,
    required this.date,
    required this.scores,
    this.imageUrl,
    List<String>? imageUrls,
    this.imagePath,
    List<String>? imagePaths,
  })  : imageUrls = imageUrls ?? [],
        imagePaths = imagePaths ?? [];

  /// The best available primary image source (prefers URL over legacy path).
  String? get displayImage {
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    if (imagePath != null && imagePath!.startsWith('http')) return imagePath;
    return null;
  }

  /// The best available list of images (prefers URLs over legacy paths).
  List<String> get displayImages {
    if (imageUrls.isNotEmpty) return imageUrls;
    // Fall back to legacy imagePaths that are network URLs
    final networkPaths = imagePaths.where((p) => p.startsWith('http')).toList();
    if (networkPaths.isNotEmpty) return networkPaths;
    return [];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'scores': scores,
    'imageUrl': imageUrl,
    'imageUrls': imageUrls,
    // Keep legacy fields for backward compat
    'imagePath': imageUrl ?? imagePath,
    'imagePaths': imageUrls.isNotEmpty ? imageUrls : imagePaths,
  };

  factory ScanHistory.fromJson(Map<String, dynamic> json) {
    // Parse new-style URLs
    final String? url = json['imageUrl'] as String?;
    final List<String> urls = json['imageUrls'] != null
        ? List<String>.from(json['imageUrls'])
        : <String>[];

    // Parse legacy paths
    final String? legacyPath = json['imagePath'] as String?;
    final List<String> legacyPaths = json['imagePaths'] != null
        ? List<String>.from(json['imagePaths'])
        : (legacyPath != null ? [legacyPath] : <String>[]);

    return ScanHistory(
      id: json['id'] ?? '',
      date: DateTime.parse(json['date']),
      scores: Map<String, dynamic>.from(json['scores']),
      imageUrl: url ?? (legacyPath != null && legacyPath.startsWith('http') ? legacyPath : null),
      imageUrls: urls.isNotEmpty
          ? urls
          : legacyPaths.where((p) => p.startsWith('http')).toList(),
      imagePath: legacyPath,
      imagePaths: legacyPaths,
    );
  }

  static String? get _userId =>
      FirebaseAuth.instance.currentUser?.uid;

  /// Save a scan with network image URLs only.
  /// [imageUrl] should be a Firebase Storage download URL (or null).
  /// [imageUrls] should all be Firebase Storage download URLs.
  static Future<void> saveScan(
      Map<String, dynamic> scores, String? imageUrl, {List<String>? imageUrls}) async {
    if (_userId == null) return;

    // Filter out any non-network paths that might have leaked in
    final cleanUrls = (imageUrls ?? [])
        .where((u) => u.startsWith('http'))
        .toList();
    final cleanUrl = (imageUrl != null && imageUrl.startsWith('http')) ? imageUrl : null;

    final scan = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'scores': scores,
      'imageUrl': cleanUrl,
      'imageUrls': cleanUrls,
      // Legacy fields for backward compat
      'imagePath': cleanUrl,
      'imagePaths': cleanUrls,
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('scans')
        .add(scan);
  }

  static Future<List<ScanHistory>> getHistory() async {
    if (_userId == null) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('scans')
          .orderBy('date', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => ScanHistory.fromJson(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearHistory() async {
    if (_userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('scans')
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}