// media_feed_widget.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../social_feed_service.dart';

class MediaFeedWidget extends StatefulWidget {
  final VoidCallback? onRefresh;

  const MediaFeedWidget({super.key, this.onRefresh});

  @override
  MediaFeedWidgetState createState() => MediaFeedWidgetState();
}

class MediaFeedWidgetState extends State<MediaFeedWidget> {
  List<MediaFeedItem> _mediaItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMediaFeed();
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
        _loadMoreMediaFeed();
      }
    }
  }

  Future<void> _loadMediaFeed() async {
    try {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMoreData = true;
      });

      final response = await SocialFeedService.getMediaFeed(
        page: 1,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _mediaItems = response.medias;
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

  Future<void> _loadMoreMediaFeed() async {
    if (_isLoadingMore || !_hasMoreData) return;

    try {
      setState(() => _isLoadingMore = true);
      
      final response = await SocialFeedService.getMediaFeed(
        page: _currentPage + 1,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _mediaItems.addAll(response.medias);
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

    if (_mediaItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun média disponible',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez à partager vos médias !',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadMediaFeed();
        if (widget.onRefresh != null) {
          widget.onRefresh!();
        }
      },
      color: const Color(0xFF2E7D32),
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: _mediaItems.length + (_isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= _mediaItems.length) {
            // Indicateur de chargement
            return const Card(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
              ),
            );
          }

          final item = _mediaItems[index];
          return _buildMediaCard(item);
        },
      ),
    );
  }

  Widget _buildMediaCard(MediaFeedItem item) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aperçu du média
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildMediaPreview(item),
                
                // Overlay avec type de média
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getMediaIcon(item.type),
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getMediaTypeName(item.type),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Informations du média
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  if (item.title.isNotEmpty)
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 4),
                  
                  // Utilisateur et date
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 8,
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
                                  fontSize: 8,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.author.name.isNotEmpty 
                                  ? item.author.name 
                                  : item.author.email.split('@').first,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              DateFormat('dd/MM').format(item.createdAt),
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.author.role == 'admin')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'A',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      Icon(
                        Icons.share,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      Icon(
                        Icons.download,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(MediaFeedItem item) {
    if (item.type.startsWith('image/') || item.type == 'image') {
      return Image.network(
        item.url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 32),
        ),
      );
    } else if (item.type.startsWith('video/') || item.type == 'video') {
      return Container(
        color: Colors.black,
        child: const Icon(
          Icons.play_circle_outline,
          color: Colors.white,
          size: 48,
        ),
      );
    } else {
      return Container(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getMediaIcon(item.type),
              size: 32,
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 8),
            Text(
              item.type.split('/').last.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      );
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  IconData _getMediaIcon(String type) {
    if (type.contains('image')) return Icons.image;
    if (type.contains('video')) return Icons.videocam;
    if (type.contains('audio')) return Icons.audiotrack;
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  String _getMediaTypeName(String type) {
    if (type.contains('image')) return 'IMG';
    if (type.contains('video')) return 'VID';
    if (type.contains('audio')) return 'AUD';
    if (type.contains('pdf')) return 'PDF';
    return 'FILE';
  }
}