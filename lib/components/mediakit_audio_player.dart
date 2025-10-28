import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../media_service.dart';
import '../utils/url_helper.dart';

/// Lecteur audio utilisant MediaKit pour Windows
class MediaKitAudioPlayer extends StatefulWidget {
  final MediaItem media;
  final double? width;
  final double? height;
  final bool showControls;
  final bool autoPlay;

  const MediaKitAudioPlayer({
    super.key,
    required this.media,
    this.width,
    this.height,
    this.showControls = true,
    this.autoPlay = false,
  });

  @override
  State<MediaKitAudioPlayer> createState() => _MediaKitAudioPlayerState();
}

class _MediaKitAudioPlayerState extends State<MediaKitAudioPlayer> {
  late final Player player;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  String _getFullMediaUrl(String url) {
    return UrlHelper.getFullUrl(url);
  }

  Future<void> _initializePlayer() async {
    try {
      debugPrint('🎵 Initializing MediaKit audio player...');
      
      // Créer le player
      player = Player();
      
      // Écouter les changements d'état
      player.stream.playing.listen((isPlaying) {
        if (mounted) {
          setState(() {
            _isPlaying = isPlaying;
          });
        }
      });

      player.stream.duration.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      });

      player.stream.position.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      player.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() {
            _isLoading = buffering;
          });
        }
      });
      
      final audioUrl = _getFullMediaUrl(widget.media.url);
      debugPrint('🎵 Loading audio URL: $audioUrl');
      
      // Charger l'audio
      await player.open(Media(audioUrl), play: widget.autoPlay);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      
      debugPrint('✅ MediaKit audio player initialized successfully');
    } catch (e) {
      debugPrint('❌ MediaKit audio player initialization error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await player.pause();
      } else {
        await player.play();
      }
    } catch (e) {
      debugPrint('❌ Error toggling play/pause: $e');
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      await player.seek(position);
    } catch (e) {
      debugPrint('❌ Error seeking: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              'Erreur de lecture audio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage ?? 'Erreur inconnue',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _initializePlayer,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement audio...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade800,
            Colors.grey.shade900,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône audio et titre
            Row(
              children: [
                Icon(
                  Icons.audiotrack,
                  color: Colors.blue,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.media.filename,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Barre de progression
            Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: Colors.grey.shade600,
                    thumbColor: Colors.blue,
                    overlayColor: Colors.blue.withValues(alpha: 0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _duration.inMilliseconds > 0
                        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (value) {
                      if (_duration.inMilliseconds > 0) {
                        final newPosition = Duration(
                          milliseconds: (value * _duration.inMilliseconds).round(),
                        );
                        _seekTo(newPosition);
                      }
                    },
                  ),
                ),
                
                // Temps
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Contrôles de lecture
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Bouton précédent (reculer de 10s)
                IconButton(
                  onPressed: () {
                    final newPosition = _position - const Duration(seconds: 10);
                    _seekTo(newPosition.isNegative ? Duration.zero : newPosition);
                  },
                  icon: const Icon(Icons.replay_10),
                  color: Colors.white70,
                  iconSize: 28,
                ),
                
                const SizedBox(width: 20),
                
                // Bouton play/pause
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _togglePlayPause,
                    icon: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                    iconSize: 32,
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // Bouton suivant (avancer de 10s)
                IconButton(
                  onPressed: () {
                    final newPosition = _position + const Duration(seconds: 10);
                    _seekTo(newPosition > _duration ? _duration : newPosition);
                  },
                  icon: const Icon(Icons.forward_10),
                  color: Colors.white70,
                  iconSize: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return _buildAudioPlayer();
  }
}