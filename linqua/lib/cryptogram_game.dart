Dartimport 'dart:ui';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'translation_service.dart';
import 'word_model.dart';

class CryptogramGameScreen extends StatefulWidget {
  final TranslationService translationService;

  const CryptogramGameScreen({super.key, required this.translationService});

  @override
  State<CryptogramGameScreen> createState() => _CryptogramGameScreenState();
}

class _CryptogramGameScreenState extends State<CryptogramGameScreen> {
  final DatabaseService _dbService = DatabaseService();

  final List<String> _proverbs = [
    "A JOURNEY OF A THOUSAND MILES BEGINS WITH A SINGLE STEP",
    "DONT COUNT YOUR CHICKENS BEFORE THEY HATCH",
    "THE EARLY BIRD CATCHES THE WORM BUT THE SECOND MOUSE GETS THE CHEESE",
    "WHEN IN ROME DO AS THE ROMANS DO",
    "ACTIONS SPEAK LOUDER THAN WORDS",
    "BEAUTY IS IN THE EYE OF THE BEHOLDER",
    "EVERY CLOUD HAS A SILVER LINING",
    "WHERE THERE IS A WILL THERE IS A WAY",
    "PRACTICE MAKES PERFECT BUT NOBODY IS PERFECT",
    "TWO WRONGS DONT MAKE A RIGHT",
  ];

  late String _currentProverb = "";
  final Map<String, int> _cipherMap = {};
  final Map<int, String> _userGuesses = {};
  int? _selectedIndex;
  int? _errorIndex;
  bool _isLoadingQuote = true;

  @override
  void initState() {
    super.initState();
    _loadSavedGame();
  }

  Future<void> _saveSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crypto_proverb', _currentProverb);
    await prefs.setString('crypto_cipher', jsonEncode(_cipherMap));

