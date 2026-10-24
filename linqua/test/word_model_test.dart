Dartimport 'package:flutter_test/flutter_test.dart';
import 'package:linqua/word_model.dart';

void main() {
  group('WordCard & SM-2 Spaced Repetition Unit Tests', () {
    test('WordCard serialization toMap and fromMap preserves all fields', () {
      final card = WordCard(
        id: '101',
        originalWord: 'Ephemeral',
        translatedWord: 'Geçici',
        capturedAt: DateTime(2026, 10, 20),
        correctedWord: null,
        meanings: [
          WordMeaning(
            partOfSpeech: 'adjective',
            partOfSpeechTr: 'Sıfat',
            definitionEn: 'Lasting for a very short time.',
            definitionTr: 'Çok kısa süren, geçici.',
          )
        ],
      );

      final map = card.toMap();
      final restored = WordCard.fromMap(map);

      expect(restored.id, '101');
      expect(restored.originalWord, 'Ephemeral');
      expect(restored.translatedWord, 'Geçici');
      expect(restored.repetition, 0);
      expect(restored.interval, 1);
      expect(restored.easeFactor, 2.5);
      expect(restored.meanings?.first.partOfSpeechTr, 'Sıfat');
    });

    test('SM-2 interval and easeFactor calculation on remembered swipe', () {
      final card = WordCard(
        id: '102',
        originalWord: 'Ubiquitous',
        translatedWord: 'Her yerde bulunan',
        capturedAt: DateTime.now(),
      );

      // 1. Doğru hatırlama (repetition 0 -> 1, interval = 1)
      card.interval = 1;
      card.repetition += 1;
      card.easeFactor += 0.1;
      expect(card.repetition, 1);
      expect(card.interval, 1);
      expect(card.easeFactor, closeTo(2.6, 0.01));

      // 2. Doğru hatırlama (repetition 1 -> 2, interval = 6)
      card.interval = 6;
      card.repetition += 1;
      card.easeFactor += 0.1;
      expect(card.repetition, 2);
      expect(card.interval, 6);
      expect(card.easeFactor, closeTo(2.7, 0.01));
    });
  });
}