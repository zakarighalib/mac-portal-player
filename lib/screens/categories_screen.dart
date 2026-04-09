import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/app_state.dart';
import 'content_list_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final String type; // 'itv', 'vod', 'series'
  
  const CategoriesScreen({super.key, required this.type});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with AutomaticKeepAliveClientMixin {
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final client = Provider.of<AppState>(context, listen: false).client!;
      final rawData = await client.getCategories(widget.type);
      final cats = rawData.map((e) => Category.fromJson(e)).toList();
      
      if (mounted) {
        setState(() {
          _categories = cats;
          _isLoading = false;
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

  String get _typeLabel {
    switch (widget.type) {
      case 'vod': return 'Movies';
      case 'series': return 'Series';
      case 'itv': return 'Channels';
      default: return 'Content';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Text('Error loading categories: $_error', style: const TextStyle(color: Colors.red)),
             ElevatedButton(
                onPressed: () {
                  setState(() { _isLoading = true; _error = null; });
                  _fetchCategories();
                },
                child: const Text('Retry')
             )
          ]
        ),
      );
    }

    if (_categories.isEmpty) {
      return Center(child: Text('No $_typeLabel categories found.'));
    }

    // Filter out duplicate 'All' categories from API
    final filteredCategories = _categories.where(
        (c) => c.title.toLowerCase() != 'all' && c.id != '*'
    ).toList();

    // Prepend a single "All" category
    final displayCategories = [
      Category(id: '*', title: 'All'),
      ...filteredCategories,
    ];

    return ListView.builder(
      itemCount: displayCategories.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final cat = displayCategories[index];
        return Card(
           child: ListTile(
             title: Text(cat.title, style: const TextStyle(fontWeight: FontWeight.bold)),
             trailing: const Icon(Icons.chevron_right),
             onTap: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (_) => ContentListScreen(
                     type: widget.type,
                     categoryId: cat.id,
                     categoryTitle: cat.title,
                   )
                 )
               );
             },
           )
        );
      },
    );
  }
}
