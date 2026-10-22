// --- SÖZLÜK ANLAM MODELİ ---
class WordMeaning {
  final String partOfSpeech; // 'noun', 'verb', 'adjective', 'adverb' vb.
  final String partOfSpeechTr; // 'İsim', 'Fiil', 'Sıfat', 'Zarf' vb.
  final String definitionEn;
  final String definitionTr;

  WordMeaning({
    required this.partOfSpeech,
    required this.partOfSpeechTr,
    required this.definitionEn,
    required this.definitionTr,
  });

  Map<String, dynamic> toMap() {
    return {
      'partOfSpeech': partOfSpeech,
      'partOfSpeechTr': partOfSpeechTr,
      'definitionEn': definitionEn,
      'definitionTr': definitionTr,
    };
  }

  factory WordMeaning.fromMap(Map<dynamic, dynamic> map) {
    return WordMeaning(
      partOfSpeech: map['partOfSpeech'] ?? '',
      partOfSpeechTr: map['partOfSpeechTr'] ?? '',
      definitionEn: map['definitionEn'] ?? '',
      definitionTr: map['definitionTr'] ?? '',
    );
  }
}

// --- KELİME KARTI MODELİ ---
class WordCard {
  String id;
  String originalWord;
  String translatedWord;
  DateTime capturedAt;

  // Yeni eklenen alanlar (Geriye dönük uyumlu - Nullable)
  String? correctedWord;
  List<WordMeaning>? meanings;

  // SRS (Aralıklı Tekrar) Değişkenleri
  int repetition;
  int interval;
  double easeFactor;
  DateTime nextReviewDate;

  WordCard({
    required this.id,
    required this.originalWord,
    required this.translatedWord,
    required this.capturedAt,
    this.correctedWord,
    this.meanings,
    this.repetition = 0,
    this.interval = 1,
    this.easeFactor = 2.5,
    DateTime? nextReviewDate,
  }) : nextReviewDate = nextReviewDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalWord': originalWord,
      'translatedWord': translatedWord,
      'capturedAt': capturedAt.toIso8601String(),
      'correctedWord': correctedWord,
      'meanings': meanings?.map((m) => m.toMap()).toList(),
      'repetition': repetition,
      'interval': interval,
      'easeFactor': easeFactor,
      'nextReviewDate': nextReviewDate.toIso8601String(),
    };
  }

  factory WordCard.fromMap(Map<dynamic, dynamic> map) {
    List<WordMeaning>? parsedMeanings;
    if (map['meanings'] != null) {
      final List<dynamic> list = map['meanings'];
      parsedMeanings = list.map((m) => WordMeaning.fromMap(m as Map)).toList();
    }

    return WordCard(
      id: map['id'] ?? '',
      originalWord: map['originalWord'] ?? '',
      translatedWord: map['translatedWord'] ?? '',
      capturedAt: DateTime.parse(map['capturedAt'] ?? DateTime.now().toIso8601String()),
      correctedWord: map['correctedWord'],
      meanings: parsedMeanings,
      repetition: map['repetition'] ?? 0,
      interval: map['interval'] ?? 1,
      easeFactor: map['easeFactor'] ?? 2.5,
      nextReviewDate: map['nextReviewDate'] != null
          ? DateTime.parse(map['nextReviewDate'])
          : DateTime.now(),
    );
  }
}