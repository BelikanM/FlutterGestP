import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'profile_service.dart';

class MediaService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/media';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api/media';
    } else {
      return 'http://localhost:5000/api/media';
    }
  }

  // Modèles
  static MediaItem mediaFromJson(Map<String, dynamic> json) {
    // Détection du type correct basé sur mimetype et nom de fichier
    String detectedType = json['type'] ?? 'document';
    final mimetype = json['mimetype'] ?? '';
    final filename = json['originalName'] ?? json['filename'] ?? '';
    
    // Si le type backend est incorrect, on le corrige côté client
    if (detectedType == 'document' && mimetype.isNotEmpty) {
      detectedType = getMediaTypeFromMimetype(mimetype);
    }
    
    // Double vérification avec l'extension si nécessaire
    if (detectedType == 'document' && filename.isNotEmpty) {
      final typeFromExt = getMediaTypeFromExtension(filename);
      if (typeFromExt != 'document') {
        detectedType = typeFromExt;
      }
    }
    
    return MediaItem(
      id: json['_id'],
      title: json['title'],
      description: json['description'] ?? '',
      filename: json['filename'],
      originalName: json['originalName'],
      url: json['url'],
      mimetype: mimetype,
      size: json['size'],
      type: detectedType, // Type corrigé
      tags: List<String>.from(json['tags'] ?? []),
      uploadedBy: json['uploadedBy'],
      isPublic: json['isPublic'] ?? false,
      usageCount: json['usageCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // Télécharger des médias
  static Future<List<MediaItem>> uploadMedias({
    required List<PlatformFile> files,
    required List<String> titles,
    List<String>? descriptions,
    List<String>? tags,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token d\'authentification manquant');

      final uri = Uri.parse('$baseUrl/upload');
      final request = http.MultipartRequest('POST', uri);

      // Headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Ajouter les fichiers
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final multipartFile = await http.MultipartFile.fromPath(
          'files',
          file.path!,
          filename: file.name,
        );
        request.files.add(multipartFile);
      }

      // Ajouter les métadonnées avec des clés indexées pour supporter plusieurs fichiers
      for (int i = 0; i < titles.length; i++) {
        request.fields['titles[$i]'] = titles[i];
        if (descriptions != null && i < descriptions.length) {
          request.fields['descriptions[$i]'] = descriptions[i];
        }
        if (tags != null && i < tags.length) {
          request.fields['tags[$i]'] = tags[i];
        }
      }

      // Uploading ${files.length} medias...

      // Timeout plus long pour les connexions lentes (2 minutes)
      final response = await request.send().timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw TimeoutException('Le téléversement prend trop de temps. Vérifiez votre connexion internet.');
        },
      );
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(responseBody);
        final mediasJson = data['medias'] as List;
        
        // ${mediasJson.length} medias uploaded successfully
        
        final uploadedMedias = mediasJson.map((media) => mediaFromJson(media)).toList();
        
        // Notifier tous les utilisateurs des nouveaux médias
        try {
          final token = await AuthService.getToken();
          if (token != null) {
            final profileService = ProfileService();
            final userInfo = await profileService.getUserInfo(token);
            final uploaderName = userInfo['name'] ?? 'Utilisateur inconnu';
            
            for (final media in uploadedMedias) {
              await NotificationService.notifyNewMedia(
                filename: media.originalName,
                type: media.type,
                uploadedBy: uploaderName,
              );
            }
            // Notifications sent for ${uploadedMedias.length} medias
          }
        } catch (e) {
          // Error sending notifications: $e
        }
        
        return uploadedMedias;
      } else {
        final error = json.decode(responseBody);
        throw Exception(error['error'] ?? 'Erreur lors du téléchargement');
      }
    } on TimeoutException catch (e) {
      throw Exception(e.message ?? 'Timeout: Le téléversement a pris trop de temps. Vérifiez votre connexion.');
    } catch (e) {
      // Upload error: $e
      if (e.toString().contains('SocketException')) {
        throw Exception('Erreur de connexion. Vérifiez votre connexion internet.');
      }
      rethrow;
    }
  }

  // Récupérer les médias de l'utilisateur
  static Future<MediaResponse> getMedias({
    String? type,
    List<String>? tags,
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token d\'authentification manquant');

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (type != null && type != 'all') queryParams['type'] = type;
      if (tags != null && tags.isNotEmpty) queryParams['tags'] = tags.join(',');
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final mediasJson = data['medias'] as List;
        final medias = mediasJson.map((media) => mediaFromJson(media)).toList();
        
        // Loaded ${medias.length} medias
        
        return MediaResponse(
          medias: medias,
          pagination: PaginationInfo.fromJson(data['pagination']),
        );
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erreur lors du chargement');
      }
    } on TimeoutException {
      throw Exception('Timeout: Le chargement a pris trop de temps');
    } catch (e) {
      // Get medias error: $e
      rethrow;
    }
  }

  // Récupérer un média spécifique
  static Future<MediaItem> getMedia(String id) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token d\'authentification manquant');

      final response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return mediaFromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Média non trouvé');
      }
    } catch (e) {
      // Get media error: $e
      rethrow;
    }
  }

  // Mettre à jour un média
  static Future<MediaItem> updateMedia({
    required String id,
    String? title,
    String? description,
    List<String>? tags,
    bool? isPublic,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token d\'authentification manquant');

      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (tags != null) body['tags'] = tags.join(',');
      if (isPublic != null) body['isPublic'] = isPublic;

      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Media updated successfully
        return mediaFromJson(data['media']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erreur lors de la mise à jour');
      }
    } catch (e) {
      // Update media error: $e
      rethrow;
    }
  }

  // Supprimer un média
  static Future<void> deleteMedia(String id) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token d\'authentification manquant');

      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Media deleted successfully
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erreur lors de la suppression');
      }
    } catch (e) {
      // Delete media error: $e
      rethrow;
    }
  }

  // Statistiques des médias
  static Future<MediaStats> getMediaStats() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Token d\'authentification manquant');

      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MediaStats.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erreur lors du chargement des stats');
      }
    } catch (e) {
      // Get stats error: $e
      rethrow;
    }
  }

  // Formatage de la taille des fichiers
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Détection du type de média basé sur le mimetype
  static String getMediaTypeFromMimetype(String mimetype) {
    if (mimetype.startsWith('image/')) {
      return 'image';
    } else if (mimetype.startsWith('video/')) {
      return 'video';
    } else if (mimetype.startsWith('audio/')) {
      return 'audio';
    } else if (mimetype.contains('pdf') || 
               mimetype.contains('document') || 
               mimetype.contains('text/') ||
               mimetype.contains('application/json') ||
               mimetype.contains('application/xml')) {
      return 'document';
    }
    return 'document'; // Par défaut
  }

  // Détection du type basé sur l'extension
  static String getMediaTypeFromExtension(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].contains(ext)) {
      return 'image';
    } else if (['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv'].contains(ext)) {
      return 'video';
    } else if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma'].contains(ext)) {
      return 'audio';
    } else {
      return 'document';
    }
  }

  // Icône selon le type de média
  static String getMediaIcon(String type) {
    switch (type) {
      case 'image':
        return '🖼️';
      case 'video':
        return '🎥';
      case 'audio':
        return '🎵';
      case 'document':
        return '📄';
      default:
        return '📎';
    }
  }
}

