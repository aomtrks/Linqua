import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:translator/translator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'word_model.dart';

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
    final bool isEnglishDownloaded =
        await _modelManager.isModelDownloaded(TranslateLanguage.english.bcpCode);
    final bool isTurkishDownloaded =
        await _modelManager.isModelDownloaded(TranslateLanguage.turkish.bcpCode);

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
    try {
      final dynamic connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult is List) {
        return !connectivityResult.contains(ConnectivityResult.none);
      }
      return connectivityResult != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

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

        final bool isSingleWord =
            !processedText.contains(' ') && processedText.length > 1;

        final results = await Future.wait([
          _onlineTranslator
              .translate(processedText, from: fromLang, to: toLang)
              .timeout(const Duration(milliseconds: 3500)),
          (isSingleWord && isEnToTr)
              ? _fetchSpellSuggestion(processedText)
              : Future.value(null),
          (isSingleWord)
              ? _fetchCombinedDictionary(processedText, isEnToTr)
              : Future.value(null),
        ]);

        final translation = results[0] as Translation;
        final String? suggestion = results[1] as String?;
        final List<WordMeaning>? meanings = results[2] as List<WordMeaning>?;

        String finalText = translation.text.trim();
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

  Future<String?> _fetchSpellSuggestion(String word) async {
    try {
      final url =
          Uri.parse('https://api.datamuse.com/words?sp=${Uri.encodeComponent(word)}&max=1');
      final response =
          await http.get(url).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final String suggestedWord = data[0]['word'].toString().toLowerCase();
          if (suggestedWord != word.toLowerCase()) {
            return suggestedWord;
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  // ÇİFT MOTORLU BİRLEŞTİRME ALGORİTMASI
  Future<List<WordMeaning>?> _fetchCombinedDictionary(
      String word, bool isEnToTr) async {
    final results = await Future.wait([
      _fetchGoogleDictionary(word, isEnToTr),
      isEnToTr ? _fetchFreeDictionaryMeanings(word) : Future.value(null),
    ]);

    final List<WordMeaning>? googleData = results[0];
    final List<WordMeaning>? freeDictData = results[1];

    if (googleData == null && freeDictData == null) return null;

    final List<WordMeaning> mergedList = [];
    final Set<String> foundPOS = {};

    if (googleData != null) {
      for (final m in googleData) {
        mergedList.add(m);
        foundPOS.add(m.partOfSpeech);
      }
    }

    if (freeDictData != null) {
      for (final m in freeDictData) {
        if (!foundPOS.contains(m.partOfSpeech)) {
          mergedList.add(m);
          foundPOS.add(m.partOfSpeech);
        }
      }
    }

    return mergedList.isNotEmpty ? mergedList : null;
  }

  Future<List<WordMeaning>?> _fetchGoogleDictionary(
      String word, bool isEnToTr) async {
    try {
      final sl = isEnToTr ? 'en' : 'tr';
      final tl = isEnToTr ? 'tr' : 'en';
      final url = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sl&tl=$tl&dt=bd&q=${Uri.encodeComponent(word)}');

      final response =
          await http.get(url).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        if (data.length > 1 && data[1] != null) {
          final List<dynamic> dict = data[1];
          final List<WordMeaning> meaningsList = [];

          for (final entry in dict) {
            if (entry is List && entry.length >= 2) {
              final String pos = entry[0].toString().toLowerCase();
              final List<dynamic> terms = entry[1];

              if (terms.isNotEmpty && _isSupportedPOS(pos)) {
                final String defTr =
                    terms.map((e) => e.toString()).take(5).join(', ');

                if (defTr.isNotEmpty) {
                  meaningsList.add(
                    WordMeaning(
                      partOfSpeech: pos,
                      partOfSpeechTr: _translatePOS(pos),
                      definitionEn: isEnToTr
                          ? "Sık kullanılan karşılıklar"
                          : "Common translations",
                      definitionTr:
                          defTr[0].toUpperCase() + defTr.substring(1),
                    ),
                  );
                }
              }
            }
          }
          return meaningsList.isNotEmpty ? meaningsList : null;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<List<WordMeaning>?> _fetchFreeDictionaryMeanings(String word) async {
    try {
      final url = Uri.parse(
          'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}');
      final response =
          await http.get(url).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) return null;

        final List<WordMeaning> meaningsList = [];
        final Set<String> foundPOS = {};

        for (final entry in data) {
          final List<dynamic> meaningsJson = entry['meanings'] ?? [];
          for (final m in meaningsJson) {
            final String pos =
                m['partOfSpeech']?.toString().toLowerCase() ?? '';
            final List<dynamic> defs = m['definitions'] ?? [];

            if (defs.isNotEmpty &&
                _isSupportedPOS(pos) &&
                !foundPOS.contains(pos)) {
              final String defEn = defs[0]['definition']?.toString() ?? '';

              if (defEn.isNotEmpty) {
                final transResult = await _onlineTranslator
                    .translate(defEn, from: 'en', to: 'tr')
                    .timeout(const Duration(milliseconds: 2500));
                String defTr = transResult.text.trim();

                if (defTr.isNotEmpty) {
                  defTr = defTr[0].toUpperCase() + defTr.substring(1);
                }

                meaningsList.add(
                  WordMeaning(
                    partOfSpeech: pos,
                    partOfSpeechTr: _translatePOS(pos),
                    definitionEn: defEn,
                    definitionTr: defTr,
                  ),
                );

                foundPOS.add(pos);
              }
            }
            if (meaningsList.length >= 5) break;
          }
          if (meaningsList.length >= 5) break;
        }
        return meaningsList.isNotEmpty ? meaningsList : null;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _isSupportedPOS(String pos) {
    return const [
      'noun',
      'verb',
      'adjective',
      'adverb',
      'pronoun',
      'preposition',
      'conjunction',
      'idiom',
      'interjection'
    ].contains(pos);
  }

  String _translatePOS(String pos) {
    switch (pos) {
      case 'noun':
        return 'İsim';
      case 'verb':
        return 'Fiil';
      case 'adjective':
        return 'Sıfat';
      case 'adverb':
        return 'Zarf';
      case 'pronoun':
        return 'Zamir';
      case 'preposition':
        return 'Edat';
      case 'conjunction':
        return 'Bağlaç';
      case 'idiom':
        return 'Deyim';
      case 'interjection':
        return 'Ünlem';
      default:
        return pos.toUpperCase();
    }
  }

  Future<TranslationResult> _performOfflineTranslation(
      String text, bool isEnToTr) async {
    final translator = isEnToTr ? _enToTrTranslator : _trToEnTranslator;
    final response = await translator.translateText(text);

    String finalText = response.trim();
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