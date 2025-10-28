import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../blog_service.dart';
import '../media_service.dart';
import '../profile_service.dart';
import '../role_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
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
      backgroundColor: const Color(0xFFE8F5E8),
      appBar: AppBar(
        title: Text('Bonjour $_userName'),
        backgroundColor: const Color(0xFF2E7D32),
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
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _mediaFiles.isEmpty
          ? const Center(child: Text('Aucun média disponible'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _mediaFiles.length,
              itemBuilder: (context, index) {
                final media = _mediaFiles[index];
                return _buildFullMediaCard(media);
              },
            ),
    );
  }

  Widget _buildFullMediaCard(dynamic media) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewMedia(media),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    colors: [
                      _getMediaColor(media['type']).withValues(alpha: 0.3),
                      _getMediaColor(media['type']).withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getMediaIcon(media['type']),
                    size: 64,
                    color: _getMediaColor(media['type']),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media['originalName'] ?? 'Sans nom',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getMediaColor(media['type']).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getMediaTypeName(media['type']),
                        style: TextStyle(
                          fontSize: 11,
                          color: _getMediaColor(media['type']),
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

  void _viewMedia(dynamic media) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ouverture de ${media['originalName']}'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.article, color: Colors.blue),
              title: Text('Nouvel article publié'),
              subtitle: Text('Il y a 2 heures'),
            ),
            ListTile(
              leading: Icon(Icons.perm_media, color: Colors.purple),
              title: Text('Nouveau média ajouté'),
              subtitle: Text('Il y a 4 heures'),
            ),
          ],
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
}