// admin_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }
  
  Map<String, String> _getHeaders({String? token}) {
    Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Récupérer tous les utilisateurs (admin seulement)
  Future<List<dynamic>> getAllUsers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/users'),
        headers: _getHeaders(token: token),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur lors du chargement des utilisateurs');
      }

      final data = jsonDecode(response.body);
      debugPrint('✅ Loaded ${data['users'].length} users');
      return data['users'];
    } catch (e) {
      debugPrint('❌ Get all users error: $e');
      rethrow;
    }
  }

  /// Modifier le statut d'un utilisateur
  Future<Map<String, dynamic>> updateUserStatus(String token, String userId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/admin/users/$userId/status'),
        headers: _getHeaders(token: token),
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur lors de la mise à jour du statut');
      }

      final data = jsonDecode(response.body);
      debugPrint('✅ User status updated to $status');
      return data;
    } catch (e) {
      debugPrint('❌ Update user status error: $e');
      rethrow;
    }
  }

  /// Modifier les permissions d'un utilisateur
  Future<Map<String, dynamic>> updateUserPermissions(String token, String userId, Map<String, dynamic> permissions) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/admin/users/$userId/permissions'),
        headers: _getHeaders(token: token),
        body: jsonEncode({'permissions': permissions}),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur lors de la mise à jour des permissions');
      }

      final data = jsonDecode(response.body);
      debugPrint('✅ User permissions updated');
      return data;
    } catch (e) {
      debugPrint('❌ Update user permissions error: $e');
      rethrow;
    }
  }

  /// Modifier le rôle d'un utilisateur
  Future<Map<String, dynamic>> updateUserRole(String token, String userId, String role) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/admin/users/$userId/role'),
        headers: _getHeaders(token: token),
        body: jsonEncode({'role': role}),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur lors de la mise à jour du rôle');
      }

      final data = jsonDecode(response.body);
      debugPrint('✅ User role updated to $role');
      return data;
    } catch (e) {
      debugPrint('❌ Update user role error: $e');
      rethrow;
    }
  }

  /// Supprimer un utilisateur
  Future<void> deleteUser(String token, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/users/$userId'),
        headers: _getHeaders(token: token),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur lors de la suppression');
      }

      debugPrint('✅ User deleted successfully');
    } catch (e) {
      debugPrint('❌ Delete user error: $e');
      rethrow;
    }
  }

  /// Vérifier si l'utilisateur est admin
  static Future<bool> isAdmin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) return false;

      final response = await http.get(
        Uri.parse('$baseUrl/api/user'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        return userData['email'] == 'nyundumathryme@gmail.com' || userData['role'] == 'admin';
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Check admin status error: $e');
      return false;
    }
  }
}