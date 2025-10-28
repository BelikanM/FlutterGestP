// blog_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'session_service.dart';

class BlogService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }
  
  // Cache pour améliorer les performances
  static List<dynamic>? _cachedArticles;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheValidDuration = Duration(minutes: 5); // Cache valide pendant 5 minutes

  Map<String, String> _getHeaders({String? token}) {
    Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Vérifie si le token est valide et le rafraîchit si nécessaire
  Future<String> _ensureValidToken(String token) async {
    try {
      // Test du token actuel avec une requête simple
      final testResponse = await http.get(
        Uri.parse('$baseUrl/api/user'),
        headers: _getHeaders(token: token),
      );
      
      if (testResponse.statusCode == 401) {
        // Token expiré, essayer de le rafraîchir
        final refreshed = await SessionService.checkAndRefreshToken();
        if (refreshed) {
          final prefs = await SharedPreferences.getInstance();
          return prefs.getString('auth_token') ?? token;
        } else {
          throw Exception('Session expirée. Veuillez vous reconnecter.');
        }
      }
      
      return token; // Token valide
    } catch (e) {
      throw Exception('Erreur d\'authentification: ${e.toString()}');
    }
  }

  /// Crée un nouvel article de blog
  Future<Map<String, dynamic>> createArticle(String token, {
    required String title,
    required String content,
    required String summary,
    List<String>? tags,
  }) async {
    try {
      // Vérifier et rafraîchir le token si nécessaire
      final validToken = await _ensureValidToken(token);
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/blog/articles'),
        headers: _getHeaders(token: validToken),
        body: jsonEncode({
          'title': title,
          'content': content,
          'summary': summary,
          'tags': tags ?? [],
        }),
      );

      if (response.statusCode != 201) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Erreur lors de la création de l\'article');
      }

      // Prolonger la session
      await SessionService.extendSession();
      
      // Invalider le cache après création d'un article
      BlogService.invalidateCache();
      
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('❌ Create article error: $e');
      rethrow;
    }
  }

  /// Récupère tous les articles de blog avec cache intelligent et optimisations performance
  Future<List<dynamic>> getArticles(String token, {int page = 1, int limit = 20, bool forceRefresh = false}) async {
    try {
      // Vérifier le cache d'abord (seulement pour la première page)
      if (!forceRefresh && page == 1 && _cachedArticles != null && _cacheTimestamp != null) {
        final now = DateTime.now();
        if (now.difference(_cacheTimestamp!) < _cacheValidDuration) {
          debugPrint('📦 Using cached articles (${_cachedArticles!.length} items)');
          return _cachedArticles!;
        }
      }
      
      debugPrint(' Making request to: $baseUrl/api/blog/articles?limit=$limit&page=$page');
      
      // Requête avec timeout plus long pour éviter les erreurs
      debugPrint('📡 Starting request with token: ${token.substring(0, 20)}...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/blog/articles?limit=$limit&page=$page'),
        headers: _getHeaders(token: token),
      ).timeout(
        const Duration(seconds: 20), 
        onTimeout: () {
          debugPrint('⏰ Request timed out after 20 seconds');
          throw TimeoutException('Connexion trop lente', const Duration(seconds: 20));
        }
      ); // Timeout encore plus généreux

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        debugPrint('❌ Server error (${response.statusCode}): $errorData');
        
        // Gestion spécifique des erreurs de timeout et de réseau
        if (response.statusCode >= 500) {
          throw Exception('Erreur serveur temporaire. Veuillez réessayer.');
        } else if (response.statusCode == 401) {
          throw Exception('Session expirée. Veuillez vous reconnecter.');
        } else {
          throw Exception(errorData['error'] ?? 'Erreur lors du chargement des articles');
        }
      }

      await SessionService.extendSession();
      
      final data = jsonDecode(response.body);
      
      List<dynamic> articles;
      if (data is List) {
        articles = data;
      } else if (data is Map && data.containsKey('articles')) {
        articles = data['articles'] ?? [];
      } else {
        articles = [];
      }
      
      // Mettre en cache seulement la première page
      if (page == 1) {
        _cachedArticles = articles;
        _cacheTimestamp = DateTime.now();
      }
      
      debugPrint('✅ Loaded ${articles.length} articles ${page == 1 ? "(cached)" : ""}');
      return articles;
    } catch (e) {
      debugPrint('❌ Exception in getArticles: $e');
      
      // Retry avec une approche différente en cas de timeout
      if (e.toString().contains('timeout') || e.toString().contains('SocketException')) {
        debugPrint('🔄 Retrying request due to network error...');
        try {
          // Petite pause avant le retry
          await Future.delayed(const Duration(milliseconds: 500));
          
          final retryResponse = await http.get(
            Uri.parse('$baseUrl/api/blog/articles?limit=$limit&page=$page'),
            headers: _getHeaders(token: token),
          ).timeout(const Duration(seconds: 20)); // Timeout encore plus long pour le retry
          
          if (retryResponse.statusCode == 200) {
            final data = jsonDecode(retryResponse.body);
            List<dynamic> articles;
            if (data is List) {
              articles = data;
            } else if (data is Map && data.containsKey('articles')) {
              articles = data['articles'] ?? [];
            } else {
              articles = [];
            }
            
            if (page == 1) {
              _cachedArticles = articles;
              _cacheTimestamp = DateTime.now();
            }
            
            debugPrint('✅ Retry successful - loaded ${articles.length} articles');
            return articles;
          }
        } catch (retryError) {
          debugPrint('❌ Retry also failed: $retryError');
        }
      }
      
      // Retourner le cache si la requête échoue mais qu'on a des données en cache
      if (_cachedArticles != null && page == 1) {
        debugPrint('📦 Fallback to cached articles');
        return _cachedArticles!;
      }
      
      rethrow;
    }
  }
  
  /// Invalide le cache des articles (à appeler après création/modification/suppression)
  static void invalidateCache() {
    _cachedArticles = null;
    _cacheTimestamp = null;
    debugPrint('🗑️ Articles cache invalidated');
  }

  /// Récupère un article spécifique
  Future<Map<String, dynamic>> getArticle(String token, String articleId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/blog/articles/$articleId'),
      headers: _getHeaders(token: token),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors du chargement de l\'article');
    }

    await SessionService.extendSession();
    
    return jsonDecode(response.body);
  }

  /// Met à jour un article
  Future<Map<String, dynamic>> updateArticle(String token, String articleId, {
    String? title,
    String? content,
    String? summary,
    List<String>? tags,
    bool? published,
  }) async {
    try {
      // Vérifier et rafraîchir le token si nécessaire
      final validToken = await _ensureValidToken(token);
      
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (content != null) body['content'] = content;
      if (summary != null) body['summary'] = summary;
      if (tags != null) body['tags'] = tags;
      if (published != null) body['published'] = published;

      if (body.isEmpty) {
        throw Exception('Aucune modification à apporter');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/blog/articles/$articleId'),
        headers: _getHeaders(token: validToken),
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Erreur lors de la mise à jour');
      }

      await SessionService.extendSession();
      
      // Invalider le cache après mise à jour d'un article
      BlogService.invalidateCache();
      
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('❌ Update article error: $e');
      rethrow;
    }
  }

  /// Supprime un article
  Future<void> deleteArticle(String token, String articleId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/blog/articles/$articleId'),
      headers: _getHeaders(token: token),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la suppression');
    }

    await SessionService.extendSession();
  }

  /// Upload de fichiers média vers le serveur
  Future<Map<String, dynamic>> uploadMedia(String token, List<String> files) async {
    try {
      // Vérifier et rafraîchir le token si nécessaire
      final validToken = await _ensureValidToken(token);
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/blog/upload'),
      );

      // Ajouter l'authorization header avec le token validé
      request.headers.addAll(_getHeaders(token: validToken));

      // Ajouter les fichiers
      for (String filePath in files) {
        final file = File(filePath);
        
        if (!await file.exists()) {
          debugPrint('❌ File not found: $filePath');
          continue;
        }
        
        debugPrint('📎 Adding file to upload: $filePath');
        request.files.add(await http.MultipartFile.fromPath('files', filePath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Upload successful: ${responseData['message']}');
        
        await SessionService.extendSession();
        
        return responseData;
      } else {
        final errorBody = jsonDecode(response.body);
        debugPrint('❌ Upload failed: ${errorBody['error']}');
        throw Exception('Erreur upload: ${errorBody['error']}');
      }
    } catch (e) {
      debugPrint('❌ Upload media error: $e');
      rethrow;
    }
  }

  /// Recherche d'articles
  Future<List<dynamic>> searchArticles(String token, String query, {List<String>? tags}) async {
    final queryParams = {
      'q': query,
      if (tags != null) 'tags': tags.join(','),
    };

    final uri = Uri.parse('$baseUrl/api/blog/search').replace(queryParameters: queryParams);
    
    final response = await http.get(
      uri,
      headers: _getHeaders(token: token),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la recherche');
    }

    await SessionService.extendSession();
    
    final data = jsonDecode(response.body);
    return data['articles'] ?? [];
  }

  /// Créer des données de test pour le blog
  Future<Map<String, dynamic>> createSeedData(String token) async {
    try {
      final validToken = await _ensureValidToken(token);
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/blog/seed-data'),
        headers: _getHeaders(token: validToken),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Erreur lors de la création des données de test');
      }

      await SessionService.extendSession();
      
      // Invalider le cache après création des articles de test
      BlogService.invalidateCache();
      
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('❌ Create seed data error: $e');
      rethrow;
    }
  }

  /// Récupérer la liste des fichiers uploadés
  Future<Map<String, dynamic>> getUploadedFiles(String token) async {
    try {
      final validToken = await _ensureValidToken(token);
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/uploads'),
        headers: _getHeaders(token: validToken),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Erreur lors de la récupération des fichiers');
      }

      await SessionService.extendSession();
      
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('❌ Get uploaded files error: $e');
      rethrow;
    }
  }
}