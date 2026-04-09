import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'categories_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<String> _types = ['vod', 'series', 'itv'];
  final List<String> _labels = ['Movies', 'Series', 'Channels'];
  final List<IconData> _icons = [Icons.movie, Icons.tv, Icons.live_tv];

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(appState.playlistName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => appState.logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _types.map((type) =>
          CategoriesScreen(key: ValueKey(type), type: type)
        ).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: List.generate(_types.length, (i) =>
          BottomNavigationBarItem(
            icon: Icon(_icons[i]),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
