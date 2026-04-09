import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_item.dart';
import '../providers/app_state.dart';
import '../utils/playback_helper.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';

class ContentListScreen extends StatefulWidget {
  final String type; // 'itv', 'vod', 'series'
  final String categoryId;
  final String categoryTitle;

  const ContentListScreen({
    super.key, 
    required this.type, 
    required this.categoryId, 
    required this.categoryTitle
  });

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  List<ContentItem> _allChannelsCache = [];
  List<ContentItem> _filteredContent = [];
  List<String> _regions = [];
  String? _selectedRegion;
  bool _isBackgroundLoading = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchContent();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  void _onSearchChanged() {
    _currentPage = 1;
    _hasMore = true;
    _fetchContent(searchQuery: _searchController.text);
  }

  void _applyLocalFilter(String query) {
    if (!mounted) return;
    setState(() {
      _extractRegions();

      var temp = List<ContentItem>.from(_allChannelsCache);

      // Apply Region Filter
      if (_selectedRegion != null && _selectedRegion!.isNotEmpty) {
        temp = temp.where((item) {
           final prefixMatches = item.title.toUpperCase().startsWith('$_selectedRegion') || 
                                 item.title.toUpperCase().contains('| $_selectedRegion');
           return prefixMatches;
        }).toList();
      }

      // Apply Search Filter
      if (query.isNotEmpty) {
        final lowerQuery = query.toLowerCase();
        temp = temp.where((item) => item.title.toLowerCase().contains(lowerQuery)).toList();
      }

      _filteredContent = temp;
      _isLoading = false;
      _hasMore = false; // Handled locally, no pagination needed for GridView
    });
  }

  void _extractRegions() {
    if (widget.type != 'itv') return;
    final Set<String> uniqueRegions = {};
    for (var item in _allChannelsCache) {
      // Common formats: "UK | BBC" or "IR: Channel" or "| US | Fox"
      final parts = item.title.split(RegExp(r'[:|]'));
      if (parts.isNotEmpty) {
         final firstPart = parts[0].trim().toUpperCase();
         final secondPart = parts.length > 1 ? parts[1].trim().toUpperCase() : '';
         
         // Extract 2-3 letter codes
         if (firstPart.length >= 2 && firstPart.length <= 4) {
           uniqueRegions.add(firstPart);
         } else if (secondPart.length >= 2 && secondPart.length <= 4 && parts[0].trim().isEmpty) {
           uniqueRegions.add(secondPart);
         }
      }
    }
    _regions = uniqueRegions.toList()..sort();
  }

