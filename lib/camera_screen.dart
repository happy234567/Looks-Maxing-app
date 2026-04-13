import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'billing_service.dart';
import 'scan_cooldown_service.dart';
import 'package:http_parser/http_parser.dart';
import 'results_screen.dart';
import 'scan_history.dart';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'ad_service.dart';

/// Strips the "Exception: " prefix from error messages for cleaner UX.
String _cleanErrorMessage(dynamic error) {
  String msg = error.toString();
  if (msg.startsWith('Exception: ')) {
    msg = msg.substring('Exception: '.length);
  }
  return msg;
}

/// Custom exception for auth/token errors to distinguish from generic exceptions
class _AuthException implements Exception {
  final String message;
  _AuthException(this.message);
  @override
  String toString() => message;
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _frontImage;
  File? _rightImage;
  File? _leftImage;
  int _currentStep = 0;
  
  bool _isAnalyzing = false;
  String? _errorMessage; // Handles the Try Again screen

  final List<Map<String, String>> _steps = [
    {
      'title': 'Front Face',
      'instruction': 'Look straight at the camera\nKeep a neutral expression',
      'icon': '😐',
      'required': 'true',
    },
    {
      'title': 'Right Side',
      'instruction': 'Turn your head to the RIGHT\nKeep chin level',
      'icon': '➡️',
      'required': 'false',
    },
    {
      'title': 'Left Side',
      'instruction': 'Turn your head to the LEFT\nKeep chin level',
      'icon': '⬅️',
      'required': 'false',
    },
  ];

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
    );

    if (photo != null) {
      setState(() {
        if (_currentStep == 0) _frontImage = File(photo.path);
        if (_currentStep == 1) _rightImage = File(photo.path);
        if (_currentStep == 2) _leftImage = File(photo.path);
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (photo != null) {
      setState(() {
        if (_currentStep == 0) _frontImage = File(photo.path);
        if (_currentStep == 1) _rightImage = File(photo.path);
        if (_currentStep == 2) _leftImage = File(photo.path);
      });
    }
  }

  Future<void> _confirmPhoto() async {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      await _analyzePhotos();
    }
  }

  void _skipPhoto() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _analyzePhotos();
    }
  }

  Future<String> _getFreshIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You are not signed in. Please sign in and try again.');
    }

    try {
      final token = await user.getIdToken(true);
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('getIdToken(true) failed: $e');
    }

    debugPrint('Force-refresh failed, attempting silent re-sign-in...');
    try {
      final googleUser = await GoogleSignIn().signInSilently();
      if (googleUser != null) {
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        final newToken = await userCredential.user?.getIdToken(true);
        if (newToken != null && newToken.isNotEmpty) return newToken;
      }
    } catch (e) {
      debugPrint('Silent re-sign-in failed: $e');
    }

    throw Exception('Authentication failed. Please sign out and sign in again.');
  }

  Future<Map<String, dynamic>> _sendScanRequest(String idToken) async {
    const String backendUrl = 'https://level-maxing-backend.onrender.com/analyze';

    http.MultipartRequest buildRequest() {
      var request = http.MultipartRequest('POST', Uri.parse(backendUrl));
      request.headers['Authorization'] = 'Bearer $idToken';
      return request;
    }

    var request = buildRequest();

    request.files.add(await http.MultipartFile.fromPath(
        'front', _frontImage!.path,
        contentType: MediaType('image', 'jpeg')));

    if (_rightImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'right', _rightImage!.path,
          contentType: MediaType('image', 'jpeg')));
    }

    if (_leftImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'left', _leftImage!.path,
          contentType: MediaType('image', 'jpeg')));
    }

    http.StreamedResponse response;
    try {
      response = await request.send().timeout(
        const Duration(seconds: 180),
        onTimeout: () {
          throw TimeoutException('Server took too long to respond.');
        },
      );
    } on SocketException {
      throw Exception('No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw Exception('Server took too long to respond. Please try again in a few minutes.');
    }

    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw _AuthException('Token rejected by server (HTTP ${response.statusCode})');
    }

    if (response.statusCode == 429) {
      try {
        final body = jsonDecode(responseBody) as Map<String, dynamic>;
        throw Exception(body['error'] ?? 'Upload limit reached. Please try again later.');
      } catch (e) {
        if (e is Exception && e.toString().contains('Upload limit')) rethrow;
        throw Exception('Upload limit reached. Please try again later.');
      }
    }

    if (response.statusCode == 500) {
      try {
        final body = jsonDecode(responseBody) as Map<String, dynamic>;
        final serverError = body['error'] as String? ?? '';
        if (serverError.contains('face') || serverError.contains('image') || serverError.contains('JSON')) {
          throw Exception('Could not analyze your photo. Please ensure your face is clearly visible and try again.');
        }
      } catch (e) {
        if (e is Exception && e.toString().contains('Could not analyze')) rethrow;
      }
      throw Exception('Server error. Please try again later.');
    }

    if (response.statusCode != 200) {
      throw Exception('Server error (HTTP ${response.statusCode}). Please try again later.');
    }

    try {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid response from server. Please try again.');
    }
  }

  Future<void> _analyzePhotos() async {
    if (_frontImage == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Front face photo is required!'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (!_frontImage!.existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Photo file not found. Please retake the photo.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      String idToken;
      try {
        idToken = await _getFreshIdToken();
      } catch (e) {
        throw Exception('Sign-in session expired. Please go back and try again.');
      }

      Map<String, dynamic> data;
      try {
        data = await _sendScanRequest(idToken);
      } on _AuthException {
        debugPrint('Token rejected, re-authenticating and retrying...');
        try {
          final googleUser = await GoogleSignIn().signInSilently();
          if (googleUser != null) {
            final googleAuth = await googleUser.authentication;
            final credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            final newToken = await userCredential.user?.getIdToken(true);
            if (newToken == null || newToken.isEmpty) {
              throw Exception('Re-authentication failed. Please sign out and sign in again.');
            }
            idToken = newToken;
            data = await _sendScanRequest(idToken);
          } else {
            throw Exception('Could not re-authenticate. Please sign out and sign in again.');
          }
        } catch (e) {
          if (e is _AuthException) {
            throw Exception('Authentication failed. Please sign out and sign in again.');
          }
          rethrow;
        }
      }

      if (!mounted) return;

      if (data['success'] == true) {
        final scores = data['scores'];
        if (scores == null || scores is! Map<String, dynamic>) {
          throw Exception('Server returned incomplete results. Please try again.');
        }

        if (scores['overall'] == null && scores['skin'] == null) {
          throw Exception('Analysis produced no scores. Please ensure your face is clearly visible.');
        }

        try {
          final billing = BillingService();
          await billing.initialize();
          await ScanCooldownService.recordScan(isPremium: billing.isPremium);
        } catch (e) {
          debugPrint('Failed to record scan cooldown: $e');
        }

        List<String> finalImagePaths = [];
        String? processedFront;
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

          Future<String?> processImage(File? file, String type) async {
            if (file == null || !file.existsSync()) return null;
            try {
              debugPrint('[Storage] Starting upload for $type, file: ${file.path}');
              final storageRef = FirebaseStorage.instanceFor(
                      bucket: 'gs://looks-maxing-app-a8f7c.firebasestorage.app')
                  .ref()
                  .child('users/$userId/scans/${timestamp}_$type.jpg');
              await storageRef.putFile(file).timeout(const Duration(seconds: 60));
              final url = await storageRef.getDownloadURL();
              return url;
            } catch (e) {
              debugPrint('[Storage] UPLOAD FAILED ($type): $e');
              return null;
            }
          }

          processedFront = await processImage(_frontImage, 'front');
          final String? processedRight = await processImage(_rightImage, 'right');
          final String? processedLeft = await processImage(_leftImage, 'left');

          finalImagePaths = [
            ?processedFront,
            ?processedRight,
            ?processedLeft,
          ];
        } catch (e) {
          debugPrint('Image processing error (non-fatal): $e');
        }

        try {
          await ScanHistory.saveScan(scores, processedFront, imagePaths: finalImagePaths);
        } catch (e) {
          debugPrint('Failed to save scan history: $e');
        }

        if (!mounted) return;

        // AD LOGIC
        if (!BillingService().isPremium) {
          await AdService().showScanAd(onComplete: () {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ResultsScreen(scores: scores, imagePaths: finalImagePaths),
              ),
            );
          });
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultsScreen(scores: scores, imagePaths: finalImagePaths),
            ),
          );
        }
      } else {
        final errorMsg = data['error'];
        if (errorMsg is String && errorMsg.contains('limit')) {
          throw Exception('You\'ve reached your scan limit. Please wait for the cooldown to end.');
        }
        throw Exception(errorMsg ?? 'Analysis failed. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = _cleanErrorMessage(e);
      });
    }
  }

  void _retakePhoto() {
    setState(() {
      if (_currentStep == 0) _frontImage = null;
      if (_currentStep == 1) _rightImage = null;
      if (_currentStep == 2) _leftImage = null;
    });
  }

  File? get _currentImage {
    if (_currentStep == 0) return _frontImage;
    if (_currentStep == 1) return _rightImage;
    return _leftImage;
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isRequired = step['required'] == 'true';

    // Shows either the loading spinner OR the Try Again error screen
    if (_isAnalyzing || _errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: _isAnalyzing
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFFFD700)),
                    const SizedBox(height: 24),
                    const Text('Analyzing your face...',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                    const SizedBox(height: 8),
                    const Text('AI is calculating your scores',
                        style: TextStyle(color: Colors.white54)),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                      const SizedBox(height: 16),
                      const Text('Analysis Failed',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 15)),
                      const SizedBox(height: 32),
                      
                      // The Try Again Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _errorMessage = null);
                            _analyzePhotos(); // Restarts the analysis instantly!
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Cancel Button
                      TextButton(
                        onPressed: () => setState(() => _errorMessage = null),
                        child: const Text('Go Back to Photos', style: TextStyle(color: Colors.white54, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Face Scan',
            style: TextStyle(color: Color(0xFFFFD700))),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Progress bar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  3,
                  (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 60,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= _currentStep
                              ? const Color(0xFFFFD700)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
            ),
            const SizedBox(height: 16),

            Text('Step ${_currentStep + 1} of 3',
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(step['title']!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                if (!isRequired) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Optional',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(step['instruction']!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 20),

            // Photo preview
            Expanded(
              child: _currentImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(_currentImage!, fit: BoxFit.cover),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFFFD700), width: 2),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(step['icon']!,
                                style: const TextStyle(fontSize: 60)),
                            const SizedBox(height: 16),
                            const Text('Take or select a photo',
                                style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Buttons
            if (_currentImage == null) ...[
              // Camera button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: Text('Take ${step['title']} Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Gallery button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library,
                      color: Colors.white70),
                  label: const Text('Choose from Gallery',
                      style: TextStyle(color: Colors.white70)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),

              // Skip button
              if (!isRequired) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _skipPhoto,
                  child: const Text('Skip this photo →',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 14)),
                ),
              ],
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _retakePhoto,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmPhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(
                          _currentStep < 2 ? 'Confirm ✓' : 'Analyze!'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}