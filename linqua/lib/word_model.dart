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
      partOfSpeech: map['partOfSpeech']?.toString() ?? '',
      partOfSpeechTr: map['partOfSpeechTr']?.toString() ?? '',
      definitionEn: map['definitionEn']?.toString() ?? '',
      definitionTr: map['definitionTr']?.toString() ?? '',
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

  // SRS (Aralıklı Tekrar - SM-2) Değişkenleri
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
    
    if (map['meanings'] != null && map['meanings'] is List) {
      final List<dynamic> list = map['meanings'] as List<dynamic>;
      parsedMeanings = [];
      for (var item in list) {
        if (item is Map) {
          parsedMeanings.add(WordMeaning.fromMap(item));
        }
      }
    }

    return WordCard(
      id: map['id']?.toString() ?? '',
      originalWord: map['originalWord']?.toString() ?? '',
      translatedWord: map['translatedWord']?.toString() ?? '',
      capturedAt: DateTime.tryParse(map['capturedAt']?.toString() ?? '') ?? DateTime.now(),
      correctedWord: map['correctedWord']?.toString(),
      meanings: parsedMeanings,
      repetition: (map['repetition'] is int)
          ? map['repetition'] as int
          : int.tryParse(map['repetition']?.toString() ?? '0') ?? 0,
      interval: (map['interval'] is int)
          ? map['interval'] as int
          : int.tryParse(map['interval']?.toString() ?? '1') ?? 1,
      easeFactor: (map['easeFactor'] is num)
          ? (map['easeFactor'] as num).toDouble()
          : double.tryParse(map['easeFactor']?.toString() ?? '2.5') ?? 2.5,
      nextReviewDate: DateTime.tryParse(map['nextReviewDate']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}