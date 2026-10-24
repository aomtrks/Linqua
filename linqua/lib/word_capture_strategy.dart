1. Dartabstract class WordCaptureStrategy {
  // Stratejiyi başlatır ve bir kelime yakalandığında ne yapılacağını belirler
  void initialize(Function(String) onWordCaptured);

  // Strateji kapatıldığında kaynakları temizler
  void dispose();
}