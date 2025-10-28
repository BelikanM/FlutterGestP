import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../media_service.dart';
import '../utils/url_helper.dart';

/// Lecteur vidéo spécialisé pour Windows Desktop
/// Évite complètement les packages video_player incompatibles
class WindowsVideoPlayer extends StatelessWidget {
  final MediaItem media;
  final double? width;
  final double? height;

  const WindowsVideoPlayer({
    super.key,
    required this.media,
    this.width,
    this.height,
  });

  String _getFullMediaUrl(String url) {
    return UrlHelper.getFullUrl(url);
  }

  Future<void> _launchVideoInSystemPlayer() async {
    try {
      final videoUrl = _getFullMediaUrl(media.url);
      debugPrint('🎬 Launching video in system player: $videoUrl');
      
      final uri = Uri.parse(videoUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('❌ Cannot launch video URL: $videoUrl');
      }
    } catch (e) {
      debugPrint('❌ Error launching video: $e');
    }
  }

  Future<void> _copyVideoUrl() async {
    try {
      final videoUrl = _getFullMediaUrl(media.url);
      debugPrint('📋 Video URL copied: $videoUrl');
      // Pour copier dans le presse-papiers :
      // await Clipboard.setData(ClipboardData(text: videoUrl));
    } catch (e) {
      debugPrint('❌ Error copying video URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? 400,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Fond avec aperçu vidéo
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey.shade800,
                    Colors.black,
                  ],
                ),
              ),
            ),
            
            // Contenu principal
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icône vidéo
                  Icon(
                    Icons.play_circle_outline,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(height: 16),
                  
                  // Titre
                  Text(
                    'Lecteur vidéo Windows',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Cliquez sur "Lire" pour ouvrir la vidéo\ndans votre lecteur système par défaut',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Boutons d'action
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Bouton Lire
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _launchVideoInSystemPlayer,
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: const Text(
                              'Lire',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Bouton Copier URL
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _copyVideoUrl,
                            icon: const Icon(
                              Icons.link,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: const Text(
                              'URL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
            
            // Indicateur de format en haut à droite
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'VIDEO',
                  style: TextStyle(
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
}