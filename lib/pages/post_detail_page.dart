import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../social_feed_service.dart';
import '../social_interactions_service.dart';
import 'comments_page.dart';
import 'likes_page.dart';

class PostDetailPage extends StatefulWidget {
  final FeedItem item;

  const PostDetailPage({
    super.key,
    required this.item,
  });

  @override
  PostDetailPageState createState() => PostDetailPageState();
}

class PostDetailPageState extends State<PostDetailPage> {
  late FeedItem _item;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    try {
      final stats = await SocialInteractionsService.getContentStats(
        _item.type,
        _item.id,
      );
      
      if (mounted) {
        setState(() {
          _item.likesCount = stats.likesCount;
          _item.commentsCount = stats.commentsCount;
          _item.viewsCount = stats.viewsCount;
          _item.isLiked = stats.isLiked;
        });
      }
    } catch (e) {
      // Silently handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Text(
          _item.type == 'article' ? 'Article' : 'Média',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    const Text('Partager'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report, size: 18, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Text('Signaler', style: TextStyle(color: Colors.red[700])),
                  ],
                ),
              ),
            ],
            onSelected: _handleMenuAction,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildContent(),
          if (_item.mediaFiles != null && _item.mediaFiles!.isNotEmpty)
            _buildMediaGallery(),
          const SizedBox(height: 20),
          _buildStats(),
          const SizedBox(height: 100), // Space for bottom actions
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2E7D32),
            backgroundImage: _item.author.profilePhoto != null
                ? MemoryImage(base64Decode(_item.author.profilePhoto!))
                : null,
            child: _item.author.profilePhoto == null
                ? Text(
                    _getInitials(_item.author.name.isNotEmpty ? _item.author.name : 'Anonyme'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _item.author.name.isNotEmpty ? _item.author.name : _item.author.email.split('@').first,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_item.author.role == 'admin')
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
                  _getTimeAgo(_item.createdAt),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_item.title.isNotEmpty)
            Text(
              _item.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          
          if (_item.title.isNotEmpty && (_item.content != null || _item.description != null))
            const SizedBox(height: 12),
          
          if (_item.content != null && _item.content!.isNotEmpty)
            Text(
              _item.content!,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          
          if (_item.description != null && _item.description!.isNotEmpty && _item.content == null)
            Text(
              _item.description!,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          
          if (_item.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _item.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#$tag',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaGallery() {
    if (_item.mediaFiles == null || _item.mediaFiles!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _item.mediaFiles!.length == 1
            ? _buildSingleMedia(_item.mediaFiles!.first)
            : _buildMediaGrid(),
      ),
    );
  }

  Widget _buildSingleMedia(MediaFile media) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.grey[200],
        child: media.type.startsWith('image/')
            ? Image.memory(
                base64Decode(media.url),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.grey[600],
                    ),
                  );
                },
              )
            : Container(
                color: Colors.grey[300],
                child: Icon(
                  Icons.play_circle_fill,
                  size: 48,
                  color: Colors.grey[600],
                ),
              ),
      ),
    );
  }

  Widget _buildMediaGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _item.mediaFiles!.length,
      itemBuilder: (context, index) {
        final media = _item.mediaFiles![index];
        return _buildSingleMedia(media);
      },
    );
  }

  Widget _buildStats() {
    if (_item.likesCount == 0 && _item.commentsCount == 0 && _item.viewsCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_item.likesCount > 0) ...[
            GestureDetector(
              onTap: _openLikesPage,
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_item.likesCount}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          
          if (_item.likesCount > 0 && _item.commentsCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('•', style: TextStyle(color: Colors.grey[400])),
            ),
          
          if (_item.commentsCount > 0) ...[
            GestureDetector(
              onTap: _openCommentsPage,
              child: Row(
                children: [
                  Icon(Icons.comment, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_item.commentsCount}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          
          const Spacer(),
          
          if (_item.viewsCount > 0) ...[
            Icon(Icons.visibility, color: Colors.grey[500], size: 16),
            const SizedBox(width: 4),
            Text(
              '${_item.viewsCount} vues',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: _toggleLike,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _item.isLiked ? Colors.red : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    color: _item.isLiked ? Colors.red.withValues(alpha: 0.1) : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _item.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _item.isLiked ? Colors.red : Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _item.isLiked ? 'Aimé' : 'J\'aime',
                        style: TextStyle(
                          color: _item.isLiked ? Colors.red : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: _openCommentsPage,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.comment_outlined, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Commenter',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);

      // Optimistic update
      setState(() {
        if (_item.isLiked) {
          _item.likesCount = (_item.likesCount - 1).clamp(0, double.infinity).toInt();
          _item.isLiked = false;
        } else {
          _item.likesCount++;
          _item.isLiked = true;
        }
      });

      // API call
      final result = await SocialInteractionsService.toggleLike(
        _item.type,
        _item.id,
      );

      // Update with actual values from server
      if (mounted) {
        setState(() {
          _item.likesCount = result.likesCount;
          _item.isLiked = result.isLiked;
        });
      }
    } catch (e) {
      // Revert on error
      setState(() {
        if (_item.isLiked) {
          _item.likesCount = (_item.likesCount - 1).clamp(0, double.infinity).toInt();
          _item.isLiked = false;
        } else {
          _item.likesCount++;
          _item.isLiked = true;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du like: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openCommentsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsPage(
          targetType: _item.type,
          targetId: _item.id,
          contentTitle: _item.title.isNotEmpty ? _item.title : 'Publication',
        ),
      ),
    ).then((_) {
      _refreshStats();
    });
  }

  void _openLikesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LikesPage(
          targetType: _item.type,
          targetId: _item.id,
          contentTitle: _item.title.isNotEmpty ? _item.title : 'Publication',
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'share':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fonctionnalité de partage à implémenter'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        break;
      case 'report':
        _showReportDialog();
        break;
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signaler ce contenu'),
        content: const Text('Voulez-vous signaler ce contenu comme inapproprié ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contenu signalé'),
                  backgroundColor: Color(0xFF2E7D32),
                ),
              );
            },
            child: const Text('Signaler', style: TextStyle(color: Colors.red)),
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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('dd MMM yyyy à HH:mm').format(dateTime);
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}