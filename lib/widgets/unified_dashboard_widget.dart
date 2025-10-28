import 'package:flutter/material.dart';
import '../models/feed_models.dart';
import '../services/unified_feed_service.dart';

class UnifiedDashboardWidget extends StatefulWidget {
  const UnifiedDashboardWidget({super.key});

  @override
  State<UnifiedDashboardWidget> createState() => _UnifiedDashboardWidgetState();
}

class _UnifiedDashboardWidgetState extends State<UnifiedDashboardWidget>
    with AutomaticKeepAliveClientMixin {
  
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<FeedItem> _allItems = [];
  final List<FeedItem> _filteredItems = [];
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMoreData = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, articles, medias

  // Statistiques
  int _totalArticles = 0;
  int _totalMedias = 0;
  bool _needsAuth = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    
    // Pré-charger en arrière-plan
    UnifiedFeedService.preloadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && _searchQuery.isEmpty) {
        _loadMoreData();
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterItems();
    });
    
    // Recherche en temps réel
    if (_searchQuery.length > 2) {
      _performQuickSearch();
    }
  }

  void _filterItems() {
    _filteredItems.clear();
    
    var itemsToFilter = _allItems;
    
    // Filtrer par type
    if (_selectedFilter != 'all') {
      itemsToFilter = _allItems.where((item) => item.type == _selectedFilter).toList();
    }
    
    // Filtrer par recherche
    if (_searchQuery.isEmpty) {
      _filteredItems.addAll(itemsToFilter);
    } else {
      _filteredItems.addAll(itemsToFilter.where((item) {
        return item.title.toLowerCase().contains(_searchQuery) ||
               item.displayContent.toLowerCase().contains(_searchQuery) ||
               item.tags.any((tag) => tag.toLowerCase().contains(_searchQuery)) ||
               item.author.displayName.toLowerCase().contains(_searchQuery);
      }));
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _needsAuth = false;
      _currentPage = 1;
    });

    try {
      // Charger le feed unifié et les médias en parallèle
      final feedFuture = UnifiedFeedService.getUnifiedFeed(page: 1, limit: 30);
      final mediasFuture = UnifiedFeedService.getAllMedias(page: 1, limit: 20);
      
      final results = await Future.wait([feedFuture, mediasFuture]);
      final feedResult = results[0];
      final mediasResult = results[1];
      
      if (mounted) {
        // Vérifier si authentification nécessaire
        if (feedResult['needsAuth'] == true || mediasResult['needsAuth'] == true) {
          setState(() {
            _isLoading = false;
            _needsAuth = true;
            _errorMessage = 'Veuillez vous reconnecter';
          });
          return;
        }

        if (feedResult['success'] == true) {
          final feedData = feedResult['feed'] as List<dynamic>;
          final feedItems = feedData.map((item) => FeedItem.fromJson(item)).toList();
          
          // Ajouter les médias additionnels
          if (mediasResult['success'] == true) {
            final mediasData = mediasResult['medias'] as List<dynamic>;
            final mediaItems = mediasData.map((item) => FeedItem.fromJson(item)).toList();
            
            // Éviter les doublons
            final existingIds = feedItems.map((item) => item.id).toSet();
            final newMedias = mediaItems.where((item) => !existingIds.contains(item.id)).toList();
            feedItems.addAll(newMedias);
          }
          
          // Trier par date
          feedItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          setState(() {
            _allItems.clear();
            _allItems.addAll(feedItems);
            _filterItems();
            _isLoading = false;
            _hasMoreData = feedItems.length >= 30;
            
            // Statistiques
            _totalArticles = _allItems.where((item) => item.type == 'article').length;
            _totalMedias = _allItems.where((item) => item.type == 'media').length;
          });
          
          // Afficher un message si les données viennent du cache
          if (feedResult['fromCache'] == true) {
            _showMessage('Données chargées depuis le cache', isError: false);
          }
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = feedResult['error'] ?? 'Erreur inconnue';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Erreur de connexion: $e';
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || _searchQuery.isNotEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await UnifiedFeedService.getUnifiedFeed(
        page: _currentPage + 1, 
        limit: 20
      );
      
      if (mounted && result['success'] == true) {
        final feedData = result['feed'] as List<dynamic>;
        final feedItems = feedData.map((item) => FeedItem.fromJson(item)).toList();
        
        setState(() {
          _allItems.addAll(feedItems);
          _filterItems();
          _currentPage++;
          _isLoadingMore = false;
          _hasMoreData = feedItems.length >= 20;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _performQuickSearch() async {
    try {
      final result = await UnifiedFeedService.quickSearch(_searchQuery);
      
      if (mounted && result['success'] == true) {
        final resultsData = result['results'] as List<dynamic>;
        final searchResults = resultsData.map((item) => FeedItem.fromJson(item)).toList();
        
        setState(() {
          _filteredItems.clear();
          _filteredItems.addAll(searchResults);
        });
      }
    } catch (e) {
      // Garder le filtre local en cas d'erreur
    }
  }

  Future<void> _refreshData() async {
    UnifiedFeedService.clearCache();
    await _loadInitialData();
  }

  Future<void> _handleLike(FeedItem item) async {
    final originalLikesCount = item.likesCount;
    final originalIsLiked = item.isLiked;
    
    // Update optimiste
    setState(() {
      if (item.isLiked) {
        item.likesCount = (item.likesCount - 1).clamp(0, double.infinity).toInt();
        item.isLiked = false;
      } else {
        item.likesCount++;
        item.isLiked = true;
      }
    });

    try {
      final result = await UnifiedFeedService.toggleLike(item.type, item.id);
      
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            item.likesCount = result['likesCount'] ?? item.likesCount;
            item.isLiked = result['isLiked'] ?? item.isLiked;
          });
          
          final action = result['action'];
          _showMessage(
            action == 'liked' ? 'Vous aimez ce contenu ❤️' : 'Like retiré',
            isError: false
          );
        } else {
          // Revenir à l'état précédent
          setState(() {
            item.likesCount = originalLikesCount;
            item.isLiked = originalIsLiked;
          });
          
          if (result['needsAuth'] == true) {
            setState(() {
              _needsAuth = true;
            });
            _showMessage('Session expirée, reconnectez-vous', isError: true);
          } else {
            _showMessage(result['error'] ?? 'Erreur lors du like', isError: true);
          }
        }
      }
    } catch (e) {
      setState(() {
        item.likesCount = originalLikesCount;
        item.isLiked = originalIsLiked;
      });
      _showMessage('Erreur de connexion', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, '/registration');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_needsAuth) {
      return _buildAuthenticationRequired();
    }
    
    return Column(
      children: [
        _buildHeader(),
        _buildFilters(),
        if (_searchQuery.isNotEmpty || _selectedFilter != 'all') _buildResultsInfo(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildAuthenticationRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Authentification requise',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre session a expiré. Veuillez vous reconnecter.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _navigateToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              'Se reconnecter',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher dans tous les contenus...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: const BorderSide(color: Color(0xFF2E7D32)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Statistiques
          Row(
            children: [
              Expanded(child: _buildStatCard('Total', _allItems.length, Icons.all_inclusive)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Articles', _totalArticles, Icons.article)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Médias', _totalMedias, Icons.perm_media)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[50],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Tous', 'all', _allItems.length),
            const SizedBox(width: 8),
            _buildFilterChip('Articles', 'article', _totalArticles),
            const SizedBox(width: 8),
            _buildFilterChip('Médias', 'media', _totalMedias),
            const SizedBox(width: 16),
            IconButton(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh, color: Color(0xFF2E7D32)),
              tooltip: 'Actualiser',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filter, int count) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
          _filterItems();
        });
      },
      selectedColor: const Color(0xFF2E7D32).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFF2E7D32),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF2E7D32) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildResultsInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue[50],
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _searchQuery.isNotEmpty
                  ? '${_filteredItems.length} résultat(s) pour "$_searchQuery"'
                  : '${_filteredItems.length} élément(s) dans ${_getFilterLabel()}',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case 'article': return 'Articles';
      case 'media': return 'Médias';
      default: return 'Tous les contenus';
    }
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF2E7D32)),
            SizedBox(height: 16),
            Text('Chargement du contenu...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text('Erreur de chargement', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.feed_outlined,
              color: Colors.grey,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'Aucun résultat trouvé'
                  : 'Aucun contenu disponible',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Essayez avec d\'autres mots-clés'
                  : 'Il n\'y a pas encore de contenu à afficher',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchQuery.isNotEmpty
                  ? () => _searchController.clear()
                  : _refreshData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              child: Text(
                _searchQuery.isNotEmpty ? 'Effacer la recherche' : 'Actualiser',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filteredItems.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _filteredItems.length) {
            final item = _filteredItems[index];
            return _buildFeedCard(item);
          } else {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildFeedCard(FeedItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigation vers le détail
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            _buildCardHeader(item),
            
            // Contenu
            _buildCardContent(item),
            
            // Média si présent
            if (item.primaryImageUrl != null) _buildCardMedia(item),
            
            // Tags
            if (item.tags.isNotEmpty) _buildCardTags(item),
            
            // Actions
            _buildCardActions(item),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(FeedItem item) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2E7D32),
            child: Text(
              item.author.displayName.isNotEmpty 
                  ? item.author.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Infos auteur
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.author.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (item.author.isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatDate(item.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getTypeColor(item.type),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getTypeLabel(item.type),
                        style: TextStyle(
                          color: _getTypeLabelColor(item.type),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(FeedItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.displayContent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.displayContent,
              style: TextStyle(color: Colors.grey[800], height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardMedia(FeedItem item) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            item.primaryImageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 32, color: Colors.grey[600]),
                      const SizedBox(height: 8),
                      Text('Image non disponible', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCardTags(FeedItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: item.tags.take(3).map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#$tag',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCardActions(FeedItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Like
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleLike(item),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: item.isLiked ? Colors.red : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.likesCount}',
                      style: TextStyle(
                        color: item.isLiked ? Colors.red : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Commentaires
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.comment_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                '${item.commentsCount}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Vues
          if (item.viewsCount > 0) ...[
            Icon(Icons.visibility, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              '${item.viewsCount}',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'article': return Colors.orange[100]!;
      case 'media': return Colors.blue[100]!;
      default: return Colors.grey[100]!;
    }
  }

  Color _getTypeLabelColor(String type) {
    switch (type) {
      case 'article': return Colors.orange[800]!;
      case 'media': return Colors.blue[800]!;
      default: return Colors.grey[800]!;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'article': return 'Article';
      case 'media': return 'Média';
      default: return 'Contenu';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Maintenant';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}