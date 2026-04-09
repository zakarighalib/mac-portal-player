class ContentItem {
  final String id;
  final String title;
  final String? logoUrl;
  final String cmd; // Command or URL used to fetch stream
  
  // Detail fields
  final String? description;
  final String? director;
  final String? actors;
  final String? year;
  final String? rating;

  ContentItem({
    required this.id, 
    required this.title, 
    this.logoUrl, 
    required this.cmd,
    this.description,
    this.director,
    this.actors,
    this.year,
    this.rating,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      id: json['id']?.toString() ?? '',
      title: json['name'] ?? json['title'] ?? '',
      logoUrl: json['cover_big']?.toString() ?? json['screenshot_uri']?.toString() ?? json['cover']?.toString() ?? json['logo']?.toString() ?? json['pic']?.toString(),
      cmd: json['cmd'] ?? '',
      description: json['description'] ?? json['plot'],
      director: json['director'],
      actors: json['actors'] ?? json['cast'],
      year: json['year']?.toString() ?? json['added']?.toString().split('-').first,
      rating: json['rating']?.toString() ?? json['kinopoisk_rating']?.toString(),
    );
  }
}
