import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../media_service.dart';
import '../utils/url_helper.dart';
import 'simple_video_player.dart';
import 'simple_audio_player.dart';
import 'pdf_viewer_widget.dart';
import 'mediakit_video_player.dart';
import 'mediakit_audio_player.dart';
import 'android_video_player_screen.dart';
import 'android_audio_player_screen.dart';

/// Widget d'affichage HTML5 pour tous types de médias
class Html5MediaViewer extends StatefulWidget {
  final MediaItem media;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool showControls;
  final bool autoPlay;
  final bool loop;

  const Html5MediaViewer({
    super.key,
    required this.media,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.showControls = true,
    this.autoPlay = false,
    this.loop = false,
  });

  @override
  State<Html5MediaViewer> createState() => _Html5MediaViewerState();
}

class _Html5MediaViewerState extends State<Html5MediaViewer> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkMediaAvailability();
  }

  void _checkMediaAvailability() async {
    try {
      // Simuler une vérification de disponibilité
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Erreur de chargement: $e';
        });
      }
    }
  }

  String _getFullMediaUrl(String url) {
    final fullUrl = UrlHelper.getFullUrl(url);
    
    // Debug: Afficher l'URL construite
    debugPrint('🔗 Media URL: $url → $fullUrl');
    return fullUrl;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }

    return _buildMediaByType();
  }

  Widget _buildMediaByType() {
    switch (widget.media.type.toLowerCase()) {
      case 'image':
        return _buildImageViewer();
      case 'video':
        return _buildVideoViewer();
      case 'audio':
        return _buildAudioViewer();
      case 'document':
        return _buildDocumentViewer();
      default:
        return _buildGenericViewer();
    }
  }

  Widget _buildImageViewer() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _getFullMediaUrl(widget.media.url),
          fit: widget.fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                  const SizedBox(height: 8),
                  const Text('Chargement de l\'image...'),
                ],
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[100],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Impossible d\'afficher l\'image'),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoViewer() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Platform.isWindows
          ? MediaKitVideoPlayer(
              media: widget.media,
              width: widget.width,
              height: widget.height,
            )
          : Platform.isAndroid
              ? _buildAndroidVideoFallback()
              : SimpleVideoPlayer(
                  media: widget.media,
                  showControls: widget.showControls,
                  autoPlay: widget.autoPlay,
                ),
    );
  }

  /// Fallback pour Android - Affichage statique avec bouton de lecture externe
  Widget _buildAndroidVideoFallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Stack(
        children: [
          // Fond avec icône vidéo
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_filled,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.media.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Appuyez pour ouvrir dans le lecteur système',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Bouton invisible pour toute la surface
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openVideoInSystemPlayer(),
                child: Container(),
              ),
            ),
          ),
          
          // Badge type fichier
          if (widget.media.originalName.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.media.originalName.split('.').last.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Fallback pour Android Audio - Affichage statique avec bouton de lecture
  Widget _buildAndroidAudioFallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple[800]!,
            Colors.blue[800]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[600]!, width: 1),
      ),
      child: Stack(
        children: [
          // Fond avec icône audio
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.music_note,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    widget.media.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Appuyez pour écouter',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Bouton invisible pour toute la surface
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openAudioInSystemPlayer(),
                child: Container(),
              ),
            ),
          ),
          
          // Badge type fichier
          if (widget.media.originalName.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.media.originalName.split('.').last.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioViewer() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Platform.isWindows
          ? MediaKitAudioPlayer(
              media: widget.media,
              width: widget.width,
              height: widget.height,
              showControls: widget.showControls,
              autoPlay: widget.autoPlay,
            )
          : Platform.isAndroid
              ? _buildAndroidAudioFallback()
              : GestureDetector(
                  onTap: () => _openAudioInBrowser(),
                  child: SimpleAudioPlayer(
                    media: widget.media,
                    showControls: widget.showControls,
                    autoPlay: widget.autoPlay,
                  ),
                ),
    );
  }

  Widget _buildDocumentViewer() {
    final extension = widget.media.originalName.split('.').last.toLowerCase();
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Prévisualisation du contenu du document
            _buildDocumentContentPreview(extension),
            
            // Overlay avec informations et bouton d'ouverture
            if (widget.showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.media.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            extension.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            MediaService.formatFileSize(widget.media.size),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (extension == 'pdf') {
                            _openPdfViewer();
                          } else {
                            _openDocumentInBrowser();
                          }
                        },
                        icon: Icon(extension == 'pdf' ? Icons.picture_as_pdf : Icons.open_in_browser, size: 16),
                        label: Text(extension == 'pdf' ? 'Voir PDF' : 'Ouvrir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: extension == 'pdf' ? Colors.red[600] : Colors.blue[600],
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 32),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Version simplifiée pour la galerie
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    extension.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericViewer() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            widget.media.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.media.originalName,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _openGenericInBrowser(),
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );
  }

  Widget _getDocumentIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return const Icon(Icons.picture_as_pdf, size: 48, color: Colors.red);
      case 'doc':
      case 'docx':
        return const Icon(Icons.description, size: 48, color: Colors.blue);
      case 'xls':
      case 'xlsx':
        return const Icon(Icons.grid_on, size: 48, color: Colors.green);
      case 'ppt':
      case 'pptx':
        return const Icon(Icons.slideshow, size: 48, color: Colors.orange);
      case 'txt':
        return const Icon(Icons.text_snippet, size: 48, color: Colors.grey);
      default:
        return const Icon(Icons.insert_drive_file, size: 48, color: Colors.grey);
    }
  }

  Future<void> _openAudioInBrowser() async {
    _showFullscreenMedia();
  }

  /// Ouvrir la vidéo dans le lecteur système Android
  Future<void> _openVideoInSystemPlayer() async {
    try {
      final videoUrl = _getFullMediaUrl(widget.media.url);
      debugPrint('🎬 Opening video with Android video_player: $videoUrl');
      
      // Ouvrir dans un lecteur plein écran avec video_player
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AndroidVideoPlayerScreen(
              videoUrl: videoUrl,
              title: widget.media.title,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Cannot open video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur vidéo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Ouvrir l'audio dans le lecteur système Android
  Future<void> _openAudioInSystemPlayer() async {
    try {
      final audioUrl = _getFullMediaUrl(widget.media.url);
      debugPrint('🎵 Opening audio with Android audio_player: $audioUrl');
      
      // Ouvrir dans un lecteur plein écran avec audioplayers
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AndroidAudioPlayerScreen(
              audioUrl: audioUrl,
              title: widget.media.title,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Cannot open audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openPdfViewer() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerWidget(
          pdfUrl: _getFullMediaUrl(widget.media.url),
          title: widget.media.title,
        ),
      ),
    );
  }

  Future<void> _openDocumentInBrowser() async {
    _showFullscreenMedia();
  }

  Future<void> _openGenericInBrowser() async {
    _showFullscreenMedia();
  }

  void _showFullscreenMedia() {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.media.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () {
                  // Fonctionnalité de téléchargement à implémenter
                  _showError('Fonctionnalité de téléchargement à venir');
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: Center(
            child: _buildFullscreenContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenContent() {
    switch (widget.media.type.toLowerCase()) {
      case 'image':
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Image.network(
            _getFullMediaUrl(widget.media.url),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text('Erreur de chargement de l\'image'),
                  ],
                ),
              );
            },
          ),
        );
      case 'video':
        return _buildFullscreenVideoPlayer();
      case 'audio':
        return _buildFullscreenAudioPlayer();
      default:
        return _buildFullscreenDocumentViewer();
    }
  }

  Widget _buildFullscreenVideoPlayer() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.play_circle_outline,
            size: 128,
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          Text(
            'Lecteur vidéo HTML5',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.media.originalName,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              _showError('Lecteur vidéo HTML5 en cours de développement');
            },
            child: const Text('Lire la vidéo'),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenAudioPlayer() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[900]!, Colors.blue[900]!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.music_note,
            size: 128,
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          Text(
            'Lecteur audio HTML5',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.media.originalName,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Visualisation audio simulée
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(15, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 4,
                height: (index % 5 + 1) * 20.0,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              _showError('Lecteur audio HTML5 en cours de développement');
            },
            child: const Text('Lire l\'audio'),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenDocumentViewer() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _getDocumentIcon(widget.media.originalName.split('.').last.toLowerCase()),
          const SizedBox(height: 24),
          Text(
            widget.media.title,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            widget.media.originalName,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 8),
                      const Text('Informations du fichier:'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Taille:'),
                      Text(MediaService.formatFileSize(widget.media.size)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Type:'),
                      Text(widget.media.mimetype),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _showError('Visualiseur de documents en cours de développement');
            },
            child: const Text('Ouvrir le document'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildDocumentContentPreview(String extension) {
    switch (extension) {
      case 'pdf':
        return _buildPdfPreview();
      case 'doc':
      case 'docx':
        return _buildWordPreview();
      case 'xls':
      case 'xlsx':
        return _buildExcelPreview();
      case 'ppt':
      case 'pptx':
        return _buildPowerPointPreview();
      case 'txt':
        return _buildTextPreview();
      case 'md':
        return _buildMarkdownPreview();
      case 'json':
        return _buildJsonPreview();
      case 'csv':
        return _buildCsvPreview();
      default:
        return _buildGenericDocumentPreview(extension);
    }
  }

  Widget _buildPdfPreview() {
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // Simulation d'une page PDF
          Column(
            children: [
              // En-tête de page
              Container(
                height: 40,
                color: Colors.grey[100],
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Container(
                      width: 100,
                      height: 8,
                      color: Colors.grey[400],
                    ),
                    const Spacer(),
                    Container(
                      width: 60,
                      height: 8,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
              
              // Contenu de page
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Titre
                      Container(
                        height: 16,
                        width: double.infinity,
                        color: Colors.grey[800],
                        margin: const EdgeInsets.only(bottom: 16),
                      ),
                      
                      // Paragraphes
                      ...List.generate(8, (index) {
                        return Container(
                          height: 4,
                          width: index % 3 == 0 ? double.infinity * 0.8 : double.infinity,
                          color: Colors.grey[400],
                          margin: const EdgeInsets.only(bottom: 6),
                        );
                      }),
                      
                      const Spacer(),
                      
                      // Pied de page
                      Container(
                        height: 1,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Icône PDF
          Positioned(
            bottom: 8,
            right: 8,
            child: Icon(
              Icons.picture_as_pdf,
              color: Colors.red[600],
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordPreview() {
    return Container(
      color: Colors.blue[50],
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre du document
                Container(
                  height: 14,
                  width: double.infinity * 0.7,
                  color: Colors.blue[800],
                  margin: const EdgeInsets.only(bottom: 12),
                ),
                
                // Lignes de texte
                ...List.generate(12, (index) {
                  return Container(
                    height: 3,
                    width: _getRandomWidth(index),
                    color: Colors.blue[400],
                    margin: const EdgeInsets.only(bottom: 4),
                  );
                }),
              ],
            ),
          ),
          
          Positioned(
            bottom: 8,
            right: 8,
            child: Icon(
              Icons.description,
              color: Colors.blue[700],
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcelPreview() {
    return Container(
      color: Colors.green[50],
      child: Stack(
        children: [
          // Grille Excel
          Column(
            children: [
              // En-têtes de colonnes
              SizedBox(
                height: 30,
                child: Row(
                  children: List.generate(4, (index) {
                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green[200],
                          border: Border.all(color: Colors.green[300]!, width: 0.5),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index), // A, B, C, D
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              
              // Cellules de données
              Expanded(
                child: Column(
                  children: List.generate(8, (rowIndex) {
                    return Expanded(
                      child: Row(
                        children: List.generate(4, (colIndex) {
                          return Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.green[200]!, width: 0.5),
                              ),
                              child: Center(
                                child: Container(
                                  width: colIndex % 2 == 0 ? 20 : 30,
                                  height: 2,
                                  color: Colors.green[600],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          
          Positioned(
            bottom: 8,
            right: 8,
            child: Icon(
              Icons.grid_on,
              color: Colors.green[700],
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerPointPreview() {
    return Container(
      color: Colors.orange[50],
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Titre de la slide
                Container(
                  height: 20,
                  width: double.infinity,
                  color: Colors.orange[800],
                  margin: const EdgeInsets.only(bottom: 16),
                ),
                
                // Contenu principal
                Expanded(
                  child: Row(
                    children: [
                      // Zone de texte
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: List.generate(6, (index) {
                            return Container(
                              height: 3,
                              width: double.infinity,
                              color: Colors.orange[400],
                              margin: const EdgeInsets.only(bottom: 6),
                            );
                          }),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Zone image/graphique
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.bar_chart,
                              color: Colors.orange[600],
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Positioned(
            bottom: 8,
            right: 8,
            child: Icon(
              Icons.slideshow,
              color: Colors.orange[700],
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPreview() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simulation d'un fichier texte
          ...List.generate(15, (index) {
            return Container(
              height: 2,
              width: _getRandomWidth(index),
              color: Colors.grey[700],
              margin: const EdgeInsets.only(bottom: 3),
            );
          }),
          
          const Spacer(),
          
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(
              Icons.text_snippet,
              color: Colors.grey[600],
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownPreview() {
    return Container(
      color: Colors.indigo[50],
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre H1
          Row(
            children: [
              Text(
                '#',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[800],
                ),
              ),
              const SizedBox(width: 4),
              Container(
                height: 6,
                width: 80,
                color: Colors.indigo[700],
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Texte normal
          ...List.generate(8, (index) {
            return Container(
              height: 2,
              width: _getRandomWidth(index),
              color: Colors.indigo[400],
              margin: const EdgeInsets.only(bottom: 3),
            );
          }),
          
          const SizedBox(height: 8),
          
          // Code block
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: List.generate(3, (index) {
                return Container(
                  height: 2,
                  width: double.infinity * 0.6,
                  color: Colors.green[400],
                  margin: const EdgeInsets.only(bottom: 2),
                );
              }),
            ),
          ),
          
          const Spacer(),
          
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(
              Icons.integration_instructions,
              color: Colors.indigo[600],
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonPreview() {
    return Container(
      color: Colors.purple[50],
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Structure JSON simulée
          _buildJsonLine('{', 0),
          _buildJsonLine('  "name": "value",', 1),
          _buildJsonLine('  "array": [', 1),
          _buildJsonLine('    {', 2),
          _buildJsonLine('      "key": "value"', 3),
          _buildJsonLine('    }', 2),
          _buildJsonLine('  ],', 1),
          _buildJsonLine('  "number": 123', 1),
          _buildJsonLine('}', 0),
          
          const Spacer(),
          
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(
              Icons.data_object,
              color: Colors.purple[600],
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonLine(String text, int indent) {
    return Padding(
      padding: EdgeInsets.only(left: indent * 12.0, bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8,
          fontFamily: 'monospace',
          color: Colors.purple[700],
        ),
      ),
    );
  }

  Widget _buildCsvPreview() {
    return Container(
      color: Colors.teal[50],
      child: Column(
        children: List.generate(10, (rowIndex) {
          return Expanded(
            child: Row(
              children: List.generate(3, (colIndex) {
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.teal[200]!, width: 0.5),
                      color: rowIndex == 0 ? Colors.teal[200] : Colors.white,
                    ),
                    child: Center(
                      child: Container(
                        height: 2,
                        width: 20,
                        color: rowIndex == 0 ? Colors.teal[800] : Colors.teal[400],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGenericDocumentPreview(String extension) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _getDocumentIcon(extension),
            const SizedBox(height: 12),
            Text(
              widget.media.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              MediaService.formatFileSize(widget.media.size),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getRandomWidth(int index) {
    final widths = [0.9, 0.7, 0.8, 0.6, 0.95, 0.75, 0.85];
    return 200.0 * widths[index % widths.length];
  }
}