import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'results_screen.dart';
import 'scan_history.dart';

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

  Future<void> _analyzePhotos() async {
    if (_frontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Front face photo is required!'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      const String backendUrl = 'http://10.63.139.189:3000/analyze';

      var request = http.MultipartRequest('POST', Uri.parse(backendUrl));

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

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = jsonDecode(responseBody);

      if (data['success'] == true) {
        await ScanHistory.saveScan(data['scores'], _frontImage?.path, imagePaths: [
  if (_frontImage != null) _frontImage!.path,
  if (_rightImage != null) _rightImage!.path,
  if (_leftImage != null) _leftImage!.path,
]);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen(scores: data['scores'], imagePaths: [
  if (_frontImage != null) _frontImage!.path,
  if (_rightImage != null) _rightImage!.path,
  if (_leftImage != null) _leftImage!.path,
]),
          ),
        );
      } else {
        throw Exception(data['error']);
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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

    if (_isAnalyzing) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Column(
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
                        margin:
                            const EdgeInsets.symmetric(horizontal: 6),
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
                style:
                    const TextStyle(color: Colors.white54, fontSize: 14)),
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
                style:
                    const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 20),

            // Photo preview
            Expanded(
              child: _currentImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child:
                          Image.file(_currentImage!, fit: BoxFit.cover),
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
                                style:
                                    TextStyle(color: Colors.white54)),
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

              // Gallery button (all steps)
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

              // Skip button (only for optional steps)
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
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