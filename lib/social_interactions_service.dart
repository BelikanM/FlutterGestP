// social_interactions_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SocialInteractionsService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }

  // Méthode pour vérifier si l'utilisateur est connecté
  static Future<bool> isUserAuthenticated() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      // Token retrieved successfully
      return token;
    } catch (e) {
      // Error getting token
      return null;
    }
  }

  static Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }



  // ==========================================
  // GESTION DES LIKES
  // ==========================================

  /// Toggle like sur un contenu (article, media, comment)
  static Future<LikeResponse> toggleLike(String targetType, String targetId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Vous devez être connecté pour aimer ce contenu');
      }

      // Toggling like for content
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/likes'),
        headers: _getHeaders(token),
        body: jsonEncode({
          'targetType': targetType,
          'targetId': targetId,
        }),
      );

      // Like response received

      if (response.statusCode == 200) {
        final result = LikeResponse.fromJson(jsonDecode(response.body));
        // Like toggled successfully
        return result;
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Erreur inconnue';
        throw Exception('Erreur serveur: $error');
      }
    } catch (e) {
      // Error in toggleLike
      throw Exception('Erreur lors du like: $e');
    }
  }

  /// Récupérer les likes d'un contenu
  static Future<LikesListResponse> getLikes(
    String targetType, 
    String targetId, {
    int page = 1,
    int limit = 20,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token non disponible');

    final response = await http.get(
      Uri.parse('$baseUrl/api/likes/$targetType/$targetId?page=$page&limit=$limit'),
      headers: _getHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la récupération des likes: ${jsonDecode(response.body)['error']}');
    }

    return LikesListResponse.fromJson(jsonDecode(response.body));
  }

  // ==========================================
  // GESTION DES COMMENTAIRES
  // ==========================================

  /// Ajouter un commentaire
  static Future<CommentResponse> addComment(
    String content,
    String targetType,
    String targetId, {
    String? parentCommentId,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token non disponible');

    final body = {
      'content': content,
      'targetType': targetType,
      'targetId': targetId,
    };

    if (parentCommentId != null) {
      body['parentCommentId'] = parentCommentId;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/comments'),
      headers: _getHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception('Erreur lors de l\'ajout du commentaire: ${jsonDecode(response.body)['error']}');
    }

    return CommentResponse.fromJson(jsonDecode(response.body));
  }

  /// Récupérer les commentaires d'un contenu
  static Future<CommentsListResponse> getComments(
    String targetType,
    String targetId, {
    int page = 1,
    int limit = 20,
    String? parentId,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token non disponible');

    String url = '$baseUrl/api/comments/$targetType/$targetId?page=$page&limit=$limit';
    if (parentId != null) {
      url += '&parentId=$parentId';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: _getHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la récupération des commentaires: ${jsonDecode(response.body)['error']}');
    }

    return CommentsListResponse.fromJson(jsonDecode(response.body));
  }

  /// Modifier un commentaire
  static Future<CommentResponse> editComment(String commentId, String content) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token non disponible');

    final response = await http.put(
      Uri.parse('$baseUrl/api/comments/$commentId'),
      headers: _getHeaders(token),
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la modification: ${jsonDecode(response.body)['error']}');
    }

    return CommentResponse.fromJson(jsonDecode(response.body));
  }

  /// Supprimer un commentaire
  static Future<void> deleteComment(String commentId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token non disponible');

    final response = await http.delete(
      Uri.parse('$baseUrl/api/comments/$commentId'),
      headers: _getHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la suppression: ${jsonDecode(response.body)['error']}');
    }
  }

  // ==========================================
  // STATISTIQUES
  // ==========================================

  /// Récupérer les statistiques d'un contenu
  static Future<ContentStats> getContentStats(String targetType, String targetId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Token non disponible');

    final response = await http.get(
      Uri.parse('$baseUrl/api/stats/$targetType/$targetId'),
      headers: _getHeaders(token),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la récupération des stats: ${jsonDecode(response.body)['error']}');
    }

    return ContentStats.fromJson(jsonDecode(response.body));
  }
}

// ==========================================
// MODÈLES DE DONNÉES
// ==========================================

class LikeResponse {
  final String message;
  final String action;
  final int likesCount;
  final bool isLiked;

  LikeResponse({
    required this.message,
    required this.action,
    required this.likesCount,
    required this.isLiked,
  });

  factory LikeResponse.fromJson(Map<String, dynamic> json) {
    return LikeResponse(
      message: json['message'],
      action: json['action'],
      likesCount: json['likesCount'],
      isLiked: json['isLiked'],
    );
  }
}

class LikesListResponse {
  final List<LikeItem> likes;
  final int totalLikes;
  final bool isLiked;
  final Pagination pagination;

  LikesListResponse({
    required this.likes,
    required this.totalLikes,
    required this.isLiked,
    required this.pagination,
  });

  factory LikesListResponse.fromJson(Map<String, dynamic> json) {
    return LikesListResponse(
      likes: (json['likes'] as List).map((item) => LikeItem.fromJson(item)).toList(),
      totalLikes: json['totalLikes'],
      isLiked: json['isLiked'],
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}

class LikeItem {
  final String id;
  final DateTime createdAt;
  final LikeUser user;

  LikeItem({
    required this.id,
    required this.createdAt,
    required this.user,
  });

  factory LikeItem.fromJson(Map<String, dynamic> json) {
    return LikeItem(
      id: json['_id'],
      createdAt: DateTime.parse(json['createdAt']),
      user: LikeUser.fromJson(json['user']),
    );
  }
}

class LikeUser {
  final String id;
  final String name;
  final String email;
  final String? profilePhoto;
  final String role;

  LikeUser({
    required this.id,
    required this.name,
    required this.email,
    this.profilePhoto,
    required this.role,
  });

  factory LikeUser.fromJson(Map<String, dynamic> json) {
    return LikeUser(
      id: json['_id'],
      name: json['name'] ?? '',
      email: json['email'],
      profilePhoto: json['profilePhoto'],
      role: json['role'],
    );
  }
}

class CommentResponse {
  final String message;
  final CommentItem comment;

  CommentResponse({
    required this.message,
    required this.comment,
  });

  factory CommentResponse.fromJson(Map<String, dynamic> json) {
    return CommentResponse(
      message: json['message'],
      comment: CommentItem.fromJson(json['comment']),
    );
  }
}

class CommentsListResponse {
  final List<CommentItem> comments;
  final int totalComments;
  final Pagination pagination;

  CommentsListResponse({
    required this.comments,
    required this.totalComments,
    required this.pagination,
  });

  factory CommentsListResponse.fromJson(Map<String, dynamic> json) {
    return CommentsListResponse(
      comments: (json['comments'] as List).map((item) => CommentItem.fromJson(item)).toList(),
      totalComments: json['totalComments'],
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}

class CommentItem {
  final String id;
  final String content;
  final bool isEdited;
  final DateTime? editedAt;
  final int likesCount;
  final int repliesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentCommentId;
  final CommentAuthor author;
  final bool isLiked;

  CommentItem({
    required this.id,
    required this.content,
    required this.isEdited,
    this.editedAt,
    required this.likesCount,
    required this.repliesCount,
    required this.createdAt,
    required this.updatedAt,
    this.parentCommentId,
    required this.author,
    required this.isLiked,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    return CommentItem(
      id: json['_id'],
      content: json['content'],
      isEdited: json['isEdited'] ?? false,
      editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt']) : null,
      likesCount: json['likesCount'] ?? 0,
      repliesCount: json['repliesCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      parentCommentId: json['parentCommentId'],
      author: CommentAuthor.fromJson(json['author']),
      isLiked: json['isLiked'] ?? false,
    );
  }
}

class CommentAuthor {
  final String id;
  final String name;
  final String email;
  final String? profilePhoto;
  final String role;

  CommentAuthor({
    required this.id,
    required this.name,
    required this.email,
    this.profilePhoto,
    required this.role,
  });

  factory CommentAuthor.fromJson(Map<String, dynamic> json) {
    return CommentAuthor(
      id: json['_id'],
      name: json['name'] ?? '',
      email: json['email'],
      profilePhoto: json['profilePhoto'],
      role: json['role'],
    );
  }
}



class ContentStats {
  final String contentType;
  final String contentId;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final int sharesCount;
  final bool isLiked;

  ContentStats({
    required this.contentType,
    required this.contentId,
    required this.likesCount,
    required this.commentsCount,
    required this.viewsCount,
    required this.sharesCount,
    required this.isLiked,
  });

  factory ContentStats.fromJson(Map<String, dynamic> json) {
    return ContentStats(
      contentType: json['contentType'],
      contentId: json['contentId'],
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      viewsCount: json['viewsCount'] ?? 0,
      sharesCount: json['sharesCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }
}

class Pagination {
  final int page;
  final int limit;
  final int total;
  final int pages;

  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'],
      limit: json['limit'],
      total: json['total'],
      pages: json['pages'],
    );
  }
}

class LikesResponse {
  final List<LikeItem> likes;
  final int totalLikes;
  final Pagination pagination;

  LikesResponse({
    required this.likes,
    required this.totalLikes,
    required this.pagination,
  });

  factory LikesResponse.fromJson(Map<String, dynamic> json) {
    return LikesResponse(
      likes: (json['likes'] as List<dynamic>? ?? [])
          .map((like) => LikeItem.fromJson(like))
          .toList(),
      totalLikes: json['totalLikes'] ?? 0,
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
    );
  }
}