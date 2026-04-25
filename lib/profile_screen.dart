import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import 'billing_service.dart';
import 'notification_service.dart';
import 'deleted_users_service.dart';
import 'scan_cooldown_service.dart';
import 'lock_in_notification_service.dart';
import 'ad_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final BillingService _billing = BillingService();
  String _username = '', _gender = '', _email = '', _firstName = '';
  int _age = 0;
  double _weight = 0, _height = 0;
  String _weightUnit = 'kg', _heightUnit = 'cm';
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _billing.addListener(_onBilling);
    if (!_billing.isInitialized) _billing.initialize();
  }

  void _onBilling() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _billing.removeListener(_onBilling);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _username = prefs.getString('username') ?? 'User';
      _gender = prefs.getString('gender') ?? '';
      _firstName = prefs.getString('firstName') ?? '';
      _email = user?.email ?? '';
      _age = prefs.getInt('age') ?? 0;
      _weight = prefs.getDouble('weight') ?? 0;
      _weightUnit = prefs.getString('weightUnit') ?? 'kg';
      _height = prefs.getDouble('height') ?? 0;
      _heightUnit = prefs.getString('heightUnit') ?? 'cm';
      _loadingProfile = false;
    });

    // Also try to refresh from Firestore
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get().timeout(const Duration(seconds: 5));
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _age = d['age'] as int? ?? _age;
          _weight = (d['weight'] as num?)?.toDouble() ?? _weight;
          _weightUnit = d['weightUnit'] as String? ?? _weightUnit;
          _height = (d['height'] as num?)?.toDouble() ?? _height;
          _heightUnit = d['heightUnit'] as String? ?? _heightUnit;
          _gender = d['gender'] as String? ?? _gender;
        });
        // Sync to local
        await prefs.setInt('age', _age);
        await prefs.setDouble('weight', _weight);
        await prefs.setString('weightUnit', _weightUnit);
        await prefs.setDouble('height', _height);
        await prefs.setString('heightUnit', _heightUnit);
      }
    } catch (_) {}
  }

  String _formatHeight() {
    if (_height <= 0) return '—';
    if (_heightUnit == 'ft/in') {
      final totalIn = _height / 2.54;
      final ft = (totalIn / 12).floor();
      final inches = (totalIn % 12).round();
      return "$ft' $inches\"";
    }
    return '${_height.round()} cm';
  }

  String _formatWeight() {
    if (_weight <= 0) return '—';
    if (_weightUnit == 'lb') return '${_weight.toStringAsFixed(1)} lb';
    return '${_weight.toStringAsFixed(1)} kg';
  }

  Future<void> _updateField(String field, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        field: value, 'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _editAge() async {
    final ctrl = TextEditingController(text: _age > 0 ? '$_age' : '');
    final result = await _showEditDialog('Age', ctrl, TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
      validator: (v) {
        final a = int.tryParse(v);
        if (a == null || a < 13 || a > 120) return 'Enter 13-120';
        return null;
      });
    if (result != null) {
      final a = int.parse(result);
      setState(() => _age = a);
      final p = await SharedPreferences.getInstance();
      await p.setInt('age', a);
      await _updateField('age', a);
    }
  }

  Future<void> _editWeight() async {
    final ctrl = TextEditingController(text: _weight > 0 ? _weight.toStringAsFixed(1) : '');
    final result = await _showEditDialog('Weight ($_weightUnit)', ctrl,
      const TextInputType.numberWithOptions(decimal: true),
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
      validator: (v) {
        final w = double.tryParse(v);
        if (w == null || w <= 0 || w > 500) return 'Enter valid weight';
        return null;
      },
      trailing: _buildUnitSwitch(_weightUnit == 'kg', 'kg', 'lb', () async {
        final newUnit = _weightUnit == 'kg' ? 'lb' : 'kg';
        double converted;
        if (newUnit == 'lb') {
          converted = _weight * 2.20462;
        } else {
          converted = _weight * 0.453592;
        }
        setState(() { _weightUnit = newUnit; _weight = double.parse(converted.toStringAsFixed(1)); });
        final p = await SharedPreferences.getInstance();
        await p.setString('weightUnit', newUnit);
        await p.setDouble('weight', _weight);
        await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).set({
          'weight': _weight, 'weightUnit': newUnit, 'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }),
    );
    if (result != null) {
      final w = double.parse(result);
      setState(() => _weight = w);
      final p = await SharedPreferences.getInstance();
      await p.setDouble('weight', w);
      await _updateField('weight', w);
    }
  }

  Future<void> _editHeight() async {
    if (_heightUnit == 'cm') {
      final ctrl = TextEditingController(text: _height > 0 ? '${_height.round()}' : '');
      final result = await _showEditDialog('Height (cm)', ctrl, TextInputType.number,
        formatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          final h = int.tryParse(v);
          if (h == null || h < 50 || h > 300) return 'Enter 50-300';
          return null;
        },
        trailing: _buildUnitSwitch(true, 'cm', 'ft/in', () => _switchHeightUnit()),
      );
      if (result != null) {
        final h = double.parse(result);
        setState(() => _height = h);
        final p = await SharedPreferences.getInstance();
        await p.setDouble('height', h);
        await _updateField('height', h);
      }
    } else {
      final totalIn = _height / 2.54;
      final ftCtrl = TextEditingController(text: '${(totalIn / 12).floor()}');
      final inCtrl = TextEditingController(text: '${(totalIn % 12).round()}');
      final result = await showDialog<bool>(context: context, builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.height, color: Color(0xFFFFD700), size: 22),
            const SizedBox(width: 10),
            const Text('Edit Height', style: TextStyle(color: Colors.white)),
            const Spacer(),
            _buildUnitSwitch(false, 'cm', 'ft/in', () { Navigator.pop(ctx); _switchHeightUnit(); }),
          ]),
          content: Row(children: [
            Expanded(child: TextField(controller: ftCtrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
              style: const TextStyle(color: Colors.white, fontSize: 20),
              decoration: _editInputDeco('ft'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: inCtrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
              style: const TextStyle(color: Colors.white, fontSize: 20),
              decoration: _editInputDeco('in'))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      });
      if (result == true) {
        final f = int.tryParse(ftCtrl.text) ?? 0;
        final i = int.tryParse(inCtrl.text) ?? 0;
        final cm = (f * 30.48) + (i * 2.54);
        setState(() => _height = cm);
        final p = await SharedPreferences.getInstance();
        await p.setDouble('height', cm);
        await _updateField('height', cm);
      }
    }
  }

  void _switchHeightUnit() async {
    final newUnit = _heightUnit == 'cm' ? 'ft/in' : 'cm';
    setState(() => _heightUnit = newUnit);
    final p = await SharedPreferences.getInstance();
    await p.setString('heightUnit', newUnit);
    await _updateField('heightUnit', newUnit);
  }

  InputDecoration _editInputDeco(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: Colors.white30),
    filled: true, fillColor: const Color(0xFF111111),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFD700))),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  Widget _buildUnitSwitch(bool isFirst, String a, String b, VoidCallback tap) {
    return GestureDetector(onTap: tap, child: Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha:0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _uo(a, isFirst), _uo(b, !isFirst),
      ]),
    ));
  }

  Widget _uo(String l, bool a) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: a ? const Color(0xFFFFD700) : Colors.transparent, borderRadius: BorderRadius.circular(6)),
    child: Text(l, style: TextStyle(color: a ? Colors.black : Colors.white54, fontWeight: FontWeight.bold, fontSize: 11)),
  );

  Future<String?> _showEditDialog(String title, TextEditingController ctrl, TextInputType kbType,
      {List<TextInputFormatter>? formatters, String? Function(String)? validator, Widget? trailing}) async {
    String? error;
    final result = await showDialog<String>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.edit, color: Color(0xFFFFD700), size: 20),
            const SizedBox(width: 10),
            Text('Edit $title', style: const TextStyle(color: Colors.white, fontSize: 18)),
            if (trailing != null) ...[const Spacer(), trailing],
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctrl, keyboardType: kbType, inputFormatters: formatters, autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 20),
              decoration: _editInputDeco('Enter value')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () {
                if (validator != null) {
                  final e = validator(ctrl.text.trim());
                  if (e != null) { setD(() => error = e); return; }
                }
                Navigator.pop(ctx, ctrl.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      });
    });
    return result;
  }

  Future<void> _editGender() async {
    String sel = _gender;
    final result = await showDialog<String>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.person, color: Color(0xFFFFD700), size: 22),
            SizedBox(width: 10),
            Text('Edit Gender', style: TextStyle(color: Colors.white)),
          ]),
          content: Row(children: ['Male', 'Female'].map((g) {
            final s = sel == g;
            return Expanded(child: GestureDetector(
              onTap: () => setD(() => sel = g),
              child: Container(
                margin: EdgeInsets.only(right: g == 'Male' ? 6 : 0, left: g == 'Female' ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: s ? const Color(0xFFFFD700) : const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: s ? const Color(0xFFFFD700) : Colors.white12),
                ),
                child: Text(g, textAlign: TextAlign.center,
                  style: TextStyle(color: s ? Colors.black : Colors.white54, fontWeight: FontWeight.bold)),
              ),
            ));
          }).toList()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, sel),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      });
    });
    if (result != null && result != _gender) {
      setState(() => _gender = result);
      final p = await SharedPreferences.getInstance();
      await p.setString('gender', result);
      await _updateField('gender', result);
    }
  }

  Future<void> _followInstagram() async {
    final url = Uri.parse('https://www.instagram.com/level_max_app/');
    try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Instagram')));
    }
  }

  Future<void> _rateUs() async {
    final url = Uri.parse('market://details?id=com.levelmaxing.app');
    final web = Uri.parse('https://play.google.com/store/apps/details?id=com.levelmaxing.app');
    try { if (!await launchUrl(url, mode: LaunchMode.externalApplication)) await launchUrl(web, mode: LaunchMode.externalApplication); }
    catch (_) { await launchUrl(web, mode: LaunchMode.externalApplication); }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.logout, color: Color(0xFFFFD700), size: 22), SizedBox(width: 10),
        Text('Sign Out', style: TextStyle(color: Colors.white))]),
      content: const Text('Are you sure?', style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    ));
    if (confirm == true) {
      // Clear all per-user state to prevent cross-account leakage
      await LockInNotificationService.cancelAll();
      await NotificationService.removeTokenOnLogout();
      BillingService().clearPremiumState();
      AdService().clearOnSignOut();
      await ScanCooldownService.clearLocalCache();
      final p = await SharedPreferences.getInstance(); await p.clear();
      await GoogleSignIn().signOut(); await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    }
  }

  Future<void> _contactUs() async {
    final uri = Uri(scheme: 'mailto', path: 'levelmaxing952@gmail.com');
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email us at levelmaxing952@gmail.com'), backgroundColor: Color(0xFF1A1A1A)));
    }
  }

  Future<void> _launchLegal() async {
    final url = Uri.parse('https://happy234567.github.io/levelmax-legal/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the legal page')));
    }
  }

  Future<void> _deleteAccount() async {
    final dc = TextEditingController();
    bool ok = false;
    final confirm = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24), SizedBox(width: 10),
          Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This will delete your account.', style: TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Your data will be permanently removed after 7 days. You will not be able to sign in again during this period.',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 12),
          const Text('Type DELETE to confirm:', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(controller: dc, autofocus: true,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 2),
            decoration: _editInputDeco('DELETE'),
            onChanged: (v) => setD(() => ok = v.trim() == 'DELETE')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: ok ? () => Navigator.pop(ctx, true) : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.red.withValues(alpha:0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    ));
    if (confirm == true) {
      // Soft-delete: store UID in deleted_users, mark profile, sign out
      await DeletedUsersService.softDeleteAccount();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isPremium = _billing.isPremium;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Profile', style: TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFFFD700), size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: _loadingProfile
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
        : SingleChildScrollView(child: Column(children: [
          // Header
          Container(
            width: double.infinity, padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
            decoration: BoxDecoration(color: const Color(0xFF111111),
              border: Border(bottom: BorderSide(color: const Color(0xFFFFD700).withValues(alpha:0.15)))),
            child: Column(children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha:0.3), blurRadius: 20, spreadRadius: 2)]),
                child: CircleAvatar(radius: 52, backgroundColor: const Color(0xFFFFD700),
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null ? Text(_firstName.isNotEmpty ? _firstName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.black)) : null),
              ),
              const SizedBox(height: 16),
              Text(_username, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_email, style: const TextStyle(color: Colors.white38, fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isPremium ? const Color(0xFFFFD700).withValues(alpha:0.15) : Colors.white.withValues(alpha:0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isPremium ? const Color(0xFFFFD700) : Colors.white24, width: 1.2)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isPremium ? Icons.workspace_premium : Icons.person_outline, color: isPremium ? const Color(0xFFFFD700) : Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  Text(isPremium ? 'Premium Member' : 'Free Member',
                    style: TextStyle(color: isPremium ? const Color(0xFFFFD700) : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
            ]),
          ),

          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ACCOUNT INFO', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha:0.07))),
              child: Column(children: [
                _infoTile(Icons.person_outline, 'Full Name', _username),
                _div(),
                _infoTile(Icons.email_outlined, 'Email', _email),
                _div(),
                _editableTile(Icons.male, 'Gender', _gender.isNotEmpty ? _gender : '—', _editGender),
                _div(),
                _editableTile(Icons.cake_outlined, 'Age', _age > 0 ? '$_age years' : '—', _editAge),
                _div(),
                _editableTile(Icons.monitor_weight_outlined, 'Weight', _formatWeight(), _editWeight),
                _div(),
                _editableTile(Icons.height, 'Height', _formatHeight(), _editHeight),
                _div(),
                _infoTile(Icons.shield_outlined, 'Account Status', isPremium ? 'Premium' : 'Free',
                  valueColor: isPremium ? const Color(0xFFFFD700) : Colors.white54),
              ]),
            ),

            const SizedBox(height: 28),
            const Text('COMMUNITY & SUPPORT', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            _actionBtn(Icons.star_outline_rounded, 'Rate Us on Play Store', const Color(0xFFFFD700), _rateUs),
            const SizedBox(height: 10),
            _igBtn(),
            const SizedBox(height: 10),
            _actionBtn(Icons.mail_outline_rounded, 'Contact Us', const Color(0xFF4FC3F7), _contactUs),

            const SizedBox(height: 28),
            const Text('ACCOUNT ACTIONS', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            _actionBtn(Icons.logout_rounded, 'Sign Out', const Color(0xFFFFD700), _signOut),
            const SizedBox(height: 10),
            _actionBtn(Icons.delete_forever_rounded, 'Delete Account', Colors.red, _deleteAccount, destructive: true),

            const SizedBox(height: 28),
            const Text('LEGAL', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            _actionBtn(Icons.privacy_tip_outlined, 'Privacy Policy & Terms', Colors.white70, _launchLegal),

            const SizedBox(height: 32),
            const Center(child: Column(children: [
              Text('Level Max', style: TextStyle(color: Colors.white24, fontSize: 12)),
              SizedBox(height: 2),
              Text('v1.0.0', style: TextStyle(color: Colors.white12, fontSize: 11)),
            ])),
            const SizedBox(height: 20),
          ])),
        ])),
    );
  }

  Widget _div() => const Divider(height: 1, color: Colors.white10, indent: 56);

  Widget _infoTile(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFFFFD700).withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFFFFD700), size: 18)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ])),
      ]));
  }

  Widget _editableTile(IconData icon, String label, String value, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFFFFD700).withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFFFFD700), size: 18)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ])),
        Icon(Icons.edit_outlined, color: const Color(0xFFFFD700).withValues(alpha:0.5), size: 16),
      ]),
    ));
  }

  Widget _igBtn() => GestureDetector(onTap: _followInstagram, child: Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [const Color(0xFF833AB4).withValues(alpha:0.15), const Color(0xFFFD1D1D).withValues(alpha:0.15), const Color(0xFFFCAF45).withValues(alpha:0.15)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE1306C).withValues(alpha:0.3))),
    child: Row(children: [
      const Icon(Icons.camera_alt_outlined, color: Color(0xFFE1306C), size: 22),
      const SizedBox(width: 14),
      const Text('Follow us on Instagram', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      const Spacer(),
      Icon(Icons.chevron_right, color: const Color(0xFFE1306C).withValues(alpha:0.5), size: 20),
    ]),
  ));

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap, {bool destructive = false}) {
    return GestureDetector(onTap: onTap, child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: destructive ? Colors.red.withValues(alpha:0.06) : color.withValues(alpha:0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: destructive ? Colors.red.withValues(alpha:0.3) : color.withValues(alpha:0.3))),
      child: Row(children: [
        Icon(icon, color: color, size: 22), const SizedBox(width: 14),
        Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
        const Spacer(),
        Icon(Icons.chevron_right, color: color.withValues(alpha:0.5), size: 20),
      ]),
    ));
  }
}