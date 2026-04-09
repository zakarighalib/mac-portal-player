import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Player Selection ---
          Text(
            'VIDEO PLAYER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _PlayerOption(
                  title: 'Built-in Player',
                  subtitle: 'Play inside the app with subtitle support',
                  icon: Icons.play_circle_fill,
                  value: PreferredPlayer.builtin,
                  groupValue: appState.preferredPlayer,
                  onChanged: (v) => appState.setPreferredPlayer(v),
                ),
                const Divider(height: 1, indent: 56),
                _PlayerOption(
                  title: 'MX Player',
                  subtitle: 'Open streams in MX Player (must be installed)',
                  icon: Icons.open_in_new,
                  value: PreferredPlayer.mxplayer,
                  groupValue: appState.preferredPlayer,
                  onChanged: (v) => appState.setPreferredPlayer(v),
                ),
                const Divider(height: 1, indent: 56),
                _PlayerOption(
                  title: 'VLC External',
                  subtitle: 'Open streams in VLC app (must be installed)',
                  icon: Icons.open_in_new,
                  value: PreferredPlayer.vlcExternal,
                  groupValue: appState.preferredPlayer,
                  onChanged: (v) => appState.setPreferredPlayer(v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- Subtitle Settings ---
          Text(
            'SUBTITLES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: const Text('Enable Subtitles'),
              subtitle: Text(
                'Automatically load subtitle tracks when available',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              value: appState.subtitlesEnabled,
              onChanged: (v) => appState.setSubtitlesEnabled(v),
              activeColor: Colors.deepPurpleAccent,
              secondary: const Icon(Icons.subtitles, color: Colors.deepPurpleAccent),
            ),
          ),

          const SizedBox(height: 24),

          // --- About ---
          Text(
            'ABOUT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const ListTile(
              leading: Icon(Icons.info_outline, color: Colors.deepPurpleAccent),
              title: Text('MAC Portal Player'),
              subtitle: Text('v1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final PreferredPlayer value;
  final PreferredPlayer groupValue;
  final ValueChanged<PreferredPlayer> onChanged;

  const _PlayerOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<PreferredPlayer>(
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      secondary: Icon(icon, color: Colors.deepPurpleAccent),
      value: value,
      groupValue: groupValue,
      activeColor: Colors.deepPurpleAccent,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
