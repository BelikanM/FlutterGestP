import 'package:flutter/material.dart';
import '../services/public_feed_service.dart';
import '../services/media_player_service.dart';
import '../models/feed_models.dart';

class PublicDashboardWidget extends StatefulWidget {
  const PublicDashboardWidget({super.key});

  @override
  State<PublicDashboardWidget> createState() => _PublicDashboardWidgetState();
}

class _PublicDashboardWidgetState extends State<PublicDashboardWidget>
    with AutomaticKeepAliveClientMixin {
  
  // État du widget
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Données du feed
  List<FeedItem> _feedItems = [];
  int _currentPage = 1;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  
  // Recherche et filtres
  final TextEditingController _searchController = TextEditingController();
  String _currentSearch = '';
  String _selectedFilter = 'all'; // all, articles, medias
  
  // Contrôleurs
  late ScrollController _scrollController;
  
  // Statistiques
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // Chargement initial des données
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      debugPrint('🚀 Chargement initial du dashboard public...');
      
      final result = await PublicFeedService.getPublicFeed(
        page: 1,
        limit: 20,
        search: _currentSearch.isEmpty ? null : _currentSearch,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final feedData = result['feed'] as List? ?? [];
        final feedItems = feedData
            .map((item) => FeedItem.fromJson(item))
            .toList();

        setState(() {
          _feedItems = feedItems;
          _currentPage = 1;
          _hasMoreData = result['pagination']?['hasMore'] ?? false;
          _stats = result['stats'] ?? {};
          _isLoading = false;
          _hasError = false;
        });

        debugPrint('✅ Données chargées: ${_feedItems.length} éléments');
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = result['error'] ?? 'Erreur inconnue';
          _isLoading = false;
        });
        debugPrint('❌ Erreur chargement: $_errorMessage');
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _hasError = true;
        _errorMessage = 'Erreur de connexion: $e';
        _isLoading = false;
      });
      debugPrint('❌ Exception chargement: $e');
    }
  }

  // Pagination infinie
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreData();
    }
  }

  // Charger plus de données
  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final result = await PublicFeedService.getPublicFeed(
        page: nextPage,
        limit: 20,
        search: _currentSearch.isEmpty ? null : _currentSearch,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final feedData = result['feed'] as List? ?? [];
        final newItems = feedData
            .map((item) => FeedItem.fromJson(item))
            .toList();

        setState(() {
          _feedItems.addAll(newItems);
          _currentPage = nextPage;
          _hasMoreData = result['pagination']?['hasMore'] ?? false;
          _isLoadingMore = false;
        });

        debugPrint('✅ Page $_currentPage chargée: ${newItems.length} nouveaux éléments');
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      debugPrint('❌ Erreur pagination: $e');
    }
  }

  // Recherche
  Future<void> _performSearch(String query) async {
    if (query == _currentSearch) return;

    setState(() {
      _currentSearch = query;
    });

    await _loadInitialData();
  }

  // Filtrer les éléments affichés
  List<FeedItem> get _filteredItems {
    switch (_selectedFilter) {
      case 'articles':
        return _feedItems.where((item) => item.type == 'article').toList();
      case 'medias':
        return _feedItems.where((item) => item.type == 'media').toList();
      default:
        return _feedItems;
    }
  }

  // Rafraîchir les données
  Future<void> _refreshData() async {
    PublicFeedService.clearCache();
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      body: Column(
        children: [
          // Header avec recherche et filtres
          _buildHeader(),
          
          // Statistiques
          if (_stats.isNotEmpty) _buildStats(),
          
          // Contenu principal
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  // Header avec barre de recherche et filtres
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher des articles ou médias...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onSubmitted: _performSearch,
          ),
          
          const SizedBox(height: 12),
          
          // Filtres
          Row(
            children: [
              _buildFilterChip('all', 'Tout', Icons.dashboard),
              const SizedBox(width: 8),
              _buildFilterChip('articles', 'Articles', Icons.article),
              const SizedBox(width: 8),
              _buildFilterChip('medias', 'Médias', Icons.perm_media),
              
              const Spacer(),
              
              // Bouton rafraîchir
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading ? null : _refreshData,
                tooltip: 'Rafraîchir',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Puce de filtre
  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[700],
    );
  }

  // Statistiques
  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildStatChip('Articles', _stats['articles']?.toString() ?? '0', Colors.blue),
          const SizedBox(width: 12),
          _buildStatChip('Médias', _stats['medias']?.toString() ?? '0', Colors.green),
          const SizedBox(width: 12),
          _buildStatChip('Total', _stats['total']?.toString() ?? '0', Colors.orange),
        ],
      ),
    );
  }

  // Puce de statistique
  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Contenu principal
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement du contenu public...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final filteredItems = _filteredItems;

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _currentSearch.isEmpty 
                  ? 'Aucun contenu disponible'
                  : 'Aucun résultat pour "$_currentSearch"',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _currentSearch.isEmpty
                  ? 'Il n\'y a pas encore de contenu publié'
                  : 'Essayez avec d\'autres mots-clés',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: filteredItems.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= filteredItems.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final item = filteredItems[index];
          return _buildFeedCard(item);
        },
      ),
    );
  }

  // Carte d'un élément du feed avec média intégré
  Widget _buildFeedCard(FeedItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec avatar et info auteur
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    item.type == 'article' ? Colors.blue[50]! : Colors.green[50]!,
                    Colors.white,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Avatar de l'auteur
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: item.type == 'article' ? Colors.blue : Colors.green,
                    child: Text(
                      item.author.name.isNotEmpty 
                          ? item.author.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              item.type == 'article' ? Icons.article_outlined : _getMediaIcon(item.mimetype),
                              size: 16,
                              color: item.type == 'article' ? Colors.blue : Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.type == 'article' ? 'Article' : _getMediaTypeLabel(item.mimetype),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: item.type == 'article' ? Colors.blue : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          item.author.name.isNotEmpty ? item.author.name : 'Utilisateur',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatDate(item.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge du type de contenu
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.type == 'article' ? Colors.blue[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: item.type == 'article' ? Colors.blue[700] : Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenu principal
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),

                  // Description
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Contenu média pour les médias
                  if (item.type == 'media' && item.url != null) ...[
                    const SizedBox(height: 12),
                    _buildMediaWidget(item),
                  ],

                  // Contenu article avec médias attachés
                  if (item.type == 'article' && item.mediaFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildArticleMedias(item.mediaFiles),
                  ],

                  // Tags
                  if (item.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: item.tags.take(6).map((tag) => 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.grey[200]!, Colors.grey[100]!],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        )
                      ).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Footer avec statistiques et actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  // Statistiques d'interaction
                  if (item.likesCount > 0) ...[
                    _buildInteractionChip(
                      Icons.favorite,
                      '${item.likesCount}',
                      Colors.red,
                      'J\'aime',
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (item.commentsCount > 0) ...[
                    _buildInteractionChip(
                      Icons.chat_bubble_outline,
                      '${item.commentsCount}',
                      Colors.blue,
                      'Commentaires',
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (item.viewsCount > 0) ...[
                    _buildInteractionChip(
                      Icons.visibility_outlined,
                      '${item.viewsCount}',
                      Colors.grey,
                      'Vues',
                    ),
                  ],
                  
                  const Spacer(),
                  
                  // Bouton partager
                  IconButton(
                    onPressed: () => _shareContent(item),
                    icon: Icon(Icons.share_outlined, color: Colors.grey[600]),
                    tooltip: 'Partager',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour afficher un média (image, vidéo, audio)
  Widget _buildMediaWidget(FeedItem item) {
    if (item.url == null || item.mimetype == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Média non disponible'),
            ],
          ),
        ),
      );
    }

    final mimeType = item.mimetype!.toLowerCase();
    
    if (mimeType.startsWith('image/')) {
      return _buildImageWidget(item.url!);
    } else if (mimeType.startsWith('video/')) {
      return _buildVideoWidget(item.url!);
    } else if (mimeType.startsWith('audio/')) {
      return _buildAudioWidget(item.url!, item.title);
    } else {
      return _buildFileWidget(item.url!, item.title, mimeType);
    }
  }

  // Widget image avec zoom
  Widget _buildImageWidget(String url) {
    return MediaPlayerService.buildImageWidget(url, heroTag: 'image_$url');
  }

  // Widget vidéo avec lecteur
  Widget _buildVideoWidget(String url) {
    return MediaPlayerService.buildVideoWidget(url);
  }

  // Widget audio avec lecteur
  Widget _buildAudioWidget(String url, String title) {
    return MediaPlayerService.buildAudioWidget(url, title);
  }

  // Widget pour fichiers génériques
  Widget _buildFileWidget(String url, String title, String mimeType) {
    final fileIcon = _getFileIcon(mimeType);
    final fileColor = _getFileColor(mimeType);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [fileColor.withValues(alpha: 0.1), Colors.white],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fileColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: fileColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              fileIcon,
              size: 24,
              color: fileColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getFileTypeLabel(mimeType),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fileColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'FICHIER',
              style: TextStyle(
                color: fileColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour médias d'articles
  Widget _buildArticleMedias(List<MediaFile> mediaFiles) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mediaFiles.length,
        itemBuilder: (context, index) {
          final media = mediaFiles[index];
          return Container(
            width: 120,
            margin: EdgeInsets.only(right: index < mediaFiles.length - 1 ? 8 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  // Miniature
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey[200],
                    child: Image.network(
                      media.url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          _getMediaIconByType(media.type),
                          size: 32,
                          color: Colors.grey,
                        );
                      },
                    ),
                  ),
                  // Overlay avec type
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                        ),
                      ),
                      child: Text(
                        _getMediaTypeLabelByType(media.type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Puce d'interaction améliorée
  Widget _buildInteractionChip(IconData icon, String value, Color color, String label) {
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Obtenir l'icône selon le type de fichier MediaFile
  IconData _getMediaIconByType(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      case 'document':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Obtenir le label du type de média selon le type MediaFile
  String _getMediaTypeLabelByType(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return 'Image';
      case 'video':
        return 'Vidéo';
      case 'audio':
        return 'Audio';
      case 'document':
        return 'Document';
      default:
        return 'Fichier';
    }
  }

  // Obtenir la couleur selon le type de fichier
  Color _getFileColor(String mimeType) {
    final type = mimeType.toLowerCase();
    if (type.contains('pdf')) return Colors.red;
    if (type.contains('document') || type.contains('word')) return Colors.blue;
    if (type.contains('spreadsheet') || type.contains('excel')) return Colors.green;
    if (type.contains('presentation') || type.contains('powerpoint')) return Colors.orange;
    if (type.contains('archive') || type.contains('zip')) return Colors.purple;
    if (type.startsWith('image/')) return Colors.pink;
    if (type.startsWith('video/')) return Colors.indigo;
    if (type.startsWith('audio/')) return Colors.teal;
    return Colors.grey;
  }

  // Obtenir le label du type de fichier
  String _getFileTypeLabel(String mimeType) {
    final type = mimeType.toLowerCase();
    if (type.contains('pdf')) return 'Document PDF';
    if (type.contains('document') || type.contains('word')) return 'Document Word';
    if (type.contains('spreadsheet') || type.contains('excel')) return 'Feuille Excel';
    if (type.contains('presentation') || type.contains('powerpoint')) return 'Présentation';
    if (type.contains('archive') || type.contains('zip')) return 'Archive';
    if (type.startsWith('image/')) return 'Image';
    if (type.startsWith('video/')) return 'Vidéo';
    if (type.startsWith('audio/')) return 'Audio';
    return 'Fichier';
  }

  // Obtenir l'icône selon le type de média
  IconData _getMediaIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
    
    final type = mimeType.toLowerCase();
    if (type.startsWith('image/')) return Icons.image;
    if (type.startsWith('video/')) return Icons.videocam;
    if (type.startsWith('audio/')) return Icons.audiotrack;
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('document') || type.contains('word')) return Icons.description;
    if (type.contains('spreadsheet') || type.contains('excel')) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  // Obtenir le label du type de média
  String _getMediaTypeLabel(String? mimeType) {
    if (mimeType == null) return 'Fichier';
    
    final type = mimeType.toLowerCase();
    if (type.startsWith('image/')) return 'Image';
    if (type.startsWith('video/')) return 'Vidéo';
    if (type.startsWith('audio/')) return 'Audio';
    if (type.contains('pdf')) return 'PDF';
    if (type.contains('document') || type.contains('word')) return 'Document';
    if (type.contains('spreadsheet') || type.contains('excel')) return 'Tableur';
    return 'Fichier';
  }

  // Obtenir l'icône de fichier
  IconData _getFileIcon(String mimeType) {
    final type = mimeType.toLowerCase();
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('document') || type.contains('word')) return Icons.description;
    if (type.contains('spreadsheet') || type.contains('excel')) return Icons.table_chart;
    if (type.contains('presentation') || type.contains('powerpoint')) return Icons.slideshow;
    if (type.contains('archive') || type.contains('zip')) return Icons.archive;
    return Icons.insert_drive_file;
  }

  // Actions des médias - Supprimé car on affiche tout inline

  void _shareContent(FeedItem item) {
    final shareText = '${item.title}\n\n${item.description ?? ""}\n\n${item.url ?? ""}';
    MediaPlayerService.shareContent(shareText, subject: item.title);
  }

  // Formater la date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}j';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'maintenant';
    }
  }
}