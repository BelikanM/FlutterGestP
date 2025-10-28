// likes_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../social_interactions_service.dart';

class LikesPage extends StatefulWidget {
  final String targetType;
  final String targetId;
  final String contentTitle;

  const LikesPage({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.contentTitle,
  });

  @override
  LikesPageState createState() => LikesPageState();
}

class LikesPageState extends State<LikesPage> {
  List<LikeItem> _likes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMoreData = true;
  int _totalLikes = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLikes();
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
        _loadMoreLikes();
      }
    }
  }

  Future<void> _loadLikes() async {
    try {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMoreData = true;
      });

      final response = await SocialInteractionsService.getLikes(
        widget.targetType,
        widget.targetId,
        page: 1,
        limit: 30,
      );

      if (mounted) {
        setState(() {
          _likes = response.likes;
          _totalLikes = response.totalLikes;
          _hasMoreData = response.pagination.pages > 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Erreur de chargement: $e');
      }
    }
  }

  Future<void> _loadMoreLikes() async {
    if (_isLoadingMore || !_hasMoreData) return;

    try {
      setState(() => _isLoadingMore = true);
      
      final response = await SocialInteractionsService.getLikes(
        widget.targetType,
        widget.targetId,
        page: _currentPage + 1,
        limit: 30,
      );

      if (mounted) {
        setState(() {
          _likes.addAll(response.likes);
          _currentPage++;
          _hasMoreData = _currentPage < response.pagination.pages;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        _showErrorSnackBar('Erreur lors du chargement: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'J\'aime${_totalLikes > 0 ? ' ($_totalLikes)' : ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.contentTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLikes,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      );
    }

    if (_likes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun like',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Soyez le premier à aimer ce contenu !',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLikes,
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _likes.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _likes.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
              ),
            );
          }

          final like = _likes[index];
          return _buildLikeItem(like);
        },
      ),
    );
  }

  Widget _buildLikeItem(LikeItem like) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF2E7D32),
                backgroundImage: like.user.profilePhoto != null && 
                                like.user.profilePhoto!.isNotEmpty
                    ? MemoryImage(
                        like.user.profilePhoto!.startsWith('data:') 
                            ? base64Decode(like.user.profilePhoto!.split(',').last)
                            : base64Decode(like.user.profilePhoto!)
                      )
                    : null,
                child: like.user.profilePhoto == null || 
                       like.user.profilePhoto!.isEmpty
                    ? Text(
                        _getInitials(like.user.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              
              // Badge admin
              if (like.user.role == 'admin')
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              
              // Icône coeur
              Positioned(
                top: -2,
                left: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
          
          title: Row(
            children: [
              Expanded(
                child: Text(
                  like.user.name.isNotEmpty 
                      ? like.user.name 
                      : like.user.email.split('@').first,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              if (like.user.role == 'admin')
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
          
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                like.user.email,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 14,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getTimeAgo(like.createdAt),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    const Text('Voir le profil'),
                  ],
                ),
              ),
              if (like.user.role != 'admin')
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 18, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Text('Bloquer', style: TextStyle(color: Colors.red[700])),
                    ],
                  ),
                ),
            ],
            onSelected: (value) => _handleMenuAction(value, like),
          ),
        ),
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

  void _handleMenuAction(String action, LikeItem like) {
    switch (action) {
      case 'profile':
        _showProfileDialog(like.user);
        break;
      case 'block':
        _showBlockDialog(like.user);
        break;
    }
  }

  void _showProfileDialog(LikeUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF2E7D32),
              backgroundImage: user.profilePhoto != null && user.profilePhoto!.isNotEmpty
                  ? MemoryImage(
                      user.profilePhoto!.startsWith('data:') 
                          ? base64Decode(user.profilePhoto!.split(',').last)
                          : base64Decode(user.profilePhoto!)
                    )
                  : null,
              child: user.profilePhoto == null || user.profilePhoto!.isEmpty
                  ? Text(
                      _getInitials(user.name),
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
                  Text(
                    user.name.isNotEmpty ? user.name : user.email.split('@').first,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (user.role == 'admin')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ADMINISTRATEUR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user.email}'),
            const SizedBox(height: 8),
            Text('Rôle: ${user.role == 'admin' ? 'Administrateur' : 'Utilisateur'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(LikeUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bloquer cet utilisateur'),
        content: Text('Voulez-vous bloquer ${user.name.isNotEmpty ? user.name : user.email} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessSnackBar('Utilisateur bloqué');
            },
            child: const Text('Bloquer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }
}