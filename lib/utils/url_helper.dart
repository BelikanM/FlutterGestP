// utils/url_helper.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Helper global pour obtenir l'URL du serveur selon la plateforme
class UrlHelper {
  /// URL de base du serveur backend
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';  // Android Emulator special IP
    } else {
      return 'http://localhost:5000';
    }
  }

  /// Obtenir une URL complète à partir d'un chemin relatif
  static String getFullUrl(String relativePath) {
    if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
      return relativePath; // Already absolute
    }
    
    // Ensure the path starts with /
    final path = relativePath.startsWith('/') ? relativePath : '/$relativePath';
    return '$baseUrl$path';
  }

  /// Obtenir l'URL d'un fichier uploadé
  static String getUploadUrl(String filename) {
    return '$baseUrl/uploads/$filename';
  }
}
