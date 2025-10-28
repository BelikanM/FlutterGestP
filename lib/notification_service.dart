import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_badge_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }
  static bool _isInitialized = false;

  // Initialiser les notifications locales
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsiOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsiOS,
      linux: initializationSettingsLinux,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _isInitialized = true;
  }

  // Gérer les clics sur les notifications
  static void _onNotificationTap(NotificationResponse notificationResponse) {
    debugPrint('Notification tapped: ${notificationResponse.payload}');
  }

  // Afficher une notification locale
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? groupId,  // Pour identifier le groupe de chat
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'emploi_channel',
      'Emploi Notifications',
      channelDescription: 'Notifications pour l\'application Emploi',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
      linux: linuxPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
    
    // Incrémenter le badge si c'est une notification de chat
    if (groupId != null) {
      await AppBadgeService.incrementGroupUnread(groupId);
    }
  }

  // Envoyer une notification push à tous les utilisateurs
  static Future<bool> sendPushNotificationToAll({
    required String title,
    required String body,
    required String type, // 'article' ou 'media'
    Map<String, dynamic>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/send-to-all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'body': body,
          'type': type,
          'data': data ?? {},
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi de notification push: $e');
      return false;
    }
  }

  // Envoyer un email à tous les utilisateurs
  static Future<bool> sendEmailToAll({
    required String subject,
    required String htmlContent,
    required String type,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/send-email-to-all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'subject': subject,
          'htmlContent': htmlContent,
          'type': type,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi d\'email: $e');
      return false;
    }
  }

  // Notification pour nouvel article
  static Future<void> notifyNewArticle({
    required String title,
    required String author,
  }) async {
    // Notification locale
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📝 Nouvel Article',
      body: '$title par $author',
      payload: 'article',
    );

    // Notification push à tous les utilisateurs
    await sendPushNotificationToAll(
      title: '📝 Nouvel Article Publié',
      body: '$title par $author',
      type: 'article',
      data: {'title': title, 'author': author},
    );

    // Email à tous les utilisateurs
    await sendEmailToAll(
      subject: '📝 Nouvel Article: $title',
      htmlContent: '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center;">
            <h1 style="margin: 0;">📝 Nouvel Article Publié</h1>
          </div>
          <div style="padding: 20px; background: #f9f9f9;">
            <h2 style="color: #333;">$title</h2>
            <p style="color: #666; font-size: 16px;">Publié par <strong>$author</strong></p>
            <p style="color: #666;">Un nouvel article vient d'être publié sur la plateforme. Connectez-vous pour le découvrir !</p>
            <div style="text-align: center; margin-top: 30px;">
              <a href="http://localhost:3000" style="background: #667eea; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">Voir l'article</a>
            </div>
          </div>
          <div style="background: #333; color: white; padding: 15px; text-align: center; font-size: 12px;">
            <p style="margin: 0;">Plateforme Emploi - Notification automatique</p>
          </div>
        </div>
      ''',
      type: 'article',
    );
  }

  // Notification pour nouveau média
  static Future<void> notifyNewMedia({
    required String filename,
    required String type,
    required String uploadedBy,
  }) async {
    final mediaTypeIcon = _getMediaIcon(type);
    final mediaTypeName = _getMediaTypeName(type);

    // Notification locale
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '$mediaTypeIcon Nouveau Média',
      body: '$filename ($mediaTypeName) ajouté par $uploadedBy',
      payload: 'media',
    );

    // Notification push à tous les utilisateurs
    await sendPushNotificationToAll(
      title: '$mediaTypeIcon Nouveau Média Ajouté',
      body: '$filename ($mediaTypeName) par $uploadedBy',
      type: 'media',
      data: {'filename': filename, 'type': type, 'uploadedBy': uploadedBy},
    );

    // Email à tous les utilisateurs
    await sendEmailToAll(
      subject: '$mediaTypeIcon Nouveau Média: $filename',
      htmlContent: '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 20px; text-align: center;">
            <h1 style="margin: 0;">$mediaTypeIcon Nouveau Média Ajouté</h1>
          </div>
          <div style="padding: 20px; background: #f9f9f9;">
            <h2 style="color: #333;">$filename</h2>
            <p style="color: #666; font-size: 16px;">Type: <strong>$mediaTypeName</strong></p>
            <p style="color: #666; font-size: 16px;">Ajouté par: <strong>$uploadedBy</strong></p>
            <p style="color: #666;">Un nouveau média vient d'être ajouté sur la plateforme. Connectez-vous pour le découvrir !</p>
            <div style="text-align: center; margin-top: 30px;">
              <a href="http://localhost:3000" style="background: #f5576c; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">Voir le média</a>
            </div>
          </div>
          <div style="background: #333; color: white; padding: 15px; text-align: center; font-size: 12px;">
            <p style="margin: 0;">Plateforme Emploi - Notification automatique</p>
          </div>
        </div>
      ''',
      type: 'media',
    );
  }

  // Obtenir l'icône selon le type de média
  static String _getMediaIcon(String type) {
    if (type.startsWith('video/')) return '🎥';
    if (type.startsWith('audio/')) return '🎵';
    if (type.startsWith('image/')) return '🖼️';
    if (type == 'application/pdf') return '📄';
    return '📎';
  }

  // Obtenir le nom du type de média
  static String _getMediaTypeName(String type) {
    if (type.startsWith('video/')) return 'Vidéo';
    if (type.startsWith('audio/')) return 'Audio';
    if (type.startsWith('image/')) return 'Image';
    if (type == 'application/pdf') return 'PDF';
    return 'Fichier';
  }

  // Notification pour nouveau message de groupe
  static Future<void> notifyGroupMessage({
    required String senderName,
    required String message,
    String groupId = 'group_chat',
  }) async {
    // Notification locale avec badge
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '💬 $senderName',
      body: message,
      payload: 'group_chat',
      groupId: groupId,  // Important: identifie le groupe pour le badge
    );
  }

  // S'abonner aux notifications (enregistrer le token FCM)
  static Future<bool> subscribeToNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/subscribe'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fcmToken': 'desktop_token_${DateTime.now().millisecondsSinceEpoch}',
          'platform': 'desktop',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erreur lors de l\'abonnement aux notifications: $e');
      return false;
    }
  }

  // Se désabonner des notifications
  static Future<bool> unsubscribeFromNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/unsubscribe'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erreur lors du désabonnement aux notifications: $e');
      return false;
    }
  }
}