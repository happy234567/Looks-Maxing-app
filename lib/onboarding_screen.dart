import 'package:flutter/material.dart';
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
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _selectedGender = '';
  bool _isLoading = false;

  Future<void> _saveProfile() async {
  if (_firstNameController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter your first name'),
          backgroundColor: Colors.red),
    );
    return;
  }
  if (_selectedGender.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select your gender'),
          backgroundColor: Colors.red),
    );
    return;
  }

  setState(() => _isLoading = true);

  final firstName = _firstNameController.text.trim();
  final middleName = _middleNameController.text.trim();
  final lastName = _lastNameController.text.trim();

  String username = firstName;
  if (middleName.isNotEmpty) username += ' $middleName';
  if (lastName.isNotEmpty) username += ' $lastName';

  final user = FirebaseAuth.instance.currentUser;

  // Save to Firestore
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user?.uid)
      .set({
    'username': username,
    'firstName': firstName,
    'middleName': middleName,
    'lastName': lastName,
    'gender': _selectedGender,
    'email': user?.email,
    'createdAt': DateTime.now().toIso8601String(),
  });

  // Also save locally for quick access
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('username', username);
  await prefs.setString('firstName', firstName);
  await prefs.setString('middleName', middleName);
  await prefs.setString('lastName', lastName);
  await prefs.setString('gender', _selectedGender);

  if (!mounted) return;
  Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => const MainNavigation()));
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text('Welcome!',
                  style: TextStyle(color: Color(0xFFFFD700),
                      fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Tell us about yourself',
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
              const SizedBox(height: 40),

              // First Name
              const Text('First Name *',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _firstNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter first name',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFFFD700))),
                ),
              ),
              const SizedBox(height: 20),

              // Middle Name
              const Text('Middle Name (Optional)',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _middleNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter middle name',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFFFD700))),
                ),
              ),
              const SizedBox(height: 20),

              // Last Name
              const Text('Last Name (Optional)',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _lastNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter last name',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFFFD700))),
                ),
              ),
              const SizedBox(height: 30),

              // Gender
              const Text('Gender *',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedGender = 'Male'),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedGender == 'Male'
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Male',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _selectedGender == 'Male'
                                    ? Colors.black
                                    : Colors.white54,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedGender = 'Female'),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedGender == 'Female'
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Female',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _selectedGender == 'Female'
                                    ? Colors.black
                                    : Colors.white54,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Get Started!',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}