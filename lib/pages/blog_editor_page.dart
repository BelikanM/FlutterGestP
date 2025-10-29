// pages/blog_editor_page.dart
import 'package:flutter/material.dart';
import '../blog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notification_service.dart';
import '../profile_service.dart';

class BlogEditorPage extends StatefulWidget {
  final Map<String, dynamic>? article; // null pour création, article existant pour édition

  const BlogEditorPage({super.key, this.article});

  @override
  BlogEditorPageState createState() => BlogEditorPageState();
}

class BlogEditorPageState extends State<BlogEditorPage> with TickerProviderStateMixin {
  final BlogService _blogService = BlogService();
  final TextEditingController _htmlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  late TabController _tabController;
  String? _token;
  bool _isLoading = false;
  bool _isPublished = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadToken();
    if (widget.article != null) {
      _loadArticleData();
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    debugPrint('📝 Blog editor loaded with token: ${_token != null ? "✓" : "✗"}');
  }

  void _loadArticleData() {
    final article = widget.article!;
    _titleController.text = article['title'] ?? '';
    _summaryController.text = article['summary'] ?? '';
    _isPublished = article['published'] ?? false;
    
    if (article['tags'] != null) {
      _tagsController.text = (article['tags'] as List).join(', ');
    }

    // Le contenu HTML sera chargé après l'initialisation du contrôleur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (article['content'] != null) {
        _htmlController.text = article['content'];
      }
    });
  }



  Future<void> _saveArticle() async {
    if (_token == null || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir le titre'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Récupérer le contenu HTML
      final htmlContent = _htmlController.text;
      
      // Préparer les tags
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (widget.article == null) {
        // Création d'un nouvel article
        debugPrint('📝 Creating new article with title: ${_titleController.text}');
        final result = await _blogService.createArticle(
          _token!,
          title: _titleController.text,
          content: htmlContent,
          summary: _summaryController.text,
          tags: tags,
        );
        debugPrint('✅ Article created successfully: ${result['article']?['_id']}');

        // Notifier tous les utilisateurs du nouvel article
        if (_isPublished) {
          try {
            // Récupérer le nom de l'auteur
            final profileService = ProfileService();
            final userInfo = await profileService.getUserInfo(_token!);
            final authorName = userInfo['name'] ?? 'Auteur inconnu';

            await NotificationService.notifyNewArticle(
              title: _titleController.text,
              author: authorName,
            );
            debugPrint('🔔 Notification sent for new article');
          } catch (e) {
            debugPrint('❌ Error sending notification: $e');
          }
        }
      } else {
        // Mise à jour d'un article existant
        debugPrint('📝 Updating article: ${widget.article!['_id']}');
        await _blogService.updateArticle(
          _token!,
          widget.article!['_id'],
          title: _titleController.text,
          content: htmlContent,
          summary: _summaryController.text,
          tags: tags,
          published: _isPublished,
        );
        debugPrint('✅ Article updated successfully');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.article == null ? 'Article créé !' : 'Article mis à jour !'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        Navigator.pop(context, true); // Retourner true pour indiquer un succès
      }
    } catch (e) {
      if (mounted) {
        // Vérifier si l'erreur est liée à l'authentification
        if (e.toString().contains('Session expirée') || 
            e.toString().contains('Invalid token') || 
            e.toString().contains('Access denied')) {
          // Token invalide, rediriger vers la connexion
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expirée. Veuillez vous reconnecter.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Nettoyer les tokens et rediriger
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          await prefs.remove('refresh_token');
          
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false,
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E8),
      appBar: AppBar(
        title: Text(widget.article == null ? 'Nouvel Article' : 'Modifier Article'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveArticle,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.article), text: 'Contenu'),
            Tab(icon: Icon(Icons.settings), text: 'Paramètres'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet Contenu
          _buildContentTab(),
          // Onglet Paramètres
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Titre
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contenu de l\'article',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Titre de l\'article',
                      prefixIcon: const Icon(Icons.title, color: Color(0xFF2E7D32)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFE8F5E8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Éditeur HTML
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contenu de l\'article',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF2E7D32).withAlpha(77)),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        // Barre d'outils de formatage simple
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E8),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildFormatButton('Gras', () => _insertHtml('<strong>', '</strong>')),
                              const SizedBox(width: 8),
                              _buildFormatButton('Italique', () => _insertHtml('<em>', '</em>')),
                              const SizedBox(width: 8),
                              _buildFormatButton('Titre', () => _insertHtml('<h2>', '</h2>')),
                              const SizedBox(width: 8),
                              _buildFormatButton('Lien', () => _insertHtml('<a href="">', '</a>')),
                              const SizedBox(width: 8),
                              _buildFormatButton('Liste', () => _insertHtml('<ul><li>', '</li></ul>')),
                            ],
                          ),
                        ),
                        // Zone de texte principale
                        Expanded(
                          child: TextField(
                            controller: _htmlController,
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              hintText: "Écrivez votre article ici...\nVous pouvez utiliser du HTML basique comme <strong>gras</strong>, <em>italique</em>, <h2>titre</h2>, etc.",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Paramètres de publication
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paramètres de l\'article',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _summaryController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Résumé/Description courte',
                      prefixIcon: const Icon(Icons.summarize, color: Color(0xFF2E7D32)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFE8F5E8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tagsController,
                    decoration: InputDecoration(
                      labelText: 'Tags (séparés par des virgules)',
                      prefixIcon: const Icon(Icons.tag, color: Color(0xFF2E7D32)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFE8F5E8),
                      hintText: 'actualités, entreprise, innovation...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Switch pour publier
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E7D32).withAlpha(77)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.publish, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Publication',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Rendre l\'article visible publiquement',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isPublished,
                          onChanged: (value) => setState(() => _isPublished = value),
                          activeTrackColor: const Color(0xFF2E7D32),
                          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return Colors.grey;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Bouton de sauvegarde
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveArticle,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      widget.article == null ? 'Créer l\'Article' : 'Mettre à Jour',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Méthode pour insérer du HTML à la position du curseur
  void _insertHtml(String startTag, String endTag) {
    final text = _htmlController.text;
    final selection = _htmlController.selection;
    
    if (selection.isValid && !selection.isCollapsed) {
      // Il y a du texte sélectionné
      final selectedText = selection.textInside(text);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$startTag$selectedText$endTag',
      );
      _htmlController.text = newText;
      _htmlController.selection = TextSelection.collapsed(
        offset: selection.start + startTag.length + selectedText.length + endTag.length,
      );
    } else {
      // Pas de sélection, insérer à la position du curseur
      final cursorPos = selection.baseOffset;
      final newText = text.replaceRange(
        cursorPos,
        cursorPos,
        '$startTag$endTag',
      );
      _htmlController.text = newText;
      _htmlController.selection = TextSelection.collapsed(
        offset: cursorPos + startTag.length,
      );
    }
  }

  /// Bouton de formatage
  Widget _buildFormatButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }





  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    _tagsController.dispose();
    _htmlController.dispose();
    super.dispose();
  }
}