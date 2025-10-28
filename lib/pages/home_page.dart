import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../blog_service.dart';
import '../media_service.dart';
import '../profile_service.dart';
import '../role_service.dart';
import '../notification_service.dart';
import '../components/html5_media_viewer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
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
  
  List<dynamic> _articles = [];
  List<dynamic> _mediaFiles = [];
  List<dynamic> _employees = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String _errorMessage = '';
  String? _token;
  String _userName = '';

  late TabController _tabController;
  Timer? _refreshTimer;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTokenAndData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadTokenAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userName = prefs.getString('user_name') ?? 'Utilisateur';
    
    if (_token == null) {
      setState(() {
        _errorMessage = 'Token manquant. Veuillez vous reconnecter.';
        _isLoading = false;
      });
      return;
    }

    // Vérifier le rôle de l'utilisateur
    try {
      _isAdmin = await RoleService.isAdmin();
    } catch (e) {
      _isAdmin = false;
    }

    await _loadData();
  }

  Future<void> _loadData() async {
    if (_token == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final blogService = BlogService();
      final profileService = ProfileService();

      // Charger les articles
      final articles = await blogService.getArticles(_token!, limit: 10, page: 1);
      
      // Charger les médias
      final mediaResponse = await MediaService.getMedias(limit: 10);
      
      // Charger les employés si admin
      List<dynamic> employees = [];
      if (_isAdmin) {
        employees = await profileService.getEmployees(_token!);
      }

      if (mounted) {
        setState(() {
          _articles = articles;
          _mediaFiles = mediaResponse.medias.map((media) => {
            'id': media.id,
            'originalName': media.originalName,
            'type': media.type,
            'url': media.url,
            'mimetype': media.mimetype,
          }).toList();
          _employees = employees;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors du chargement: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Bonjour $_userName'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _showNotifications,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(icon: Icon(Icons.dashboard), text: 'Accueil'),
            const Tab(icon: Icon(Icons.article), text: 'Articles'),
            const Tab(icon: Icon(Icons.perm_media), text: 'Médias'),
            if (_isAdmin) const Tab(icon: Icon(Icons.people), text: 'Équipe'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(),
                    _buildArticlesTab(),
                    _buildMediasTab(),
                    if (_isAdmin) _buildTeamTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_errorMessage, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistiques rapides
            _buildStatsCards(),
            const SizedBox(height: 24),
            
            // Articles récents
            _buildSectionTitle('Articles Récents', Icons.article),
            const SizedBox(height: 12),
            _buildRecentArticles(),
            
            const SizedBox(height: 24),
            
            // Médias récents
            _buildSectionTitle('Médias Récents', Icons.perm_media),
            const SizedBox(height: 12),
            _buildRecentMedia(),
            
            if (_isAdmin) ...[
              const SizedBox(height: 24),
              // Activité de l'équipe
              _buildSectionTitle('Activité de l\'Équipe', Icons.people),
              const SizedBox(height: 12),
              _buildTeamActivity(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Articles',
            _articles.length.toString(),
            Icons.article,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Médias',
            _mediaFiles.length.toString(),
            Icons.perm_media,
            Colors.purple,
          ),
        ),
        if (_isAdmin) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Employés',
              _employees.length.toString(),
              Icons.people,
              Colors.green,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentArticles() {
    if (_articles.isEmpty) {
      return _buildEmptyState('Aucun article disponible', Icons.article);
    }

    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _articles.take(5).length,
        itemBuilder: (context, index) {
          final article = _articles[index];
          return _buildArticleCard(article);
        },
      ),
    );
  }

  Widget _buildRecentMedia() {
    if (_mediaFiles.isEmpty) {
      return _buildEmptyState('Aucun média disponible', Icons.perm_media);
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _mediaFiles.take(5).length,
        itemBuilder: (context, index) {
          final media = _mediaFiles[index];
          return _buildMediaCard(media);
        },
      ),
    );
  }

  Widget _buildTeamActivity() {
    if (_employees.isEmpty) {
      return _buildEmptyState('Aucune activité d\'équipe', Icons.people);
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _employees.take(5).length,
        itemBuilder: (context, index) {
          final employee = _employees[index];
          return _buildEmployeeCard(employee);
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(dynamic article) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _viewArticle(article),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image de l'article
              Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.purple.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.article,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title'] ?? 'Sans titre',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article['excerpt'] ?? article['content'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            article['author'] ?? 'Auteur inconnu',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
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
      ),
    );
  }

  Widget _buildMediaCard(dynamic media) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _viewMedia(media),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: _getMediaColor(media['type']).withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Icon(
                    _getMediaIcon(media['type']),
                    size: 48,
                    color: _getMediaColor(media['type']),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      media['originalName'] ?? 'Sans nom',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMediaTypeName(media['type']),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(dynamic employee) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: employee['photo'] != null && employee['photo'].isNotEmpty
                    ? MemoryImage(base64Decode(employee['photo']))
                    : null,
                child: employee['photo'] == null || employee['photo'].isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                employee['name'] ?? 'Sans nom',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                employee['position'] ?? employee['role'] ?? '',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticlesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _articles.isEmpty
          ? const Center(child: Text('Aucun article disponible'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _articles.length,
              itemBuilder: (context, index) {
                final article = _articles[index];
                return _buildFullArticleCard(article);
              },
            ),
    );
  }

  Widget _buildFullArticleCard(dynamic article) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewArticle(article),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.article, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article['title'] ?? 'Sans titre',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Par ${article['author'] ?? 'Auteur inconnu'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                article['excerpt'] ?? article['content'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _viewArticle(article),
                    icon: const Icon(Icons.read_more, size: 16),
                    label: const Text('Lire plus'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediasTab() {
    if (_mediaFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.perm_media, size: 64, color: Colors.white70),
            SizedBox(height: 16),
            Text('Aucun média disponible', 
                 style: TextStyle(fontSize: 18, color: Colors.white70)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _mediaFiles.length,
        itemBuilder: (context, index) {
          final media = _mediaFiles[index];
          return _buildLibraryStyleMediaCard(media);
        },
      ),
    );
  }

  Widget _buildLibraryStyleMediaCard(dynamic mediaData) {
    // Convertir le format de données de l'API en MediaItem
    final media = MediaItem(
      id: mediaData['_id'] ?? '',
      title: mediaData['title'] ?? mediaData['originalName'] ?? 'Sans titre',
      description: mediaData['description'] ?? '',
      url: '$_serverBaseUrl/uploads/${mediaData['filename']}',
      filename: mediaData['filename'] ?? '',
      originalName: mediaData['originalName'] ?? '',
      mimetype: mediaData['mimetype'] ?? mediaData['type'] ?? '',
      size: mediaData['size'] ?? 0,
      type: _getMediaTypeFromMimetype(mediaData['mimetype'] ?? mediaData['type'] ?? ''),
      tags: List<String>.from(mediaData['tags'] ?? []),
      uploadedBy: mediaData['uploadedBy'] ?? '',
      isPublic: mediaData['isPublic'] ?? true,
      usageCount: mediaData['usageCount'] ?? 0,
      createdAt: DateTime.tryParse(mediaData['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(mediaData['updatedAt'] ?? '') ?? DateTime.now(),
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[900],
      child: InkWell(
        onTap: () => _showLibraryMediaDetails(media),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview du média
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: _buildMediaPreview(media),
              ),
            ),
            
            // Informations du média
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      MediaService.formatFileSize(media.size),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getMediaColor(media.mimetype).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getMediaTypeName(media.mimetype),
                        style: TextStyle(
                          fontSize: 11,
                          color: _getMediaColor(media.mimetype),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(MediaItem media) {
    if (media.type == 'image') {
      return Image.network(
        media.url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[800],
          child: const Icon(Icons.image, size: 48, color: Colors.white54),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[800],
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        },
      );
    } else {
      return Container(
        color: Colors.grey[800],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getMediaIcon(media.mimetype),
                size: 48,
                color: _getMediaColor(media.mimetype),
              ),
              const SizedBox(height: 8),
              const Icon(
                Icons.play_circle_fill,
                size: 24,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      );
    }
  }

  String _getMediaTypeFromMimetype(String mimetype) {
    if (mimetype.startsWith('video/')) return 'video';
    if (mimetype.startsWith('audio/')) return 'audio';
    if (mimetype.startsWith('image/')) return 'image';
    if (mimetype == 'application/pdf') return 'document';
    return 'document';
  }











  Widget _buildTeamTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _employees.isEmpty
          ? const Center(child: Text('Aucun employé disponible'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _employees.length,
              itemBuilder: (context, index) {
                final employee = _employees[index];
                return _buildFullEmployeeCard(employee);
              },
            ),
    );
  }

  Widget _buildFullEmployeeCard(dynamic employee) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: employee['photo'] != null && employee['photo'].isNotEmpty
                  ? MemoryImage(base64Decode(employee['photo']))
                  : null,
              child: employee['photo'] == null || employee['photo'].isEmpty
                  ? const Icon(Icons.person, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee['name'] ?? 'Sans nom',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (employee['position'] != null)
                    Text(
                      employee['position'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  Text(
                    employee['email'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: employee['isActive'] == true ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                employee['isActive'] == true ? 'Actif' : 'Inactif',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMediaColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'image':
        return Colors.green;
      case 'video':
        return Colors.red;
      case 'audio':
        return Colors.orange;
      case 'document':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getMediaIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_library;
      case 'audio':
        return Icons.audio_file;
      case 'document':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getMediaTypeName(String? type) {
    switch (type?.toLowerCase()) {
      case 'image':
        return 'Image';
      case 'video':
        return 'Vidéo';
      case 'audio':
        return 'Audio';
      case 'document':
        return 'Document';
      default:
        return 'Fichier';
    }
  }

  void _viewArticle(dynamic article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(article['title'] ?? 'Article'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article['author'] != null)
                Text(
                  'Par ${article['author']}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(height: 16),
              Text(article['content'] ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showLibraryMediaDetails(MediaItem media) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      media.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Html5MediaViewer(
                  media: media,
                  fit: BoxFit.contain,
                  showControls: true,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (media.description.isNotEmpty) ...[
                      const Text(
                        'Description:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        media.description,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Text(
                          'Taille: ${MediaService.formatFileSize(media.size)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Type: ${media.mimetype}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    if (media.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        children: media.tags
                            .map((tag) => Chip(
                                  label: Text(tag),
                                  backgroundColor: Colors.blue.withValues(alpha: 0.2),
                                  labelStyle: const TextStyle(color: Colors.white),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewMedia(dynamic media) {
    final mediaType = (media['type'] as String? ?? '').toLowerCase();
    final mediaUrl = '$_serverBaseUrl/uploads/${media['filename']}';
    final mediaName = media['originalName'] as String;
    final filename = (media['filename'] as String? ?? '').toLowerCase();
    
    // Debug - afficher le type de média (développement seulement)
    // print('Type de média: "$mediaType", Filename: "$filename"');
    
    // Détection améliorée du type de média
    bool isVideo = mediaType.startsWith('video/') || 
                   filename.endsWith('.mp4') || 
                   filename.endsWith('.avi') || 
                   filename.endsWith('.mkv') || 
                   filename.endsWith('.mov') ||
                   filename.endsWith('.wmv') ||
                   filename.endsWith('.flv');
                   
    bool isAudio = mediaType.startsWith('audio/') || 
                   filename.endsWith('.mp3') || 
                   filename.endsWith('.wav') || 
                   filename.endsWith('.ogg') || 
                   filename.endsWith('.aac') ||
                   filename.endsWith('.flac') ||
                   filename.endsWith('.m4a');
                   
    bool isImage = mediaType.startsWith('image/') || 
                   mediaType == 'image' ||
                   filename.endsWith('.jpg') || 
                   filename.endsWith('.jpeg') || 
                   filename.endsWith('.png') || 
                   filename.endsWith('.gif') || 
                   filename.endsWith('.bmp') ||
                   filename.endsWith('.webp') ||
                   filename.endsWith('.svg');
                   
    bool isPdf = mediaType == 'application/pdf' || 
                 filename.endsWith('.pdf');
    
    if (isVideo || isAudio) {
      _showMediaPlayerDialog(mediaUrl, mediaName, mediaType);
    } else if (isImage) {
      _showImageViewer(mediaUrl, mediaName);
    } else if (isPdf) {
      _showPdfViewer(mediaUrl, mediaName);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Type de média non supporté: "$mediaType" ($filename)'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showMediaPlayerDialog(String mediaUrl, String mediaName, String mediaType) {
    final player = Player();
    VideoController? controller;
    
    if (mediaType.startsWith('video/')) {
      controller = VideoController(player);
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      mediaName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      player.dispose();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: mediaType.startsWith('video/') && controller != null
                    ? Video(controller: controller)
                    : mediaType.startsWith('audio/')
                        ? _buildAudioPlayer(player, mediaName)
                        : const Center(child: Text('Lecteur non disponible')),
              ),
            ],
          ),
        ),
      ),
    );

    // Charger le média
    player.open(Media(mediaUrl));
  }

  Widget _buildAudioPlayer(Player player, String mediaName) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.music_note,
            size: 100,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          Text(
            mediaName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          StreamBuilder<Duration>(
            stream: player.stream.position,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: player.stream.duration,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;
                  return Column(
                    children: [
                      Slider(
                        value: duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0.0,
                        onChanged: (value) {
                          final seekPosition = Duration(
                            milliseconds: (value * duration.inMilliseconds).round(),
                          );
                          player.seek(seekPosition);
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position)),
                          Text(_formatDuration(duration)),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: 36,
                onPressed: () {
                  player.seek(Duration.zero);
                },
              ),
              const SizedBox(width: 16),
              StreamBuilder<bool>(
                stream: player.stream.playing,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    iconSize: 48,
                    onPressed: () {
                      if (isPlaying) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    },
                  );
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.stop),
                iconSize: 36,
                onPressed: () {
                  player.stop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showImageViewer(String imageUrl, String imageName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        imageName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 64, color: Colors.red),
                          SizedBox(height: 16),
                          Text('Erreur de chargement de l\'image'),
                        ],
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPdfViewer(String pdfUrl, String pdfName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pdfName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Visualisation PDF'),
                      const SizedBox(height: 8),
                      Text(pdfName),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Ouvrir le PDF dans le navigateur
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Ouverture de $pdfName...'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Ouvrir dans le navigateur'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications, color: Colors.blue),
              SizedBox(width: 8),
              Text('Centre de Notifications'),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Options de notifications
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paramètres de Notification',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final success = await NotificationService.subscribeToNotifications();
                                if (!mounted) return;
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(success 
                                        ? '✅ Abonné aux notifications' 
                                        : '❌ Erreur d\'abonnement'),
                                    backgroundColor: success ? Colors.green : Colors.red,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.notifications_active),
                              label: const Text('S\'abonner'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final success = await NotificationService.unsubscribeFromNotifications();
                                if (!mounted) return;
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(success 
                                        ? '✅ Désabonné des notifications' 
                                        : '❌ Erreur de désabonnement'),
                                    backgroundColor: success ? Colors.orange : Colors.red,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.notifications_off),
                              label: const Text('Se désabonner'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Test des notifications
                if (_isAdmin) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tests de Notification (Admin)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  await NotificationService.notifyNewArticle(
                                    title: 'Article de Test',
                                    author: _userName,
                                  );
                                  if (!mounted) return;
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('📝 Notification article test envoyée'),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.article),
                                label: const Text('Test Article'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  await NotificationService.notifyNewMedia(
                                    filename: 'test-media.mp4',
                                    type: 'video/mp4',
                                    uploadedBy: _userName,
                                  );
                                  if (!mounted) return;
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('🎥 Notification média test envoyée'),
                                      backgroundColor: Colors.purple,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.perm_media),
                                label: const Text('Test Média'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Historique des notifications récentes
                const Text(
                  'Notifications Récentes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.article, color: Colors.blue),
                          title: const Text('Nouvel article publié'),
                          subtitle: const Text('Il y a 2 heures'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Article', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.perm_media, color: Colors.purple),
                          title: const Text('Nouveau média ajouté'),
                          subtitle: const Text('Il y a 4 heures'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Média', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.people, color: Colors.green),
                          title: const Text('Nouvel employé ajouté'),
                          subtitle: const Text('Hier'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Équipe', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}