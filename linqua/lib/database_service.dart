import 'package:hive_flutter/hive_flutter.dart';
import 'word_model.dart';

class DatabaseService {
  static const String _wordsBox = 'words_box';
  static const String _settingsBox = 'settings_box'; // Ayarlar için yeni kutu

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_wordsBox);
    await Hive.openBox(_settingsBox);
  }

  // --- TEMA AYARLARI ---
  bool isDarkMode() {
    final box = Hive.box(_settingsBox);
    return box.get('isDark', defaultValue: false);
  }

  Future<void> toggleTheme(bool isDark) async {
    final box = Hive.box(_settingsBox);
    await box.put('isDark', isDark);
  }

  // --- KELİME İŞLEMLERİ (Aynı kaldı) ---
  List<WordCard> getAllWords() {
    final box = Hive.box(_wordsBox);
    final List<WordCard> words = [];
    for (var item in box.values) {
      if (item is Map) words.add(WordCard.fromMap(item));
    }
    words.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return words;
  }

  List<WordCard> getWordsForReview() {
    final allWords = getAllWords();
    final now = DateTime.now();
    return allWords.where((w) => w.nextReviewDate.isBefore(now) || w.nextReviewDate.isAtSameMomentAs(now)).toList();
  }

  Future<void> saveWord(WordCard word) async {
    final box = Hive.box(_wordsBox);
    await box.put(word.id, word.toMap());
  }

  Future<void> deleteWord(String id) async {
    final box = Hive.box(_wordsBox);
    await box.delete(id);
  }
}