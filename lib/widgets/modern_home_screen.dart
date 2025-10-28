import 'package:flutter/material.dart';
import '../services/public_feed_service.dart';
import '../services/media_player_service.dart';
import '../models/feed_models.dart';

class ModernHomeScreen extends StatelessWidget {
  static String routeName = "/home";

  const ModernHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              HomeHeader(),
              DiscountBanner(),
              PopularMedias(),
              SizedBox(height: 20),
              RecentlyAddedContent(),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(child: SearchField()),
          const SizedBox(width: 16),
          IconBtnWithCounter(
            icon: Icons.video_library,
            press: () {},
          ),
          const SizedBox(width: 8),
          IconBtnWithCounter(
            icon: Icons.notifications,
            numOfitem: 3,
            press: () {},
          ),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key});

  @override
  Widget build(BuildContext context) {
    return Form(
      child: TextFormField(
        onChanged: (value) {},
        decoration: InputDecoration(
          filled: true,
          hintStyle: const TextStyle(color: Color(0xFF757575)),
          fillColor: const Color(0xFF979797).withValues(alpha: 0.1),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          hintText: "Rechercher du contenu...",
          prefixIcon: const Icon(Icons.search),
        ),
      ),
    );
  }
}

class IconBtnWithCounter extends StatelessWidget {
  const IconBtnWithCounter({
    super.key,
    required this.icon,
    this.numOfitem = 0,
    required this.press,
  });

  final IconData icon;
  final int numOfitem;
  final GestureTapCallback press;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: press,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF979797).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF626262)),
          ),
          if (numOfitem != 0)
            Positioned(
              top: -3,
              right: 0,
              child: Container(
                height: 20,
                width: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4848),
                  shape: BoxShape.circle,
                  border: Border.all(width: 1.5, color: Colors.white),
                ),
                child: Center(
                  child: Text(
                    "$numOfitem",
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}

class DiscountBanner extends StatelessWidget {
  const DiscountBanner({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A3298), Color(0xFF6A4C93)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text.rich(
        TextSpan(
          style: TextStyle(color: Colors.white),
          children: [
            TextSpan(text: "Bibliothèque Média\n"),
            TextSpan(
              text: "Contenu Premium",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    required this.press,
  });

  final String title;
  final GestureTapCallback press;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        TextButton(
          onPressed: press,
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
          child: const Text("Voir plus"),
        ),
      ],
    );
  }
}

class PopularMedias extends StatefulWidget {
  const PopularMedias({super.key});

  @override
  State<PopularMedias> createState() => _PopularMediasState();
}

class _PopularMediasState extends State<PopularMedias> {
  List<FeedItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final result = await PublicFeedService.getPublicFeed();
      if (result['success'] == true && result['feed'] != null) {
        final List<dynamic> feedData = result['feed'];
        setState(() {
          _items = feedData.map((item) => FeedItem.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur de chargement: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionTitle(
            title: "Médias Populaires",
            press: () {},
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) {
                return MediaCard(
                  item: _items[index],
                  onPress: () => _showMediaDetail(context, _items[index]),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showMediaDetail(BuildContext context, FeedItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaDetailSheet(item: item),
    );
  }
}

class RecentlyAddedContent extends StatefulWidget {
  const RecentlyAddedContent({super.key});

  @override
  State<RecentlyAddedContent> createState() => _RecentlyAddedContentState();
}

class _RecentlyAddedContentState extends State<RecentlyAddedContent> {
  List<MediaFile> _medias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedias();
  }

  Future<void> _loadMedias() async {
    try {
      final result = await PublicFeedService.getPublicMedias();
      if (result['success'] == true && result['medias'] != null) {
        final List<dynamic> mediasData = result['medias'];
        setState(() {
          _medias = mediasData.map((item) => MediaFile.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur de chargement des médias: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionTitle(
            title: "Récemment Ajoutés",
            press: () {},
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _medias.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) {
                return MediaFileCard(
                  media: _medias[index],
                  onPress: () => _showMediaFileDetail(context, _medias[index]),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showMediaFileDetail(BuildContext context, MediaFile media) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaFileDetailSheet(media: media),
    );
  }
}

class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    this.width = 140,
    this.aspectRatio = 1.02,
    required this.item,
    required this.onPress,
  });

  final double width, aspectRatio;
  final FeedItem item;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF979797).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildPreview(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.type,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF7643),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7643).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getTypeIcon(),
                    size: 12,
                    color: const Color(0xFFFF7643),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    // Utiliser l'URL principale selon le type
    String? previewUrl = item.url ?? item.primaryImageUrl;
    
    if (previewUrl != null && previewUrl.isNotEmpty) {
      if (item.type == 'image' || item.primaryImageUrl != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            previewUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 40),
              );
            },
          ),
        );
      } else if (item.type == 'video' || item.isVideo) {
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getTypeIcon(),
        size: 40,
        color: Colors.grey[600],
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (item.type) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.play_circle_fill;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.description;
    }
  }
}

class MediaFileCard extends StatelessWidget {
  const MediaFileCard({
    super.key,
    this.width = 140,
    this.aspectRatio = 1.02,
    required this.media,
    required this.onPress,
  });

  final double width, aspectRatio;
  final MediaFile media;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF979797).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildMediaPreview(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              media.filename,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  media.type,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF7643),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7643).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getMediaTypeIcon(),
                    size: 12,
                    color: const Color(0xFFFF7643),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (media.type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          media.url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, size: 40),
            );
          },
        ),
      );
    } else if (media.type == 'video') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.play_circle_fill,
            size: 40,
            color: Colors.white,
          ),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getMediaTypeIcon(),
          size: 40,
          color: Colors.grey[600],
        ),
      );
    }
  }

  IconData _getMediaTypeIcon() {
    switch (media.type) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.play_circle_fill;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.description;
    }
  }
}

