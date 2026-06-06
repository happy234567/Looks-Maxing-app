import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FoodScanCountService {
  static const int _freeLimit = 3;
  static const int _premiumLimit = 10;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static String get _countKey => 'food_scan_count_$_uid';
  static String get _dateKey => 'food_scan_date_$_uid';
  static String get _today => DateTime.now().toIso8601String().substring(0, 10);

  static Future<int> getCountToday() async {
    if (_uid == null) return 0;
    final p = await SharedPreferences.getInstance();
    final stored = p.getString(_dateKey);
    if (stored != _today) return 0;
    return p.getInt(_countKey) ?? 0;
  }

  static Future<bool> canScan({required bool isPremium}) async {
    if (_uid == null) return false;
    final count = await getCountToday();
    return count < (isPremium ? _premiumLimit : _freeLimit);
  }

  static Future<void> recordScan() async {
    if (_uid == null) return;
    final p = await SharedPreferences.getInstance();
    final stored = p.getString(_dateKey);
    int count = 0;
    if (stored == _today) {
      count = p.getInt(_countKey) ?? 0;
    }
    await p.setInt(_countKey, count + 1);
    await p.setString(_dateKey, _today);
  }

  static Future<int> remainingScans({required bool isPremium}) async {
    if (_uid == null) return 0;
    final count = await getCountToday();
    final limit = isPremium ? _premiumLimit : _freeLimit;
    return (limit - count).clamp(0, limit);
  }
}
