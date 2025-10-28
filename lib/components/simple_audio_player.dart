import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../media_service.dart';
import '../utils/url_helper.dart';

/// Lecteur audio professionnel avec audioplayers
class SimpleAudioPlayer extends StatefulWidget {
  final MediaItem media;
  final bool autoPlay;
  final bool showControls;

  const SimpleAudioPlayer({
    super.key,
    required this.media,
    this.autoPlay = false,
    this.showControls = true,
  });

  @override
  State<SimpleAudioPlayer> createState() => _SimpleAudioPlayerState();
}

class _SimpleAudioPlayerState extends State<SimpleAudioPlayer>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  late AnimationController _visualizerController;
  late Animation<double> _visualizerAnimation;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAnimations();
    _setupAudioPlayer();
    _initializeAudio();
  }

  void _setupAnimations() {
    _visualizerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _visualizerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_visualizerController);
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = state == PlayerState.stopped && _position == Duration.zero;
        });
        
        if (_isPlaying) {
          _visualizerController.repeat();
        } else {
          _visualizerController.stop();
        }
      }
    });

    _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((Duration position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        _visualizerController.stop();
      }
    });
  }

  String _getFullMediaUrl(String url) {
    return UrlHelper.getFullUrl(url);
  }

  Future<void> _initializeAudio() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      final audioUrl = _getFullMediaUrl(widget.media.url);
      
      await _audioPlayer.setSourceUrl(audioUrl);

      if (widget.autoPlay) {
        await _audioPlayer.resume();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _stop() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _position = Duration.zero;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  double get _progressValue {
    if (_duration.inMilliseconds > 0) {
      return _position.inMilliseconds / _duration.inMilliseconds;
    }
    return 0.0;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _visualizerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple[100]!,
            Colors.indigo[100]!,
            Colors.blue[100]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildVisualizer(),
          const SizedBox(height: 16),
          _buildProgressBar(),
          const SizedBox(height: 12),
          if (widget.showControls) _buildControls(),
          if (_hasError) ...[
            const SizedBox(height: 12),
            _buildErrorWidget(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple[600],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.music_note,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.media.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.media.originalName,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisualizer() {
    return SizedBox(
      height: 60,
      child: AnimatedBuilder(
        animation: _visualizerAnimation,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(25, (index) {
              final height = _isPlaying 
                  ? (20 + (index % 5 + 1) * 8.0) * (0.5 + _visualizerAnimation.value * 0.5)
                  : 8.0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  color: _isPlaying 
                      ? Colors.deepPurple[400 + (index % 3) * 100] 
                      : Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.deepPurple[600],
            inactiveTrackColor: Colors.grey[300],
            thumbColor: Colors.deepPurple[600],
            overlayColor: Colors.deepPurple[600]!.withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: _progressValue,
            onChanged: _isLoading ? null : (value) {
              final position = Duration(
                milliseconds: (value * _duration.inMilliseconds).round(),
              );
              _seek(position);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          MediaService.formatFileSize(widget.media.size),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: _isLoading ? null : _stop,
              icon: const Icon(Icons.stop),
              color: Colors.deepPurple[600],
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.deepPurple[600],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _togglePlay,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
              ),
            ),
            IconButton(
              onPressed: _isLoading ? null : _initializeAudio,
              icon: const Icon(Icons.refresh),
              color: Colors.deepPurple[600],
            ),
          ],
        ),
        Text(
          '${(_progressValue * 100).toInt()}%',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? 'Erreur de lecture audio',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}