import 'package:hive_flutter/hive_flutter.dart';
import 'word_model.dart';

class DatabaseService {
  static const String _wordsBox = 'words_box';
  static const String _settingsBox = 'settings_box';

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_wordsBox)) {
      await Hive.openBox(_wordsBox);
    }
    if (!Hive.isBoxOpen(_settingsBox)) {
      await Hive.openBox(_settingsBox);
    }
  }

  // --- TEMA AYARLARI ---
  bool isDarkMode() {
    if (!Hive.isBoxOpen(_settingsBox)) return false;
    final box = Hive.box(_settingsBox);
    return box.get('isDark', defaultValue: false) as bool;
  }

  Future<void> toggleTheme(bool isDark) async {
    final box = Hive.box(_settingsBox);
    await box.put('isDark', isDark);
  }

  // --- KELİME HAVUZU VE SM-2 İŞLEMLERİ ---
  List<WordCard> getAllWords() {
    if (!Hive.isBoxOpen(_wordsBox)) return [];
    final box = Hive.box(_wordsBox);
    final List<WordCard> words = [];
    for (final item in box.values) {
      if (item is Map) {
        words.add(WordCard.fromMap(item));
      }
    }
    words.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return words;
  }

  List<WordCard> getWordsForReview() {
    final allWords = getAllWords();
    final now = DateTime.now();
    return allWords
        .where((w) =>
            w.nextReviewDate.isBefore(now) ||
            w.nextReviewDate.isAtSameMomentAs(now))
        .toList();
  }

  Future<void> saveWord(WordCard word) async {
    final box = Hive.box(_wordsBox);
    await box.put(word.id, word.toMap());
  }

  Future<void> deleteWord(String id) async {
    final box = Hive.box(_wordsBox);
    await box.delete(id);
  }

  int getMasteredWordCount() {
    return getAllWords().where((w) => w.repetition >= 2).length;
  }
}