import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class CameraScanner extends StatefulWidget {
  const CameraScanner({super.key});

  @override
  State<CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends State<CameraScanner> {
  final MobileScannerController _cameraController = MobileScannerController();
  final ImagePicker _picker = ImagePicker();

  bool _qrDetecting = true;
  bool _processingOCR = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  // ===================== QR DETECTION =====================
  void _onQRDetected(String code) {
    if (!_qrDetecting) return;
    _qrDetecting = false;
    Navigator.pop(context, code);
  }

  // ===================== OCR USING CAMERA =====================
  Future<void> _extractTextFromCamera() async {
    if (_processingOCR) return;

    setState(() => _processingOCR = true);

    try {
      // Open camera and capture image
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (pickedFile == null) {
        _showError('No image captured');
        return;
      }

      // Convert to ML Kit format
      final inputImage = InputImage.fromFile(File(pickedFile.path));

      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final urls = _extractUrls(recognizedText.text);

      if (urls.isNotEmpty) {
        Navigator.pop(context, urls.first);
      } else if (recognizedText.text.isNotEmpty) {
        Navigator.pop(context, recognizedText.text);
      } else {
        _showError('No text found');
      }
    } catch (e) {
      _showError('OCR failed: $e');
    } finally {
      if (mounted) setState(() => _processingOCR = false);
    }
  }

  // ===================== URL EXTRACTION =====================
  List<String> _extractUrls(String text) {
    final pattern =
        r'(https?:\/\/[^\s]+|www\.[^\s]+|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^\s]*)';
    final matches = RegExp(pattern, caseSensitive: false).allMatches(text);
    return matches.map((m) => m.group(0)!).toList();
  }

  // ===================== ERROR =====================
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Camera',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          // Camera preview (QR scanning)
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;

              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _onQRDetected(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // Scanner frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                _processingOCR
                    ? const CircularProgressIndicator(color: Colors.white)
                    : ElevatedButton.icon(
                        onPressed: _extractTextFromCamera,
                        icon: const Icon(Icons.text_fields),
                        label: const Text('Extract Text from Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                const SizedBox(height: 12),
                const Text(
                  'Align QR code within the frame\nor tap to extract text',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}