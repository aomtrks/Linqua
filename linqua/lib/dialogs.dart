import 'package:flutter/material.dart';
import 'translation_service.dart';
import 'word_model.dart';

// --- HIZLI ÇEVİRİ DİYALOĞU ---
class QuickTranslateDialogWidget extends StatefulWidget {
  final TranslationService translationService;
  final Function(String enWord, String trWord, bool isOffline, {String? correctedWord, List<WordMeaning>? meanings}) onAddToPool;

  const QuickTranslateDialogWidget({
    super.key,
    required this.translationService,
    required this.onAddToPool,
  });

  @override
  State<QuickTranslateDialogWidget> createState() => _QuickTranslateDialogWidgetState();
}

class _QuickTranslateDialogWidgetState extends State<QuickTranslateDialogWidget> {
  final TextEditingController _inputController = TextEditingController();
  bool _isEnToTr = true;
  bool _isTranslating = false;
  String _translatedText = "";
  bool _wasOffline = false;
  String? _correctedWord;
  List<WordMeaning>? _meanings;

  // Çeviri yapıldığında arka planda çevrilen kelimeyi güvenliğe alıyoruz
  String _lastSearchedText = "";

  Future<void> _performTranslation() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isTranslating = true;
      _translatedText = "";
      _correctedWord = null;
      _meanings = null;
      _lastSearchedText = text; // Aramayı hafızaya al
    });

    try {
      final result = await widget.translationService.translateText(text, isEnToTr: _isEnToTr);
      if (mounted) {
        setState(() {
          _translatedText = result.text;
          _wasOffline = result.isOfflineFallback;
          _correctedWord = result.correctedWord;
          _meanings = result.meanings;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translatedText = "Hata oluştu: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  void _applySuggestion(String suggestedWord) {
    _inputController.text = suggestedWord;
    _performTranslation();
  }

  void _swapLanguages() {
    setState(() {
      _isEnToTr = !_isEnToTr;
      _translatedText = "";
      _correctedWord = null;
      _meanings = null;
    });
  }

  Color _getBadgeColor(String pos) {
    switch (pos) {
      case 'noun': return Colors.blue.shade600;
      case 'verb': return Colors.red.shade600;
      case 'adjective': return Colors.orange.shade700;
      case 'adverb': return Colors.purple.shade600;
      default: return Colors.teal.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white10) : Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Hızlı Çeviri & Sözlük", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(_isEnToTr ? "İngilizce" : "Türkçe", style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.swap_horiz_rounded), color: Theme.of(context).colorScheme.primary, onPressed: _swapLanguages),
                  Text(_isEnToTr ? "Türkçe" : "İngilizce", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inputController,
              maxLines: 3,
              minLines: 1,
              // MANTIK 1: Metin değiştiği an eski sonuçları ekrandan temizler
              onChanged: (value) {
                if (_translatedText.isNotEmpty || _correctedWord != null) {
                  setState(() {
                    _translatedText = "";
                    _correctedWord = null;
                    _meanings = null;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: "Çevrilecek kelime veya cümleyi yazın...",
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _performTranslation(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isTranslating ? null : _performTranslation,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: _isTranslating
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Çevir & İncele", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (_correctedWord != null && _correctedWord!.isNotEmpty) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _applySuggestion(_correctedWord!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: Colors.amber.shade700, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                            children: [
                              const TextSpan(text: "Bunu mu demek istediniz: "),
                              TextSpan(
                                text: _correctedWord,
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800, decoration: TextDecoration.underline),
                              ),
                              const TextSpan(text: "?"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_translatedText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Genel Çeviri:", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_translatedText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (_meanings != null && _meanings!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text("Kelime Türleri ve Anlamları", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                ..._meanings!.map((meaning) {
                  final badgeColor = _getBadgeColor(meaning.partOfSpeech);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                meaning.partOfSpeechTr,
                                style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                meaning.definitionEn,
                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.grey.shade700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          meaning.definitionTr,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  // MANTIK 2: Her ihtimale karşı TextField'daki anlık değer yerine
                  // araması yapılarak hafızaya alınmış son doğru kelimeyi (_lastSearchedText) havuza atar
                  final enText = _isEnToTr ? _lastSearchedText : _translatedText;
                  final trText = _isEnToTr ? _translatedText : _lastSearchedText;
                  widget.onAddToPool(enText, trText, _wasOffline, correctedWord: _correctedWord, meanings: _meanings);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.add_task_rounded),
                label: const Text("Havuza Ekle"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// --- GÜNÜN KELİMESİ DİYALOĞU ---
class WordOfTheDayDialogWidget extends StatefulWidget {
  final String wordOfTheDay;
  final TranslationService translationService;
  final VoidCallback onSpeak;
  final Function(String enWord, String trWord, bool isOffline, {String? correctedWord, List<WordMeaning>? meanings}) onAddToPool;

  const WordOfTheDayDialogWidget({
    super.key,
    required this.wordOfTheDay,
    required this.translationService,
    required this.onSpeak,
    required this.onAddToPool,
  });

  @override
  State<WordOfTheDayDialogWidget> createState() => _WordOfTheDayDialogWidgetState();
}

class _WordOfTheDayDialogWidgetState extends State<WordOfTheDayDialogWidget> {
  String _translatedWord = "";
  bool _isLoading = true;
  bool _isOffline = false;

  // GÜNCELLEME: Sözlük anlamları ve öneriler için değişkenler eklendi
  String? _correctedWord;
  List<WordMeaning>? _meanings;

  @override
  void initState() {
    super.initState();
    _translateWord();
  }

  Future<void> _translateWord() async {
    try {
      final result = await widget.translationService.translateText(widget.wordOfTheDay, isEnToTr: true);
      if (mounted) {
        setState(() {
          _translatedWord = result.text;
          _isOffline = result.isOfflineFallback;
          
          // GÜNCELLEME: Çeviri servisinden gelen zengin içerikler yakalanır
          _correctedWord = result.correctedWord;
          _meanings = result.meanings;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translatedWord = "Çeviri başarısız.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.orange.withOpacity(0.2)) : Border.all(color: Colors.orange.shade200),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: const Text("GÜNÜN KELİMESİ", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 32),
          Text(widget.wordOfTheDay, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.5), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          IconButton(icon: Icon(Icons.volume_up_rounded, color: Theme.of(context).colorScheme.primary, size: 28), onPressed: widget.onSpeak),
          const SizedBox(height: 16),
          _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_translatedWord, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () {
                // GÜNCELLEME: Tüm detaylı anlamlar havuza iletiliyor
                widget.onAddToPool(
                  widget.wordOfTheDay,
                  _translatedWord,
                  _isOffline,
                  correctedWord: _correctedWord,
                  meanings: _meanings,
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add_task_rounded),
              label: const Text("Havuza Ekle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          )
        ],
      ),
    );
  }
}