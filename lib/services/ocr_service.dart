// Conditional export: uses real ML Kit on mobile, stub on web
export 'ocr_service_stub.dart'
    if (dart.library.io) 'ocr_service_mobile.dart';
