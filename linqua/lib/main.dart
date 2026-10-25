Dartimport 'package:flutter/material.dart';
import 'database_service.dart';
import 'main_screen.dart';

// Tema bildirimcisi her yerden erişilebilmesi için global tutuldu
final ValueNotifier<bool> themeNotifier = ValueNotifier(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dbService = DatabaseService();
  await dbService.init();

  themeNotifier.value = dbService.isDarkMode();

  runApp(const KelimeAvcisiApp());
}

class KelimeAvcisiApp extends StatelessWidget {
  const KelimeAvcisiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'Kelime Avcısı',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurpleAccent,
              brightness: Brightness.dark,
              surface: const Color(0xFF1E1E2C),
            ),
            scaffoldBackgroundColor: const Color(0xFF12121D),
            useMaterial3: true,
            cardTheme: CardThemeData(
              elevation: 0,
              color: const Color(0xFF252536),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white10),
              ),
            ),
          ),
          home: const MainScreen(),
        );
      },
    );
  }
}