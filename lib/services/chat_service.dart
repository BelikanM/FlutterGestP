import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';

class ChatService {
  // URL du backend selon la plateforme
  static String get baseUrl {
    if (kIsWeb) {
      // Web : localhost
      return 'http://localhost:5000/api';
    } else if (Platform.isAndroid) {
      // Android émulateur : 10.0.2.2 pointe vers localhost de l'hôte
      return 'http://10.0.2.2:5000/api';
    } else {
      // Windows, iOS, autres : localhost
      return 'http://localhost:5000/api';
    }
  }
  
  // Récupérer le token d'authentification
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Headers avec authentification
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Headers pour upload de fichiers
  Future<Map<String, String>> _getUploadHeaders() async {
    final token = await _getAuthToken();
    return {
      'Authorization': 'Bearer $token',
    };
  }

  // ========================================
  // RÉCUPÉRATION DES MESSAGES
  // ========================================

  /// Récupère les messages du chat de groupe avec pagination
  Future<ChatMessagesResponse> getMessages({
    int page = 1,
    int limit = 50,
    String? before,
  }) async {
    try {
      final headers = await _getHeaders();
      
      String url = '$baseUrl/chat/messages?page=$page&limit=$limit';
      if (before != null) {
        url += '&before=$before';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatMessagesResponse.fromJson(data);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // ========================================
  // ENVOI DE MESSAGES
  // ========================================

  /// Partage un article de blog dans le chat de groupe
  Future<ChatMessage> shareBlogArticle({
    required String articleId,
    required String title,
    required String summary,
    required String authorName,
  }) async {
    try {
      final headers = await _getHeaders();

      // Formater le contenu du message de partage
      final content = '📝 **Article partagé**\n\n'
          '**$title**\n\n'
          '${summary.isNotEmpty ? '$summary\n\n' : ''}'
          '🔗 Voir l\'article complet';

      final body = {
        'content': content,
        'blogArticleId': articleId,
        'messageType': 'blog_share',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/chat/message'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return ChatMessage.fromJson(data['message']);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur lors du partage de l\'article: $e');
    }
  }

  /// Envoie un message texte
  Future<ChatMessage> sendTextMessage(String content, {String? replyToId}) async {
    try {
      final headers = await _getHeaders();

      final body = {
        'content': content,
        if (replyToId != null) 'replyToId': replyToId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/chat/message'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return ChatMessage.fromJson(data['message']);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi: $e');
    }
  }

  /// Envoie un message avec média (image, vidéo, audio)
  Future<ChatMessage> sendMediaMessage(
    File mediaFile, 
    String mediaType, {
    String? content,
    String? replyToId,
  }) async {
    try {
      final headers = await _getUploadHeaders();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/chat/message'),
      );

      // Ajouter les headers d'authentification
      request.headers.addAll(headers);

      // Ajouter le fichier média
      request.files.add(
        await http.MultipartFile.fromPath(
          'media',
          mediaFile.path,
        ),
      );

      // Ajouter les champs texte
      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }
      if (replyToId != null) {
        request.fields['replyToId'] = replyToId;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return ChatMessage.fromJson(data['message']);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi du média: $e');
    }
  }

  // ========================================
  // GESTION DES MESSAGES
  // ========================================

  /// Marquer un message comme lu
  Future<bool> markMessageAsRead(String messageId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.put(
        Uri.parse('$baseUrl/chat/message/$messageId/read'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      // Log silencieux en cas d'erreur de marquage
      return false;
    }
  }

  /// Supprimer un message
  Future<bool> deleteMessage(String messageId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl/chat/message/$messageId'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      // Log silencieux en cas d'erreur de suppression
      return false;
    }
  }

  /// Modifier un message existant
  Future<bool> editMessage(String messageId, String newContent) async {
    try {
      final headers = await _getHeaders();

      final response = await http.put(
        Uri.parse('$baseUrl/chat/message/$messageId'),
        headers: headers,
        body: json.encode({'content': newContent}),
      );

      return response.statusCode == 200;
    } catch (e) {
      // Log silencieux en cas d'erreur de modification
      return false;
    }
  }

  /// Ajouter une photo à un message texte
  Future<bool> addPhotoToMessage(String messageId, File imageFile) async {
    try {
      final uploadHeaders = await _getUploadHeaders();
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/chat/message/$messageId/photo'),
      );
      
      request.headers.addAll(uploadHeaders);
      request.files.add(
        await http.MultipartFile.fromPath('photo', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Remplacer la photo d'un message
  Future<bool> replaceMessagePhoto(String messageId, File imageFile) async {
    try {
      final uploadHeaders = await _getUploadHeaders();
      
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/chat/message/$messageId/photo'),
      );
      
      request.headers.addAll(uploadHeaders);
      request.files.add(
        await http.MultipartFile.fromPath('photo', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Supprimer la photo d'un message
  Future<bool> removeMessagePhoto(String messageId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl/chat/message/$messageId/photo'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ========================================
  // NOTIFICATIONS DE GROUPE
  // ========================================

  /// Récupérer les notifications non lues
  Future<List<GroupNotification>> getUnreadNotifications() async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/chat/notifications'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final notifications = (data['notifications'] as List)
            .map((item) => GroupNotification.fromJson(item))
            .toList();
        return notifications;
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // Log silencieux en cas d'erreur de récupération des notifications
      return [];
    }
  }

  /// Marquer toutes les notifications comme lues
  Future<bool> markAllNotificationsAsRead() async {
    try {
      final headers = await _getHeaders();

      final response = await http.put(
        Uri.parse('$baseUrl/chat/notifications/read-all'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      // Log silencieux en cas d'erreur de marquage des notifications
      return false;
    }
  }

  // ========================================
  // STATISTIQUES DU CHAT
  // ========================================

  /// Récupérer les statistiques du chat
  Future<ChatStats?> getChatStats() async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/chat/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatStats.fromJson(data['stats']);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // Log silencieux en cas d'erreur de récupération des stats
      return null;
    }
  }

  // ========================================
  // UTILITAIRES
  // ========================================

  /// Déterminer le type de média à partir de l'extension du fichier
  String getMediaTypeFromFile(File file) {
    final extension = file.path.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'image';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'webm':
        return 'video';
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'm4a':
        return 'audio';
      default:
        return 'file';
    }
  }

  /// Formater la taille d'un fichier
  String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Vérifier si un fichier est supporté pour l'upload
  bool isFileTypeSupported(File file) {
    final mediaType = getMediaTypeFromFile(file);
    return ['image', 'video', 'audio'].contains(mediaType);
  }

  /// Obtenir l'URL complète d'un média
  String getMediaUrl(String relativePath) {
    if (relativePath.startsWith('http')) {
      return relativePath;
    }
    // Utilise le baseUrl dynamique
    final base = baseUrl.replaceAll('/api', ''); // Enlever /api du baseUrl
    return '$base$relativePath';
  }
}