  Future<void> _loadAllChannelsInBackground() async {
    if (!mounted) return;
    setState(() {
      _isBackgroundLoading = true;
      _isLoading = true;
      _error = null;
    });

    int page = 1;
    bool hasMore = true;
    final client = Provider.of<AppState>(context, listen: false).client!;

    try {
      while (hasMore && mounted) {
        // Fetch 5 pages concurrently to massively speed up channel gathering
        final futures = <Future<List<dynamic>>>[];
        for (int i = 0; i < 5; i++) {
          futures.add(client.getContent(widget.type, widget.categoryId, page: page + i).catchError((_) => []));
        }
        
        final results = await Future.wait(futures);
        
        bool batchHasData = false;
        final newItems = <ContentItem>[];
        for (final rawData in results) {
          final items = rawData.whereType<Map>().map((e) => ContentItem.fromJson(Map<String, dynamic>.from(e))).toList();
          if (items.isNotEmpty) {
            batchHasData = true;
            newItems.addAll(items);
          }
          if (items.length < 14) {
            hasMore = false;
          }
        }

        if (newItems.isNotEmpty) {
          _allChannelsCache.addAll(newItems);
          if (mounted) _applyLocalFilter(_searchController.text);
        }

        if (!batchHasData) hasMore = false;
        page += 5;
      }
    } catch (e) {
      if (mounted && _allChannelsCache.isEmpty) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackgroundLoading = false;
          // Background loader retrieved everything
          _hasMore = false; 
        });
      }
    }
  }

  Future<void> _fetchContent({String searchQuery = ''}) async {
    if (widget.type == 'itv') {
      if (_allChannelsCache.isNotEmpty) {
        _applyLocalFilter(searchQuery);
        return;
      }
      if (!_isBackgroundLoading) {
        _loadAllChannelsInBackground();
      }
      return;
    }

    // Normal API fetching for VOD / Series
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
    });

    try {
      final client = Provider.of<AppState>(context, listen: false).client!;
      final rawData = await client.getContent(
        widget.type, 
        widget.categoryId, 
        search: searchQuery,
        page: _currentPage,
      );
      final items = rawData
          .whereType<Map>()
          .map((e) => ContentItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      
      if (mounted) {
        setState(() {
          _filteredContent = items;
          _isLoading = false;
          _hasMore = items.length >= 14; 
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

  Future<void> _loadMore() async {
    if (widget.type == 'itv') return; // Handled by background loader bypassing pagination
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;

    try {
      final client = Provider.of<AppState>(context, listen: false).client!;
      final rawData = await client.getContent(
        widget.type,
        widget.categoryId,
        search: _searchController.text,
        page: _currentPage,
      );
      final newItems = rawData
          .whereType<Map>()
          .map((e) => ContentItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (mounted) {
        setState(() {
          _filteredContent.addAll(newItems);
          _isLoadingMore = false;
          _hasMore = newItems.length >= 14;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more: $e')),
        );
      }
    }
  }

  void _onItemTapped(ContentItem item) {
    if (widget.type == 'series') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(
            seriesItem: item,
          ),
        ),
      );
    } else if (widget.type == 'vod') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(movie: item),
        ),
      );
    } else {
      // Live channels
      PlaybackHelper.playContent(
        context, 
        item, 
        widget.type,
        playlist: widget.type == 'itv' ? _filteredContent : null,
        initialIndex: widget.type == 'itv' ? _filteredContent.indexOf(item) : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
            ),
          ),
          if (widget.type == 'itv' && _regions.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _regions.length + 1,
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final region = isAll ? 'ALL' : _regions[index - 1];
                  final isSelected = isAll ? _selectedRegion == null : _selectedRegion == region;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(region),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedRegion = isAll ? null : region;
                          _applyLocalFilter(_searchController.text);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
       return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }
    if (_filteredContent.isEmpty) return const Center(child: Text('No content found.'));

    return Stack(
      children: [
        GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
      itemCount: _filteredContent.length,
      itemBuilder: (context, index) {
        final item = _filteredContent[index];
        final client = Provider.of<AppState>(context, listen: false).client!;
        final resolvedLogo = client.resolveImageUrl(item.logoUrl);

        return InkWell(
          onTap: () => _onItemTapped(item),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: resolvedLogo.isNotEmpty
                    ? Container(
                        color: Colors.white, // White screen background behind logo
                        child: CachedNetworkImage(
                          imageUrl: resolvedLogo,
                          fit: BoxFit.contain, // Changed to contain fit
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, size: 50, color: Colors.black54),
                        ),
                      )
                    : Container(
                        color: Colors.white,
                        child: const Icon(Icons.image_not_supported, size: 50, color: Colors.black54),
                    ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black87,
                  child: Row(
                     children: [
                        Expanded(
                           child: Text(
                             item.title,
                             style: const TextStyle(fontWeight: FontWeight.bold),
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                           ),
                        ),
                        Icon(
                          widget.type == 'series' ? Icons.list : Icons.play_circle_fill,
                          color: Colors.deepPurpleAccent,
                        ),
                     ]
                  ),
                ),
              ],
            ),
          ),
        );
      },
      ),
      if (_isLoadingMore)
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: FloatingActionButton.small(
              onPressed: null,
              backgroundColor: Colors.deepPurpleAccent,
              child: const CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
