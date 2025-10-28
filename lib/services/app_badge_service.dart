import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AppBadgeService {
  static const String _unreadCountKey = 'unread_message_count';
  
  // Vérifier si le device supporte les badges
  static Future<bool> isSupported() async {
    return await AppBadgePlus.isSupported();
  }
  
  // Mettre à jour le badge avec le nombre de messages non lus
  static Future<void> updateBadge(int count) async {
    try {
      if (count > 0) {
        await AppBadgePlus.updateBadge(count);
      } else {
        await AppBadgePlus.updateBadge(0);
      }
      
      // Sauvegarder le compteur
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, count);
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour du badge: $e');
    }
  }
  
  // Incrémenter le badge (nouveau message)
  static Future<void> incrementBadge() async {
    try {
      final currentCount = await getUnreadCount();
      await updateBadge(currentCount + 1);
    } catch (e) {
      debugPrint('Erreur lors de l\'incrémentation du badge: $e');
    }
  }
  
  // Décrémenter le badge (message lu)
  static Future<void> decrementBadge() async {
    try {
      final currentCount = await getUnreadCount();
      if (currentCount > 0) {
        await updateBadge(currentCount - 1);
      }
    } catch (e) {
      debugPrint('Erreur lors de la décrémentation du badge: $e');
    }
  }
  
  // Réinitialiser le badge (tous les messages lus)
  static Future<void> clearBadge() async {
    try {
      await AppBadgePlus.updateBadge(0);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, 0);
    } catch (e) {
      debugPrint('Erreur lors de la suppression du badge: $e');
    }
  }
  
  // Obtenir le nombre de messages non lus
  static Future<int> getUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_unreadCountKey) ?? 0;
    } catch (e) {
      debugPrint('Erreur lors de la récupération du compteur: $e');
      return 0;
    }
  }
  
  // Définir le nombre de messages non lus pour un groupe spécifique
  static Future<void> setGroupUnreadCount(String groupId, int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('unread_group_$groupId', count);
      
      // Recalculer le total
      await _recalculateTotalBadge();
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour du compteur du groupe: $e');
    }
  }
  
  // Incrémenter le compteur pour un groupe spécifique
  static Future<void> incrementGroupUnread(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt('unread_group_$groupId') ?? 0;
      await prefs.setInt('unread_group_$groupId', currentCount + 1);
      
      // Recalculer le total
      await _recalculateTotalBadge();
    } catch (e) {
      debugPrint('Erreur lors de l\'incrémentation du groupe: $e');
    }
  }
  
  // Réinitialiser le compteur pour un groupe spécifique (quand l'utilisateur ouvre le chat)
  static Future<void> clearGroupUnread(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('unread_group_$groupId');
      
      // Recalculer le total
      await _recalculateTotalBadge();
    } catch (e) {
      debugPrint('Erreur lors de la suppression du compteur du groupe: $e');
    }
  }
  
  // Recalculer le badge total en additionnant tous les groupes
  static Future<void> _recalculateTotalBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int total = 0;
      for (final key in keys) {
        if (key.startsWith('unread_group_')) {
          total += prefs.getInt(key) ?? 0;
        }
      }
      
      await updateBadge(total);
    } catch (e) {
      debugPrint('Erreur lors du recalcul du badge total: $e');
    }
  }
  
  // Obtenir tous les compteurs de groupes
  static Future<Map<String, int>> getAllGroupUnreadCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final Map<String, int> groupCounts = {};
      for (final key in keys) {
        if (key.startsWith('unread_group_')) {
          final groupId = key.substring('unread_group_'.length);
          groupCounts[groupId] = prefs.getInt(key) ?? 0;
        }
      }
      
      return groupCounts;
    } catch (e) {
      debugPrint('Erreur lors de la récupération des compteurs de groupes: $e');
      return {};
    }
  }
}
