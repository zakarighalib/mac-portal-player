import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/content_item.dart';
import '../providers/app_state.dart';
import '../utils/playback_helper.dart';

class MovieDetailScreen extends StatelessWidget {
  final ContentItem movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<AppState>(context, listen: false).client!;
    final coverUrl = client.resolveImageUrl(movie.logoUrl);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          // Large Poster Header
          SliverAppBar(
            expandedHeight: 400.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.movie, size: 80, color: Colors.white54),
                    )
                  else
                    Container(color: Colors.grey[900], child: const Icon(Icons.movie, size: 80, color: Colors.white54)),
                  
                  // Gradient overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF121212)],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Details List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    movie.title,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Metadata row (Year, Rating)
                  Row(
                    children: [
                      if (movie.year != null && movie.year!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                          child: Text(movie.year!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (movie.rating != null && movie.rating!.isNotEmpty) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(movie.rating!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Play Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => PlaybackHelper.playContent(context, movie, 'vod'),
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text('PLAY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Description
                  if (movie.description != null && movie.description!.isNotEmpty) ...[
                    const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(
                      movie.description!,
                      style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Director & Cast
                  if (movie.director != null && movie.director!.isNotEmpty) ...[
                    _buildMetaRow('Director', movie.director!),
                    const SizedBox(height: 12),
                  ],
                  if (movie.actors != null && movie.actors!.isNotEmpty) ...[
                    _buildMetaRow('Cast', movie.actors!),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
