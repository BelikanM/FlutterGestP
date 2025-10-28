import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SocialService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }
  
  // Obtenir le token JWT
  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('jwt_token');
    } catch (e) {
      // Error getting token - return null for silent handling
      return null;
    }
  }

  // Headers avec authentification
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  // Vérifier si l'utilisateur est authentifié
  static Future<bool> isUserAuthenticated() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  // ==========================================
  // FEED SOCIAL
  // ==========================================
  
  // Récupérer le feed social combiné (articles + médias)
  static Future<Map<String, dynamic>> getSocialFeed({
    int page = 1, 
    int limit = 10
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/feed/social?page=$page&limit=$limit'),
        headers: headers,
      );

      // Social feed request completed
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'feed': data['feed'] ?? [],
          'pagination': data['pagination'] ?? {},
          'stats': data['stats'] ?? {}
        };
      } else {
        // Error getting social feed response
        return {
          'success': false,
          'error': 'Erreur lors du chargement du feed: ${response.statusCode}'
        };
      }
    } catch (e) {
      // Exception getting social feed
      return {
        'success': false,
        'error': 'Erreur de connexion: $e'
      };
    }
  }

  // ==========================================
  // LIKES
  // ==========================================
  
  // Toggle like sur un contenu
  static Future<Map<String, dynamic>> toggleLike(String targetType, String targetId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/likes'),
        headers: headers,
        body: json.encode({
          'targetType': targetType,
          'targetId': targetId,
        }),
      );

      // Toggle like request completed
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'action': data['action'], // 'liked' ou 'unliked'
          'likesCount': data['likesCount'] ?? 0,
          'isLiked': data['isLiked'] ?? false
        };
      } else {
        // Error toggling like
        return {
          'success': false,
          'error': 'Erreur lors du like: ${response.statusCode}'
        };
      }
    } catch (e) {
      // Exception toggling like
      return {
        'success': false,
        'error': 'Erreur de connexion: $e'
      };
    }
  }

  // Obtenir les likes d'un contenu
  static Future<Map<String, dynamic>> getLikes(String targetType, String targetId, {
    int page = 1, 
    int limit = 20
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/likes/$targetType/$targetId?page=$page&limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'likes': data['likes'] ?? [],
          'totalLikes': data['totalLikes'] ?? 0,
          'isLiked': data['isLiked'] ?? false,
          'pagination': data['pagination'] ?? {}
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur lors du chargement des likes: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion: $e'
      };
    }
  }

  // ==========================================
  // COMMENTAIRES
  // ==========================================
  
  // Ajouter un commentaire
  static Future<Map<String, dynamic>> addComment(String targetType, String targetId, String content, {
    String? parentCommentId
  }) async {
    try {
      final headers = await _getHeaders();
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
        headers: headers,
        body: json.encode(body),
      );

      // Add comment request completed
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'comment': data['comment']
        };
      } else {
        // Error adding comment
        return {
          'success': false,
          'error': 'Erreur lors de l\'ajout du commentaire: ${response.statusCode}'
        };
      }
    } catch (e) {
      // Exception adding comment
      return {
        'success': false,
        'error': 'Erreur de connexion: $e'
      };
    }
  }

  // Obtenir les commentaires d'un contenu
  static Future<Map<String, dynamic>> getComments(String targetType, String targetId, {
    int page = 1, 
    int limit = 20,
    String? parentId
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/api/comments/$targetType/$targetId?page=$page&limit=$limit';
      
      if (parentId != null) {
        url += '&parentId=$parentId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'comments': data['comments'] ?? [],
          'totalComments': data['totalComments'] ?? 0,
          'pagination': data['pagination'] ?? {}
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur lors du chargement des commentaires: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion: $e'
      };
    }
  }

  // Modifier un commentaire
  static Future<Map<String, dynamic>> editComment(String commentId, String content) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/api/comments/$commentId'),
        headers: headers,
        body: json.encode({
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'comment': data['comment']
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur lors de la modification: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion: $e'
      };
    }
  }

  // Supprimer un commentaire
  static Future<Map<String, dynamic>> deleteComment(String commentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/comments/$commentId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Commentaire supprimé'
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur lors de la suppression: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion: $e'
      };
    }
  }

  // ==========================================
  // STATISTIQUES
  // ==========================================
  
  // Obtenir les statistiques d'un contenu
  static Future<Map<String, dynamic>> getContentStats(String targetType, String targetId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/stats/$targetType/$targetId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'stats': data
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur lors du chargement des statistiques: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion: $e'
      };
    }
  }

  // ==========================================
  // ARTICLES
  // ==========================================
  
  // Créer un nouvel article
  static Future<Map<String, dynamic>> createArticle({
    required String title,
    required String content,
    String? summary,
    bool published = false,
    List<String>? tags
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/blog/articles'),
        headers: headers,
        body: json.encode({
          'title': title,
          'content': content,
          'summary': summary ?? '',
          'published': published,
          'tags': tags ?? []
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'article': data['article']
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur lors de la création: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion: $e'
      };
    }
  }

  // ==========================================
  // MÉDIAS
  // ==========================================
  
  // Upload de média
  static Future<Map<String, dynamic>> uploadMedia(File file, {
    String? title,
    String? description,
    List<String>? tags
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/media/upload'),
      );
      
      // Ajouter les headers d'auth
      final token = await _getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // Ajouter le fichier
      request.files.add(await http.MultipartFile.fromPath('files', file.path));
      
      // Ajouter les métadonnées
      if (title != null) request.fields['titles'] = title;
      if (description != null) request.fields['descriptions'] = description;
      if (tags != null) request.fields['tags'] = tags.join(',');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        return {
          'success': true,
          'medias': data['medias']
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur lors de l\'upload: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion: $e'
      };
    }
  }
}