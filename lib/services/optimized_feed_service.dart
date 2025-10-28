import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feed_models.dart';

class OptimizedFeedService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }
  static const Duration timeoutDuration = Duration(seconds: 10);
  
  // Cache pour optimiser les performances
  static final Map<String, dynamic> _cache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration cacheDuration = Duration(minutes: 5);
  
  // Obtenir le token JWT avec cache
  static String? _cachedToken;
  static DateTime? _tokenCacheTime;
  static Future<String?> _getToken() async {
    // Cache le token pendant 30 minutes
    if (_cachedToken != null && _tokenCacheTime != null) {
      final age = DateTime.now().difference(_tokenCacheTime!);
      if (age.inMinutes < 30) {
        return _cachedToken;
      }
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString('jwt_token');
      _tokenCacheTime = DateTime.now();
      return _cachedToken;
    } catch (e) {
      return null;
    }
  }

  // Headers optimisés
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

  // Feed unifié optimisé (articles + médias + blogs)
  static Future<Map<String, dynamic>> getUnifiedFeed({
    int page = 1,
    int limit = 20,
    String? search,
    bool useCache = true,
  }) async {
    // Vérifier le cache
    final cacheKey = 'unified_feed_$page${limit}_${search ?? 'all'}';
    if (useCache && _cache.containsKey(cacheKey) && _lastCacheUpdate != null) {
      final age = DateTime.now().difference(_lastCacheUpdate!);
      if (age < cacheDuration) {
        return _cache[cacheKey];
      }
    }

    try {
      final headers = await _getHeaders();
      
      // Essayer d'abord l'endpoint unifié optimisé
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'includeMedia': 'true',
        'includeArticles': 'true',
        'includeBlog': 'true',
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse('$baseUrl/api/feed/unified').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: headers).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Traiter et optimiser les données
        final feedItems = <FeedItem>[];
        
        // Traitement des articles
        final articles = data['articles'] as List? ?? [];
        for (final article in articles) {
          feedItems.add(FeedItem.fromArticle(article));
        }
        
        // Traitement des médias
        final medias = data['medias'] as List? ?? [];
        for (final media in medias) {
          feedItems.add(FeedItem.fromMedia(media));
        }
        
        // Traitement des blogs
        final blogs = data['blogs'] as List? ?? [];
        for (final blog in blogs) {
          feedItems.add(FeedItem.fromBlog(blog));
        }
        
        // Tri par date de création (plus récent en premier)
        feedItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        final result = {
          'success': true,
          'feed': feedItems.map((item) => item.toJson()).toList(),
          'pagination': data['pagination'] ?? {
            'page': page,
            'limit': limit,
            'total': feedItems.length,
            'hasMore': feedItems.length == limit,
          },
          'stats': {
            'articles': articles.length,
            'medias': medias.length,
            'blogs': blogs.length,
            'total': feedItems.length,
          }
        };
        
        // Mettre en cache
        _cache[cacheKey] = result;
        _lastCacheUpdate = DateTime.now();
        
        return result;
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
        final cachedData = _cache[cacheKey];
        cachedData['fromCache'] = true;
        return cachedData;
      }
      
      return {
        'success': false,
        'error': 'Erreur de connexion: $e',
        'feed': [],
      };
    }
  }

  // Obtenir tous les médias de la bibliothèque
  static Future<Map<String, dynamic>> getAllMedias({
    int page = 1,
    int limit = 50,
    String? type,
    String? search,
    bool useCache = true,
  }) async {
    final cacheKey = 'all_medias_$page${limit}_${type ?? 'all'}_${search ?? 'all'}';
    
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
        
        // Traiter les médias en FeedItems pour l'affichage unifié
        final medias = data['medias'] as List? ?? [];
        final feedItems = medias.map((media) => FeedItem.fromMedia(media)).toList();
        
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
      } else {
        return {
          'success': false,
          'error': 'Erreur du serveur: ${response.statusCode}',
          'medias': [],
        };
      }
    } catch (e) {
      if (_cache.containsKey(cacheKey)) {
        final cachedData = _cache[cacheKey];
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

  // Toggle like optimisé
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

  // Recherche rapide dans tout le contenu
  static Future<Map<String, dynamic>> quickSearch(String query, {int limit = 20}) async {
    if (query.isEmpty) {
      return {'success': true, 'results': []};
    }

    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/search').replace(queryParameters: {
          'q': query,
          'limit': limit.toString(),
          'includeAll': 'true',
        }),
        headers: headers,
      ).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Combiner tous les résultats en FeedItems
        final results = <FeedItem>[];
        
        final articles = data['articles'] as List? ?? [];
        final medias = data['medias'] as List? ?? [];
        final blogs = data['blogs'] as List? ?? [];
        
        for (final article in articles) {
          results.add(FeedItem.fromArticle(article));
        }
        
        for (final media in medias) {
          results.add(FeedItem.fromMedia(media));
        }
        
        for (final blog in blogs) {
          results.add(FeedItem.fromBlog(blog));
        }
        
        // Tri par pertinence/date
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        return {
          'success': true,
          'results': results.map((item) => item.toJson()).toList(),
          'stats': {
            'total': results.length,
            'articles': articles.length,
            'medias': medias.length,
            'blogs': blogs.length,
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
    _cachedToken = null;
    _tokenCacheTime = null;
  }

  // Pré-charger les données populaires
  static Future<void> preloadData() async {
    // Pré-charger la première page du feed
    getUnifiedFeed(page: 1, limit: 20, useCache: false);
    
    // Pré-charger les médias populaires
    getAllMedias(page: 1, limit: 30, useCache: false);
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