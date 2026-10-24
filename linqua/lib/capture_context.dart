Dartimport 'word_capture_strategy.dart';

class WordCaptureContext {
  WordCaptureStrategy _strategy;

  // Başlangıç stratejisini alıyoruz
  WordCaptureContext(this._strategy);

  // İleride Premium'a geçince stratejiyi anında değiştirebilmek için
  void setStrategy(WordCaptureStrategy newStrategy, Function(String) onWordCaptured) {
    _strategy.dispose(); // Eski stratejiyi kapat
    _strategy = newStrategy;
    _strategy.initialize(onWordCaptured); // Yeni stratejiyi başlat
  }

  void startListening(Function(String) onWordCaptured) {
    _strategy.initialize(onWordCaptured);
  }

  void stopListening() {
    _strategy.dispose();
  }
}