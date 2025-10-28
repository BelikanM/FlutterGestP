import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feed_models.dart';

class UnifiedFeedService {
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
  
  // Cache simple
  static final Map<String, dynamic> _cache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration cacheDuration = Duration(minutes: 3);
  
  // Obtenir le token JWT
  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('jwt_token');
    } catch (e) {
      return null;
    }
  }

  // Headers avec authentification
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Vérifier l'authentification
  static Future<bool> isUserAuthenticated() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  // Feed unifié utilisant les endpoints existants
  static Future<Map<String, dynamic>> getUnifiedFeed({
    int page = 1,
    int limit = 20,
    String? search,
    bool useCache = true,
  }) async {
    final cacheKey = 'unified_feed_${page}_${limit}_${search ?? 'all'}';
    
    // Vérifier le cache
    if (useCache && _cache.containsKey(cacheKey) && _lastCacheUpdate != null) {
      final age = DateTime.now().difference(_lastCacheUpdate!);
      if (age < cacheDuration) {
        return _cache[cacheKey];
      }
    }

    try {
      final headers = await _getHeaders();
      
      // Utiliser l'endpoint social feed existant qui combine articles et médias
      final uri = Uri.parse('$baseUrl/api/feed/social').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

      final response = await http.get(uri, headers: headers).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Traiter les données pour le format attendu
        final feedData = data['feed'] as List<dynamic>;
        final feedItems = <FeedItem>[];
        
        for (final item in feedData) {
          try {
            // Déterminer le type basé sur les propriétés
            final itemType = item['type'] ?? item['feedType'] ?? 'article';
            
            FeedItem feedItem;
            if (itemType == 'media') {
              feedItem = FeedItem.fromMedia(item);
            } else {
              feedItem = FeedItem.fromArticle(item);
            }
            
            feedItems.add(feedItem);
          } catch (e) {
            // Ignorer les éléments problématiques mais continuer
            continue;
          }
        }
        
        final result = {
          'success': true,
          'feed': feedItems.map((item) => item.toJson()).toList(),
          'pagination': data['pagination'] ?? {
            'page': page,
            'limit': limit,
            'total': feedItems.length,
            'hasMore': feedItems.length == limit,
          },
          'stats': data['stats'] ?? {
            'articles': feedItems.where((item) => item.type == 'article').length,
            'medias': feedItems.where((item) => item.type == 'media').length,
            'total': feedItems.length,
          }
        };
        
        // Mettre en cache
        _cache[cacheKey] = result;
        _lastCacheUpdate = DateTime.now();
        
        return result;
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Vous devez vous reconnecter',
          'needsAuth': true,
          'feed': [],
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur du serveur: ${response.statusCode}',
          'feed': [],
        };
      }
    } catch (e) {
      // En cas d'erreur, essayer de retourner les données du cache
      if (_cache.containsKey(cacheKey)) {
        final cachedData = Map<String, dynamic>.from(_cache[cacheKey]);
        cachedData['fromCache'] = true;
        cachedData['cacheError'] = e.toString();
        return cachedData;
      }
      
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
        'feed': [],
      };
    }
  }

  // Obtenir tous les médias
  static Future<Map<String, dynamic>> getAllMedias({
    int page = 1,
    int limit = 50,
    String? type,
    String? search,
    bool useCache = true,
  }) async {
    final cacheKey = 'all_medias_${page}_${limit}_${type ?? 'all'}_${search ?? 'all'}';
    
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

      final uri = Uri.parse('$baseUrl/api/media').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: headers).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Traiter les médias en FeedItems
        final medias = data['medias'] as List<dynamic>;
        final feedItems = <FeedItem>[];
        
        for (final media in medias) {
          try {
            final feedItem = FeedItem.fromMedia(media);
            feedItems.add(feedItem);
          } catch (e) {
            continue;
          }
        }
        
        final result = {
          'success': true,
          'medias': feedItems.map((item) => item.toJson()).toList(),
          'pagination': data['pagination'] ?? {},
          'stats': {
            'total': feedItems.length,
            'byType': data['stats']?['byType'] ?? [],
          }
        };
        
        // Mettre en cache
        _cache[cacheKey] = result;
        _lastCacheUpdate = DateTime.now();
        
        return result;
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Vous devez vous reconnecter',
          'needsAuth': true,
          'medias': [],
        };
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

  // Toggle like
  static Future<Map<String, dynamic>> toggleLike(String targetType, String targetId) async {
    try {
      if (!await isUserAuthenticated()) {
        return {
          'success': false,
          'error': 'Vous devez être connecté pour aimer ce contenu',
          'needsAuth': true,
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
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expirée, veuillez vous reconnecter',
          'needsAuth': true,
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

  // Recherche rapide
  static Future<Map<String, dynamic>> quickSearch(String query, {int limit = 20}) async {
    if (query.isEmpty) {
      return {'success': true, 'results': []};
    }

    try {
      final headers = await _getHeaders();
      
      // Utiliser l'endpoint social feed avec recherche
      final response = await http.get(
        Uri.parse('$baseUrl/api/feed/social').replace(queryParameters: {
          'search': query,
          'limit': limit.toString(),
        }),
        headers: headers,
      ).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final feedData = data['feed'] as List<dynamic>;
        final results = <FeedItem>[];
        
        for (final item in feedData) {
          try {
            final itemType = item['type'] ?? item['feedType'] ?? 'article';
            
            FeedItem feedItem;
            if (itemType == 'media') {
              feedItem = FeedItem.fromMedia(item);
            } else {
              feedItem = FeedItem.fromArticle(item);
            }
            
            results.add(feedItem);
          } catch (e) {
            continue;
          }
        }
        
        return {
          'success': true,
          'results': results.map((item) => item.toJson()).toList(),
          'stats': {
            'total': results.length,
            'articles': results.where((item) => item.type == 'article').length,
            'medias': results.where((item) => item.type == 'media').length,
          }
        };
      } else {
        return {
          'success': false,
          'error': 'Erreur de recherche: ${response.statusCode}',
          'results': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
        'results': [],
      };
    }
  }

  // Vider le cache
  static void _clearFeedCache() {
    _cache.removeWhere((key, value) => key.contains('unified_feed') || key.contains('all_medias'));
  }

  // Vider tout le cache
  static void clearCache() {
    _cache.clear();
    _lastCacheUpdate = null;
  }

  // Pré-charger les données
  static Future<void> preloadData() async {
    try {
      // Pré-charger la première page du feed
      await getUnifiedFeed(page: 1, limit: 20, useCache: false);
      
      // Pré-charger les médias
      await getAllMedias(page: 1, limit: 30, useCache: false);
    } catch (e) {
      // Ignorer les erreurs de pré-chargement
    }
  }

  // Statistiques du cache (pour debug)
  static Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _cache.length,
      'lastUpdate': _lastCacheUpdate?.toIso8601String(),
      'cacheKeys': _cache.keys.toList(),
    };
  }
}