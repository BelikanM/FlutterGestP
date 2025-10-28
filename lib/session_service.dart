// session_service.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class SessionService {
  static Timer? _sessionTimer;
  static Timer? _refreshTimer;
  static const int sessionDurationMinutes = 60; // 1 heure
  static const int refreshCheckMinutes = 5; // Vérification toutes les 5 minutes

  /// Démarre une nouvelle session utilisateur
  static Future<void> startSession() async {
    await _saveSessionTimestamp();
    _startSessionTimer();
    _startRefreshTimer();
  }

  /// Prolonge la session actuelle
  static Future<void> extendSession() async {
    await _saveSessionTimestamp();
    _restartSessionTimer();
  }

  /// Vérifie si la session est encore valide
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStart = prefs.getInt('session_start_time');
    
    if (sessionStart == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionDuration = now - sessionStart;
    final maxDuration = sessionDurationMinutes * 60 * 1000; // en millisecondes

    return sessionDuration < maxDuration;
  }

  /// Termine la session
  static Future<void> endSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_start_time');
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('cached_employees');
    
    _sessionTimer?.cancel();
    _refreshTimer?.cancel();
  }

  /// Nettoie complètement toutes les données utilisateur (logout forcé)
  static Future<void> clearAllUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Supprimer TOUTES les données utilisateur
    await prefs.remove('session_start_time');
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('cached_employees');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('last_login');
    
    // Ou même plus radical : nettoyer tout
    // await prefs.clear();
    
    _sessionTimer?.cancel();
    _refreshTimer?.cancel();
  }

  /// Vérifie et rafraîchit automatiquement le token si nécessaire
  static Future<bool> checkAndRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      
      if (refreshToken == null) return false;

      final authService = AuthService();
      final tokens = await authService.refreshToken(refreshToken);
      
      await AuthService.saveTokens(tokens.token, tokens.refreshToken);
      await extendSession();
      
      return true;
    } catch (e) {
      await endSession();
      return false;
    }
  }

  /// Sauvegarde le timestamp de début de session
  static Future<void> _saveSessionTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('session_start_time', DateTime.now().millisecondsSinceEpoch);
  }

  /// Démarre le timer de session
  static void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(Duration(minutes: sessionDurationMinutes), () {
      endSession();
    });
  }

  /// Redémarre le timer de session
  static void _restartSessionTimer() {
    _sessionTimer?.cancel();
    _startSessionTimer();
  }

  /// Démarre le timer de vérification/rafraîchissement
  static void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(minutes: refreshCheckMinutes), (timer) async {
      final isValid = await isSessionValid();
      if (!isValid) {
        timer.cancel();
        await endSession();
      } else {
        // Tente de rafraîchir le token
        await checkAndRefreshToken();
      }
    });
  }

  /// Vérifie si l'utilisateur a des tokens valides au démarrage
  static Future<bool> hasValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final refreshToken = prefs.getString('refresh_token');
    
    if (token == null || refreshToken == null) return false;
    
    return await isSessionValid();
  }

  /// Auto-connexion au démarrage de l'application
  static Future<bool> tryAutoLogin() async {
    try {
      final hasSession = await hasValidSession();
      if (!hasSession) {
        return await checkAndRefreshToken();
      }
      
      await startSession();
      return true;
    } catch (e) {
      await endSession();
      return false;
    }
  }
}