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

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _frontImage;
  File? _sideImage;
  int _currentStep = 0;
  
  bool _isAnalyzing = false;

  // ── Scan loading animation state ──
  double _scanProgress = 0.0;
  int _statusIndex = 0;
  Timer? _progressTimer;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  static const List<String> _statusMessages = [
    'Uploading photos…',
    'Detecting facial landmarks…',
    'Measuring bone structure…',
    'Analyzing symmetry…',
    'Evaluating skin quality…',
    'Calculating PSL metrics…',
    'Computing final scores…',
  ];

  void _startScanAnimation() {
    _scanProgress = 0.0;
    _statusIndex = 0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        // Progress caps at 92% — the remaining 8% jumps to 100 on completion
        if (_scanProgress < 0.92) {
          _scanProgress += 0.012 + (0.005 * (1 - _scanProgress)); // slows as it nears end
        }
        // Cycle status messages roughly every 2.5s
        final newIndex = (_scanProgress * _statusMessages.length).floor().clamp(0, _statusMessages.length - 1);
        if (newIndex != _statusIndex) _statusIndex = newIndex;
      });
    });
  }

  void _stopScanAnimation() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _rescueAndroidPhoto();
  }

  // This rescues the photo if Android killed the app while the camera was open
  Future<void> _rescueAndroidPhoto() async {
    if (Platform.isAndroid) {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) {
        return;
      }
      setState(() {
        if (_currentStep == 0) _frontImage = File(response.file!.path);
        if (_currentStep == 1) _sideImage = File(response.file!.path);
      });
      // If we rescued a photo, automatically advance to the next step
      _confirmPhoto();
    }
  }

  @override
  void dispose() {
    _stopScanAnimation();
    _glowController.dispose();
    super.dispose();
  }

  String? _errorMessage; // Handles the Try Again screen

  final List<Map<String, String>> _steps = [
    {
      'title': 'Front Face',
      'instruction': 'Look straight at the camera\nKeep a neutral expression',
      'icon': '😐',
      'required': 'true',
    },
    {
      'title': 'Side Face',
      'instruction': 'Turn your head to either side\nKeep chin level',
      'icon': '👤',
      'required': 'false',
    },
  ];

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          if (_currentStep == 0) _frontImage = File(photo.path);
          if (_currentStep == 1) _sideImage = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Camera ignored: $e'); // Prevents the already_active crash!
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          if (_currentStep == 0) _frontImage = File(photo.path);
          if (_currentStep == 1) _sideImage = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Gallery ignored: $e'); // Prevents the already_active crash!
    }
  }

  Future<void> _confirmPhoto() async {
    if (_currentStep < 1) {
      setState(() => _currentStep++);
    } else {
      await _analyzePhotos();
    }
  }

  void _skipPhoto() {
    if (_currentStep < 1) {
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

    if (_sideImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'side', _sideImage!.path,
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
    _startScanAnimation();

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
          await ScanCooldownService.recordScan(isPremium: BillingService().isPremium);
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
          final String? processedSide = await processImage(_sideImage, 'side');

          finalImagePaths = [
            if (processedFront != null) processedFront
            else if (_frontImage != null) _frontImage!.path,
            if (processedSide != null) processedSide
            else if (_sideImage != null) _sideImage!.path,
          ].whereType<String>().toList();
        } catch (e) {
          debugPrint('Image processing error (non-fatal): $e');
        }

        try {
          await ScanHistory.saveScan(scores, processedFront, imagePaths: finalImagePaths);
        } catch (e) {
          debugPrint('Failed to save scan history: $e');
        }

        if (!mounted) return;

        // AD LOGIC — use user-scoped premium check from BillingService.
        // isPremium is always fetched from Firestore per userId on login,
        // so this is safe against cross-account leakage.
        final currentBilling = BillingService();
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        debugPrint('[CameraScreen] Ad check: isPremium=${currentBilling.isPremium} userId=$currentUserId');
        if (!currentBilling.isPremium) {
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
      _stopScanAnimation();
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
      if (_currentStep == 1) _sideImage = null;
    });
  }

  File? get _currentImage {
    if (_currentStep == 0) return _frontImage;
    return _sideImage;
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
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pulsing face icon
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.25 * _glowAnimation.value),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.07 * _glowAnimation.value),
                                  blurRadius: 50 * _glowAnimation.value,
                                  spreadRadius: 10 * _glowAnimation.value,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFFFFD700), size: 64),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      const Text('Analyzing Your Face',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 24),
                      // Live progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _scanProgress.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: const Color(0xFF1A1A1A),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Percentage + status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _statusMessages[_statusIndex],
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          Text(
                            '${(_scanProgress * 100).toInt().clamp(0, 99)}%',
                            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('This may take a minute',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
            // Progress bar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  2,
                  (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 80,
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

            Text('Step ${_currentStep + 1} of 2',
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
                          _currentStep < 1 ? 'Confirm ✓' : 'Analyze!'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ), // This closes the new SafeArea widget
    );
  }
}