// auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokens {
  final String token;
  final String refreshToken;
  AuthTokens({required this.token, required this.refreshToken});
}

class AuthService {
  // URL du backend selon la plateforme
  static String get baseUrl {
    if (kIsWeb) {
      // Web : localhost
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      // Android émulateur : 10.0.2.2 pointe vers localhost de l'hôte
      return 'http://10.0.2.2:5000';
    } else {
      // Windows, iOS, autres : localhost
      return 'http://localhost:5000';
    }
  }

  // Headers par défaut
  Map<String, String> _getHeaders({String? token}) {
    Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Save tokens to SharedPreferences
  static Future<void> saveTokens(String token, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('refresh_token', refreshToken);
  }

  // Get auth token from SharedPreferences
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Inscription : Envoi email pour OTP
  Future<void> register(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/register'),
      headers: _getHeaders(),
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 201) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur d\'inscription');
    }
    // Succès : OTP envoyé par email
  }

  // Vérification OTP pour inscription : Retourne les tokens
  Future<AuthTokens> verifyOtpForRegister(String email, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/verify-otp'),
      headers: _getHeaders(),
      body: jsonEncode({'email': email, 'otp': otp}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'OTP invalide');
    }

    final data = jsonDecode(response.body);
    return AuthTokens(
      token: data['token'],
      refreshToken: data['refreshToken'],
    );
  }

  // Connexion : Envoi email pour OTP
  Future<void> login(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: _getHeaders(),
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erreur de connexion');
    }
    // Succès : OTP envoyé par email
  }

  // Vérification OTP pour connexion : Retourne les tokens
  Future<AuthTokens> verifyOtpForLogin(String email, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login-verify'),
      headers: _getHeaders(),
      body: jsonEncode({'email': email, 'otp': otp}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'OTP invalide');
    }

    final data = jsonDecode(response.body);
    return AuthTokens(
      token: data['token'],
      refreshToken: data['refreshToken'],
    );
  }

  // Rafraîchissement de token
  Future<AuthTokens> refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/refresh-token'),
      headers: _getHeaders(),
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Token invalide');
    }

    final data = jsonDecode(response.body);
    return AuthTokens(
      token: data['token'],
      refreshToken: data['refreshToken'],
    );
  }

  // Accès au profil (protégé)
  Future<String> getProfile(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/profile'),
      headers: _getHeaders(token: token),
    );

    if (response.statusCode != 200) {
      throw Exception('Accès refusé');
    }

    final data = jsonDecode(response.body);
    return data['user']; // Retourne l'email
  }

  // Déconnexion (invalide le token côté serveur)
  Future<void> logout(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/logout'),
      headers: _getHeaders(token: token),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur de déconnexion');
    }
    // Succès : Token invalidé
  }
}