// Modèles de données
class MediaItem {
  final String id;
  final String title;
  final String description;
  final String filename;
  final String originalName;
  final String url;
  final String mimetype;
  final int size;
  final String type;
  final List<String> tags;
  final String uploadedBy;
  final bool isPublic;
  final int usageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  MediaItem({
    required this.id,
    required this.title,
    required this.description,
    required this.filename,
    required this.originalName,
    required this.url,
    required this.mimetype,
    required this.size,
    required this.type,
    required this.tags,
    required this.uploadedBy,
    required this.isPublic,
    required this.usageCount,
    required this.createdAt,
    required this.updatedAt,
  });
}

class MediaResponse {
  final List<MediaItem> medias;
  final PaginationInfo pagination;

  MediaResponse({required this.medias, required this.pagination});
}

class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int pages;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'],
      limit: json['limit'],
      total: json['total'],
      pages: json['pages'],
    );
  }
}

class MediaStats {
  final int totalMedias;
  final int totalSize;
  final List<TypeStats> byType;

  MediaStats({
    required this.totalMedias,
    required this.totalSize,
    required this.byType,
  });

  factory MediaStats.fromJson(Map<String, dynamic> json) {
    final byTypeList = json['byType'] as List? ?? [];
    return MediaStats(
      totalMedias: json['totalMedias'] ?? 0,
      totalSize: json['totalSize'] ?? 0,
      byType: byTypeList.map((item) => TypeStats.fromJson(item)).toList(),
    );
  }
}

class TypeStats {
  final String type;
  final int count;
  final int totalSize;

  TypeStats({
    required this.type,
    required this.count,
    required this.totalSize,
  });

  factory TypeStats.fromJson(Map<String, dynamic> json) {
    return TypeStats(
      type: json['_id'] ?? 'unknown',
      count: json['count'] ?? 0,
      totalSize: json['totalSize'] ?? 0,
    );
  }
}