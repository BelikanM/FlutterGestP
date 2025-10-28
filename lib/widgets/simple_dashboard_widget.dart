import 'package:flutter/material.dart';
import '../models/feed_models.dart';
import '../services/social_service.dart';

class SimpleDashboardWidget extends StatefulWidget {
  const SimpleDashboardWidget({super.key});

  @override
  State<SimpleDashboardWidget> createState() => _SimpleDashboardWidgetState();
}

class _SimpleDashboardWidgetState extends State<SimpleDashboardWidget> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<FeedItem> _feedItems = [];
  final List<FeedItem> _filteredItems = [];
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMoreData = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialFeed();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoadingMore && _hasMoreData && _searchQuery.isEmpty) {
        _loadMoreFeed();
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterItems();
    });
  }

  void _filterItems() {
    if (_searchQuery.isEmpty) {
      _filteredItems.clear();
      _filteredItems.addAll(_feedItems);
    } else {
      _filteredItems.clear();
      _filteredItems.addAll(_feedItems.where((item) {
        return item.title.toLowerCase().contains(_searchQuery) ||
               item.displayContent.toLowerCase().contains(_searchQuery) ||
               item.tags.any((tag) => tag.toLowerCase().contains(_searchQuery)) ||
               item.author.displayName.toLowerCase().contains(_searchQuery);
      }));
    }
  }

  Future<void> _loadInitialFeed() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _currentPage = 1;
    });

    final result = await SocialService.getSocialFeed(page: 1, limit: 20);
    
    if (mounted) {
      if (result['success'] == true) {
        final feedData = result['feed'] as List<dynamic>;
        final feedItems = feedData.map((item) => FeedItem.fromJson(item)).toList();
        
        setState(() {
          _feedItems.clear();
          _feedItems.addAll(feedItems);
          _filterItems();
          _isLoading = false;
          _hasMoreData = feedItems.length == 20;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = result['error'] ?? 'Erreur inconnue';
        });
      }
    }
  }

  Future<void> _loadMoreFeed() async {
    if (_isLoadingMore || _searchQuery.isNotEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    final result = await SocialService.getSocialFeed(
      page: _currentPage + 1, 
      limit: 20
    );
    
    if (mounted) {
      if (result['success'] == true) {
        final feedData = result['feed'] as List<dynamic>;
        final feedItems = feedData.map((item) => FeedItem.fromJson(item)).toList();
        
        setState(() {
          _feedItems.addAll(feedItems);
          _filterItems();
          _currentPage++;
          _isLoadingMore = false;
          _hasMoreData = feedItems.length == 20;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshFeed() async {
    await _loadInitialFeed();
  }

  Future<void> _handleLike(FeedItem item) async {
    if (!await SocialService.isUserAuthenticated()) {
      _showMessage('Vous devez être connecté pour aimer ce contenu', isError: true);
      return;
    }

    final originalLikesCount = item.likesCount;
    final originalIsLiked = item.isLiked;
    
    setState(() {
      if (item.isLiked) {
        item.likesCount = (item.likesCount - 1).clamp(0, double.infinity).toInt();
        item.isLiked = false;
      } else {
        item.likesCount++;
        item.isLiked = true;
      }
    });

    final result = await SocialService.toggleLike(item.type, item.id);
    
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
        setState(() {
          item.likesCount = originalLikesCount;
          item.isLiked = originalIsLiked;
        });
        
        _showMessage('Erreur lors du like', isError: true);
      }
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre de recherche
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher dans les articles et médias...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
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
        ),
        
        // Résultats de recherche
        if (_searchQuery.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.search_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_filteredItems.length} résultat(s) pour "$_searchQuery"',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Contenu principal
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
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
              onPressed: _loadInitialFeed,
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
                  : _refreshFeed,
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
      onRefresh: _refreshFeed,
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filteredItems.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _filteredItems.length) {
            final item = _filteredItems[index];
            return _buildFeedItemCard(item);
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

  Widget _buildFeedItemCard(FeedItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF2E7D32),
                  child: item.author.profilePhoto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            item.author.profilePhoto!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultAvatar(item);
                            },
                          ),
                        )
                      : _buildDefaultAvatar(item),
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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
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
                              color: item.type == 'article' ? Colors.orange[100] : Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.type == 'article' ? 'Article' : 'Média',
                              style: TextStyle(
                                color: item.type == 'article' ? Colors.orange[800] : Colors.blue[800],
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
          ),
          
          // Contenu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          ),
          
          // Média
          if (item.primaryImageUrl != null) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    item.primaryImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
          
          // Tags
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: item.tags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
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
            ),
          ],
          
          // Actions
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Like
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleLike(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: item.isLiked ? Colors.red : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${item.likesCount}',
                            style: TextStyle(
                              color: item.isLiked ? Colors.red : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Commentaires
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.comment_outlined, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      '${item.commentsCount}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Vues
                if (item.viewsCount > 0) ...[
                  Icon(Icons.visibility, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${item.viewsCount}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(FeedItem item) {
    return Text(
      item.author.displayName.isNotEmpty 
          ? item.author.displayName[0].toUpperCase()
          : '?',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'À l\'instant';
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