// social_feed_widget.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../social_feed_service.dart';

class SocialFeedWidget extends StatefulWidget {
  final VoidCallback? onRefresh;

  const SocialFeedWidget({super.key, this.onRefresh});

  @override
  SocialFeedWidgetState createState() => SocialFeedWidgetState();
}

class SocialFeedWidgetState extends State<SocialFeedWidget> {
  List<FeedItem> _feedItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreFeed();
      }
    }
  }

  Future<void> _loadFeed() async {
    try {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMoreData = true;
      });

      final response = await SocialFeedService.getSocialFeed(
        page: 1,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _feedItems = response.feed;
          _hasMoreData = response.pagination.pages > 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreFeed() async {
    if (_isLoadingMore || !_hasMoreData) return;

    try {
      setState(() => _isLoadingMore = true);
      
      final response = await SocialFeedService.getSocialFeed(
        page: _currentPage + 1,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _feedItems.addAll(response.feed);
          _currentPage++;
          _hasMoreData = _currentPage < response.pagination.pages;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      );
    }

    if (_feedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feed, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun contenu disponible',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez à partager du contenu !',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadFeed();
        if (widget.onRefresh != null) {
          widget.onRefresh!();
        }
      },
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _feedItems.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _feedItems.length) {
            // Indicateur de chargement pour plus de contenu
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
              ),
            );
          }

          final item = _feedItems[index];
          return _buildFeedItem(item);
        },
      ),
    );
  }

  Widget _buildFeedItem(FeedItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec profil utilisateur
            _buildUserHeader(item),
            
            // Contenu du post
            if (item.type == 'article' || item.feedType == 'article')
              _buildArticleContent(item)
            else
              _buildMediaContent(item),
            
            // Actions et interactions
            _buildPostActions(item),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(FeedItem item) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Avatar de l'utilisateur
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF2E7D32),
            backgroundImage: item.author.profilePhoto != null && 
                            item.author.profilePhoto!.isNotEmpty
                ? MemoryImage(
                    item.author.profilePhoto!.startsWith('data:') 
                        ? base64Decode(item.author.profilePhoto!.split(',').last)
                        : base64Decode(item.author.profilePhoto!)
                  )
                : null,
            child: item.author.profilePhoto == null || 
                   item.author.profilePhoto!.isEmpty
                ? Text(
                    _getInitials(item.author.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // Informations utilisateur
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.author.name.isNotEmpty 
                          ? item.author.name 
                          : item.author.email.split('@').first,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (item.author.role == 'admin')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
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
                ),
                Text(
                  DateFormat('dd MMM yyyy • HH:mm').format(item.createdAt),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Menu d'actions
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 18),
                    SizedBox(width: 8),
                    Text('Partager'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, size: 18),
                    SizedBox(width: 8),
                    Text('Signaler'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              // Gérer les actions du menu
              switch (value) {
                case 'share':
                  _sharePost(item);
                  break;
                case 'report':
                  _reportPost(item);
                  break;
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArticleContent(FeedItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de l'article
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 8),
          
          // Résumé ou contenu tronqué
          if (item.summary != null && item.summary!.isNotEmpty)
            Text(
              item.summary!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            )
          else if (item.content != null)
            Text(
              item.content!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          
          const SizedBox(height: 12),
          
          // Médias attachés
          if (item.mediaFiles != null && item.mediaFiles!.isNotEmpty)
            _buildAttachedMedia(item.mediaFiles!),
          
          // Tags
          if (item.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.tags.take(3).map((tag) => Chip(
                  label: Text(tag),
                  backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2E7D32),
                  ),
                )).toList(),
              ),
            ),
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMediaContent(FeedItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre du média
        if (item.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        
        // Description
        if (item.description != null && item.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              item.description!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        
        const SizedBox(height: 12),
        
        // Aperçu du média
        if (item.url != null)
          _buildMediaPreview(item),
        
        // Tags
        if (item.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.tags.take(3).map((tag) => Chip(
                label: Text(tag),
                backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2E7D32),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachedMedia(List<MediaFile> mediaFiles) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mediaFiles.take(5).length,
        itemBuilder: (context, index) {
          final media = mediaFiles[index];
          return Container(
            width: 100,
            margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildMediaThumbnail(media.url, media.type),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaPreview(FeedItem item) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(0)),
        child: _buildMediaThumbnail(item.url!, item.type),
      ),
    );
  }

  Widget _buildMediaThumbnail(String url, String type) {
    if (type.startsWith('image/') || type == 'image') {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else if (type.startsWith('video/') || type == 'video') {
      return Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: const Icon(
          Icons.play_circle_outline,
          color: Colors.white,
          size: 48,
        ),
      );
    } else {
      return Container(
        color: Colors.grey[100],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getFileIcon(type), size: 32, color: Colors.grey[600]),
            const SizedBox(height: 4),
            Text(
              type.split('/').last.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPostActions(FeedItem item) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () => _likePost(item),
            color: Colors.grey[600],
          ),
          IconButton(
            icon: const Icon(Icons.comment_outlined),
            onPressed: () => _commentPost(item),
            color: Colors.grey[600],
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _sharePost(item),
            color: Colors.grey[600],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => _savePost(item),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  IconData _getFileIcon(String type) {
    if (type.contains('image')) return Icons.image;
    if (type.contains('video')) return Icons.videocam;
    if (type.contains('audio')) return Icons.audiotrack;
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  void _likePost(FeedItem item) {
    // Implémenter la logique de like
  }

  void _commentPost(FeedItem item) {
    // Implémenter la logique de commentaire
  }

  void _sharePost(FeedItem item) {
    // Implémenter la logique de partage
  }

  void _savePost(FeedItem item) {
    // Implémenter la logique de sauvegarde
  }

  void _reportPost(FeedItem item) {
    // Implémenter la logique de signalement
  }
}