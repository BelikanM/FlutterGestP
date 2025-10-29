// pages/blog_detail_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../blog_service.dart';
import '../services/chat_service.dart';
import 'blog_editor_page.dart';
import 'group_chat_page.dart';

class BlogDetailPage extends StatefulWidget {
  final String articleId;
  final bool fromChat;
  
  const BlogDetailPage({super.key, required this.articleId, this.fromChat = false});

  @override
  BlogDetailPageState createState() => BlogDetailPageState();
}

class BlogDetailPageState extends State<BlogDetailPage> {
  final BlogService _blogService = BlogService();
  final ChatService _chatService = ChatService();
  
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
  Map<String, dynamic>? _article;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (_token != null) {
      await _fetchArticle();
    }
  }

  Future<void> _fetchArticle() async {
    if (_token == null) return;
    
    setState(() => _isLoading = true);
    try {
      final article = await _blogService.getArticle(_token!, widget.articleId);
      
      if (mounted) {
        setState(() {
          _article = article;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteArticle() async {
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
        await _blogService.deleteArticle(_token!, widget.articleId);
        if (mounted) {
          Navigator.pop(context); // Retour à la liste
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

  Future<void> _shareArticleToChat() async {
    if (_article == null || _token == null) return;

    try {
      // Afficher un indicateur de chargement
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partage en cours...')),
      );

      // Partager l'article dans le chat
      await _chatService.shareBlogArticle(
        articleId: _article!['_id'],
        title: _article!['title'] ?? 'Sans titre',
        summary: _article!['summary'] ?? '',
        authorName: 'Utilisateur', // On pourrait récupérer le nom depuis le profil
      );

      if (mounted) {
        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Article partagé dans le chat !'),
            backgroundColor: Colors.green,
          ),
        );

        // Demander si l'utilisateur veut aller au chat
        final goToChat = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Article partagé !'),
            content: const Text('Voulez-vous aller voir le message dans le chat de groupe ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Rester ici'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Aller au chat'),
              ),
            ],
          ),
        );

        if (goToChat == true) {
          // Naviguer vers la page de chat
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GroupChatPage()),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du partage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImage(String imageData) {
    try {
      debugPrint('🔍 Processing image: ${imageData.substring(0, 100)}...');
      
      // Vérifier si c'est une URL base64 (data:image/...)
      if (imageData.startsWith('data:image/')) {
        debugPrint('📸 Loading as base64 image');
        final base64String = imageData.split(',').last;
        final bytes = base64.decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Error loading base64 image: $error');
            return _buildErrorImage();
          },
        );
      }
      // Vérifier si c'est une URL HTTP complète
      else if (imageData.startsWith('http')) {
        debugPrint('🌐 Loading as network image: $imageData');
        return Image.network(
          imageData,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Error loading network image: $imageData');
            debugPrint('❌ Error details: $error');
            return _buildErrorImage();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[100],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2E7D32),
                ),
              ),
            );
          },
        );
      }
      // Sinon, essayer comme URL relative du serveur
      else {
        final serverUrl = imageData.startsWith('/') ? '$_serverBaseUrl$imageData' : '$_serverBaseUrl/$imageData';
        debugPrint('🏠 Loading as server URL: $serverUrl');
        return Image.network(
          serverUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Error loading server image: $serverUrl');
            debugPrint('❌ Error details: $error');
            return _buildErrorImage();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[100],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2E7D32),
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error processing image data: $e');
      return _buildErrorImage();
    }
  }

  Widget _buildErrorImage() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(
        Icons.broken_image,
        color: Colors.grey,
        size: 40,
      ),
    );
  }

  // Nouvelle méthode pour créer une carte d'image élégante
  Widget _buildImageCard(String imageUrl, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de la carte avec numéro d'image
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withAlpha(26),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Image',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const Spacer(),
                  // Bouton pour agrandir l'image
                  IconButton(
                    icon: const Icon(
                      Icons.fullscreen,
                      color: Color(0xFF2E7D32),
                      size: 20,
                    ),
                    onPressed: () => _showImageFullscreen(imageUrl),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              ),
            ),
            // Contenu de l'image
            Container(
              width: double.infinity,
              height: 200,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: _buildImage(imageUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Méthode pour afficher l'image en plein écran
  void _showImageFullscreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImage(imageUrl),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E8),
      appBar: AppBar(
        title: Text(_article?['title'] ?? 'Article'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        leading: widget.fromChat ? IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour au chat',
          onPressed: () => Navigator.of(context).pop(),
        ) : null,
        actions: [
          if (_article != null) ...[
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Partager dans le chat',
              onPressed: _shareArticleToChat,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlogEditorPage(article: _article),
                ),
              ).then((_) => _fetchArticle()),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _deleteArticle();
              },
              itemBuilder: (context) => [
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _article == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Article non trouvé',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retour'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Statut de publication
                            Row(
                              children: [
                                Icon(
                                  _article!['published'] ? Icons.visibility : Icons.visibility_off,
                                  size: 20,
                                  color: _article!['published'] ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _article!['published'] ? 'Article publié' : 'Brouillon',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _article!['published'] ? Colors.green : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('dd/MM/yyyy à HH:mm').format(
                                    DateTime.parse(_article!['createdAt']),
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Titre
                            Text(
                              _article!['title'],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Résumé
                            if (_article!['summary'] != null && _article!['summary'].isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withAlpha(26),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF2E7D32).withAlpha(77),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _article!['summary'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF1B5E20),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            
                            // Tags
                            if (_article!['tags'] != null && (_article!['tags'] as List).isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (_article!['tags'] as List).map<Widget>((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D32).withAlpha(51),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF2E7D32).withAlpha(102)),
                                  ),
                                  child: Text(
                                    tag.toString(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )).toList(),
                              ),
                              const SizedBox(height: 24),
                            ],
                            
                            // Images/Médias avec design en cartes élégantes
                            if (_article!['mediaFiles'] != null && (_article!['mediaFiles'] as List).isNotEmpty) ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.photo_library_outlined,
                                        color: Color(0xFF2E7D32),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Galerie d\'images',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E7D32).withAlpha(26),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${(_article!['mediaFiles'] as List).length}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF2E7D32),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Affichage en cartes responsives
                                  ...(_article!['mediaFiles'] as List).asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final mediaItem = entry.value;
                                    
                                    debugPrint('🖼️ Processing image $index: ${mediaItem.runtimeType}');
                                    debugPrint('🖼️ Media data: $mediaItem');
                                    
                                    // Extraction de l'URL de l'image
                                    String mediaUrl;
                                    if (mediaItem is String) {
                                      mediaUrl = mediaItem;
                                    } else if (mediaItem is Map) {
                                      mediaUrl = mediaItem['url']?.toString() ?? '';
                                      debugPrint('🖼️ Extracted URL: $mediaUrl');
                                    } else {
                                      mediaUrl = mediaItem.toString();
                                    }
                                    
                                    if (mediaUrl.isEmpty) {
                                      debugPrint('❌ Empty URL for image $index');
                                      return const SizedBox.shrink();
                                    }
                                    
                                    return _buildImageCard(mediaUrl, index);
                                  }),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ],
                            
                            // Contenu HTML
                            if (_article!['content'] != null) ...[
                              Html(
                                data: _article!['content']?.toString() ?? '',
                                style: {
                                  'body': Style(
                                    fontSize: FontSize(16),
                                    color: Colors.black87,
                                  ),
                                  'h1': Style(
                                    fontSize: FontSize(24),
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                  'h2': Style(
                                    fontSize: FontSize(20),
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF388E3C),
                                  ),
                                  'h3': Style(
                                    fontSize: FontSize(18),
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                  'p': Style(
                                    fontSize: FontSize(16),
                                    color: Colors.black87,
                                  ),
                                  'ul': Style(
                                    color: Colors.black87,
                                  ),
                                  'ol': Style(
                                    color: Colors.black87,
                                  ),
                                  'li': Style(
                                    fontSize: FontSize(16),
                                    color: Colors.black87,
                                  ),
                                  'blockquote': Style(
                                    backgroundColor: const Color(0xFFE8F5E8),
                                    color: Colors.black87,
                                    padding: HtmlPaddings.all(12),
                                  ),
                                  'code': Style(
                                    backgroundColor: const Color(0xFFF5F5F5),
                                    color: Colors.black87,
                                    padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
                                  ),
                                  'pre': Style(
                                    backgroundColor: const Color(0xFFF5F5F5),
                                    color: Colors.black87,
                                    padding: HtmlPaddings.all(12),
                                  ),
                                },
                              ),
                            ],
                            
                            const SizedBox(height: 20),
                            
                            // Informations de modification
                            if (_article!['updatedAt'] != _article!['createdAt']) ...[
                              const Divider(),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Dernière modification: ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.parse(_article!['updatedAt']))}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}