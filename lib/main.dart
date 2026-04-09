import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'providers/app_state.dart';
import 'screens/profiles_screen.dart';
import 'screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState()..loadProfiles(),
      child: const MacPortalApp(),
    ),
  );
}

class MacPortalApp extends StatelessWidget {
  const MacPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAC Portal Player',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.amber,
        ),
      ),
      home: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.isLoggedIn) {
            return const MainScreen();
          }
          return const ProfilesScreen();
        },
      ),
    );
  }
}
