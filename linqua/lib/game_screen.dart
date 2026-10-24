Dartimport 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_tts/flutter_tts.dart'; // TTS Kütüphanesi
import 'word_model.dart';
import 'database_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final FlutterTts _flutterTts = FlutterTts(); // TTS Nesnesi
  List<WordCard> _reviewWords = [];
  int _cardsLeft = 0;

  @override
  void initState() {
    super.initState();
    _loadWordsForReview();
  }

  // Seslendirme Fonksiyonu
  Future<void> _speak(String text, String languageCode) async {
    await _flutterTts.setLanguage(languageCode);
    await _flutterTts.setSpeechRate(0.5); // Okuma hızı
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  void _loadWordsForReview() {
    setState(() {
      _reviewWords = _databaseService.getWordsForReview()..shuffle();
      _cardsLeft = _reviewWords.length;
    });
  }

  void _processSwipe(WordCard word, bool isRemembered) {
    if (isRemembered) {
      if (word.repetition == 0) {
        word.interval = 1;
      } else if (word.repetition == 1) {
        word.interval = 6;
      } else {
        word.interval = (word.interval * word.easeFactor).round();
      }
      word.repetition += 1;
      word.easeFactor += 0.1;
      word.nextReviewDate = DateTime.now().add(Duration(days: word.interval));
    } else {
      word.repetition = 0;
      word.interval = 1;
      word.easeFactor = (word.easeFactor - 0.2 < 1.3) ? 1.3 : word.easeFactor - 0.2;
    }
    _databaseService.saveWord(word);
  }

  @override
  void dispose() {
    _flutterTts.stop(); // Ekrandan çıkıldığında sesi durdur
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_reviewWords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.1),
              ),
              child: const Icon(Icons.task_alt_rounded, size: 64, color: Colors.green),
            ),
            const SizedBox(height: 24),
            Text(
              "Bugünlük bitti!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              "Harika gidiyorsun.\nYarın aynı saatte görüşmek üzere.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Unuttum (Sol)", style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Kalan: $_cardsLeft",
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              Text("Öğrendim (Sağ)", style: TextStyle(color: Colors.green.shade400, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: CardSwiper(
            cardsCount: _reviewWords.length,
            numberOfCardsDisplayed: _reviewWords.length >= 3 ? 3 : _reviewWords.length,
            backCardOffset: const Offset(0, 30),
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40, top: 10),
            onSwipe: (previousIndex, currentIndex, direction) {
              final swipedWord = _reviewWords[previousIndex];
              if (direction == CardSwiperDirection.right) {
                _processSwipe(swipedWord, true);
              } else if (direction == CardSwiperDirection.left) {
                _processSwipe(swipedWord, false);
              }
              setState(() { _cardsLeft--; });
              return true;
            },
            onEnd: () => _loadWordsForReview(),
            cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
              final word = _reviewWords[index];
              return FlipCard(
                direction: FlipDirection.HORIZONTAL,
                front: _buildCardUI(word.originalWord, Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.onSurface, "İNGİLİZCE", "en-US", context),
                back: _buildCardUI(word.translatedWord, Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.onPrimary, "TÜRKÇE", "tr-TR", context),
              );
            },
          ),
        ),
      ],
    );
  }

  // langCode eklendi ve UI güncellendi
  Widget _buildCardUI(String text, Color bgColor, Color textColor, String label, String langCode, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
        border: isDark ? Border.all(color: Colors.white10, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 30,
            left: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Seslendirme Butonu
                  IconButton(
                    icon: Icon(Icons.volume_up_rounded, color: textColor.withOpacity(0.8), size: 36),
                    onPressed: () => _speak(text, langCode),
                    style: IconButton.styleFrom(
                      backgroundColor: textColor.withOpacity(0.1),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            right: 0,
            left: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded, color: textColor.withOpacity(0.3), size: 20),
                const SizedBox(width: 8),
                Text(
                  "Çevirmek için dokun",
                  style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w500),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
