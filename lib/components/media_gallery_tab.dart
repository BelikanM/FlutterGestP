import 'package:flutter/material.dart';
import '../media_service.dart';
import '../components/html5_media_viewer.dart';

class MediaGalleryTab extends StatefulWidget {
  final List<MediaItem> medias;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;
  final bool hasNextPage;
  final Function(MediaItem) onMediaTap;
  final Function(MediaItem) onMediaEdit;
  final Function(MediaItem) onMediaDelete;

  const MediaGalleryTab({
    super.key,
    required this.medias,
    required this.isLoading,
    this.error,
    required this.onRefresh,
    required this.onLoadMore,
    required this.hasNextPage,
    required this.onMediaTap,
    required this.onMediaEdit,
    required this.onMediaDelete,
  });

  @override
  State<MediaGalleryTab> createState() => _MediaGalleryTabState();
}

class _MediaGalleryTabState extends State<MediaGalleryTab> {
  String selectedFilter = 'all';
  String searchQuery = '';

  List<MediaItem> get filteredMedias {
    var filtered = widget.medias;
    
    // Filtrage par type
    if (selectedFilter != 'all') {
      filtered = filtered.where((media) => media.type == selectedFilter).toList();
    }
    
    // Filtrage par recherche
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((media) => 
        media.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
        media.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
        media.tags.any((tag) => tag.toLowerCase().contains(searchQuery.toLowerCase()))
      ).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre de recherche et filtres
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              // Barre de recherche
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Rechercher dans vos médias...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              
              // Filtres par type
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'Tout', Icons.all_inclusive),
                    const SizedBox(width: 8),
                    _buildFilterChip('image', 'Images', Icons.image),
                    const SizedBox(width: 8),
                    _buildFilterChip('video', 'Vidéos', Icons.video_library),
                    const SizedBox(width: 8),
                    _buildFilterChip('audio', 'Audio', Icons.audio_file),
                    const SizedBox(width: 8),
                    _buildFilterChip('document', 'Documents', Icons.description),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Contenu principal
        Expanded(
          child: _buildGalleryContent(),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String type, String label, IconData icon) {
    final isSelected = selectedFilter == type;
    return FilterChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedFilter = type;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[700],
    );
  }

  Widget _buildGalleryContent() {
    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
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

    final filtered = filteredMedias;

    if (filtered.isEmpty && !widget.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchQuery.isNotEmpty || selectedFilter != 'all' 
                  ? Icons.search_off 
                  : Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty || selectedFilter != 'all'
                  ? 'Aucun média correspondant'
                  : 'Aucun média dans votre bibliothèque',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty || selectedFilter != 'all'
                  ? 'Essayez de modifier vos critères de recherche'
                  : 'Commencez par ajouter vos premiers médias',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            if (searchQuery.isEmpty && selectedFilter == 'all') ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Trigger upload
                },
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Ajouter des médias'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(context),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: filtered.length + (widget.hasNextPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= filtered.length) {
            // Loading indicator pour pagination
            return Card(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            );
          }

          final media = filtered[index];
          return _buildMediaCard(media);
        },
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 5;
    if (width > 800) return 4;
    if (width > 600) return 3;
    return 2;
  }

  Widget _buildMediaCard(MediaItem media) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => widget.onMediaTap(media),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Zone d'aperçu média
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Html5MediaViewer(
                        media: media,
                        fit: BoxFit.cover,
                        showControls: false,
                      ),
                    ),
                    
                    // Overlay avec type de média
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTypeColor(media.type).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(media.type),
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              media.type.toUpperCase(),
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
                    
                    // Menu d'actions
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white, size: 16),
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                widget.onMediaEdit(media);
                                break;
                              case 'delete':
                                widget.onMediaDelete(media);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Text('Modifier'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Supprimer', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Informations du média
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          media.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          MediaService.formatFileSize(media.size),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Tags
                    if (media.tags.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 2,
                              children: media.tags.take(2).map((tag) => 
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 8,
                                    ),
                                  ),
                                )
                              ).toList(),
                            ),
                          ),
                        ],
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