import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCmCtrl = TextEditingController();
  final _heightFtCtrl = TextEditingController();
  final _heightInCtrl = TextEditingController();
  String _gender = '';
  bool _loading = false;
  bool _wKg = true;
  bool _hCm = true;
  int _step = 0;
  final _pc = PageController();

  @override
  void dispose() {
    for (final c in [_firstNameCtrl, _middleNameCtrl, _lastNameCtrl, _ageCtrl, _weightCtrl, _heightCmCtrl, _heightFtCtrl, _heightInCtrl]) {
      c.dispose();
    }
    _pc.dispose();
    super.dispose();
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  bool _ok(int s) {
    if (s == 0) {
      if (_firstNameCtrl.text.trim().isEmpty) { _err('Enter your first name'); return false; }
      if (_gender.isEmpty) { _err('Select your gender'); return false; }
    } else if (s == 1) {
      final a = int.tryParse(_ageCtrl.text.trim());
      if (a == null || a < 13 || a > 120) { _err('Enter a valid age (13-120)'); return false; }
    } else if (s == 2) {
      final w = double.tryParse(_weightCtrl.text.trim());
      if (w == null || w <= 0 || w > 500) { _err('Enter a valid weight'); return false; }
      if (_hCm) {
        final c = double.tryParse(_heightCmCtrl.text.trim());
        if (c == null || c < 50 || c > 300) { _err('Enter valid height (50-300 cm)'); return false; }
      } else {
        final f = int.tryParse(_heightFtCtrl.text.trim());
        final i = int.tryParse(_heightInCtrl.text.trim());
        if (f == null || f < 1 || f > 9) { _err('Enter valid feet (1-9)'); return false; }
        if (i == null || i < 0 || i > 11) { _err('Enter valid inches (0-11)'); return false; }
      }
    }
    return true;
  }

  void _next() {
    if (!_ok(_step)) return;
    if (_step < 2) {
      setState(() => _step++);
      _pc.animateToPage(_step, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    } else {
      _save();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pc.animateToPage(_step, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  double _getCm() {
    if (_hCm) return double.tryParse(_heightCmCtrl.text.trim()) ?? 0;
    final f = int.tryParse(_heightFtCtrl.text.trim()) ?? 0;
    final i = int.tryParse(_heightInCtrl.text.trim()) ?? 0;
    return (f * 30.48) + (i * 2.54);
  }

  Future<void> _save() async {
    if (!_ok(2)) return;
    setState(() => _loading = true);
    try {
      final fn = _firstNameCtrl.text.trim();
      final mn = _middleNameCtrl.text.trim();
      final ln = _lastNameCtrl.text.trim();
      String un = fn;
      if (mn.isNotEmpty) un += ' $mn';
      if (ln.isNotEmpty) un += ' $ln';
      final u = FirebaseAuth.instance.currentUser;
      final age = int.parse(_ageCtrl.text.trim());
      final wt = double.parse(_weightCtrl.text.trim());
      final ht = _getCm();

      await FirebaseFirestore.instance.collection('users').doc(u?.uid).set({
        'username': un, 'firstName': fn, 'middleName': mn, 'lastName': ln,
        'gender': _gender, 'age': age,
        'weight': wt, 'weightUnit': _wKg ? 'kg' : 'lb',
        'height': ht, 'heightUnit': _hCm ? 'cm' : 'ft/in',
        'email': u?.email,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      final p = await SharedPreferences.getInstance();
      await p.setString('username', un);
      await p.setString('firstName', fn);
      await p.setString('gender', _gender);
      await p.setInt('age', age);
      await p.setDouble('weight', wt);
      await p.setString('weightUnit', _wKg ? 'kg' : 'lb');
      await p.setDouble('height', ht);
      await p.setString('heightUnit', _hCm ? 'cm' : 'ft/in');

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigation()));
    } catch (e) {
      if (!mounted) return;
      _err('Failed to save: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 20),
          _stepBar(),
          const SizedBox(height: 8),
          Expanded(child: PageView(
            controller: _pc, physics: const NeverScrollableScrollPhysics(),
            children: [_s1(), _s2(), _s3()],
          )),
          _navBtns(),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _stepBar() {
    const labels = ['Profile', 'Age', 'Body'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(children: List.generate(3, (i) {
        final active = i <= _step;
        final cur = i == _step;
        return Expanded(child: Row(children: [
          Expanded(child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: cur ? 36 : 28, height: cur ? 36 : 28,
              decoration: BoxDecoration(
                color: active ? const Color(0xFFFFD700) : const Color(0xFF2A2A2A),
                shape: BoxShape.circle,
                boxShadow: cur ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha:0.4), blurRadius: 12)] : null,
              ),
              child: Center(child: Text('${i+1}', style: TextStyle(
                color: active ? Colors.black : Colors.white38,
                fontWeight: FontWeight.bold, fontSize: cur ? 15 : 12))),
            ),
            const SizedBox(height: 6),
            Text(labels[i], style: TextStyle(color: active ? Colors.white70 : Colors.white24, fontSize: 11)),
          ])),
          if (i < 2) Expanded(child: Container(
            height: 2, margin: const EdgeInsets.only(bottom: 18),
            color: i < _step ? const Color(0xFFFFD700) : const Color(0xFF2A2A2A),
          )),
        ]));
      })),
    );
  }

  Widget _navBtns() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        if (_step > 0) ...[
          Expanded(child: OutlinedButton(
            onPressed: _back,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
              foregroundColor: const Color(0xFFFFD700),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(width: 12),
        ],
        Expanded(flex: _step > 0 ? 2 : 1, child: ElevatedButton(
          onPressed: _loading ? null : _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black,
            disabledBackgroundColor: const Color(0xFFFFD700).withValues(alpha:0.3),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
            : Text(_step == 2 ? 'Get Started!' : 'Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }

  Widget _s1() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      const Text('Welcome!', style: TextStyle(color: Color(0xFFFFD700), fontSize: 32, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Tell us about yourself', style: TextStyle(color: Colors.white54, fontSize: 16)),
      const SizedBox(height: 36),
      _tf(label: 'First Name *', ctrl: _firstNameCtrl, hint: 'Enter first name'),
      const SizedBox(height: 20),
      _tf(label: 'Middle Name (Optional)', ctrl: _middleNameCtrl, hint: 'Enter middle name'),
      const SizedBox(height: 20),
      _tf(label: 'Last Name (Optional)', ctrl: _lastNameCtrl, hint: 'Enter last name'),
      const SizedBox(height: 30),
      const Text('Gender *', style: TextStyle(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 12),
      Row(children: [_gc('Male'), const SizedBox(width: 12), _gc('Female')]),
    ]),
  );

  Widget _s2() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      const Text('How old are you?', style: TextStyle(color: Color(0xFFFFD700), fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('This helps us personalize your experience', style: TextStyle(color: Colors.white54, fontSize: 15)),
      const SizedBox(height: 40),
      Center(child: Container(
        width: 160, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha:0.3)),
        ),
        child: TextField(
          controller: _ageCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          decoration: const InputDecoration(hintText: '18', hintStyle: TextStyle(color: Colors.white12, fontSize: 48), border: InputBorder.none),
        ),
      )),
      const SizedBox(height: 16),
      const Center(child: Text('years old', style: TextStyle(color: Colors.white38, fontSize: 16))),
    ]),
  );

  Widget _s3() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      const Text('Body Stats', style: TextStyle(color: Color(0xFFFFD700), fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Help us understand your build', style: TextStyle(color: Colors.white54, fontSize: 15)),
      const SizedBox(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Weight *', style: TextStyle(color: Colors.white70, fontSize: 14)),
        _unitTog(_wKg, 'kg', 'lb', () => setState(() => _wKg = !_wKg)),
      ]),
      const SizedBox(height: 10),
      _tf(ctrl: _weightCtrl, hint: _wKg ? 'e.g. 70' : 'e.g. 154',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        formatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
        suffix: Text(_wKg ? 'kg' : 'lb', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
      ),
      const SizedBox(height: 28),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Height *', style: TextStyle(color: Colors.white70, fontSize: 14)),
        _unitTog(_hCm, 'cm', 'ft/in', () => setState(() => _hCm = !_hCm)),
      ]),
      const SizedBox(height: 10),
      if (_hCm)
        _tf(ctrl: _heightCmCtrl, hint: 'e.g. 175', keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          suffix: const Text('cm', style: TextStyle(color: Color(0xFFFFD700), fontSize: 16)))
      else
        Row(children: [
          Expanded(child: _tf(ctrl: _heightFtCtrl, hint: 'ft', keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
            suffix: const Text('ft', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14)))),
          const SizedBox(width: 12),
          Expanded(child: _tf(ctrl: _heightInCtrl, hint: 'in', keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            suffix: const Text('in', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14)))),
        ]),
    ]),
  );

  Widget _tf({String? label, required TextEditingController ctrl, required String hint,
    TextInputType? keyboardType, List<TextInputFormatter>? formatters, Widget? suffix}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null) ...[Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 8)],
      TextField(
        controller: ctrl, keyboardType: keyboardType, inputFormatters: formatters,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Colors.white30),
          filled: true, fillColor: const Color(0xFF1A1A1A),
          suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 16), child: suffix) : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFFD700))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    ]);
  }

  Widget _gc(String g) {
    final sel = _gender == g;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _gender = g),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFFD700) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? const Color(0xFFFFD700) : Colors.white.withValues(alpha:0.1), width: sel ? 2 : 1),
          boxShadow: sel ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha:0.2), blurRadius: 10)] : null,
        ),
        child: Text(g, textAlign: TextAlign.center,
          style: TextStyle(color: sel ? Colors.black : Colors.white54, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    ));
  }

  Widget _unitTog(bool isFirst, String a, String b, VoidCallback tap) {
    return GestureDetector(onTap: tap, child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha:0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [_uo(a, isFirst), _uo(b, !isFirst)]),
    ));
  }

  Widget _uo(String l, bool a) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: a ? const Color(0xFFFFD700) : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(l, style: TextStyle(color: a ? Colors.black : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
  );
}