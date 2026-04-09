import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mx_player_plugin/mx_player_plugin.dart';
import '../models/content_item.dart';
import '../providers/app_state.dart';
import '../screens/player_screen.dart';

class PlaybackHelper {
  /// Resolves the stream URL and either launches an external player OR
  /// pushes the built-in `PlayerScreen` onto the navigator.
  static Future<void> playContent(
    BuildContext context, 
    ContentItem item, 
    String type, 
    {int? episodeNum, List<ContentItem>? playlist, int? initialIndex}
  ) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final preferredPlayer = appState.preferredPlayer;

    if (preferredPlayer == PreferredPlayer.builtin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            item: item, 
            type: type, 
            episodeNum: episodeNum,
            playlist: playlist,
            initialIndex: initialIndex,
          ),
        ),
      );
      return;
    }

    // --- External Player Flow ---

    // Show loading dialog while resolving URL
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final client = appState.client!;
      String streamUrl = await client.getStreamUrl(
        type,
        item.cmd,
        episodeNum: episodeNum,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (streamUrl.isEmpty || !streamUrl.startsWith('http')) {
        throw Exception('Could not resolve stream URL for: ${item.title}');
      }

      if (preferredPlayer == PreferredPlayer.mxplayer) {
        await _launchMxPlayer(context, streamUrl, item.title);
      } else if (preferredPlayer == PreferredPlayer.vlcExternal) {
        await _launchVlcExternal(context, streamUrl);
      }
    } catch (e) {
      if (context.mounted) {
        // Try to close loading dialog if it's still open
        try { Navigator.pop(context); } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  static Future<void> _launchMxPlayer(BuildContext context, String url, String title) async {
    try {
      await PlayerPlugin.openWithMxPlayer(url, '', title: title);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MX Player error: ${_extractErrorMessage(e)}'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  static Future<void> _launchVlcExternal(BuildContext context, String url) async {
    try {
      await PlayerPlugin.openWithVlcPlayer(url);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('VLC error: ${_extractErrorMessage(e)}'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Extract a user-friendly error message from a PlatformException
  static String _extractErrorMessage(dynamic e) {
    if (e is PlatformException) {
      return e.message ?? e.code;
    }
    return e.toString();
  }
}
