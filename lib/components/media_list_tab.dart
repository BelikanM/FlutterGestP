import 'package:flutter/material.dart';
import '../media_service.dart';
import '../components/html5_media_viewer.dart';

class MediaListTab extends StatefulWidget {
  final List<MediaItem> medias;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;
  final bool hasNextPage;
  final Function(MediaItem) onMediaTap;
  final Function(MediaItem) onMediaEdit;
  final Function(MediaItem) onMediaDelete;

  const MediaListTab({
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
  State<MediaListTab> createState() => _MediaListTabState();
}

class _MediaListTabState extends State<MediaListTab> {
  String sortBy = 'date_desc'; // date_asc, date_desc, name_asc, name_desc, size_asc, size_desc
  String filterType = 'all';
  String searchQuery = '';

  List<MediaItem> get processedMedias {
    var filtered = widget.medias;
    
    // Filtrage par type
    if (filterType != 'all') {
      filtered = filtered.where((media) => media.type == filterType).toList();
    }
    
    // Filtrage par recherche
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((media) => 
        media.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
        media.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
        media.originalName.toLowerCase().contains(searchQuery.toLowerCase()) ||
        media.tags.any((tag) => tag.toLowerCase().contains(searchQuery.toLowerCase()))
      ).toList();
    }
    
    // Tri
    switch (sortBy) {
      case 'date_asc':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'date_desc':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'name_asc':
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'name_desc':
        filtered.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'size_asc':
        filtered.sort((a, b) => a.size.compareTo(b.size));
        break;
      case 'size_desc':
        filtered.sort((a, b) => b.size.compareTo(a.size));
        break;
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre d'outils
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              // Recherche
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Rechercher par nom, description, tags...',
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
              
              // Filtres et tri
              Row(
                children: [
                  // Filtre par type
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: filterType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tous les types')),
                        DropdownMenuItem(value: 'image', child: Text('Images')),
                        DropdownMenuItem(value: 'video', child: Text('Vidéos')),
                        DropdownMenuItem(value: 'audio', child: Text('Audio')),
                        DropdownMenuItem(value: 'document', child: Text('Documents')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          filterType = value ?? 'all';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Tri
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: sortBy,
                      decoration: const InputDecoration(
                        labelText: 'Trier par',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'date_desc', child: Text('Plus récent')),
                        DropdownMenuItem(value: 'date_asc', child: Text('Plus ancien')),
                        DropdownMenuItem(value: 'name_asc', child: Text('Nom A-Z')),
                        DropdownMenuItem(value: 'name_desc', child: Text('Nom Z-A')),
                        DropdownMenuItem(value: 'size_desc', child: Text('Plus gros')),
                        DropdownMenuItem(value: 'size_asc', child: Text('Plus petit')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          sortBy = value ?? 'date_desc';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Liste des médias
        Expanded(
          child: _buildListContent(),
        ),
      ],
    );
  }

  Widget _buildListContent() {
    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Erreur de chargement', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.error!, textAlign: TextAlign.center),
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

    final processed = processedMedias;

    if (processed.isEmpty && !widget.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchQuery.isNotEmpty || filterType != 'all' 
                  ? Icons.search_off 
                  : Icons.list_alt,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty || filterType != 'all'
                  ? 'Aucun résultat trouvé'
                  : 'Aucun média à afficher',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: processed.length + (widget.hasNextPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= processed.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final media = processed[index];
          return _buildMediaListItem(media);
        },
      ),
    );
  }

  Widget _buildMediaListItem(MediaItem media) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => widget.onMediaTap(media),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Aperçu miniature
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                clipBehavior: Clip.antiAlias,
                child: Html5MediaViewer(
                  media: media,
                  fit: BoxFit.cover,
                  showControls: false,
                ),
              ),
              const SizedBox(width: 12),
              
              // Informations principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre et type
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            media.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTypeColor(media.type),
                            borderRadius: BorderRadius.circular(12),
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
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Description
                    if (media.description.isNotEmpty) ...[
                      Text(
                        media.description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    // Métadonnées
                    Row(
                      children: [
                        Icon(Icons.insert_drive_file, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          media.originalName,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.data_usage, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          MediaService.formatFileSize(media.size),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(media.createdAt),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Tags
                    if (media.tags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: media.tags.map((tag) => 
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        ).toList(),
                      ),
                  ],
                ),
              ),
              
              // Actions
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () => widget.onMediaTap(media),
                    tooltip: 'Voir',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => widget.onMediaEdit(media),
                    tooltip: 'Modifier',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => widget.onMediaDelete(media),
                    tooltip: 'Supprimer',
                  ),
                ],
              ),
            ],
          ),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inMinutes}m';
    }
  }
}