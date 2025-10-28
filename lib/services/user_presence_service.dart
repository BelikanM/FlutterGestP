import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserPresenceService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    } else {
      return 'http://localhost:5000/api';
    }
  }
  static Timer? _heartbeatTimer;
  
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

  // ========================================
  // GESTION DE LA PRÉSENCE UTILISATEUR
  // ========================================

  /// Récupérer la liste des utilisateurs connectés
  Future<List<OnlineUser>> getOnlineUsers() async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/users/online'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final users = (data['users'] as List<dynamic>? ?? [])
            .map((item) => OnlineUser.fromJson(item))
            .toList();
        return users;
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // Retourner une liste vide en cas d'erreur
      return [];
    }
  }

  /// Récupérer les informations d'un utilisateur spécifique
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserProfile.fromJson(data['user']);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Démarrer le heartbeat pour maintenir le statut en ligne
  void startHeartbeat() {
    stopHeartbeat(); // Arrêter le précédent s'il existe
    
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _sendHeartbeat();
    });

    // Premier heartbeat immédiat
    _sendHeartbeat();
  }

  /// Arrêter le heartbeat
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Envoyer un heartbeat pour maintenir le statut en ligne
  Future<void> _sendHeartbeat() async {
    try {
      final headers = await _getHeaders();

      await http.put(
        Uri.parse('$baseUrl/users/heartbeat'),
        headers: headers,
      );
    } catch (e) {
      // Ignorer les erreurs de heartbeat silencieusement
    }
  }

  // ========================================
  // CACHE DES PROFILS
  // ========================================

  final Map<String, UserProfile> _profileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Récupérer un profil utilisateur avec cache
  Future<UserProfile?> getCachedUserProfile(String userId) async {
    // Vérifier si le profil est en cache et toujours valide
    if (_profileCache.containsKey(userId) && _cacheTimestamps.containsKey(userId)) {
      final timestamp = _cacheTimestamps[userId]!;
      if (DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _profileCache[userId];
      }
    }

    // Récupérer le profil depuis l'API
    final profile = await getUserProfile(userId);
    if (profile != null) {
      _profileCache[userId] = profile;
      _cacheTimestamps[userId] = DateTime.now();
    }

    return profile;
  }

  /// Vider le cache des profils
  void clearCache() {
    _profileCache.clear();
    _cacheTimestamps.clear();
  }
}

// ========================================
// MODÈLES DE DONNÉES
// ========================================

class OnlineUser {
  final String id;
  final String name;
  final String email;
  final String profilePhoto;
  final String role;

  OnlineUser({
    required this.id,
    required this.name,
    required this.email,
    this.profilePhoto = '',
    this.role = 'user',
  });

  factory OnlineUser.fromJson(Map<String, dynamic> json) {
    return OnlineUser(
      id: json['id'] ?? '',
      name: json['name'] ?? json['email'] ?? '',
      email: json['email'] ?? '',
      profilePhoto: json['profilePhoto'] ?? '',
      role: json['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profilePhoto': profilePhoto,
      'role': role,
    };
  }

  String get displayName => name.isNotEmpty ? name : email;
  String get initials => displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String profilePhoto;
  final String role;
  final String status;
  final DateTime createdAt;
  final bool isOnline;
  final DateTime? lastSeen;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.profilePhoto = '',
    this.role = 'user',
    this.status = 'active',
    required this.createdAt,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? json['email'] ?? '',
      email: json['email'] ?? '',
      profilePhoto: json['profilePhoto'] ?? '',
      role: json['role'] ?? 'user',
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['createdAt']),
      isOnline: json['isOnline'] ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profilePhoto': profilePhoto,
      'role': role,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  String get displayName => name.isNotEmpty ? name : email;
  String get initials => displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  
  String get statusText {
    if (isOnline) return 'En ligne';
    if (lastSeen != null) {
      final difference = DateTime.now().difference(lastSeen!);
      if (difference.inMinutes < 1) return 'À l\'instant';
      if (difference.inHours < 1) return 'Il y a ${difference.inMinutes}min';
      if (difference.inDays < 1) return 'Il y a ${difference.inHours}h';
      return 'Il y a ${difference.inDays}j';
    }
    return 'Hors ligne';
  }
}