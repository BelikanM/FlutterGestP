import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feed_models.dart';

class PublicFeedService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }
  static const Duration timeoutDuration = Duration(seconds: 15);
  
  // Cache simple pour améliorer les performances
  static final Map<String, dynamic> _cache = <String, dynamic>{};
  static DateTime? _lastCacheUpdate;
  static const Duration cacheDuration = Duration(minutes: 5);
  
  // Obtenir le token JWT (optionnel)
  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('jwt_token');
    } catch (e) {
      return null;
    }
  }

  // Headers basiques (sans authentification obligatoire)
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Ajouter le token seulement s'il existe
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  // Vérifier l'authentification (optionnelle)
  static Future<bool> isUserAuthenticated() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  // Feed public (articles + médias publics)
  static Future<Map<String, dynamic>> getPublicFeed({
    int page = 1,
    int limit = 20,
    String? search,
    bool useCache = true,
  }) async {
    // Vérifier le cache
    final cacheKey = 'public_feed_${page}_${limit}_${search ?? 'all'}';
    if (useCache && _cache.containsKey(cacheKey) && _lastCacheUpdate != null) {
      final age = DateTime.now().difference(_lastCacheUpdate!);
      if (age < cacheDuration) {
        return _cache[cacheKey];
      }
    }

    try {
      final headers = await _getHeaders();
      
      // Utiliser le nouveau endpoint public combiné
      final feedUri = Uri.parse('$baseUrl/api/public/feed').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

      final response = await http.get(feedUri, headers: headers).timeout(timeoutDuration);

      final feedItems = <FeedItem>[];

      if (response.statusCode == 200) {
        try {
          final feedData = json.decode(response.body);
          final items = feedData['feed'] as List? ?? [];
          
          for (final item in items) {
            if (item['feedType'] == 'article') {
              feedItems.add(FeedItem(
                id: item['_id'] ?? '',
                type: 'article',
                title: item['title'] ?? '',
                content: item['content'],
                description: item['summary'] ?? item['description'],
                tags: List<String>.from(item['tags'] ?? []),
                createdAt: DateTime.parse(item['createdAt'] ?? DateTime.now().toIso8601String()),
                author: FeedUser(
                  id: item['author']?['_id'] ?? '',
                  name: item['author']?['name'] ?? 'Auteur',
                  email: item['author']?['email'] ?? '',
                  role: item['author']?['role'] ?? 'user',
                ),
                likesCount: item['likesCount'] ?? 0,
                commentsCount: item['commentsCount'] ?? 0,
                viewsCount: item['viewsCount'] ?? 0,
                mediaFiles: (item['mediaFiles'] as List<dynamic>?)
                    ?.map((mf) => MediaFile.fromJson(mf))
                    .toList() ?? [],
              ));
            } else if (item['feedType'] == 'media') {
              feedItems.add(FeedItem(
                id: item['_id'] ?? '',
                type: 'media',
                title: item['title'] ?? item['originalName'] ?? '',
                description: item['description'],
                url: item['url'],
                mimetype: item['mimetype'],
                tags: List<String>.from(item['tags'] ?? []),
                createdAt: DateTime.parse(item['createdAt'] ?? DateTime.now().toIso8601String()),
                author: FeedUser(
                  id: item['author']?['_id'] ?? '',
                  name: item['author']?['name'] ?? 'Utilisateur',
                  email: item['author']?['email'] ?? '',
                  role: item['author']?['role'] ?? 'user',
                ),
                viewsCount: item['usageCount'] ?? 0,
              ));
            }
          }
        } catch (e) {
          debugPrint('❌ Erreur parsing feed public: $e');
        }
      }

      final result = {
        'success': true,
        'feed': feedItems.map((item) => item.toJson()).toList(),
        'pagination': {
          'page': page,
          'limit': limit,
          'total': feedItems.length,
          'hasMore': feedItems.length >= limit,
        },
        'stats': {
          'articles': feedItems.where((item) => item.type == 'article').length,
          'medias': feedItems.where((item) => item.type == 'media').length,
          'total': feedItems.length,
        }
      };

      // Mettre en cache seulement si on a des données
      if (feedItems.isNotEmpty) {
        _cache[cacheKey] = result;
        _lastCacheUpdate = DateTime.now();
      }

      return result;

    } catch (e) {
      // En cas d'erreur, essayer de retourner les données du cache
      if (_cache.containsKey(cacheKey)) {
        final cachedData = Map<String, dynamic>.from(_cache[cacheKey]);
        cachedData['fromCache'] = true;
        return cachedData;
      }

      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
        'feed': [],
        'pagination': {
          'page': page,
          'limit': limit,
          'total': 0,
          'hasMore': false,
        },
        'stats': {
          'articles': 0,
          'medias': 0,
          'total': 0,
        }
      };
    }
  }

  // Obtenir les médias publics
  static Future<Map<String, dynamic>> getPublicMedias({
    int page = 1,
    int limit = 50,
    String? type,
    String? search,
    bool useCache = true,
  }) async {
    final cacheKey = 'public_medias_${page}_${limit}_${type ?? 'all'}_${search ?? 'all'}';
    
    if (useCache && _cache.containsKey(cacheKey) && _lastCacheUpdate != null) {
      final age = DateTime.now().difference(_lastCacheUpdate!);
      if (age < cacheDuration) {
        return _cache[cacheKey];
      }
    }

    try {
      final headers = await _getHeaders();
      
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (type != null && type != 'all') 'type': type,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse('$baseUrl/api/public/medias').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: headers).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Traiter les médias
        final medias = data['medias'] as List? ?? [];
        final mediaItems = medias.map((media) {
          return FeedItem(
            id: media['_id'] ?? '',
            type: 'media',
            title: media['title'] ?? media['originalName'] ?? '',
            description: media['description'],
            url: media['url'],
            mimetype: media['mimetype'],
            tags: List<String>.from(media['tags'] ?? []),
            createdAt: DateTime.parse(media['createdAt'] ?? DateTime.now().toIso8601String()),
            author: FeedUser(
              id: media['uploadedBy']?['_id'] ?? '',
              name: media['uploadedBy']?['name'] ?? 'Utilisateur',
              email: media['uploadedBy']?['email'] ?? '',
              role: media['uploadedBy']?['role'] ?? 'user',
            ),
            viewsCount: media['usageCount'] ?? 0,
          );
        }).toList();

        final result = {
          'success': true,
          'medias': mediaItems.map((item) => item.toJson()).toList(),
          'pagination': data['pagination'] ?? {},
          'stats': {
            'total': mediaItems.length,
            'byType': data['stats']?['byType'] ?? [],
          }
        };

        // Mettre en cache
        if (mediaItems.isNotEmpty) {
          _cache[cacheKey] = result;
          _lastCacheUpdate = DateTime.now();
        }

        return result;
      } else {
        return {
          'success': false,
          'error': 'Erreur du serveur: ${response.statusCode}',
          'medias': [],
        };
      }
    } catch (e) {
      if (_cache.containsKey(cacheKey)) {
        final cachedData = Map<String, dynamic>.from(_cache[cacheKey]);
        cachedData['fromCache'] = true;
        return cachedData;
      }

      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
        'medias': [],
      };
    }
  }

  // Toggle like (seulement si connecté)
  static Future<Map<String, dynamic>> toggleLike(String targetType, String targetId) async {
    try {
      if (!await isUserAuthenticated()) {
        return {
          'success': false,
          'error': 'Vous devez être connecté pour aimer ce contenu',
        };
      }

      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/likes'),
        headers: headers,
        body: json.encode({
          'targetType': targetType,
          'targetId': targetId,
        }),
      ).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Invalider le cache après un like
        _clearFeedCache();
        
        return {
          'success': true,
          'action': data['action'],
          'likesCount': data['likesCount'] ?? 0,
          'isLiked': data['isLiked'] ?? false,
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur lors du like: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
      };
    }
  }

  // Recherche publique
  static Future<Map<String, dynamic>> quickSearch(String query, {int limit = 20}) async {
    if (query.isEmpty) {
      return {'success': true, 'results': []};
    }

    try {
      final result = await getPublicFeed(page: 1, limit: limit, search: query, useCache: false);
      
      if (result['success'] == true) {
        final feedItems = result['feed'] as List;
        
        return {
          'success': true,
          'results': feedItems,
          'stats': {
            'total': feedItems.length,
            'query': query,
          }
        };
      } else {
        return result;
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
        'results': [],
      };
    }
  }

  // Vider le cache du feed
  static void _clearFeedCache() {
    _cache.removeWhere((key, value) => key.contains('public_feed') || key.contains('public_medias'));
  }

  // Vider tout le cache
  static void clearCache() {
    _cache.clear();
    _lastCacheUpdate = null;
  }

  // Pré-charger les données publiques
  static Future<void> preloadData() async {
    // Pré-charger la première page du feed public
    getPublicFeed(page: 1, limit: 20, useCache: false);
    
    // Pré-charger les médias publics
    getPublicMedias(page: 1, limit: 30, useCache: false);
  }

  // Statistiques du cache
  static Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _cache.length,
      'lastUpdate': _lastCacheUpdate?.toIso8601String(),
      'cacheKeys': _cache.keys.toList(),
    };
  }
}