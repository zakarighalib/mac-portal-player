import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import '../models/content_item.dart';
import '../providers/app_state.dart';

class PlayerScreen extends StatefulWidget {
  final ContentItem item;
  final String type;
  final int? episodeNum;
  final List<ContentItem>? playlist;
  final int? initialIndex;

  const PlayerScreen({
    super.key,
    required this.item,
    required this.type,
    this.episodeNum,
    this.playlist,
    this.initialIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player;
  late final VideoController controller;
  bool _isLoading = true;
  String? _error;
  
  late ContentItem _currentItem;
  late int _currentIndex;
  BoxFit _currentFit = BoxFit.contain;
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Heartbeat timer to keep the stream alive
  Timer? _keepAliveTimer;

  // Video stats fetched from MPV properties
  String _videoStats = '';

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _currentIndex = widget.initialIndex ?? 0;
    
    player = Player();
    controller = VideoController(player);

    // Listen to video params to build stats string with resolution
    player.stream.videoParams.listen((params) {
      if (!mounted) return;
      if (params.w != null && params.h != null && params.h! > 0) {
        _updateVideoStats('${params.w}x${params.h}');
      }
    });

    _startPlayback();
  }

  void _updateVideoStats(String resolution) async {
    // Query MPV native properties for FPS and codec
    String fps = '';
    String codec = '';
    try {
      final fpsVal = await (player.platform as dynamic).getProperty('estimated-vf-fps');
      if (fpsVal != null) {
        final fpsNum = double.tryParse(fpsVal.toString());
        if (fpsNum != null && fpsNum > 0) {
          fps = '${fpsNum.round()} fps';
        }
      }
    } catch (_) {}

    try {
      final codecVal = await (player.platform as dynamic).getProperty('video-codec');
      if (codecVal != null && codecVal.toString().isNotEmpty) {
        codec = codecVal.toString().split(' ').first; // e.g. "h264" or "hevc"
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      final parts = <String>[resolution];
      if (codec.isNotEmpty) parts.add(codec);
      if (fps.isNotEmpty) parts.add(fps);
      _videoStats = parts.join(' | ');
    });
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    final appState = Provider.of<AppState>(context, listen: false);
    final client = appState.client;
    if (client == null) return;

    // Send heartbeat every 30 seconds
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      client.keepAlive();
    });
  }

  Future<void> _startPlayback() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _videoStats = '';
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final client = appState.client!;
      
      String streamUrl = await client.getStreamUrl(
        widget.type,
        _currentItem.cmd,
        episodeNum: widget.episodeNum,
      );

      if (streamUrl.isEmpty || !streamUrl.startsWith('http')) {
        throw Exception('Could not resolve stream URL for: ${_currentItem.title}');
      }

      await player.open(Media(streamUrl));
      _startKeepAlive();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _playNext() {
    if (widget.playlist == null || widget.playlist!.isEmpty) return;
    if (_currentIndex < widget.playlist!.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0;
    }
    _currentItem = widget.playlist![_currentIndex];
    _startPlayback();
  }

  void _playPrevious() {
    if (widget.playlist == null || widget.playlist!.isEmpty) return;
    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = widget.playlist!.length - 1;
    }
    _currentItem = widget.playlist![_currentIndex];
    _startPlayback();
  }

  void _toggleFit() {
    setState(() {
      if (_currentFit == BoxFit.contain) {
        _currentFit = BoxFit.cover;
      } else if (_currentFit == BoxFit.cover) {
        _currentFit = BoxFit.fill;
      } else {
        _currentFit = BoxFit.contain;
      }
    });
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  Widget _buildFixedStats() {
    if (_videoStats.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 64,
      left: 16,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Text(
            _videoStats,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _showTracksDialog(String title, List<dynamic> tracks, Function(dynamic) onSelect, dynamic currentTrack) {
    showDialog(
      context: _scaffoldKey.currentContext ?? context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: tracks.map((track) {
              final isSelected = track == currentTrack;
              String label = track.id == 'no' || track.id == 'auto' ? track.id.toString().toUpperCase() : (track.language ?? track.title ?? track.id ?? 'Unknown');
              return ListTile(
                title: Text(label, style: TextStyle(color: isSelected ? Colors.deepPurpleAccent : Colors.white)),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.deepPurpleAccent) : null,
                onTap: () {
                  onSelect(track);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = MaterialVideoControlsThemeData(
      volumeGesture: true,
      brightnessGesture: true,
      seekGesture: true,
      bottomButtonBarMargin: const EdgeInsets.only(bottom: 56, left: 16, right: 16),
      topButtonBarMargin: const EdgeInsets.only(top: 16, left: 16, right: 16),
      seekBarMargin: const EdgeInsets.only(bottom: 52, left: 16, right: 16),
      topButtonBar: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text(
            _currentItem.title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.audiotrack, color: Colors.white),
          onPressed: () {
            _showTracksDialog('Audio Tracks', player.state.tracks.audio, (track) => player.setAudioTrack(track), player.state.track.audio);
          },
        ),
        IconButton(
          icon: const Icon(Icons.subtitles, color: Colors.white),
          onPressed: () {
            _showTracksDialog('Subtitles', player.state.tracks.subtitle, (track) => player.setSubtitleTrack(track), player.state.track.subtitle);
          },
        ),
        if (widget.playlist != null)
          IconButton(
            icon: const Icon(Icons.format_list_bulleted, color: Colors.white, size: 28),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
      ],
      primaryButtonBar: [
        const Spacer(flex: 2),
        if (widget.playlist != null)
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white),
            iconSize: 48,
            onPressed: _playPrevious,
          ),
        const Spacer(),
        const MaterialPlayOrPauseButton(iconSize: 64),
        const Spacer(),
        if (widget.playlist != null)
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white),
            iconSize: 48,
            onPressed: _playNext,
          ),
        const Spacer(flex: 2),
      ],
      bottomButtonBar: [
        const MaterialPositionIndicator(),
        const Spacer(),
        // PIP Mode
        IconButton(
          icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
          onPressed: () async {
            final isPipAvailable = await SimplePip.isPipAvailable;
            if (isPipAvailable) {
              SimplePip().enterPipMode();
            } else {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIP not supported on this device')));
            }
          },
        ),
        // Fit Screen Mode
        IconButton(
          icon: Icon(
            _currentFit == BoxFit.contain ? Icons.fit_screen :
            _currentFit == BoxFit.cover ? Icons.crop_free : Icons.fullscreen_exit, 
            color: Colors.white
          ),
          onPressed: _toggleFit,
        ),
        const MaterialFullscreenButton(),
      ],
    );

    return PipWidget(
      pipBuilder: (context) {
        return Scaffold(
           backgroundColor: Colors.black,
           body: Video(
             controller: controller,
             fit: BoxFit.contain,
             controls: NoVideoControls,
           ),
        );
      },
      builder: (context) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.black,
          endDrawer: _buildChannelsDrawer(),
          body: SafeArea(
            child: _isLoading 
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : Stack(
                        children: [
                          MaterialVideoControlsTheme(
                            normal: customTheme,
                            fullscreen: customTheme,
                            child: Video(
                              controller: controller,
                              fit: _currentFit,
                            ),
                          ),
                          _buildFixedStats(),
                        ],
                      ),
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Loading ${_currentItem.title}...', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startPlayback,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            )
          ],
        ),
      ),
    );
  }

  Widget? _buildChannelsDrawer() {
    if (widget.playlist == null) return null;
    return Drawer(
      backgroundColor: Colors.grey[900],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Text(
                widget.type == 'vod' ? 'Episodes' : 'Channels',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.playlist!.length,
              itemBuilder: (context, index) {
                final item = widget.playlist![index];
                final isSelected = index == _currentIndex;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Colors.deepPurple.withValues(alpha: 0.3),
                  leading: Icon(widget.type == 'vod' ? Icons.play_circle : Icons.live_tv, color: Colors.white70),
                  title: Text(item.title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentIndex = index;
                      _currentItem = item;
                    });
                    _startPlayback();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
