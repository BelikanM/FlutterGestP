import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../media_service.dart';
import '../components/html5_media_viewer.dart';
import '../components/media_gallery_tab.dart';
import '../components/media_list_tab.dart';
import '../components/media_stats_tab.dart';
import '../components/media_settings_tab.dart';
import '../widgets/background_pattern.dart';
import 'media_test_page.dart';

class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({super.key});

  @override
  MediaLibraryPageState createState() => MediaLibraryPageState();
}

class MediaLibraryPageState extends State<MediaLibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MediaItem> medias = [];
  bool isLoading = true;
  String? error;
  
  // Filtres
  String selectedType = 'all';
  String searchQuery = '';
  List<String> selectedTags = [];
  
  // Pagination
  int currentPage = 1;
  bool hasNextPage = false;
  
  // Statistiques
  MediaStats? stats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadMedias();
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedias({bool reset = false}) async {
    if (reset) {
      currentPage = 1;
      medias.clear();
    }

    if (mounted) {
      setState(() {
        if (reset) isLoading = true;
        error = null;
      });
    }

    try {
      final response = await MediaService.getMedias(
        type: selectedType,
        search: searchQuery.isNotEmpty ? searchQuery : null,
        tags: selectedTags.isNotEmpty ? selectedTags : null,
        page: currentPage,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            medias = response.medias;
          } else {
            medias.addAll(response.medias);
          }
          hasNextPage = response.pagination.page < response.pagination.pages;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final mediaStats = await MediaService.getMediaStats();
      if (mounted) {
        setState(() {
          stats = mediaStats;
        });
      }
    } catch (e) {
      // Erreur stats: $e
    }
  }

  Future<void> _uploadMedias() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      await _showUploadDialog(result.files);
    }
  }

  Future<void> _showUploadDialog(List<PlatformFile> files) async {
    final titles = <String>[];
    final descriptions = <String>[];
    final tags = <String>[];

    for (int i = 0; i < files.length; i++) {
      titles.add(files[i].name);
      descriptions.add('');
      tags.add('');
    }

    await showDialog(
      context: context,
      builder: (context) => _UploadDialog(
        files: files,
        titles: titles,
        descriptions: descriptions,
        tags: tags,
        onUpload: () async {
          // Afficher un dialogue de progression
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => PopScope(
                canPop: false,
                child: AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Téléversement en cours...\n${files.length} fichier(s)',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cela peut prendre quelques instants selon votre connexion',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          
          try {
            await MediaService.uploadMedias(
              files: files,
              titles: titles,
              descriptions: descriptions,
              tags: tags,
            );
            
            // Fermer le dialogue de progression
            if (context.mounted) {
              Navigator.pop(context);
            }
            
            _loadMedias(reset: true);
            _loadStats();
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ ${files.length} média(s) téléversé(s) avec succès'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            // Fermer le dialogue de progression
            if (context.mounted) {
              Navigator.pop(context);
            }
            
            if (context.mounted) {
              final errorMessage = e.toString().replaceAll('Exception:', '').trim();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Erreur: $errorMessage'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'Réessayer',
                    textColor: Colors.white,
                    onPressed: () => _showUploadDialog(files),
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteMedia(MediaItem media) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le média'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${media.title}" ?'),
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

    if (confirm == true) {
      try {
        await MediaService.deleteMedia(media.id);
        _loadMedias(reset: true);
        _loadStats();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Média supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }



  void _showMediaDetails(MediaItem media) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      media.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editMedia(media),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteMedia(media);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
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
              _buildMediaInfo(media),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaInfo(MediaItem media) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (media.description.isNotEmpty) ...[
          Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(media.description),
          const SizedBox(height: 8),
        ],
        Text('Taille: ${MediaService.formatFileSize(media.size)}'),
        Text('Type: ${media.mimetype}'),
        if (media.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: media.tags
                .map((tag) => Chip(
                      label: Text(tag),
                      backgroundColor: Colors.blue.withValues(alpha: 0.2),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  void _editMedia(MediaItem media) {
    showDialog(
      context: context,
      builder: (context) => _EditMediaDialog(
        media: media,
        onSave: (updatedMedia) {
          // Rafraîchir la liste après modification
          _loadMedias(reset: true);
          _loadStats();
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Média mis à jour avec succès'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CSSBackgroundPattern(
      backgroundColor: const Color(0xFF0A0A0A),
      patternType: CSSPatternType.gridLines,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Bibliothèque Média'),
        actions: [
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'Test HTML5',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MediaTestPage(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.grid_view), text: 'Galerie'),
            Tab(icon: Icon(Icons.list), text: 'Liste'),
            Tab(icon: Icon(Icons.analytics), text: 'Statistiques'),
            Tab(icon: Icon(Icons.settings), text: 'Paramètres'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Galerie avec notre nouveau composant
          MediaGalleryTab(
            medias: medias,
            isLoading: isLoading,
            error: error,
            hasNextPage: hasNextPage,
            onRefresh: () => _loadMedias(reset: true),
            onLoadMore: () {
              currentPage++;
              _loadMedias();
            },
            onMediaTap: _showMediaDetails,
            onMediaDelete: _deleteMedia,
            onMediaEdit: _editMedia,
          ),
          
          // Liste avec notre nouveau composant  
          MediaListTab(
            medias: medias,
            isLoading: isLoading,
            error: error,
            hasNextPage: hasNextPage,
            onRefresh: () => _loadMedias(reset: true),
            onLoadMore: () {
              currentPage++;
              _loadMedias();
            },
            onMediaTap: _showMediaDetails,
            onMediaDelete: _deleteMedia,
            onMediaEdit: _editMedia,
          ),
          
          // Statistiques avec notre nouveau composant
          MediaStatsTab(
            stats: stats,
            medias: medias,
            isLoading: isLoading,
            error: error,
            onRefresh: () {
              _loadMedias(reset: true);
              _loadStats();
            },
          ),
          
          // Paramètres avec notre nouveau composant
          MediaSettingsTab(
            isLoading: isLoading,
            error: error,
            onRefresh: () => _loadStats(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadMedias,
        tooltip: 'Ajouter des médias',
        child: const Icon(Icons.add),
      ),
    ), // Fermeture Scaffold
    ); // Fermeture CSSBackgroundPattern
  } // Fermeture méthode build
}

class _EditMediaDialog extends StatefulWidget {
  final MediaItem media;
  final Function(MediaItem) onSave;

  const _EditMediaDialog({
    required this.media,
    required this.onSave,
  });

  @override
  EditMediaDialogState createState() => EditMediaDialogState();
}

class EditMediaDialogState extends State<_EditMediaDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _tagsController;
  bool _isPublic = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.media.title);
    _descriptionController = TextEditingController(text: widget.media.description);
    _tagsController = TextEditingController(text: widget.media.tags.join(', '));
    _isPublic = widget.media.isPublic;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le titre est obligatoire'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isSaving = true;
      });
    }

    try {
      final updatedMedia = await MediaService.updateMedia(
        id: widget.media.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        tags: _tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
        isPublic: _isPublic,
      );

      widget.onSave(updatedMedia);
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('Éditer le média'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Aperçu du média
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: widget.media.type == 'image'
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.media.url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.error, size: 48),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            MediaService.getMediaIcon(widget.media.type),
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.media.originalName,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Formulaire d'édition
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (séparés par des virgules)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
                hintText: 'photo, vacances, famille...',
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),

            // Switch pour visibilité publique
            SwitchListTile(
              title: const Text('Média public'),
              subtitle: const Text('Visible par tous les utilisateurs'),
              value: _isPublic,
              onChanged: (value) {
                setState(() {
                  _isPublic = value;
                });
              },
              secondary: Icon(
                _isPublic ? Icons.public : Icons.lock,
                color: _isPublic ? Colors.green : Colors.orange,
              ),
            ),

            const SizedBox(height: 16),

            // Informations du fichier
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informations du fichier',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.file_present, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(MediaService.formatFileSize(widget.media.size)),
                      const SizedBox(width: 16),
                      Icon(Icons.category, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(widget.media.type.toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('Créé le ${_formatDate(widget.media.createdAt)}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _UploadDialog extends StatefulWidget {
  final List<PlatformFile> files;
  final List<String> titles;
  final List<String> descriptions;
  final List<String> tags;
  final VoidCallback onUpload;

  const _UploadDialog({
    required this.files,
    required this.titles,
    required this.descriptions,
    required this.tags,
    required this.onUpload,
  });

  @override
  _UploadDialogState createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  bool isUploading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Télécharger ${widget.files.length} fichier(s)'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.files.length,
                itemBuilder: (context, index) {
                  final file = widget.files[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Titre',
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController(
                                text: widget.titles[index]),
                            onChanged: (value) => widget.titles[index] = value,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController(
                                text: widget.descriptions[index]),
                            onChanged: (value) =>
                                widget.descriptions[index] = value,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Tags (séparés par des virgules)',
                              border: OutlineInputBorder(),
                            ),
                            controller:
                                TextEditingController(text: widget.tags[index]),
                            onChanged: (value) => widget.tags[index] = value,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isUploading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: isUploading
              ? null
              : () async {
                  if (mounted) {
                    setState(() {
                      isUploading = true;
                    });
                  }
                  widget.onUpload();
                  Navigator.pop(context);
                },
          child: isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Télécharger'),
        ),
      ],
    );
  }
}