    Map<String, String> stringKeyGuesses = {};
    _userGuesses.forEach((key, value) {
      stringKeyGuesses[key.toString()] = value;
    });
    await prefs.setString('crypto_guesses', jsonEncode(stringKeyGuesses));
  }

  Future<void> _clearSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('crypto_proverb');
    await prefs.remove('crypto_cipher');
    await prefs.remove('crypto_guesses');
  }

  Future<void> _loadSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProverb = prefs.getString('crypto_proverb');
    final savedCipher = prefs.getString('crypto_cipher');
    final savedGuesses = prefs.getString('crypto_guesses');

    if (savedProverb != null && savedProverb.isNotEmpty && savedCipher != null && savedGuesses != null) {
      setState(() {
        _currentProverb = savedProverb;

        Map<String, dynamic> decodedCipher = jsonDecode(savedCipher);
        _cipherMap.clear();
        decodedCipher.forEach((key, value) {
          _cipherMap[key] = value as int;
        });

        Map<String, dynamic> decodedGuesses = jsonDecode(savedGuesses);
        _userGuesses.clear();
        decodedGuesses.forEach((key, value) {
          _userGuesses[int.parse(key)] = value as String;
        });

        _isLoadingQuote = false;
      });
      _selectFirstEmptyBox();
    } else {
      _initGame();
    }
  }

  Future<void> _initGame({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await _clearSessionState();
    }

    setState(() {
      _isLoadingQuote = true;
      _cipherMap.clear();
      _userGuesses.clear();
      _selectedIndex = null;
      _errorIndex = null;
    });

    String fetchedProverb = "";

    try {
      for (int i = 0; i < 5; i++) {
        final response = await http.get(
          Uri.parse('https://dummyjson.com/quotes/random')
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String quote = data['quote'].toString().toUpperCase();

          quote = quote.replaceAll(RegExp(r'[^A-Z ]'), '');
          quote = quote.replaceAll(RegExp(r'\s+'), ' ').trim();

          if (quote.length > 30) {
            fetchedProverb = quote;
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Atasözü API'sine ulaşılamadı, yedek listeye geçiliyor: $e");
    }

    if (fetchedProverb.isEmpty) {
      fetchedProverb = _proverbs[Random().nextInt(_proverbs.length)];
    }

    setState(() {
      _currentProverb = fetchedProverb;

      List<int> numbers = List.generate(26, (i) => i + 1)..shuffle();
      int indexCount = 0;

      for (int i = 0; i < _currentProverb.length; i++) {
        String char = _currentProverb[i];
        if (RegExp(r'[A-Z]').hasMatch(char)) {
          if (!_cipherMap.containsKey(char)) {
            _cipherMap[char] = numbers[indexCount++];
          }
        }
      }

      List<String> words = _currentProverb.split(' ');
      List<List<int>> wordIndices = [];
      int currentIndexTracker = 0;

      for (String word in words) {
        List<int> currentWordIndices = [];
        for (int i = 0; i < word.length; i++) {
          if (RegExp(r'[A-Z]').hasMatch(word[i])) {
            currentWordIndices.add(currentIndexTracker + i);
          }
        }
        if (currentWordIndices.isNotEmpty) {
          wordIndices.add(currentWordIndices);
        }
        currentIndexTracker += word.length + 1;
      }

      int totalLetters = wordIndices.expand((element) => element).length;
      int hintCount = max(1, (totalLetters * 0.10).ceil());

      wordIndices.shuffle();

      for (int i = 0; i < hintCount && i < wordIndices.length; i++) {
        List<int> targetWord = wordIndices[i];
        int randomCharIndex = targetWord[Random().nextInt(targetWord.length)];
        _userGuesses[randomCharIndex] = _currentProverb[randomCharIndex];
      }

      _isLoadingQuote = false;
    });

    await _saveSessionState();
    _selectFirstEmptyBox();
  }

  void _selectFirstEmptyBox() {
    for (int i = 0; i < _currentProverb.length; i++) {
      String char = _currentProverb[i];
      if (RegExp(r'[A-Z]').hasMatch(char)) {
        if (!_userGuesses.containsKey(i)) {
          setState(() {
            _selectedIndex = i;
          });
          return;
        }
      }
    }
    setState(() {
      _selectedIndex = null;
    });
  }

  void _navigateBox({required bool forward}) {
    if (_selectedIndex == null) {
      _selectFirstEmptyBox();
      return;
    }

    int currentPos = _selectedIndex!;
    for (int i = 1; i <= _currentProverb.length; i++) {
      int checkPos = forward
          ? (currentPos + i) % _currentProverb.length
          : (currentPos - i + _currentProverb.length) % _currentProverb.length;

      if (RegExp(r'[A-Z]').hasMatch(_currentProverb[checkPos])) {
        if (!_userGuesses.containsKey(checkPos)) {
          setState(() {
            _selectedIndex = checkPos;
          });
          return;
        }
      }
    }

    setState(() => _selectedIndex = null);
  }

  void _onKeyPress(String actionOrLetter) {
    if (actionOrLetter == "PREV") {
      _navigateBox(forward: false);
      return;
    }

    if (actionOrLetter == "NEXT") {
      _navigateBox(forward: true);
      return;
    }

    if (_selectedIndex != null) {
      if (actionOrLetter == "DEL") {
        setState(() {
          _userGuesses.remove(_selectedIndex);
        });
        _saveSessionState();
        return;
      }

      String correctChar = _currentProverb[_selectedIndex!];

      if (actionOrLetter == correctChar) {
        setState(() {
          _userGuesses[_selectedIndex!] = actionOrLetter;
        });
        _saveSessionState();
        _navigateBox(forward: true);
        _checkWinCondition();
      } else {
        setState(() {
          _errorIndex = _selectedIndex;
        });

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              if (_errorIndex == _selectedIndex) _errorIndex = null;
            });
          }
        });
      }
    }
  }

  bool _isLetterFullyGuessed(String letter) {
    int totalRequired = 0;
    int totalGuessed = 0;

    for (int i = 0; i < _currentProverb.length; i++) {
      if (_currentProverb[i] == letter) {
        totalRequired++;
        if (_userGuesses[i] == letter) {
          totalGuessed++;
        }
      }
    }
    return totalRequired > 0 && totalRequired == totalGuessed;
  }

  void _checkWinCondition() {
    bool isWin = true;
    for (int i = 0; i < _currentProverb.length; i++) {
      if (RegExp(r'[A-Z]').hasMatch(_currentProverb[i])) {
        if (_userGuesses[i] != _currentProverb[i]) {
          isWin = false;
          break;
        }
      }
    }

    if (isWin) {
      _clearSessionState();
      _showWinDialog();
    }
  }

  void _showWinDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5 * animation.value, sigmaY: 5 * animation.value),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
            child: FadeTransition(
              opacity: animation,
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: _WinDialogWidget(
                  proverb: _currentProverb,
                  translationService: widget.translationService,
                  dbService: _dbService,
                  onRestart: () {
                    Navigator.pop(context);
                    _initGame(forceRefresh: true);
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("Kriptogram Bulmacası", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoadingQuote ? null : () => _initGame(forceRefresh: true),
            tooltip: "Yeni Oyun",
          )
        ],
      ),
      body: _isLoadingQuote
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text("İnternetten Yeni Bulmaca Çekiliyor...", style: TextStyle(color: Theme.of(context).colorScheme.primary))
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildProverbArea(isDark),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: true,
                  top: false,
                  child: _buildKeyboard(isDark),
                ),
              ],
            ),
    );
  }

  Widget _buildProverbArea(bool isDark) {
    List<Widget> wordsWidgets = [];
    List<Widget> charWidgets = [];

    for (int i = 0; i < _currentProverb.length; i++) {
      String char = _currentProverb[i];
      if (char == ' ') {
        if (charWidgets.isNotEmpty) {
          wordsWidgets.add(Wrap(children: charWidgets));
          charWidgets = [];
        }
      } else {
        charWidgets.add(_buildCharBox(char, i, isDark));
      }
    }

    if (charWidgets.isNotEmpty) {
      wordsWidgets.add(Wrap(children: charWidgets));
    }

    return Wrap(
      spacing: 16,
      runSpacing: 24,
      alignment: WrapAlignment.center,
      children: wordsWidgets
    );
  }

  Widget _buildCharBox(String char, int index, bool isDark) {
    if (!RegExp(r'[A-Z]').hasMatch(char)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(char, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      );
    }

    final int mappedNumber = _cipherMap[char]!;
    final String? guessedChar = _userGuesses[index];
    final bool isSelected = _selectedIndex == index;
    final bool isError = _errorIndex == index;
    final bool hasGuess = guessedChar != null;

    // GÜNCELLEME: Harf tamamen bulunmuşsa altındaki sayıyı gizle
    final bool isFullyGuessed = _isLetterFullyGuessed(char);

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        width: 36,
        height: 52,
        decoration: BoxDecoration(
          color: isError
              ? Colors.redAccent.withOpacity(0.5)
              : isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
          border: Border.all(
            color: isError
                ? Colors.redAccent
                : isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (hasGuess)
              Text(
                guessedChar,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            // GÜNCELLEME: isFullyGuessed false ise numarayı göster
            if (!isFullyGuessed)
              Positioned(
                bottom: 4,
                child: Text(
                  mappedNumber.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboard(bool isDark) {
    const List<String> rows = [
      "QWERTYUIOP",
      "ASDFGHJKL",
      "ZXCVBNM"
    ];

    return Container(
      padding: const EdgeInsets.only(bottom: 16, top: 16, left: 8, right: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.split('').map((letter) {
                  return _buildKey(letter, isDark);
                }).toList(),
              ),
            );
          }),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionKey("PREV", Icons.arrow_back_ios_new_rounded, isDark),
              _buildActionKey("DEL", Icons.backspace_rounded, isDark),
              _buildActionKey("NEXT", Icons.arrow_forward_ios_rounded, isDark),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildKey(String letter, bool isDark) {
    final bool isUsed = _isLetterFullyGuessed(letter);

    return GestureDetector(
      onTap: isUsed ? null : () => _onKeyPress(letter),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: MediaQuery.of(context).size.width / 11 - 6,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isUsed
              ? (isDark ? Colors.white12.withOpacity(0.05) : Colors.grey.shade300)
              : (isDark ? Colors.white10 : Colors.white),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            if (!isDark && !isUsed) BoxShadow(color: Colors.grey.shade300, offset: const Offset(0, 2))
          ],
        ),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isUsed ? (isDark ? Colors.white30 : Colors.grey.shade500) : null,
          )
        ),
      ),
    );
  }

  Widget _buildActionKey(String action, IconData icon, bool isDark) {
    final bool isDel = action == "DEL";

    return GestureDetector(
      onTap: () => _onKeyPress(action),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: isDel ? 80 : 64,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDel
              ? Colors.redAccent.withOpacity(0.8)
              : Theme.of(context).colorScheme.primary.withOpacity(0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _WinDialogWidget extends StatefulWidget {
  final String proverb;
  final TranslationService translationService;
  final DatabaseService dbService;
  final VoidCallback onRestart;

  const _WinDialogWidget({
    required this.proverb,
    required this.translationService,
    required this.dbService,
    required this.onRestart,
  });

  @override
  State<_WinDialogWidget> createState() => _WinDialogWidgetState();
}

class _WinDialogWidgetState extends State<_WinDialogWidget> {
  String _translatedText = "";
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _translateResult();
  }

  Future<void> _translateResult() async {
    try {
      final result = await widget.translationService.translateText(widget.proverb, isEnToTr: true);
      if (mounted) {
        setState(() {
          _translatedText = result.text;
          _isOffline = result.isOfflineFallback;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translatedText = "Çeviri tamamlanamadı.";
          _isLoading = false;
        });
      }
    }
  }

  void _saveToPool(BuildContext context) async {
    final newCard = WordCard(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      originalWord: widget.proverb,
      translatedWord: _translatedText,
      capturedAt: DateTime.now(),
    );
    await widget.dbService.saveWord(newCard);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Havuza başarıyla eklendi!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onRestart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 64),
          const SizedBox(height: 16),
          const Text("Tebrikler!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(widget.proverb, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 16),
          _isLoading
              ? const CircularProgressIndicator()
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Text(_translatedText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onRestart,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text("Yeni Oyun"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _saveToPool(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16)
                  ),
                  child: const Text("Havuza Ekle"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
