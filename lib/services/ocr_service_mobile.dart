import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Mobile (Android/iOS) implementation using Google ML Kit
class OcrService {
  static bool get isSupported => true;

  Future<String?> extractText(String filePath) async {
    final inputImage = InputImage.fromFilePath(filePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText result = await recognizer.processImage(inputImage);
      return result.text.trim().isEmpty ? null : result.text;
    } finally {
      recognizer.close();
    }
  }
}
