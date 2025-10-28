import 'package:flutter/material.dart';
import '../media_service.dart';

class MediaStatsTab extends StatefulWidget {
  final MediaStats? stats;
  final List<MediaItem> medias;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const MediaStatsTab({
    super.key,
    this.stats,
    required this.medias,
    required this.isLoading,
    this.error,
    required this.onRefresh,
  });

  @override
  State<MediaStatsTab> createState() => _MediaStatsTabState();
}

class _MediaStatsTabState extends State<MediaStatsTab> {
  String selectedPeriod = 'all'; // all, week, month, year

  Map<String, dynamic> get computedStats {
    final medias = _getFilteredMedias();
    
    // Calculs généraux
    final totalCount = medias.length;
    final totalSize = medias.fold<int>(0, (sum, media) => sum + media.size);
    
    // Par type
    final byType = <String, Map<String, dynamic>>{};
    for (final media in medias) {
      if (!byType.containsKey(media.type)) {
        byType[media.type] = {'count': 0, 'size': 0, 'medias': <MediaItem>[]};
      }
      byType[media.type]!['count']++;
      byType[media.type]!['size'] += media.size;
      byType[media.type]!['medias'].add(media);
    }
    
    // Tendances temporelles
    final now = DateTime.now();
    final last7Days = medias.where((m) => 
      now.difference(m.createdAt).inDays <= 7
    ).length;
    final last30Days = medias.where((m) => 
      now.difference(m.createdAt).inDays <= 30
    ).length;
    
    // Plus utilisés
    final sortedByUsage = List<MediaItem>.from(medias)
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    
    // Plus gros fichiers
    final sortedBySize = List<MediaItem>.from(medias)
      ..sort((a, b) => b.size.compareTo(a.size));

    return {
      'totalCount': totalCount,
      'totalSize': totalSize,
      'byType': byType,
      'last7Days': last7Days,
      'last30Days': last30Days,
      'mostUsed': sortedByUsage.take(5).toList(),
      'largest': sortedBySize.take(5).toList(),
      'averageSize': totalCount > 0 ? totalSize / totalCount : 0,
    };
  }

  List<MediaItem> _getFilteredMedias() {
    final now = DateTime.now();
    switch (selectedPeriod) {
      case 'week':
        return widget.medias.where((m) => 
          now.difference(m.createdAt).inDays <= 7
        ).toList();
      case 'month':
        return widget.medias.where((m) => 
          now.difference(m.createdAt).inDays <= 30
        ).toList();
      case 'year':
        return widget.medias.where((m) => 
          now.difference(m.createdAt).inDays <= 365
        ).toList();
      default:
        return widget.medias;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Erreur de chargement des statistiques'),
            const SizedBox(height: 8),
            Text(widget.error!),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (widget.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Calcul des statistiques...'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sélecteur de période
            _buildPeriodSelector(),
            const SizedBox(height: 24),
            
            // Vue d'ensemble
            _buildOverviewSection(),
            const SizedBox(height: 24),
            
            // Répartition par type
            _buildTypeDistribution(),
            const SizedBox(height: 24),
            
            // Tendances temporelles
            _buildTimeTrends(),
            const SizedBox(height: 24),
            
            // Top médias
            _buildTopMedias(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Période d\'analyse',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Tout'), icon: Icon(Icons.all_inclusive, size: 16)),
                ButtonSegment(value: 'year', label: Text('Année'), icon: Icon(Icons.calendar_today, size: 16)),
                ButtonSegment(value: 'month', label: Text('Mois'), icon: Icon(Icons.calendar_month, size: 16)),
                ButtonSegment(value: 'week', label: Text('Semaine'), icon: Icon(Icons.date_range, size: 16)),
              ],
              selected: {selectedPeriod},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  selectedPeriod = selection.first;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    final stats = computedStats;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vue d\'ensemble',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total médias',
                    '${stats['totalCount']}',
                    Icons.folder_open,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Espace utilisé',
                    MediaService.formatFileSize(stats['totalSize']),
                    Icons.storage,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Taille moyenne',
                    MediaService.formatFileSize(stats['averageSize'].round()),
                    Icons.analytics,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Ajouts récents',
                    '${stats['last7Days']} (7j)',
                    Icons.trending_up,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeDistribution() {
    final stats = computedStats;
    final byType = stats['byType'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition par type',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (byType.isEmpty)
              const Center(
                child: Text('Aucune donnée disponible'),
              )
            else
              Column(
                children: byType.entries.map((entry) {
                  final type = entry.key;
                  final data = entry.value;
                  final count = data['count'] as int;
                  final size = data['size'] as int;
                  final percentage = stats['totalCount'] > 0 
                      ? (count / stats['totalCount'] * 100)
                      : 0.0;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTypeRow(type, count, size, percentage),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeRow(String type, int count, int size, double percentage) {
    final color = _getTypeColor(type);
    final icon = _getTypeIcon(type);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      type.substring(0, 1).toUpperCase() + type.substring(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$count fichier${count > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      MediaService.formatFileSize(size),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTrends() {
    final stats = computedStats;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activité récente',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTrendCard(
                    '7 derniers jours',
                    '${stats['last7Days']}',
                    'nouveaux médias',
                    Icons.date_range,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTrendCard(
                    '30 derniers jours',
                    '${stats['last30Days']}',
                    'nouveaux médias',
                    Icons.calendar_month,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMedias() {
    final stats = computedStats;
    final mostUsed = stats['mostUsed'] as List<MediaItem>;
    final largest = stats['largest'] as List<MediaItem>;
    
    return Column(
      children: [
        if (mostUsed.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Médias les plus utilisés',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...mostUsed.map((media) => _buildTopMediaItem(media, '${media.usageCount} utilisations')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        if (largest.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plus gros fichiers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...largest.map((media) => _buildTopMediaItem(media, MediaService.formatFileSize(media.size))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopMediaItem(MediaItem media, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTypeColor(media.type).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getTypeIcon(media.type),
              color: _getTypeColor(media.type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
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

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return Colors.green;
      case 'video':
        return Colors.red;
      case 'audio':
        return Colors.purple;
      case 'document':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_file;
      case 'audio':
        return Icons.audio_file;
      case 'document':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }
}