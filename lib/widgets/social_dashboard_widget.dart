import 'package:flutter/material.dart';
import '../models/feed_models.dart';
import '../services/social_service.dart';
import 'post_card_widget.dart';

class SocialDashboardWidget extends StatefulWidget {
  const SocialDashboardWidget({super.key});

  @override
  State<SocialDashboardWidget> createState() => _SocialDashboardWidgetState();
}

class _SocialDashboardWidgetState extends State<SocialDashboardWidget> {
  final ScrollController _scrollController = ScrollController();
  final List<FeedItem> _feedItems = [];
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _loadInitialFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreFeed();
      }
    }
  }

  Future<void> _loadInitialFeed() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _currentPage = 1;
    });

    final result = await SocialService.getSocialFeed(page: 1, limit: 10);
    
    if (mounted) {
      if (result['success'] == true) {
        final feedData = result['feed'] as List<dynamic>;
        final feedItems = feedData.map((item) => FeedItem.fromJson(item)).toList();
        
        setState(() {
          _feedItems.clear();
          _feedItems.addAll(feedItems);
          _isLoading = false;
          _hasMoreData = feedItems.length == 10; // Si moins de 10, c'est fini
        });
        
        // Feed items loaded successfully
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = result['error'] ?? 'Erreur inconnue';
        });
        // Error loading feed
      }
    }
  }

  Future<void> _loadMoreFeed() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    final result = await SocialService.getSocialFeed(
      page: _currentPage + 1, 
      limit: 10
    );
    
    if (mounted) {
      if (result['success'] == true) {
        final feedData = result['feed'] as List<dynamic>;
        final feedItems = feedData.map((item) => FeedItem.fromJson(item)).toList();
        
        setState(() {
          _feedItems.addAll(feedItems);
          _currentPage++;
          _isLoadingMore = false;
          _hasMoreData = feedItems.length == 10;
        });
        
        // More feed items loaded successfully
      } else {
        setState(() {
          _isLoadingMore = false;
        });
        // Error loading more feed items
      }
    }
  }

  Future<void> _refreshFeed() async {
    await _loadInitialFeed();
  }

  Future<void> _handleLike(FeedItem item, int index) async {
    if (!await SocialService.isUserAuthenticated()) {
      _showMessage('Vous devez être connecté pour aimer ce contenu', isError: true);
      return;
    }

    // Optimistic update
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

    // API call
    final result = await SocialService.toggleLike(item.type, item.id);
    
    if (mounted) {
      if (result['success'] == true) {
        // Mettre à jour avec les vraies valeurs du serveur
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
        // Revert en cas d'erreur
        setState(() {
          item.likesCount = originalLikesCount;
          item.isLiked = originalIsLiked;
        });
        
        _showMessage(
          'Erreur lors du like: ${result['error']}',
          isError: true
        );
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
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement du feed social...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
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
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialFeed,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_feedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.feed_outlined,
              color: Colors.grey,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun contenu disponible',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Il n\'y a pas encore de contenu à afficher.\nCommencez par créer des articles ou des médias !',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshFeed,
              child: const Text('Actualiser'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Header du feed
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.dynamic_feed,
                    color: Color(0xFF2E7D32),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Feed Social',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_feedItems.length} éléments',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Liste du feed
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < _feedItems.length) {
                  final item = _feedItems[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: PostCardWidget(
                      item: item,
                      onLike: () => _handleLike(item, index),
                      onComment: () => _navigateToComments(item),
                      onShare: () => _shareItem(item),
                    ),
                  );
                } else if (_hasMoreData) {
                  // Indicateur de chargement pour plus de contenu
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else {
                  // Fin du feed
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Vous avez vu tout le contenu !',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }
              },
              childCount: _feedItems.length + (_hasMoreData ? 1 : 1),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToComments(FeedItem item) {
    // Feature: Navigation to comments page implementation needed
    _showMessage('Navigation vers les commentaires (à implémenter)');
  }

  void _shareItem(FeedItem item) {
    // Feature: Content sharing implementation needed
    _showMessage('Partage du contenu (à implémenter)');
  }
}