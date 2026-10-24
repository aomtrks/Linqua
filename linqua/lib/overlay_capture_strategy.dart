Dartimport 'word_capture_strategy.dart';

class OverlayCaptureStrategy implements WordCaptureStrategy {
  @override
  void initialize(Function(String) onWordCaptured) {
    // TODO: İleride AccessibilityService veya System Alert Window
    // paketleri kullanılarak ekrandaki kelimeye tıklanma anı burada dinlenecek.
    print("Overlay stratejisi başlatıldı. Hazırlık aşamasında.");
  }

  @override
  void dispose() {
    // TODO: Overlay kaynaklarını temizle
  }
}