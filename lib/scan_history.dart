import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanHistory {
  final String id;
  final DateTime date;
  final Map<String, dynamic> scores;
  final String? imagePath;
  final List<String> imagePaths;

  ScanHistory({
    required this.id,
    required this.date,
    required this.scores,
    this.imagePath,
    List<String>? imagePaths,
  }) : imagePaths = imagePaths ?? (imagePath != null ? [imagePath] : []);

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'scores': scores,
    'imagePath': imagePath,
    'imagePaths': imagePaths,
  };

  factory ScanHistory.fromJson(Map<String, dynamic> json) {
    final paths = json['imagePaths'] != null
        ? List<String>.from(json['imagePaths'])
        : (json['imagePath'] != null ? [json['imagePath'] as String] : <String>[]);
    return ScanHistory(
      id: json['id'] ?? '',
      date: DateTime.parse(json['date']),
      scores: Map<String, dynamic>.from(json['scores']),
      imagePath: json['imagePath'],
      imagePaths: paths,
    );
  }

  static String? get _userId =>
      FirebaseAuth.instance.currentUser?.uid;

  static Future<void> saveScan(
      Map<String, dynamic> scores, String? imagePath, {List<String>? imagePaths}) async {
    if (_userId == null) return;

    final paths = imagePaths ?? (imagePath != null ? [imagePath] : []);

    final scan = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'scores': scores,
      'imagePath': imagePath,
      'imagePaths': paths,
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