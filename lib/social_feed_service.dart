// social_feed_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class SocialFeedService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    } else {
      return 'http://localhost:5000/api';
    }
  }

  /// Récupérer le feed social combiné (articles + médias) avec profils utilisateurs
  static Future<SocialFeedResponse> getSocialFeed({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token manquant');

      final response = await http.get(
        Uri.parse('$baseUrl/feed/social?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SocialFeedResponse.fromJson(data);
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Récupérer le feed médias avec profils utilisateurs
  static Future<MediaFeedResponse> getMediaFeed({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token manquant');

      final response = await http.get(
        Uri.parse('$baseUrl/media/feed?page=$page&limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MediaFeedResponse.fromJson(data);
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Méthode pour récupérer le feed avec interactions
  static Future<List<FeedItem>> getFeedWithInteractions({
    int page = 1,
    int limit = 10,
  }) async {
    // Utilise l'endpoint /api/feed/social qui est déjà implémenté avec les interactions
    final response = await getSocialFeed(page: page, limit: limit);
    
    // Ajouter des valeurs par défaut pour les interactions
    for (var item in response.feed) {
      item.likesCount = 0;
      item.commentsCount = 0;
      item.viewsCount = 0;
      item.isLiked = false;
    }
    
    return response.feed;
  }
}

/// Modèles de données pour le feed social
class SocialFeedResponse {
  final List<FeedItem> feed;
  final FeedPagination pagination;
  final FeedStats stats;

  SocialFeedResponse({
    required this.feed,
    required this.pagination,
    required this.stats,
  });

  factory SocialFeedResponse.fromJson(Map<String, dynamic> json) {
    return SocialFeedResponse(
      feed: (json['feed'] as List).map((item) => FeedItem.fromJson(item)).toList(),
      pagination: FeedPagination.fromJson(json['pagination']),
      stats: FeedStats.fromJson(json['stats']),
    );
  }
}

class MediaFeedResponse {
  final List<MediaFeedItem> medias;
  final FeedPagination pagination;

  MediaFeedResponse({
    required this.medias,
    required this.pagination,
  });

  factory MediaFeedResponse.fromJson(Map<String, dynamic> json) {
    return MediaFeedResponse(
      medias: (json['medias'] as List).map((item) => MediaFeedItem.fromJson(item)).toList(),
      pagination: FeedPagination.fromJson(json['pagination']),
    );
  }
}

class FeedItem {
  final String id;
  final String title;
  final String? description;
  final String? summary;
  final String? content;
  final String? url;
  final String? mimetype;
  final String type; // 'article' ou 'media'
  final String? feedType;
  final List<String> tags;
  final DateTime createdAt;
  final FeedAuthor author;
  final List<MediaFile>? mediaFiles; // Pour les articles
  int likesCount;
  int commentsCount;
  int viewsCount;
  bool isLiked;

  FeedItem({
    required this.id,
    required this.title,
    this.description,
    this.summary,
    this.content,
    this.url,
    this.mimetype,
    required this.type,
    this.feedType,
    required this.tags,
    required this.createdAt,
    required this.author,
    this.mediaFiles,
    required this.likesCount,
    required this.commentsCount,
    required this.viewsCount,
    required this.isLiked,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['_id'],
      title: json['title'] ?? '',
      description: json['description'],
      summary: json['summary'],
      content: json['content'],
      url: json['url'],
      mimetype: json['mimetype'],
      type: json['type'] ?? json['feedType'] ?? 'unknown',
      feedType: json['feedType'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      author: FeedAuthor.fromJson(json['author']),
      mediaFiles: json['mediaFiles'] != null 
          ? (json['mediaFiles'] as List).map((item) => MediaFile.fromJson(item)).toList()
          : null,
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      viewsCount: json['viewsCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }
}

class MediaFeedItem {
  final String id;
  final String title;
  final String? description;
  final String url;
  final String mimetype;
  final String type;
  final List<String> tags;
  final DateTime createdAt;
  final FeedAuthor author;
  int likesCount;
  int commentsCount;
  int viewsCount;
  bool isLiked;

  MediaFeedItem({
    required this.id,
    required this.title,
    this.description,
    required this.url,
    required this.mimetype,
    required this.type,
    required this.tags,
    required this.createdAt,
    required this.author,
    required this.likesCount,
    required this.commentsCount,
    required this.viewsCount,
    required this.isLiked,
  });

  factory MediaFeedItem.fromJson(Map<String, dynamic> json) {
    return MediaFeedItem(
      id: json['_id'],
      title: json['title'] ?? '',
      description: json['description'],
      url: json['url'],
      mimetype: json['mimetype'] ?? '',
      type: json['type'] ?? 'unknown',
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      author: FeedAuthor.fromJson(json['user']),
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      viewsCount: json['viewsCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }
}

class FeedAuthor {
  final String id;
  final String name;
  final String email;
  final String? profilePhoto;
  final String role;

  FeedAuthor({
    required this.id,
    required this.name,
    required this.email,
    this.profilePhoto,
    required this.role,
  });

  factory FeedAuthor.fromJson(Map<String, dynamic> json) {
    return FeedAuthor(
      id: json['_id'],
      name: json['name'] ?? 'Utilisateur',
      email: json['email'] ?? '',
      profilePhoto: json['profilePhoto'],
      role: json['role'] ?? 'user',
    );
  }
}

class MediaFile {
  final String filename;
  final String url;
  final String type;

  MediaFile({
    required this.filename,
    required this.url,
    required this.type,
  });

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    return MediaFile(
      filename: json['filename'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

class FeedPagination {
  final int page;
  final int limit;
  final int total;
  final int pages;

  FeedPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory FeedPagination.fromJson(Map<String, dynamic> json) {
    return FeedPagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      pages: json['pages'] ?? 1,
    );
  }
}

class FeedStats {
  final int articles;
  final int medias;

  FeedStats({
    required this.articles,
    required this.medias,
  });

  factory FeedStats.fromJson(Map<String, dynamic> json) {
    return FeedStats(
      articles: json['articles'] ?? 0,
      medias: json['medias'] ?? 0,
    );
  }
}