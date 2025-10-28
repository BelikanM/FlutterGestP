// profile_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'employee_cache_service.dart';
import 'session_service.dart';

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
  static const _timeout = Duration(seconds: 30); // Timeout de 30 secondes pour connexions lentes
  
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
  // Récupération des informations utilisateur (section infos)
  Future<Map<String, dynamic>> getUserInfo(String token) async {
    final response = await _makeRequest(
      () => _client.get(
        Uri.parse('$baseUrl/api/user'),
        headers: _getHeaders(token: token),
      ),
    );
    
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur lors de la récupération des infos');
    }
    final data = jsonDecode(response.body);
    return {
      'email': data['email'],
      'name': data['name'] ?? '',
      'profilePhoto': data['profilePhoto'] ?? '',
      'createdAt': data['createdAt'],
      'isVerified': data['isVerified'],
      'role': data['role'] ?? 'user',
    }; // Retourne les infos pour la section
  }
  // Mise à jour des informations utilisateur (nom, photo de profil)
  Future<Map<String, dynamic>> updateUserInfo(String token, {String? name, String? profilePhoto}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (profilePhoto != null) body['profilePhoto'] = profilePhoto;
    if (body.isEmpty) {
      throw Exception('Aucune information à mettre à jour');
    }
    final response = await http.put(
      Uri.parse('$baseUrl/api/user'),
      headers: _getHeaders(token: token),
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
    final response = await http.put(
      Uri.parse('$baseUrl/api/user/password'),
      headers: _getHeaders(token: token),
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
    final response = await http.delete(
      Uri.parse('$baseUrl/api/user'),
      headers: _getHeaders(token: token),
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
    final response = await http.post(
      Uri.parse('$baseUrl/api/employee'),
      headers: _getHeaders(token: token),
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
    final response = await http.put(
      Uri.parse('$baseUrl/api/employee/$id'),
      headers: _getHeaders(token: token),
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
    final response = await http.delete(
      Uri.parse('$baseUrl/api/employee/$id'),
      headers: _getHeaders(token: token),
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
      
      // Récupérer depuis le serveur avec optimisations
      final response = await _makeRequest(
        () => _client.get(
          Uri.parse('$baseUrl/api/employees?limit=200'), // Pagination
          headers: _getHeaders(token: token),
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