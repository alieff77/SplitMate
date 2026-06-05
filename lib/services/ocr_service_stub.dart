// Web stub — OCR not supported on Flutter Web
class OcrService {
  static bool get isSupported => false;

  Future<String?> extractText(String filePath) async => null;
}
