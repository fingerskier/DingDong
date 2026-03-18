import 'package:flutter/material.dart';
import 'models/chime_settings.dart';
import 'services/chime_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await ChimeSettings.load();
  final chimeService = ChimeService(settings: settings);

  runApp(DingDongApp(chimeService: chimeService));
}

class DingDongApp extends StatelessWidget {
  final ChimeService chimeService;

  const DingDongApp({super.key, required this.chimeService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DingDong',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF5B4FCF),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF5B4FCF),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: HomeScreen(chimeService: chimeService),
    );
  }
}
