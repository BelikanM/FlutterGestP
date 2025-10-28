// role_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_service.dart';

class RoleService {
  static const String _adminEmail = 'nyundumathryme@gmail.com';
  
  /// Vérifie si l'utilisateur actuel est administrateur
  static Future<bool> isAdmin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) return false;
      
      final profileService = ProfileService();
      final userInfo = await profileService.getUserInfo(token);
      
      // Vérifier par email ou rôle explicite
      return userInfo['email'] == _adminEmail || userInfo['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }
  
  /// Récupère les informations utilisateur avec le rôle
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) return null;
      
      final profileService = ProfileService();
      final userInfo = await profileService.getUserInfo(token);
      
      // Ajouter le flag admin
      userInfo['isAdmin'] = userInfo['email'] == _adminEmail || userInfo['role'] == 'admin';
      
      return userInfo;
    } catch (e) {
      return null;
    }
  }
  
  /// Liste des sections accessibles pour les utilisateurs non-admin
  static const List<String> nonAdminAllowedSections = [
    'Accueil',     // Dashboard/Actualités
    'Médias',      // Bibliothèque média
    'Profiles',    // Informations de profil
    'Blog'         // Blog
  ];
  
  /// Vérifie si une section est accessible pour l'utilisateur actuel
  static Future<bool> canAccessSection(String sectionName) async {
    final isAdminUser = await isAdmin();
    
    if (isAdminUser) {
      return true; // Les admins ont accès à tout
    }
    
    return nonAdminAllowedSections.contains(sectionName);
  }
  
  /// Obtient la liste des sections accessibles pour l'utilisateur actuel
  static Future<List<String>> getAccessibleSections() async {
    final isAdminUser = await isAdmin();
    
    if (isAdminUser) {
      return ['Dashboard', 'Employés', 'Certificats', 'Médias', 'Blog', 'Profiles'];
    } else {
      return ['Accueil', 'Médias', 'Blog', 'Profiles'];
    }
  }
}