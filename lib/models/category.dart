class Category {
  final String id;
  final String title;
  
  Category({required this.id, required this.title});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? json['name'] ?? '',
    );
  }
}
