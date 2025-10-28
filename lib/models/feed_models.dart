class FeedItem {
  final String id;
  final String type; // 'article' ou 'media'
  final String title;
  final String? content;
  final String? description;
  final String? url; // Pour les médias
  final String? mimetype; // Pour les médias
  final List<String> tags;
  final DateTime createdAt;
  final FeedUser author;
  
  // Statistiques sociales
  int likesCount;
  int commentsCount;
  int viewsCount;
  bool isLiked;
  
  // Médias associés (pour les articles)
  final List<MediaFile> mediaFiles;

  FeedItem({
    required this.id,
    required this.type,
    required this.title,
    this.content,
    this.description,
    this.url,
    this.mimetype,
    required this.tags,
    required this.createdAt,
    required this.author,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.isLiked = false,
    this.mediaFiles = const [],
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['_id'] ?? '',
      type: json['type'] ?? json['feedType'] ?? 'article',
      title: json['title'] ?? '',
      content: json['content'],
      description: json['description'],
      url: json['url'],
      mimetype: json['mimetype'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      author: FeedUser.fromJson(json['author'] ?? {}),
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      viewsCount: json['viewsCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      mediaFiles: (json['mediaFiles'] as List<dynamic>?)
          ?.map((item) => MediaFile.fromJson(item))
          .toList() ?? [],
    );
  }

  // Constructeur pour créer un FeedItem à partir d'un article
  factory FeedItem.fromArticle(Map<String, dynamic> json) {
    return FeedItem(
      id: json['_id'] ?? '',
      type: 'article',
      title: json['title'] ?? '',
      content: json['content'],
      description: json['description'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      author: FeedUser.fromJson(json['author'] ?? json['uploadedBy'] ?? {}),
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      viewsCount: json['viewsCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      mediaFiles: (json['mediaFiles'] as List<dynamic>?)
          ?.map((item) => MediaFile.fromJson(item))
          .toList() ?? [],
    );
  }

  // Constructeur pour créer un FeedItem à partir d'un média
  factory FeedItem.fromMedia(Map<String, dynamic> json) {
    return FeedItem(
      id: json['_id'] ?? '',
      type: 'media',
      title: json['title'] ?? json['originalName'] ?? '',
      description: json['description'],
      url: json['url'],
      mimetype: json['mimetype'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      author: FeedUser.fromJson(json['uploadedBy'] ?? json['author'] ?? {}),
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      viewsCount: json['viewsCount'] ?? json['usageCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }

  // Constructeur pour créer un FeedItem à partir d'un blog
  factory FeedItem.fromBlog(Map<String, dynamic> json) {
    return FeedItem(
      id: json['_id'] ?? '',
      type: 'blog',
      title: json['title'] ?? '',
      content: json['content'],
      description: json['excerpt'] ?? json['description'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      author: FeedUser.fromJson(json['author'] ?? json['uploadedBy'] ?? {}),
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      viewsCount: json['viewsCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      mediaFiles: (json['mediaFiles'] as List<dynamic>?)
          ?.map((item) => MediaFile.fromJson(item))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type,
      'title': title,
      'content': content,
      'description': description,
      'url': url,
      'mimetype': mimetype,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'author': author.toJson(),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'viewsCount': viewsCount,
      'isLiked': isLiked,
      'mediaFiles': mediaFiles.map((item) => item.toJson()).toList(),
    };
  }

  // Helper pour obtenir le contenu à afficher
  String get displayContent {
    if (type == 'media') {
      return description ?? title;
    } else {
      // Pour les articles, retourner une version tronquée du contenu HTML
      if (content != null) {
        String plainText = content!
            .replaceAll(RegExp(r'<[^>]*>'), '') // Supprimer les balises HTML
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .trim();
        
        if (plainText.length > 200) {
          return '${plainText.substring(0, 200)}...';
        }
        return plainText;
      }
      return description ?? title;
    }
  }

  // Helper pour obtenir l'image principale
  String? get primaryImageUrl {
    if (type == 'media' && mimetype?.startsWith('image/') == true) {
      return url;
    } else if (mediaFiles.isNotEmpty) {
      final imageFile = mediaFiles.firstWhere(
        (file) => file.type == 'image',
        orElse: () => mediaFiles.first,
      );
      return imageFile.url;
    }
    return null;
  }

  // Helper pour vérifier si c'est du contenu vidéo
  bool get isVideo {
    if (type == 'media' && mimetype?.startsWith('video/') == true) {
      return true;
    }
    return mediaFiles.any((file) => file.type == 'video');
  }

  // Helper pour vérifier si c'est du contenu audio
  bool get isAudio {
    if (type == 'media' && mimetype?.startsWith('audio/') == true) {
      return true;
    }
    return mediaFiles.any((file) => file.type == 'audio');
  }
}

class FeedUser {
  final String id;
  final String name;
  final String email;
  final String? profilePhoto;
  final String role;

  FeedUser({
    required this.id,
    required this.name,
    required this.email,
    this.profilePhoto,
    required this.role,
  });

  factory FeedUser.fromJson(Map<String, dynamic> json) {
    return FeedUser(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Utilisateur',
      email: json['email'] ?? '',
      profilePhoto: json['profilePhoto'],
      role: json['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'profilePhoto': profilePhoto,
      'role': role,
    };
  }

  // Helper pour obtenir l'avatar
  String get displayName {
    if (name.isNotEmpty) {
      return name;
    } else {
      return email.split('@').first;
    }
  }

  // Helper pour vérifier si c'est un admin
  bool get isAdmin => role == 'admin';
}

class MediaFile {
  final String filename;
  final String url;
  final String type; // 'image', 'video', 'audio', 'document'

  MediaFile({
    required this.filename,
    required this.url,
    required this.type,
  });

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    return MediaFile(
      filename: json['filename'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? 'image',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'url': url,
      'type': type,
    };
  }
}

class Comment {
  final String id;
  final String content;
  final FeedUser author;
  final DateTime createdAt;
  final bool isEdited;
  final DateTime? editedAt;
  final int likesCount;
  final int repliesCount;
  final String? parentCommentId;
  bool isLiked;

  Comment({
    required this.id,
    required this.content,
    required this.author,
    required this.createdAt,
    this.isEdited = false,
    this.editedAt,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.parentCommentId,
    this.isLiked = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      author: FeedUser.fromJson(json['author'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isEdited: json['isEdited'] ?? false,
      editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt']) : null,
      likesCount: json['likesCount'] ?? 0,
      repliesCount: json['repliesCount'] ?? 0,
      parentCommentId: json['parentCommentId'],
      isLiked: json['isLiked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'content': content,
      'author': author.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'likesCount': likesCount,
      'repliesCount': repliesCount,
      'parentCommentId': parentCommentId,
      'isLiked': isLiked,
    };
  }

  // Helper pour vérifier si c'est une réponse
  bool get isReply => parentCommentId != null;
}