// Sheets détaillés pour affichage des médias
class MediaDetailSheet extends StatelessWidget {
  final FeedItem item;

  const MediaDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMediaDisplay(item),
                      const SizedBox(height: 16),
                      if (item.description != null)
                        Text(
                          item.description!,
                          style: const TextStyle(fontSize: 16),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaDisplay(FeedItem item) {
    // Afficher les médias selon le type
    if (item.url != null && item.url!.isNotEmpty) {
      if (item.type == 'image' || item.mimetype?.startsWith('image/') == true) {
        return MediaPlayerService.buildImageWidget(item.url!);
      } else if (item.type == 'video' || item.isVideo) {
        return SimpleVideoPlayerWidget(url: item.url!, title: item.title);
      } else if (item.type == 'audio' || item.isAudio) {
        return MediaPlayerService.buildAudioWidget(item.url!, item.title);
      }
    }
    
    // Afficher les médias associés aux articles
    if (item.mediaFiles.isNotEmpty) {
      return Column(
        children: item.mediaFiles.map((mediaFile) {
          if (mediaFile.type == 'image') {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MediaPlayerService.buildImageWidget(mediaFile.url),
            );
          } else if (mediaFile.type == 'video') {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SimpleVideoPlayerWidget(url: mediaFile.url, title: mediaFile.filename),
            );
          } else if (mediaFile.type == 'audio') {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MediaPlayerService.buildAudioWidget(mediaFile.url, mediaFile.filename),
            );
          }
          return const SizedBox.shrink();
        }).toList(),
      );
    }
    
    return const SizedBox.shrink();
  }
}

// Widget simple pour la lecture vidéo
class SimpleVideoPlayerWidget extends StatelessWidget {
  final String url;
  final String title;

  const SimpleVideoPlayerWidget({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 50,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MediaFileDetailSheet extends StatelessWidget {
  final MediaFile media;

  const MediaFileDetailSheet({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.filename,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMediaFileDisplay(media),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Informations',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Type: ${media.type}'),
                              Text('URL: ${media.url}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaFileDisplay(MediaFile media) {
    if (media.type == 'image') {
      return MediaPlayerService.buildImageWidget(media.url);
    } else if (media.type == 'video') {
      return SimpleVideoPlayerWidget(url: media.url, title: media.filename);
    } else if (media.type == 'audio') {
      return MediaPlayerService.buildAudioWidget(media.url, media.filename);
    }
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.description, size: 60),
      ),
    );
  }
}