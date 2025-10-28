// user_dashboard_content.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../blog_service.dart';
import '../media_service.dart';
import '../pages/blog_detail_page.dart';

import '../components/html5_media_viewer.dart';
import 'social_feed_widget.dart';

class UserDashboardContent extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  
  const UserDashboardContent({super.key, this.onNavigateToTab});

  @override
  UserDashboardContentState createState() => UserDashboardContentState();
}

class UserDashboardContentState extends State<UserDashboardContent> {
  final BlogService _blogService = BlogService();
  String? _token;
  List<dynamic> _recentArticles = [];
  MediaStats? _mediaStats;
  List<MediaItem> _recentMedias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    
    if (_token != null) {
      await Future.wait([
        _loadRecentArticles(),
        _loadMediaStats(),
        _loadRecentMedias(),
      ]);
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecentArticles() async {
    try {
      final articles = await _blogService.getArticles(_token!, page: 1, limit: 5);
      if (mounted) {
        setState(() => _recentArticles = articles);
      }
    } catch (e) {
      debugPrint('Erreur chargement articles: $e');
    }
  }

  Future<void> _loadMediaStats() async {
    try {
      final stats = await MediaService.getMediaStats();
      if (mounted) {
        setState(() => _mediaStats = stats);
      }
    } catch (e) {
      debugPrint('Erreur chargement stats médias: $e');
    }
  }

  Future<void> _loadRecentMedias() async {
    try {
      final response = await MediaService.getMedias(page: 1, limit: 6);
      if (mounted) {
        setState(() => _recentMedias = response.medias);
      }
    } catch (e) {
      debugPrint('Erreur chargement médias récents: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // En-tête avec onglets
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF2E7D32),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF2E7D32),
              tabs: const [
                Tab(
                  icon: Icon(Icons.feed),
                  text: 'Actualités',
                ),
                Tab(
                  icon: Icon(Icons.dashboard),
                  text: 'Vue d\'ensemble',
                ),
              ],
            ),
          ),
          
          // Contenu des onglets
          Expanded(
            child: TabBarView(
              children: [
                // Onglet Feed Social
                SocialFeedWidget(
                  onRefresh: _loadData,
                ),
                
                // Onglet Vue d'ensemble (ancien dashboard)
                RefreshIndicator(
                  onRefresh: _loadData,
                  color: const Color(0xFF2E7D32),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête de bienvenue
                        _buildWelcomeHeader(),
                        const SizedBox(height: 24),
                        
                        // Statistiques rapides
                        _buildQuickStats(),
                        const SizedBox(height: 24),
                        
                        // Articles récents
                        _buildRecentArticles(),
                        const SizedBox(height: 24),
                        
                        // Médias récents
                        _buildRecentMedias(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.dashboard,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tableau de Bord',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bienvenue ! Découvrez les dernières actualités et contenus.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.article,
            title: 'Articles',
            value: '${_recentArticles.length}+',
            color: Colors.blue,
            onTap: () => _navigateToTab(2), // Blog tab
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.photo_library,
            title: 'Médias',
            value: '${_mediaStats?.totalMedias ?? 0}',
            color: Colors.orange,
            onTap: () => _navigateToTab(1), // Bibliothèque tab
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentArticles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.article, color: Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            const Text(
              'Articles Récents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _navigateToTab(2),
              child: const Text('Voir tout →'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentArticles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.article, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'Aucun article disponible',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          ...(_recentArticles.take(3).map((article) => _buildArticleCard(article))),
      ],
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article) {
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(article['createdAt']?.toString() ?? DateTime.now().toIso8601String());
    } catch (e) {
      createdAt = DateTime.now();
    }
    final formattedDate = DateFormat('dd MMM yyyy').format(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlogDetailPage(articleId: article['_id']?.toString() ?? ''),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    article['published'] == true ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFF2E7D32),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article['title']?.toString() ?? 'Sans titre',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (article['summary'] != null && article['summary'].toString().isNotEmpty)
                        Text(
                          article['summary']?.toString() ?? '',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentMedias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library, color: Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            const Text(
              'Médias Récents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _navigateToTab(1),
              child: const Text('Voir tout →'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentMedias.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.photo_library, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'Aucun média disponible',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentMedias.length,
              itemBuilder: (context, index) {
                final media = _recentMedias[index];
                return Container(
                  width: 100,
                  margin: EdgeInsets.only(right: index < _recentMedias.length - 1 ? 12 : 0),
                  child: GestureDetector(
                    onTap: () => _showMediaViewer(media),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildMediaPreview(media),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                media.title,
                                style: const TextStyle(fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMediaPreview(MediaItem media) {
    if (media.type.startsWith('image/')) {
      return Image.network(
        media.url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else if (media.type.startsWith('video/')) {
      return Container(
        color: Colors.black.withValues(alpha: 0.1),
        child: const Icon(Icons.play_circle_outline, size: 32, color: Colors.grey),
      );
    } else {
      return Container(
        color: Colors.grey[100],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getFileIcon(media.type), size: 24, color: Colors.grey[600]),
            const SizedBox(height: 4),
            Text(
              media.type.split('/').last.toUpperCase(),
              style: TextStyle(fontSize: 8, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  void _showMediaViewer(MediaItem media) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Html5MediaViewer(media: media),
      ),
    );
  }

  void _navigateToTab(int tabIndex) {
    // Utilise le callback si disponible, sinon ne fait rien
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(tabIndex);
    }
  }
}