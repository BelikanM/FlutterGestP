// comments_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../social_interactions_service.dart';

class CommentsPage extends StatefulWidget {
  final String targetType;
  final String targetId;
  final String contentTitle;

  const CommentsPage({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.contentTitle,
  });

  @override
  CommentsPageState createState() => CommentsPageState();
}

class CommentsPageState extends State<CommentsPage> {
  List<CommentItem> _comments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSubmitting = false;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  String? _replyingToCommentId;
  String? _replyingToAuthorName;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreComments();
      }
    }
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMoreData = true;
      });

      final response = await SocialInteractionsService.getComments(
        widget.targetType,
        widget.targetId,
        page: 1,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _comments = response.comments;
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

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMoreData) return;

    try {
      setState(() => _isLoadingMore = true);
      
      final response = await SocialInteractionsService.getComments(
        widget.targetType,
        widget.targetId,
        page: _currentPage + 1,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _comments.addAll(response.comments);
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

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      setState(() => _isSubmitting = true);

      final response = await SocialInteractionsService.addComment(
        _commentController.text.trim(),
        widget.targetType,
        widget.targetId,
        parentCommentId: _replyingToCommentId,
      );

      if (mounted) {
        setState(() {
          if (_replyingToCommentId == null) {
            // Nouveau commentaire principal - l'ajouter en haut
            _comments.insert(0, response.comment);
          } else {
            // C'est une réponse - actualiser la liste complète
            _loadComments();
          }
          _commentController.clear();
          _replyingToCommentId = null;
          _replyingToAuthorName = null;
          _isSubmitting = false;
        });

        _showSuccessSnackBar('Commentaire ajouté !');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  Future<void> _toggleLike(CommentItem comment, int index) async {
    try {
      final response = await SocialInteractionsService.toggleLike(
        'comment',
        comment.id,
      );

      if (mounted) {
        setState(() {
          _comments[index] = CommentItem(
            id: comment.id,
            content: comment.content,
            isEdited: comment.isEdited,
            editedAt: comment.editedAt,
            likesCount: response.likesCount,
            repliesCount: comment.repliesCount,
            createdAt: comment.createdAt,
            updatedAt: comment.updatedAt,
            parentCommentId: comment.parentCommentId,
            author: comment.author,
            isLiked: response.isLiked,
          );
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors du like: $e');
    }
  }

  void _replyToComment(CommentItem comment) {
    setState(() {
      _replyingToCommentId = comment.id;
      _replyingToAuthorName = comment.author.name.isNotEmpty ? comment.author.name : comment.author.email.split('@').first;
    });
    _commentController.text = '@$_replyingToAuthorName ';
    // Focus sur le champ de texte
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToAuthorName = null;
    });
    _commentController.clear();
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
            const Text(
              'Commentaires',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
            onPressed: _loadComments,
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone de réponse si l'utilisateur répond à un commentaire
          if (_replyingToCommentId != null) _buildReplyIndicator(),
          
          // Liste des commentaires
          Expanded(child: _buildCommentsList()),
          
          // Zone de saisie
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            color: const Color(0xFF2E7D32),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Réponse à $_replyingToAuthorName',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _cancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      );
    }

    if (_comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun commentaire',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Soyez le premier à commenter !',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _comments.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            ),
          );
        }

        final comment = _comments[index];
        return _buildCommentItem(comment, index);
      },
    );
  }

  Widget _buildCommentItem(CommentItem comment, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête du commentaire
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF2E7D32),
                    backgroundImage: comment.author.profilePhoto != null && 
                                    comment.author.profilePhoto!.isNotEmpty
                        ? MemoryImage(
                            comment.author.profilePhoto!.startsWith('data:') 
                                ? base64Decode(comment.author.profilePhoto!.split(',').last)
                                : base64Decode(comment.author.profilePhoto!)
                          )
                        : null,
                    child: comment.author.profilePhoto == null || 
                           comment.author.profilePhoto!.isEmpty
                        ? Text(
                            _getInitials(comment.author.name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              comment.author.name.isNotEmpty 
                                  ? comment.author.name 
                                  : comment.author.email.split('@').first,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (comment.author.role == 'admin')
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
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          _getTimeAgo(comment.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag, size: 16),
                            SizedBox(width: 8),
                            Text('Signaler'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'report') {
                        _showReportDialog(comment);
                      }
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Contenu du commentaire
              Text(
                comment.content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              
              if (comment.isEdited) ...[
                const SizedBox(height: 8),
                Text(
                  'Modifié ${comment.editedAt != null ? DateFormat('dd/MM à HH:mm').format(comment.editedAt!) : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Actions du commentaire
              Row(
                children: [
                  InkWell(
                    onTap: () => _toggleLike(comment, index),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            comment.isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: comment.isLiked ? Colors.red : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment.likesCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: comment.isLiked ? Colors.red : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  InkWell(
                    onTap: () => _replyToComment(comment),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Répondre',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (comment.repliesCount > 0) ...[
                    const SizedBox(width: 16),
                    Text(
                      '${comment.repliesCount} réponse${comment.repliesCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: _replyingToCommentId != null 
                    ? 'Répondre à $_replyingToAuthorName...' 
                    : 'Ajouter un commentaire...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSubmitting ? null : _submitComment,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
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
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'À l\'instant';
    }
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

  void _showReportDialog(CommentItem comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signaler ce commentaire'),
        content: const Text('Voulez-vous signaler ce commentaire comme inapproprié ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessSnackBar('Commentaire signalé');
            },
            child: const Text('Signaler', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}