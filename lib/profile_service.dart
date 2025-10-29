// profile_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'employee_cache_service.dart';
import 'session_service.dart';
import 'auth_service.dart';

class ProfileService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }
  
  // Client HTTP avec timeout optimisé
  static final _client = http.Client();
  static const _timeout = Duration(seconds: 30); // Augmenté à 30 secondes pour gérer les connexions lentes
  
  // Headers par défaut (similaire à AuthService)
  Map<String, String> _getHeaders({String? token}) {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept-Encoding': 'gzip, deflate', // Accepter la compression
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
  
  // Méthode helper pour les requêtes avec timeout et retry
  Future<http.Response> _makeRequest(
    Future<http.Response> Function() request, {
    int retries = 3, // 3 tentatives par défaut
  }) async {
    int attempts = 0;
    Exception? lastException;
    
    while (attempts < retries) {
      try {
        return await request().timeout(_timeout);
      } on TimeoutException catch (e) {
        lastException = e;
        attempts++;
        if (attempts >= retries) {
          throw Exception('Timeout: La connexion est trop lente. Vérifiez votre réseau.');
        }
        // Attendre progressivement plus longtemps entre les tentatives
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      } on SocketException catch (e) {
        lastException = e;
        attempts++;
        if (attempts >= retries) {
          throw Exception('Pas de connexion internet. Vérifiez votre réseau.');
        }
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      } catch (e) {
        lastException = e as Exception?;
        attempts++;
        if (attempts >= retries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    throw lastException ?? Exception('Request failed after $retries attempts');
  }

  static Completer<String>? _tokenRefresher;

  // Méthode pour gérer une session expirée
  Future<void> _handleExpiredSession() async {
    try {
      final storage = FlutterSecureStorage();
      await storage.delete(key: 'auth_token');
      await storage.delete(key: 'refresh_token');
      await SessionService.endSession();
    } catch (e) {
      // Log l'erreur mais ne la propage pas
      debugPrint('Erreur lors du nettoyage de session: $e');
    }
  }

  bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final String normalized = base64Url.normalize(parts[1]);
      final String decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      final exp = payload['exp'] as int?;
      if (exp == null) return true;
      final expiration = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return expiration.isBefore(DateTime.now());
    } catch (e) {
      return true;
    }
  }

  Future<String> refreshAccessToken() async {
    final storage = FlutterSecureStorage();
    final refreshToken = await storage.read(key: 'refresh_token');
    if (refreshToken == null) {
      throw Exception('No refresh token available. Please login again.');
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/api/auth/refresh-token'),
      headers: _getHeaders(),
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to refresh token';

      // Si le refresh token est expiré ou invalide, nettoyer la session
      if (response.statusCode == 401 && (error.contains('expired') || error.contains('invalid'))) {
        await _handleExpiredSession();
        throw Exception('Session expirée. Veuillez vous reconnecter.');
      }

      throw Exception(error);
    }

    final data = jsonDecode(response.body);
    final newAccessToken = data['accessToken'];
    final newRefreshToken = data['refreshToken'];

    await AuthService.saveTokens(newAccessToken, newRefreshToken ?? refreshToken);

    return newAccessToken;
  }

  Future<String> getFreshToken(String currentToken) async {
    if (!isTokenExpired(currentToken)) {
      return currentToken;
    }

    if (_tokenRefresher != null) {
      return await _tokenRefresher!.future;
    }

    _tokenRefresher = Completer<String>();

    try {
      final newToken = await refreshAccessToken();
      _tokenRefresher!.complete(newToken);
      return newToken;
    } catch (e) {
      _tokenRefresher!.completeError(e);

      // Si c'est une erreur de session expirée, ne pas retenter automatiquement
      if (e.toString().contains('Session expirée') || e.toString().contains('Please login again')) {
        rethrow;
      }

      // Pour les autres erreurs, permettre une nouvelle tentative plus tard
      rethrow;
    } finally {
      _tokenRefresher = null;
    }
  }
  
  // Récupération des informations utilisateur (section infos)
  Future<Map<String, dynamic>> getUserInfo(String token) async {
    try {
      var currentToken = await getFreshToken(token);
      final response = await _makeRequest(
        () => _client.get(
          Uri.parse('$baseUrl/api/user'),
          headers: _getHeaders(token: currentToken),
        ),
        retries: 2, // Réduire à 2 tentatives pour chargement plus rapide
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Erreur lors de la récupération des infos';

        // Gestion spécifique des erreurs d'authentification
        if (response.statusCode == 401) {
          throw Exception('Session expirée. Veuillez vous reconnecter.');
        } else if (response.statusCode == 403) {
          throw Exception('Accès refusé. Vérifiez vos permissions.');
        } else if (response.statusCode >= 500) {
          throw Exception('Erreur serveur. Réessayez plus tard.');
        }

        throw Exception(errorMessage);
      }

      final data = jsonDecode(response.body);
      return {
        'email': data['email'],
        'name': data['name'] ?? '',
        'profilePhoto': data['profilePhoto'] ?? '',
        'createdAt': data['createdAt'],
        'isVerified': data['isVerified'],
        'role': data['role'] ?? 'user',
      };
    } catch (e) {
      // Re-throw avec message plus clair pour l'utilisateur
      if (e.toString().contains('Timeout')) {
        throw Exception('Connexion lente. Vérifiez votre réseau et réessayez.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Pas de connexion internet. Vérifiez votre réseau.');
      }
      rethrow;
    }
  }
  // Mise à jour des informations utilisateur (nom, photo de profil)
  Future<Map<String, dynamic>> updateUserInfo(String token, {String? name, String? profilePhoto}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (profilePhoto != null) body['profilePhoto'] = profilePhoto;
    if (body.isEmpty) {
      throw Exception('Aucune information à mettre à jour');
    }
    var currentToken = await getFreshToken(token);
    final response = await http.put(
      Uri.parse('$baseUrl/api/user'),
      headers: _getHeaders(token: currentToken),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la mise à jour');
    }
    final data = jsonDecode(response.body);
    return {
      'email': data['user']['email'],
      'name': data['user']['name'],
      'profilePhoto': data['user']['profilePhoto'],
    }; // Retourne les infos mises à jour pour refresh UI
  }
  // Mise à jour du mot de passe
  Future<void> updatePassword(String token, String currentPassword, String newPassword) async {
    var currentToken = await getFreshToken(token);
    final response = await http.put(
      Uri.parse('$baseUrl/api/user/password'),
      headers: _getHeaders(token: currentToken),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la mise à jour du mot de passe');
    }
    // Succès : Notification email envoyée côté serveur
  }
  // Suppression du compte
  Future<void> deleteAccount(String token) async {
    var currentToken = await getFreshToken(token);
    final response = await http.delete(
      Uri.parse('$baseUrl/api/user'),
      headers: _getHeaders(token: currentToken),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la suppression du compte');
    }
    // Succès : Notification email envoyée côté serveur
  }
  // Création d'un employé
  Future<Map<String, dynamic>> createEmployee(String token, {
    required String name,
    required String position,
    required String email,
    required String photo,
    required String certificate,
    required String startDate,
    required String endDate,
  }) async {
    var currentToken = await getFreshToken(token);
    final response = await http.post(
      Uri.parse('$baseUrl/api/employee'),
      headers: _getHeaders(token: currentToken),
      body: jsonEncode({
        'name': name,
        'position': position,
        'email': email,
        'photo': photo,
        'certificate': certificate,
        'startDate': startDate,
        'endDate': endDate,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la création de l\'employé');
    }
    
    final result = jsonDecode(response.body);
    
    // Prolonger la session car l'utilisateur est actif
    await SessionService.extendSession();
    
    // Ajouter au cache local
    if (result['employee'] != null) {
      await EmployeeCacheService.addEmployeeToCache(result['employee']);
    }
    
    return result;
  }
  // Mise à jour d'un employé
  Future<Map<String, dynamic>> updateEmployee(String token, String id, {
    String? name,
    String? position,
    String? email,
    String? photo,
    String? certificate,
    String? startDate,
    String? endDate,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (position != null) body['position'] = position;
    if (email != null) body['email'] = email;
    if (photo != null) body['photo'] = photo;
    if (certificate != null) body['certificate'] = certificate;
    if (startDate != null) body['startDate'] = startDate;
    if (endDate != null) body['endDate'] = endDate;
    if (body.isEmpty) {
      throw Exception('Aucune information à mettre à jour');
    }
    var currentToken = await getFreshToken(token);
    final response = await http.put(
      Uri.parse('$baseUrl/api/employee/$id'),
      headers: _getHeaders(token: currentToken),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la mise à jour de l\'employé');
    }
    
    final result = jsonDecode(response.body);
    
    // Prolonger la session
    await SessionService.extendSession();
    
    // Mettre à jour dans le cache local
    if (result['employee'] != null) {
      await EmployeeCacheService.updateEmployeeInCache(id, result['employee']);
    }
    
    return result;
  }
  // Suppression d'un employé
  Future<void> deleteEmployee(String token, String id) async {
    var currentToken = await getFreshToken(token);
    final response = await http.delete(
      Uri.parse('$baseUrl/api/employee/$id'),
      headers: _getHeaders(token: currentToken),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la suppression de l\'employé');
    }
    
    // Prolonger la session
    await SessionService.extendSession();
    
    // Supprimer du cache local
    await EmployeeCacheService.removeEmployeeFromCache(id);
  }
  // Récupération de tous les employés avec cache intelligent
  Future<List<dynamic>> getEmployees(String token) async {
    try {
      // Vérifier si le cache est récent
      final isCacheRecent = await EmployeeCacheService.isCacheRecent();
      
      if (isCacheRecent) {
        // Utiliser le cache si récent
        final cachedEmployees = await EmployeeCacheService.getCachedEmployees();
        if (cachedEmployees.isNotEmpty) {
          // Cache utilisé: ${cachedEmployees.length} employés
          return cachedEmployees;
        }
      }
      
      // Récupération depuis le serveur
      var currentToken = await getFreshToken(token);
      
      // Récupérer depuis le serveur avec optimisations
      final response = await _makeRequest(
        () => _client.get(
          Uri.parse('$baseUrl/api/employees?limit=200'), // Pagination
          headers: _getHeaders(token: currentToken),
        ),
        retries: 2, // 2 tentatives pour éviter les timeouts trop longs
      );
      
      if (response.statusCode != 200) {
        // En cas d'erreur, essayer le cache comme fallback
        final cachedEmployees = await EmployeeCacheService.getCachedEmployees();
        if (cachedEmployees.isNotEmpty) {
          // Utilisation du cache après erreur serveur
          return cachedEmployees;
        }
        throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la récupération des employés');
      }
      
      final data = jsonDecode(response.body);
      final employees = data['employees'] ?? [];
      
      // ${employees.length} employés reçus du serveur
      
      // Prolonger la session
      await SessionService.extendSession();
      
      // Synchroniser avec le cache
      return await EmployeeCacheService.syncWithServer(employees);
      
    } catch (e) {
      // Erreur lors de la récupération: $e
      // En cas d'erreur réseau, essayer le cache
      final cachedEmployees = await EmployeeCacheService.getCachedEmployees();
      if (cachedEmployees.isNotEmpty) {
        // Utilisation du cache après exception
        return cachedEmployees;
      }
      rethrow;
    }
  }
}