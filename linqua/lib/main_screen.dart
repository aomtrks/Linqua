Dartimport 'dart:ui';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'word_model.dart';
import 'share_intent_strategy.dart';
import 'capture_context.dart';
import 'translation_service.dart';
import 'database_service.dart';
import 'game_screen.dart';
import 'main.dart';
import 'dialogs.dart';
import 'cryptogram_game.dart';
// M3-M4 Aşamasında aktif edilecek mini oyunlar:
// import 'sliding_puzzle_game.dart';
// import 'log_sorting_game.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final DatabaseService _databaseService = DatabaseService();
  int _currentIndex = 0;

  late WordCaptureContext _captureContext;
  final TranslationService _translationService = TranslationService();
  final FlutterTts _flutterTts = FlutterTts();

  List<WordCard> _savedWords = [];
  bool _isProcessing = false;
  bool _isInitializingModels = true;
  String _initializationError = '';

  String _wordOfTheDay = "";
  final List<String> _advancedWords = [
    'Ubiquitous', 'Ephemeral', 'Pernicious', 'Esoteric', 'Paradigm',
    'Eloquent', 'Inevitable', 'Pragmatic', 'Tenacious', 'Meticulous',
    'Ambiguous', 'Diligent', 'Lucid', 'Resilient', 'Vindicate',
    'Cacophony', 'Ineffable', 'Mellifluous', 'Sycophant', 'Obfuscate'
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isInitializingModels = true;
      _initializationError = '';
    });

    try {
      await _translationService.ensureModelsDownloaded().timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw Exception("İndirme süresi aşıldı, internet hızınızı kontrol edin."),
      );

      await _loadWordOfTheDay();
      _loadStoredWords();

      _captureContext = WordCaptureContext(ShareIntentCaptureStrategy());
      _captureContext.startListening(_handleCapturedWord);

      setState(() {
        _isInitializingModels = false;
      });
    } catch (e) {
      setState(() {
        _initializationError = "Çevrimdışı destek kütüphaneleri indirilirken bir sorun oluştu.\nLütfen internet bağlantınızı kontrol edin.\n\nHata Detayı: ${e.toString()}";
      });
    }
  }

  Future<void> _loadWordOfTheDay() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString('wotd_date');
    final savedWord = prefs.getString('wotd_word');

    final now = DateTime.now();
    DateTime lastDate = lastDateStr != null ? DateTime.parse(lastDateStr) : DateTime.fromMillisecondsSinceEpoch(0);

    if (now.difference(lastDate).inHours >= 24 || savedWord == null) {
      String newWord = "";

      try {
        final response = await http.get(
          Uri.parse('https://random-word-api.herokuapp.com/word?length=9')
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          if (data.isNotEmpty) {
            newWord = data[0].toString();
            newWord = newWord[0].toUpperCase() + newWord.substring(1);
          }
        }
      } catch (e) {
        debugPrint("API'ye ulaşılamadı, yedek listeye geçiliyor: $e");
      }

      if (newWord.isEmpty) {
        newWord = _advancedWords[Random().nextInt(_advancedWords.length)];
      }

      await prefs.setString('wotd_date', now.toIso8601String());
      await prefs.setString('wotd_word', newWord);
      setState(() { _wordOfTheDay = newWord; });
    } else {
      setState(() { _wordOfTheDay = savedWord; });
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  void _loadStoredWords() {
    setState(() {
      _savedWords = _databaseService.getAllWords();
    });
  }

  Future<void> _addWordToPool(
    String original,
    String translated,
    bool isOffline, {
    String? correctedWord,
    List<WordMeaning>? meanings,
  }) async {
    final newCard = WordCard(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      originalWord: original,
      translatedWord: translated,
      capturedAt: DateTime.now(),
      correctedWord: correctedWord,
      meanings: meanings,
    );

    await _databaseService.saveWord(newCard);
    _loadStoredWords();

    if (isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('"$original" çevrimdışı eklendi.')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$original" havuza eklendi!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }

  void _handleCapturedWord(String word) async {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty) return;

    setState(() { _isProcessing = true; });

    try {
      TranslationResult result = await _translationService.translateText(cleanWord, isEnToTr: true);
      await _addWordToPool(
        cleanWord,
        result.text,
        result.isOfflineFallback,
        correctedWord: result.correctedWord,
        meanings: result.meanings,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çeviri sırasında bir hata oluştu: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() { _isProcessing = false; });
    }
  }

  Future<void> _applyCorrectionToCard(WordCard oldCard, String correctedWord) async {
    setState(() { _isProcessing = true; });
    try {
      TranslationResult result = await _translationService.translateText(correctedWord, isEnToTr: true);

      oldCard.originalWord = correctedWord;
      oldCard.translatedWord = result.text;
      oldCard.correctedWord = null;
      oldCard.meanings = result.meanings;

      await _databaseService.saveWord(oldCard);
      _loadStoredWords();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kelime "$correctedWord" olarak düzeltildi ve güncellendi!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Düzeltme sırasında bir hata oluştu: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() { _isProcessing = false; });
    }
  }

  void _deleteWord(String id) async {
    await _databaseService.deleteWord(id);
    _loadStoredWords();
  }

  void _showAddWordSheet(BuildContext context) {
    final TextEditingController textController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Yeni Kelime Ekle", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: "İngilizce kelime veya cümle yazın...",
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      onSubmitted: (value) {
                        Navigator.pop(context);
                        _handleCapturedWord(value);
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (textController.text.trim().isNotEmpty) {
                          Navigator.pop(context);
                          _handleCapturedWord(textController.text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text("Çevir ve Ekle", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showQuickTranslateDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8 * animation.value, sigmaY: 8 * animation.value),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(20),
                child: QuickTranslateDialogWidget(
                  translationService: _translationService,
                  onAddToPool: (enWord, trWord, isOffline, {String? correctedWord, List<WordMeaning>? meanings}) {
                    _addWordToPool(enWord, trWord, isOffline, correctedWord: correctedWord, meanings: meanings);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showWordOfTheDayDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8 * animation.value, sigmaY: 8 * animation.value),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(20),
                child: WordOfTheDayDialogWidget(
                  wordOfTheDay: _wordOfTheDay,
                  translationService: _translationService,
                  onSpeak: () => _speak(_wordOfTheDay),
                  onAddToPool: (enWord, trWord, isOffline, {String? correctedWord, List<WordMeaning>? meanings}) {
                    _addWordToPool(enWord, trWord, isOffline, correctedWord: correctedWord, meanings: meanings);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showExampleSentenceDialog(WordCard card) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8 * animation.value, sigmaY: 8 * animation.value),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(20),
                child: ExampleSentenceDialogWidget(
                  card: card,
                  translationService: _translationService,
                  onAddToPool: (enSentence, trSentence, isOffline) {
                    _addWordToPool(enSentence, trSentence, isOffline);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    if (!_isInitializingModels && _initializationError.isEmpty) {
      _captureContext.stopListening();
    }
    _translationService.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_initializationError.isNotEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 80, color: Colors.red.shade400),
                const SizedBox(height: 24),
                Text("Bağlantı Hatası", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 16),
                Text(_initializationError, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.5)),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _initializeApp,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Tekrar Dene"),
                )
              ],
            ),
          ),
        ),
      );
    }

    if (_isInitializingModels) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 32),
              Text("Sisteme Hazırlanıyor...", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 12),
              Text("Çevrimdışı dil modelleri indiriliyor.\nBu işlem sadece ilk açılışta yapılır,\nlütfen bekleyin (Yaklaşık 30MB).", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, height: 1.5)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      drawer: Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.rocket_launch_rounded, size: 32, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text("Kelime Avcısı", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary, letterSpacing: -0.5)),
                ],
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.g_translate_rounded, color: Colors.blue),
              ),
              title: const Text("Hızlı Çeviri", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text("Uygulama içi anlık çeviri", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              onTap: () {
                Navigator.pop(context);
                _showQuickTranslateDialog();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.orange),
              ),
              title: const Text("Günün Kelimesi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text("Günde 1 kez B2-C2 kelime", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              onTap: () {
                Navigator.pop(context);
                _showWordOfTheDayDialog();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.extension_rounded, color: Colors.green),
              ),
              title: const Text("Kriptogram Bulmacası", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text("Kriptogram çöz, kelime öğren", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CryptogramGameScreen(
                      translationService: _translationService,
                    ),
                  ),
                ).then((_) => _loadStoredWords());
              },
            ),
            /* M4 Aşamasında Açılacak Mini Oyunlar:
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.grid_view_rounded, color: Colors.purple),
              ),
              title: const Text("Sliding Puzzle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text("Blokları kaydır, satırları erit", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SlidingPuzzleGameScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.brown.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.forest_rounded, color: Colors.brown),
              ),
              title: const Text("Kütük Birleştirme", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text("Kütükleri birleştir ve patlat", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LogSortingGameScreen(),
                  ),
                );
              },
            ),
            */
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Kelime Havuzu' : 'Öğrenme Odasu', style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () {
              final newTheme = !isDark;
              _databaseService.toggleTheme(newTheme);
              themeNotifier.value = newTheme;
            },
          )
        ],
      ),
      body: SafeArea(
        child: _currentIndex == 0 ? _buildWordList(isDark) : const GameScreen(),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showAddWordSheet(context),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 4,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: isDark ? Colors.white54 : Colors.grey.shade500,
            showUnselectedLabels: false,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.style_outlined), activeIcon: Icon(Icons.style), label: 'Havuz'),
              BottomNavigationBarItem(icon: Icon(Icons.psychology_outlined), activeIcon: Icon(Icons.psychology), label: 'Öğren'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordList(bool isDark) {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text("Kelime İşleniyor...", style: TextStyle(color: Theme.of(context).colorScheme.primary))
          ],
        )
      );
    }

    if (_savedWords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey.shade200),
            const SizedBox(height: 16),
            Text('Havuzun bomboş!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            Text('Okurken bir kelime seçip paylaşın\nveya sağ alt köşeden yazın.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, height: 1.5)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: _savedWords.length,
      itemBuilder: (context, index) {
        final card = _savedWords[index];
        return Dismissible(
          key: Key(card.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
          ),
          onDismissed: (direction) => _deleteWord(card.id),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onLongPress: () => _showExampleSentenceDialog(card),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card.originalWord, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 4),
                              Text(card.translatedWord, style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.grey.shade800)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.volume_up_rounded, color: Theme.of(context).colorScheme.primary),
                          onPressed: () => _speak(card.originalWord),
                        ),
                      ],
                    ),
                    if (card.correctedWord != null && card.correctedWord!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => _applyCorrectionToCard(card, card.correctedWord!),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade700, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb_rounded, color: Colors.amber.shade700, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                                    children: [
                                      const TextSpan(text: "Bunu mu kastettiniz: "),
                                      TextSpan(
                                        text: card.correctedWord,
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800, decoration: TextDecoration.underline),
                                      ),
                                      const TextSpan(text: "? (Düzeltmek için dokun)"),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (card.meanings != null && card.meanings!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: card.meanings!.map((m) {
                          final badgeColor = _getBadgeColorForPool(m.partOfSpeech);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: badgeColor.withOpacity(0.4)),
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                                children: [
                                  TextSpan(
                                    text: "${m.partOfSpeechTr}: ",
                                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: m.definitionTr),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getBadgeColorForPool(String pos) {
    switch (pos) {
      case 'noun': return Colors.blue.shade500;
      case 'verb': return Colors.red.shade500;
      case 'adjective': return Colors.orange.shade600;
      case 'adverb': return Colors.purple.shade400;
      default: return Colors.teal.shade500;
    }
  }
}

// --- YENİ ÖRNEK CÜMLE DİYALOG WIDGET'I ---
class ExampleSentenceDialogWidget extends StatefulWidget {
  final WordCard card;
  final TranslationService translationService;
  final Function(String enSentence, String trSentence, bool isOffline) onAddToPool;

  const ExampleSentenceDialogWidget({
    super.key,
    required this.card,
    required this.translationService,
    required this.onAddToPool,
  });

  @override
  State<ExampleSentenceDialogWidget> createState() => _ExampleSentenceDialogWidgetState();
}

class _ExampleSentenceDialogWidgetState extends State<ExampleSentenceDialogWidget> {
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _exampleEn;
  String? _exampleTr;
  bool _wasOffline = false;

  Future<void> _fetchAndTranslateExample() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _exampleEn = null;
      _exampleTr = null;
    });

    try {
      final word = widget.card.originalWord.trim().toLowerCase();
      String? foundExample;

      // --- 1. AŞAMA: Free Dictionary API ---
      try {
        final url1 = Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}');
        final response1 = await http.get(url1).timeout(const Duration(seconds: 3));

        if (response1.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response1.body);
          for (var entry in data) {
            final meanings = entry['meanings'] as List<dynamic>? ?? [];
            for (var m in meanings) {
              final defs = m['definitions'] as List<dynamic>? ?? [];
              for (var d in defs) {
                if (d['example'] != null && d['example'].toString().isNotEmpty) {
                  foundExample = d['example'].toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
                  break;
                }
              }
              if (foundExample != null) break;
            }
            if (foundExample != null) break;
          }
        }
      } catch (_) {}

      // --- 2. AŞAMA: Google Translate API (Güçlü Fallback) ---
      if (foundExample == null) {
        try {
          // ÖNEMLİ DEĞİŞİKLİK: sl=en ve tl=en yaparak İngilizce->İngilizce cümleleri zorluyoruz.
          final url2 = Uri.parse('https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=en&dt=ex&q=${Uri.encodeComponent(word)}');
          final response2 = await http.get(url2).timeout(const Duration(seconds: 4));

          if (response2.statusCode == 200) {
            final List<dynamic> data = jsonDecode(response2.body);

            // "Deep Search" (Derin Arama) ile JSON'ın neresinde olursa olsun örneği buluyoruz.
            String? searchPass1(dynamic node) {
              if (node is String && (node.contains('<b>') || node.contains('</b>'))) {
                String clean = node.replaceAll(RegExp(r'<[^>]*>'), '').trim();
                if (clean.toLowerCase().contains(word) && clean.split(' ').length >= 2) {
                  return clean;
                }
              } else if (node is List) {
                for (var child in node) {
                  String? res = searchPass1(child);
                  if (res != null) return res;
                }
              }
              return null;
            }

            String? searchPass2(dynamic node) {
              if (node is String) {
                String clean = node.replaceAll(RegExp(r'<[^>]*>'), '').trim();
                if (clean.toLowerCase().contains(word) && clean.split(' ').length >= 3) {
                  return clean;
                }
              } else if (node is List) {
                for (var child in node) {
                  String? res = searchPass2(child);
                  if (res != null) return res;
                }
              }
              return null;
            }

            foundExample = searchPass1(data) ?? searchPass2(data);
          }
        } catch (_) {}
      }

      // --- 3. AŞAMA: Çeviri ve Ekrana Basma ---
      if (foundExample != null) {
        foundExample = foundExample![0].toUpperCase() + foundExample!.substring(1);
        final transResult = await widget.translationService.translateText(foundExample!, isEnToTr: true);

        if (mounted) {
          setState(() {
            _exampleEn = foundExample;
            _exampleTr = transResult.text;
            _wasOffline = transResult.isOfflineFallback;
          });
        }
      } else {
        if (mounted) {
          setState(() { _exampleEn = null; });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _exampleEn = null; });
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
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
        border: isDark ? Border.all(color: Colors.white10) : Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.format_quote_rounded, size: 48, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 18, color: isDark ? Colors.white : Colors.black87),
              children: [
                TextSpan(text: '"', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                TextSpan(text: widget.card.originalWord, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                const TextSpan(text: '" kelimesi için örnek bir cümle görmek ister misin?'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!_hasSearched)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _fetchAndTranslateExample,
                icon: const Icon(Icons.search_rounded),
                label: const Text("Örnek Cümle Getir", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(),
            ),
          if (_hasSearched && !_isLoading && _exampleEn == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                "Bu kelime veya deyim için uygun bir örnek cümle bulunamadı.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold),
              ),
            ),
          if (_hasSearched && !_isLoading && _exampleEn != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_exampleEn!, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Container(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(_exampleTr ?? "Çeviri yapılamadı.", style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Kapat"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      widget.onAddToPool(_exampleEn!, _exampleTr ?? "", _wasOffline);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add_task_rounded, size: 20),
                    label: const Text("Havuza Ekle"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}
