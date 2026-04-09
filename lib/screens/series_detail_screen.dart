import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/series_info.dart';
import '../models/content_item.dart';
import '../providers/app_state.dart';
import '../utils/playback_helper.dart';

class SeriesDetailScreen extends StatefulWidget {
  final ContentItem seriesItem;

  const SeriesDetailScreen({
    super.key,
    required this.seriesItem,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  List<Season> _seasons = [];
  bool _isLoading = true;
  String? _error;
  int _expandedSeason = -1;

  @override
  void initState() {
    super.initState();
    _fetchSeriesInfo();
  }

  Future<void> _fetchSeriesInfo() async {
    try {
      final client = Provider.of<AppState>(context, listen: false).client!;
      final seasons = await client.getSeriesInfo(widget.seriesItem.id);
      
      if (mounted) {
        setState(() {
          _seasons = seasons;
          _isLoading = false;
          // Auto-expand first season if there's only one
          if (seasons.length == 1) _expandedSeason = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _playEpisode(Episode episode) {
    // Generate a flat playlist of ALL episodes across ALL seasons 
    // to allow smooth "Next Episode" switching within the player
    final List<ContentItem> fullPlaylist = [];
    for (var s in _seasons) {
      for (var ep in s.episodes) {
        fullPlaylist.add(ContentItem(
          id: ep.id,
          title: '${widget.seriesItem.title} - S${s.seasonNumber}E${ep.episodeNum} ${ep.name}',
          cmd: ep.cmd,
        ));
      }
    }

    final tappedItem = fullPlaylist.firstWhere((item) => item.id == episode.id);

    PlaybackHelper.playContent(
      context, 
      tappedItem, 
      'vod', // Series episodes use vod type for create_link
      episodeNum: episode.episodeNum,
      playlist: fullPlaylist,
      initialIndex: fullPlaylist.indexOf(tappedItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.seriesItem.title),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() { _isLoading = true; _error = null; });
                _fetchSeriesInfo();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_seasons.isEmpty) {
      return const Center(child: Text('No seasons found for this series.'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Series header with logo
          if (widget.seriesItem.logoUrl != null && widget.seriesItem.logoUrl!.isNotEmpty)
            Builder(builder: (context) {
              final client = Provider.of<AppState>(context, listen: false).client!;
              final resolvedLogo = client.resolveImageUrl(widget.seriesItem.logoUrl);
              return Container(
                width: double.infinity,
                height: 200,
                color: Colors.black,
                child: CachedNetworkImage(
                  imageUrl: resolvedLogo,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              );
            }),

          if (widget.seriesItem.description != null && widget.seriesItem.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                widget.seriesItem.description!,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ),
          if (widget.seriesItem.actors != null && widget.seriesItem.actors!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Cast: ${widget.seriesItem.actors}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          if (widget.seriesItem.director != null && widget.seriesItem.director!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Director: ${widget.seriesItem.director}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          if (widget.seriesItem.year != null || widget.seriesItem.rating != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                '${widget.seriesItem.year ?? ''} ${widget.seriesItem.rating != null ? '⭐ ${widget.seriesItem.rating}' : ''}'.trim(),
                style: const TextStyle(fontSize: 12, color: Colors.amberAccent),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '${_seasons.length} Season${_seasons.length > 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Seasons list with expandable episodes
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _seasons.length,
            itemBuilder: (context, seasonIndex) {
              final season = _seasons[seasonIndex];
              final isExpanded = _expandedSeason == seasonIndex;

              return Column(
                children: [
                  // Season header
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurpleAccent,
                      child: Text(
                        '${season.seasonNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      season.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      '${season.episodes.length} episode${season.episodes.length != 1 ? 's' : ''}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    trailing: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.deepPurpleAccent,
                    ),
                    onTap: () {
                      setState(() {
                        _expandedSeason = isExpanded ? -1 : seasonIndex;
                      });
                    },
                  ),

                  // Episodes list (expanded)
                  if (isExpanded)
                    Container(
                      color: Colors.grey[900],
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: season.episodes.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey[800],
                        ),
                        itemBuilder: (context, episodeIndex) {
                          final episode = season.episodes[episodeIndex];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[800],
                              child: Text(
                                '${episode.episodeNum}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            title: Text(episode.name),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.play_circle_fill,
                                color: Colors.deepPurpleAccent,
                                size: 36,
                              ),
                              onPressed: () => _playEpisode(episode),
                            ),
                            onTap: () => _playEpisode(episode),
                          );
                        },
                      ),
                    ),

                  Divider(height: 1, color: Colors.grey[800]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
