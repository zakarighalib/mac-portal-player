import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/series_info.dart';

class MacPortalClient {
  final String serverUrl;
  final String macAddress;
  String? _token;

  MacPortalClient({required this.serverUrl, required this.macAddress});

  String get _baseUrl {
    String url = serverUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    // Most standard MAC portals have the stalker API at /portal.php
    // If user provides a full /stalker_portal/c/ URL, we adapt.
    if (!url.contains('.php')) {
        if (!url.endsWith('/c')) url += '/c';
    }
    return url;
  }
  
  String get _apiUrl {
    if (_baseUrl.contains('portal.php')) return _baseUrl;
    return '${_baseUrl.replaceAll('/c', '')}/server/load.php';
  }

  /// Resolve relative image URLs by prepending the base server URL
  String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    
    // Some Stalker portals return relative paths starting with /
    final base = _baseUrl.replaceAll('/c', '');
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  Map<String, String> get _headers {
    final formattedMac = _formatMac(macAddress);
    final cookieString = 'mac=${Uri.encodeComponent(formattedMac)}; stb_lang=en; timezone=Europe/London';

    final headers = {
      'User-Agent': 'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG254 stbapp ver: 2 rev: 250 Safari/533.3',
      'X-User-Agent': 'Model: MAG254; Link: Ethernet',
      'Referer': _baseUrl,
      'Cookie': cookieString,
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Encoding': 'gzip',
      'Connection': 'Keep-Alive',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  String _formatMac(String mac) {
    final cleaned = mac.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '').toUpperCase();
    final pairs = <String>[];
    for (int i = 0; i < cleaned.length && i < 12; i += 2) {
      pairs.add(cleaned.substring(i, i + 2 > cleaned.length ? cleaned.length : i + 2));
    }
    return pairs.join(':');
  }

  Future<dynamic> _get(Map<String, String> queryParams) async {
    // Add JsHttpRequest param required by Stalker portals
    final params = Map<String, String>.from(queryParams);
    params['JsHttpRequest'] = '1-xml';
    
    final uri = Uri.parse(_apiUrl).replace(queryParameters: params);
    try {
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        try {
           final jsonData = json.decode(response.body);
           return jsonData['js'] ?? jsonData;
        } catch (e) {
           return response.body; 
        }
      } else {
        throw Exception('Failed to load data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<bool> handshake() async {
    try {
      final response = await _get({'type': 'stb', 'action': 'handshake'});
      if (response != null && response is Map && response['token'] != null) {
        _token = response['token'];
        return true;
      }
      return true; // Sometimes handshake isn't strictly necessary
    } catch (e) {
      return false;
    }
  }

  Future<dynamic> getProfile() async {
     return await _get({'type': 'stb', 'action': 'get_profile'});
  }

  Future<List<dynamic>> getCategories(String type) async {
    // type: 'itv' (channels), 'vod' (movies), 'series' (series)
    final action = type == 'itv' ? 'get_genres' : 'get_categories'; 
    final response = await _get({'type': type, 'action': action});
    
    if (response is List) {
      return response;
    } else if (response is Map && response.containsKey('data')) {
      return response['data'] as List<dynamic>;
    }
    return [];
  }
  
  Future<List<dynamic>> getContent(String type, String categoryId, {int page = 1, String search = ''}) async {
    String action = 'get_ordered_list';
    // For live channels, the category param is 'genre', not 'category'
    final categoryParam = type == 'itv' ? 'genre' : 'category';
    final query = {
      'type': type,
      'action': action,
      'p': page.toString(),
    };

    if (categoryId != '*') {
       query[categoryParam] = categoryId;
    }

    if (search.isNotEmpty) {
       query['search'] = search;
    }
    
    final response = await _get(query);
    if (response is Map && response.containsKey('data')) {
      return response['data'] as List<dynamic>;
    } else if (response is List) {
      return response;
    }
    return [];
  }

  /// Fetch seasons and episodes for a series by its ID.
  /// Uses the Stalker portal API: type=series&action=get_ordered_list&movie_id=<id>
  Future<List<Season>> getSeriesInfo(String seriesId) async {
    final response = await _get({
      'type': 'series',
      'action': 'get_ordered_list',
      'movie_id': seriesId,
    });

    final List<dynamic> rows;
    if (response is Map && response.containsKey('data')) {
      rows = response['data'] as List<dynamic>;
    } else if (response is List) {
      rows = response;
    } else {
      return [];
    }

    final List<Season> seasons = [];

    for (final s in rows) {
      if (s is! Map) continue;
      
      final seasonNum = int.tryParse(
        (s['season_number'] ?? s['season'] ?? '1').toString()
      ) ?? 1;
      
      List<Episode> episodes = [];
      final seriesData = s['series'];
      final cmd = s['cmd']?.toString() ?? '';

      if (seriesData is String && seriesData.isNotEmpty) {
        // Comma-separated episode numbers: "1,2,3,4,5"
        episodes = seriesData.split(',').map((num) {
          final epNum = int.tryParse(num.trim()) ?? 0;
          return Episode(
            id: '$seriesId:$seasonNum-$epNum',
            name: 'Episode $epNum',
            episodeNum: epNum,
            seasonNum: seasonNum,
            cmd: cmd,
          );
        }).where((e) => e.episodeNum > 0).toList();
      } else if (seriesData is List) {
        episodes = seriesData.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          if (item is int || item is String) {
            final epNum = int.tryParse(item.toString()) ?? (idx + 1);
            return Episode(
              id: '$seriesId:$seasonNum-$epNum',
              name: 'Episode $epNum',
              episodeNum: epNum,
              seasonNum: seasonNum,
              cmd: cmd,
            );
          } else if (item is Map) {
            final epNum = int.tryParse(
              (item['episode_num'] ?? item['episode'] ?? item['num'] ?? (idx + 1)).toString()
            ) ?? (idx + 1);
            return Episode(
              id: (item['id'] ?? '$seriesId:$seasonNum-$epNum').toString(),
              name: item['title']?.toString() ?? item['name']?.toString() ?? 'Episode $epNum',
              episodeNum: epNum,
              seasonNum: seasonNum,
              cmd: item['cmd']?.toString() ?? cmd,
            );
          }
          return Episode(
            id: '$seriesId:$seasonNum-${idx + 1}',
            name: 'Episode ${idx + 1}',
            episodeNum: idx + 1,
            seasonNum: seasonNum,
            cmd: cmd,
          );
        }).where((e) => e.episodeNum > 0).toList();
      }

      seasons.add(Season(
        id: s['id']?.toString() ?? seasonNum.toString(),
        name: s['name']?.toString() ?? 'Season $seasonNum',
        seasonNumber: seasonNum,
        cmd: cmd,
        episodes: episodes,
      ));
    }

    return seasons;
  }

  /// Get stream URL by calling create_link on the Stalker portal.
  /// Play tokens are one-time use, so always call this fresh before playback.
  /// [episodeNum] is optional, used for series episode playback.
  Future<String> getStreamUrl(String type, String cmd, {int? episodeNum}) async {
    if (type == 'itv') {
      try {
        final uri = Uri.parse(_baseUrl);
        final host = uri.host;
        final port = uri.port > 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);
        final scheme = uri.scheme;
        final token = _token ?? '';
        return '$scheme://$host:$port/play/live.php?mac=$macAddress&stream=$cmd&extension=ts&play_token=$token';
      } catch (e) {
        // Fallback to default if URL parsing fails
      }
    }

    final query = {
      'type': type,
      'action': 'create_link',
      'cmd': cmd,
    };
    if (episodeNum != null) {
      query['series'] = episodeNum.toString();
    }

    final response = await _get(query);
    
    String rawUrl = '';
    if (response is Map) {
      rawUrl = (response['cmd'] ?? response['url'] ?? response['playlist'] ?? '').toString();
    } else if (response is String) {
      rawUrl = response;
    }
    
    // Clean ffmpeg / ffrt prefixes
    rawUrl = rawUrl.replaceFirst(RegExp(r'^(ffmpeg|ffrt\d*)\s+', caseSensitive: false), '').trim();
    
    // Extract first valid http(s) URL from possible space/pipe-separated values
    final candidates = rawUrl.split(RegExp(r'[\s|]+')).where((s) => s.isNotEmpty).toList();
    final httpUrl = candidates.firstWhere(
      (c) => c.startsWith('http://') || c.startsWith('https://'),
      orElse: () => rawUrl.startsWith('http') ? rawUrl : '',
    );
    
    return httpUrl.isNotEmpty ? httpUrl : rawUrl;
  }

  /// Re-authenticate (handshake) to get a fresh token.
  /// Useful for retry logic when stream URLs fail.
  Future<bool> refreshToken() async {
    _token = null;
    return await handshake();
  }

  /// Send a keepalive/watchdog signal to the Stalker portal.
  /// Must be called periodically (every 30-60s) during active playback
  /// to prevent the server from killing the stream.
  Future<void> keepAlive() async {
    try {
      await _get({'type': 'stb', 'action': 'get_profile'});
    } catch (_) {
      // Silently ignore keepalive failures
    }
  }
}
