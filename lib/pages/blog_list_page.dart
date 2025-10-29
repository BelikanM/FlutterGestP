import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../blog_service.dart';
import '../widgets/background_pattern.dart';
import 'blog_editor_page.dart';
import 'blog_detail_page.dart';

class BlogListPage extends StatefulWidget {
  const BlogListPage({super.key});

  @override
  BlogListPageState createState() => BlogListPageState();
}

class BlogListPageState extends State<BlogListPage> {
  final BlogService _blogService = BlogService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Helper pour obtenir l'URL du serveur selon la plateforme
  String get _serverBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }
  
  String? _token;
  List<dynamic> _articles = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadToken();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreArticles();
      }
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (_token != null) {
      await _fetchArticles();
    }
  }

  Future<void> _fetchArticles({bool forceRefresh = false}) async {
    if (_token == null) return;
    
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMoreData = true;
    });
    
    try {
      final articles = await _blogService.getArticles(
        _token!, 
        page: 1, 
        limit: _pageSize, 
        forceRefresh: forceRefresh
      );
      debugPrint('� Received ${articles.length} articles');
      
      if (mounted) {
        setState(() {
          _articles = articles;
          _hasMoreData = articles.length == _pageSize; // S'il y a moins d'articles que la taille de page, pas plus de données
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching articles: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _searchArticles(String query) async {
    if (_token == null || query.isEmpty) {
      await _fetchArticles();
      return;
    }
    
    setState(() => _isSearching = true);
    try {
      final articles = await _blogService.searchArticles(_token!, query);
      if (mounted) {
        setState(() {
          _articles = articles;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de recherche: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteArticle(String articleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'article'),
        content: const Text('Cette action est irréversible. Continuer ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && _token != null) {
      try {
        await _blogService.deleteArticle(_token!, articleId);
        await _fetchArticles(); // Rafraîchir la liste
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Article supprimé !'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildArticleCard(Map<String, dynamic> article) {
    debugPrint('🔍 Building card for article: ${article['_id']}');
    debugPrint('📅 CreatedAt value: ${article['createdAt']}, type: ${article['createdAt'].runtimeType}');
    
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(article['createdAt']?.toString() ?? DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ Error parsing date: $e');
      createdAt = DateTime.now();
    }
    final String formattedDate = DateFormat('dd/MM/yyyy à HH:mm').format(createdAt);
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlogDetailPage(articleId: article['_id']?.toString() ?? ''),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec titre et actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              (article['published'] == true) ? Icons.visibility : Icons.visibility_off,
                              size: 16,
                              color: (article['published'] == true) ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (article['published'] == true) ? 'Publié' : 'Brouillon',
                              style: TextStyle(
                                fontSize: 12,
                                color: (article['published'] == true) ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article['title']?.toString() ?? 'Sans titre',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BlogEditorPage(article: article),
                            ),
                          ).then((_) => _fetchArticles());
                          break;
                        case 'delete':
                          _deleteArticle(article['_id']?.toString() ?? '');
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Modifier'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Supprimer', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Résumé
            if (article['summary'] != null && article['summary'].toString().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  article['summary']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Tags
            if (article['tags'] != null && (article['tags'] as List).isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (article['tags'] as List).map<Widget>((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E7D32).withAlpha(102)),
                    ),
                    child: Text(
                      tag.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Aperçu des médias avec design moderne
            if (article['mediaFiles'] != null && (article['mediaFiles'] as List).isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withAlpha(13),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF2E7D32).withAlpha(51),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.photo_library_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(article['mediaFiles'] as List).length} image${(article['mediaFiles'] as List).length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((article['mediaFiles'] as List).length > 3) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${(article['mediaFiles'] as List).length - 3}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (article['mediaFiles'] as List).length > 3 ? 3 : (article['mediaFiles'] as List).length,
                        itemBuilder: (context, index) {
                          final mediaItem = (article['mediaFiles'] as List)[index];
                          
                          // Extraction de l'URL de l'image comme dans le détail
                          String mediaUrl;
                          if (mediaItem is String) {
                            mediaUrl = mediaItem;
                          } else if (mediaItem is Map) {
                            mediaUrl = mediaItem['url']?.toString() ?? '';
                          } else {
                            mediaUrl = mediaItem.toString();
                          }
                          
                          debugPrint('🔍 Preview image $index: $mediaUrl');
                          
                          return Container(
                            margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 90,
                                  height: 70,
                                  child: _buildPreviewImage(mediaUrl),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Contenu preview (HTML tronqué)
            if (article['content'] != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTruncatedHtmlContent(article['content']?.toString() ?? ''),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackgroundPattern(
      backgroundColor: const Color(0xFF121212),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Blog Entreprise'),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BlogEditorPage()),
            ).then((_) => _fetchArticles()),
          ),
          // Bouton pour créer des articles de test
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'seed' && _token != null) {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                try {
                  await _blogService.createSeedData(_token!);
                  await _fetchArticles();
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Articles de test créés avec images !'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else if (value == 'refresh') {
                _fetchArticles();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('Actualiser'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'seed',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Créer articles test', style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher des articles...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _fetchArticles();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFE8F5E8),
              ),
              onSubmitted: _searchArticles,
            ),
          ),

          // Liste des articles
          Expanded(
            child: _isLoading || _isSearching
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
                : _articles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.article, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun article trouvé',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const BlogEditorPage()),
                              ).then((_) => _fetchArticles()),
                              icon: const Icon(Icons.add),
                              label: const Text('Créer le premier article'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchArticles,
                        color: const Color(0xFF2E7D32),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _articles.length,
                          itemBuilder: (context, index) => _buildArticleCard(_articles[index]),
                        ),
                      ),
          ),
        ],
      ),
    ), // Fermeture du Scaffold
    ); // Fermeture AnimatedBackgroundPattern
  } // Fermeture méthode build

  Future<void> _loadMoreArticles() async {
    if (_token == null || _isLoadingMore || !_hasMoreData) return;
    
    setState(() => _isLoadingMore = true);
    try {
      _currentPage++;
      final moreArticles = await _blogService.getArticles(_token!, page: _currentPage, limit: _pageSize);
      
      if (mounted) {
        setState(() {
          if (moreArticles.isEmpty) {
            _hasMoreData = false;
          } else {
            _articles.addAll(moreArticles);
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _currentPage--; // Revenir à la page précédente en cas d'erreur
        });
      }
    }
  }

  /// Widget pour afficher un aperçu des médias dans la liste
  Widget _buildPreviewImage(String imageData) {
    try {
      // Vérifier si c'est une URL base64 (data:image/...)
      if (imageData.startsWith('data:image/')) {
        final base64String = imageData.split(',').last;
        final bytes = base64.decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Error loading base64 preview: $error');
            return _buildPreviewError();
          },
        );
      }
      // Vérifier si c'est une URL HTTP complète
      else if (imageData.startsWith('http')) {
        return Image.network(
          imageData,
          fit: BoxFit.cover,
          // Cache réseau optimisé
          cacheWidth: 200, // Limite la résolution en cache
          cacheHeight: 150,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Error loading network preview: $imageData - $error');
            return _buildPreviewError();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[50],
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: const Color(0xFF2E7D32),
                    strokeWidth: 2,
                  ),
                ),
              ),
            );
          },
        );
      }
      // Sinon, essayer comme URL relative du serveur
      else {
        final serverUrl = imageData.startsWith('/') ? '$_serverBaseUrl$imageData' : '$_serverBaseUrl/$imageData';
        return Image.network(
          serverUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Error loading server preview: $serverUrl - $error');
            return _buildPreviewError();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[100],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2E7D32),
                  strokeWidth: 2,
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error processing preview image: $e');
      return _buildPreviewError();
    }
  }

  /// Widget d'erreur pour l'aperçu des médias
  Widget _buildPreviewError() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(
        Icons.broken_image,
        color: Colors.grey,
        size: 24,
      ),
    );
  }

  /// Widget pour afficher un aperçu tronqué du contenu HTML
  Widget _buildTruncatedHtmlContent(String htmlContent) {
    // Convertir le HTML en texte brut pour la prévisualisation
    String plainText = _htmlToPlainText(htmlContent);

    // Tronquer le texte à environ 150 caractères
    const int maxLength = 150;
    String truncatedText = plainText.length > maxLength
        ? '${plainText.substring(0, maxLength)}...'
        : plainText;

    return Text(
      truncatedText,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[800],
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Convertit un contenu HTML en texte brut
  String _htmlToPlainText(String html) {
    // Supprimer les balises HTML de base
    String text = html
        .replaceAll(RegExp(r'<[^>]*>'), '') // Supprimer toutes les balises
        .replaceAll('&nbsp;', ' ') // Remplacer les espaces insécables
        .replaceAll('&amp;', '&') // Remplacer les &
        .replaceAll('&lt;', '<') // Remplacer les <
        .replaceAll('&gt;', '>') // Remplacer les >
        .replaceAll('&quot;', '"') // Remplacer les guillemets
        .replaceAll('&apos;', "'") // Remplacer les apostrophes
        .replaceAll(RegExp(r'\s+'), ' ') // Normaliser les espaces
        .trim();

    return text;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}