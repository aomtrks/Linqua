import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:translator/translator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'word_model.dart';

// --- ZENGİN SONUÇ MODELİ ---
class TranslationResult {
  final String text;
  final bool isOfflineFallback;
  final String? correctedWord;
  final List<WordMeaning>? meanings;

  TranslationResult({
    required this.text,
    required this.isOfflineFallback,
    this.correctedWord,
    this.meanings,
  });
}

class TranslationService {
  late final OnDeviceTranslator _enToTrTranslator;
  late final OnDeviceTranslator _trToEnTranslator;
  late final OnDeviceTranslatorModelManager _modelManager;
  final GoogleTranslator _onlineTranslator = GoogleTranslator();

  TranslationService() {
    _modelManager = OnDeviceTranslatorModelManager();
    _enToTrTranslator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: TranslateLanguage.turkish,
    );
    _trToEnTranslator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.turkish,
      targetLanguage: TranslateLanguage.english,
    );
  }

  Future<void> ensureModelsDownloaded() async {
    final bool isEnglishDownloaded = await _modelManager.isModelDownloaded(TranslateLanguage.english.bcpCode);
    final bool isTurkishDownloaded = await _modelManager.isModelDownloaded(TranslateLanguage.turkish.bcpCode);

    if (!isEnglishDownloaded) {
      await _modelManager.downloadModel(TranslateLanguage.english.bcpCode);
    }
    if (!isTurkishDownloaded) {
      await _modelManager.downloadModel(TranslateLanguage.turkish.bcpCode);
    }
  }

  String _sanitizeText(String text) {
    String cleanText = text.trim();
    cleanText = cleanText.replaceAll(RegExp(r'[\n\t\r]+'), ' ');
    cleanText = cleanText.replaceAll(RegExp(r'\s{2,}'), ' ');
    return cleanText.toLowerCase();
  }

  Future<bool> _hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    return true;
  }

  // --- ANA ÇEVİRİ VE ZENGİNLEŞTİRME AKIŞI ---
  Future<TranslationResult> translateText(String text, {bool isEnToTr = true}) async {
    if (text.trim().isEmpty) {
      return TranslationResult(text: "", isOfflineFallback: false);
    }

    final processedText = _sanitizeText(text);
    final hasInternet = await _hasInternetConnection();

    if (hasInternet) {
      try {
        final fromLang = isEnToTr ? 'en' : 'tr';
        final toLang = isEnToTr ? 'tr' : 'en';

        final bool isSingleWord = !processedText.contains(' ') && processedText.length > 1;

        final results = await Future.wait([
          _onlineTranslator.translate(processedText, from: fromLang, to: toLang),
          (isSingleWord && isEnToTr) ? _fetchSpellSuggestion(processedText) : Future.value(null),
          // GÜNCELLEME: Sözlük araması artık hem TR->EN hem de EN->TR yönünde çalışır
          (isSingleWord) ? _fetchGoogleDictionary(processedText, isEnToTr) : Future.value(null),
        ]);

        final translation = results[0] as Translation;
        final String? suggestion = results[1] as String?;
        final List<WordMeaning>? meanings = results[2] as List<WordMeaning>?;

        String finalText = translation.text;
        if (finalText.isNotEmpty) {
          finalText = finalText[0].toUpperCase() + finalText.substring(1);
        }

        return TranslationResult(
          text: finalText,
          isOfflineFallback: false,
          correctedWord: suggestion,
          meanings: meanings,
        );
      } catch (e) {
        return _performOfflineTranslation(processedText, isEnToTr);
      }
    } else {
      return _performOfflineTranslation(processedText, isEnToTr);
    }
  }

  // --- YAZIM ÖNERİSİ SERVİSİ (Datamuse API) ---
  Future<String?> _fetchSpellSuggestion(String word) async {
    try {
      final url = Uri.parse('https://api.datamuse.com/words?sp=$word&max=1');
      final response = await http.get(url).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final String suggestedWord = data[0]['word'].toString().toLowerCase();
          if (suggestedWord != word.toLowerCase()) {
            return suggestedWord;
          }
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  // --- GOOGLE BILINGUAL DICTIONARY SERVİSİ (İstatistiksel ve Kusursuz Sonuçlar) ---
  Future<List<WordMeaning>?> _fetchGoogleDictionary(String word, bool isEnToTr) async {
    try {
      final sl = isEnToTr ? 'en' : 'tr';
      final tl = isEnToTr ? 'tr' : 'en';
      final url = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sl&tl=$tl&dt=bd&q=${Uri.encodeComponent(word)}');

      final response = await http.get(url).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // Google Translate API'de sözlük verisi data[1] içinde liste olarak gelir
        if (data.length > 1 && data[1] != null) {
          final List<dynamic> dict = data[1];
          List<WordMeaning> meaningsList = [];

          for (var entry in dict) {
            if (entry is List && entry.length >= 2) {
              final String pos = entry[0].toString().toLowerCase(); // noun, verb vb.
              final List<dynamic> terms = entry[1]; // Karşılıklar listesi

              if (terms.isNotEmpty && _isSupportedPOS(pos)) {
                // İstatistiksel olarak en yaygın 5 karşılığı aralarına virgül koyarak birleştir
                final String defTr = terms.cast<String>().take(5).join(', ');

                meaningsList.add(
                  WordMeaning(
                    partOfSpeech: pos,
                    partOfSpeechTr: _translatePOS(pos),
                    definitionEn: isEnToTr ? "Sık kullanılan karşılıklar" : "Common translations",
                    definitionTr: defTr[0].toUpperCase() + defTr.substring(1),
                  ),
                );
              }
            }
          }
          return meaningsList.isNotEmpty ? meaningsList : null;
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  bool _isSupportedPOS(String pos) {
    return ['noun', 'verb', 'adjective', 'adverb', 'pronoun', 'preposition', 'conjunction', 'idiom', 'interjection'].contains(pos);
  }

  String _translatePOS(String pos) {
    switch (pos) {
      case 'noun': return 'İsim';
      case 'verb': return 'Fiil';
      case 'adjective': return 'Sıfat';
      case 'adverb': return 'Zarf';
      case 'pronoun': return 'Zamir';
      case 'preposition': return 'Edat';
      case 'conjunction': return 'Bağlaç';
      case 'idiom': return 'Deyim';
      case 'interjection': return 'Ünlem';
      default: return pos.toUpperCase();
    }
  }

  Future<TranslationResult> _performOfflineTranslation(String text, bool isEnToTr) async {
    final translator = isEnToTr ? _enToTrTranslator : _trToEnTranslator;
    final response = await translator.translateText(text);

    String finalText = response;
    if (finalText.isNotEmpty) {
      finalText = finalText[0].toUpperCase() + finalText.substring(1);
    }

    return TranslationResult(
      text: finalText,
      isOfflineFallback: true,
    );
  }

  void dispose() {
    _enToTrTranslator.close();
    _trToEnTranslator.close();
  }
}