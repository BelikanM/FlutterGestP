import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../services/chat_service.dart';
import '../services/user_presence_service.dart';
import '../services/app_badge_service.dart';
import '../models/chat_models.dart';
import '../components/html5_media_viewer.dart';
import '../media_service.dart';
import '../widgets/background_pattern.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({super.key});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final ChatService _chatService = ChatService();
  final UserPresenceService _presenceService = UserPresenceService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final ImagePicker _imagePicker = ImagePicker();
  
  // État du chat
  ChatState _chatState = ChatState();
  Timer? _refreshTimer;
  Timer? _presenceTimer;
  
  // Focus et UI
  bool _isComposingMessage = false;
  String? _currentUserId;
  
  // Audio recording state
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _isRecorderInitialized = false;
  
  // Utilisateurs connectés et profils
  List<OnlineUser> _onlineUsers = [];
  final Map<String, UserProfile> _userProfiles = {};
  bool _showOnlineUsers = false;
  
  @override
  void initState() {
    super.initState();
    _initRecorder();
    _loadCurrentUser();
    _loadMessages();
    _startAutoRefresh();
    _startPresenceTracking();
    _scrollController.addListener(_onScroll);
    // Réinitialiser le badge quand l'utilisateur ouvre le chat
    _clearChatBadge();
  }
  
  Future<void> _clearChatBadge() async {
    try {
      // Réinitialiser le badge pour le chat de groupe
      await AppBadgeService.clearGroupUnread('group_chat');
    } catch (e) {
      debugPrint('Erreur lors de la réinitialisation du badge: $e');
    }
  }

  Future<void> _initRecorder() async {
    try {
      await _audioRecorder.openRecorder();
      setState(() {
        _isRecorderInitialized = true;
      });
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation de l\'enregistreur: $e');
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id') ?? prefs.getString('userId');
    } catch (e) {
      _currentUserId = null;
    }
  }

  void _startPresenceTracking() {
    // Démarrer le heartbeat pour maintenir la présence en ligne
    _presenceService.startHeartbeat();
    
    // Charger les utilisateurs connectés périodiquement
    _loadOnlineUsers();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadOnlineUsers();
    });
  }

  Future<void> _loadOnlineUsers() async {
    try {
      final users = await _presenceService.getOnlineUsers();
      if (mounted) {
        setState(() {
          _onlineUsers = users;
        });
      }
    } catch (e) {
      // Ignorer les erreurs de chargement des utilisateurs connectés
    }
  }

  Future<UserProfile?> _getUserProfile(String userId) async {
    // Utiliser le cache local d'abord
    if (_userProfiles.containsKey(userId)) {
      return _userProfiles[userId];
    }

    try {
      // Utiliser getCachedUserProfile pour éviter trop de requêtes
      final profile = await _presenceService.getCachedUserProfile(userId);
      if (profile != null && mounted) {
        setState(() {
          _userProfiles[userId] = profile;
        });
      }
      return profile;
    } catch (e) {
      debugPrint('Erreur récupération profil $userId: $e');
      return null;
    }
  }
  
  // Fonction utilitaire pour créer une ImageProvider à partir d'une photo de profil
  ImageProvider? _getProfileImageProvider(String photoData) {
    if (photoData.isEmpty) return null;
    
    try {
      if (photoData.startsWith('http://') || photoData.startsWith('https://')) {
        return NetworkImage(photoData);
      } else {
        // Décoder le base64
        final bytes = base64Decode(photoData);
        return MemoryImage(bytes);
      }
    } catch (e) {
      debugPrint('Erreur création ImageProvider: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _refreshTimer?.cancel();
    _presenceTimer?.cancel();
    _recordingTimer?.cancel();
    _presenceService.stopHeartbeat();
    _audioRecorder.closeRecorder();
    super.dispose();
  }

  // ========================================
  // GESTION DES DONNÉES
  // ========================================

  Future<void> _loadMessages() async {
    if (!mounted) return;
    
    setState(() {
      _chatState = _chatState.copyWith(isLoading: true, hasError: false);
    });

    try {
      final response = await _chatService.getMessages(limit: 50);
      
      if (!mounted) return;
      
      setState(() {
        _chatState = _chatState.copyWith(
          messages: response.messages,
          isLoading: false,
          hasMoreMessages: response.pagination.hasMore,
        );
      });
      
      // Pré-charger les profils utilisateurs pour les messages
      _preloadUserProfiles(response.messages);
      
      // Faire défiler vers le bas après le chargement
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToBottom();
          }
        });
      }
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _chatState = _chatState.copyWith(
          isLoading: false,
          hasError: true,
          errorMessage: e.toString(),
        );
      });
    }
  }

  // Pré-charger les profils utilisateurs pour éviter les appels multiples
  Future<void> _preloadUserProfiles(List<ChatMessage> messages) async {
    final userIds = messages
        .map((msg) => msg.senderId)
        .where((id) => id.isNotEmpty && id != _currentUserId)
        .toSet();
    
    // Charger uniquement les profils manquants
    final missingUserIds = userIds.where((id) => !_userProfiles.containsKey(id)).toList();
    
    if (missingUserIds.isEmpty) return;
    
    // Limiter le nombre de requêtes simultanées pour éviter la surcharge
    const batchSize = 5;
    for (var i = 0; i < missingUserIds.length; i += batchSize) {
      final batch = missingUserIds.skip(i).take(batchSize);
      
      await Future.wait(
        batch.map((userId) async {
          try {
            final profile = await _presenceService.getCachedUserProfile(userId);
            if (profile != null && mounted) {
              setState(() {
                _userProfiles[userId] = profile;
              });
            }
          } catch (e) {
            debugPrint('Erreur chargement profil $userId: $e');
          }
        }),
      );
      
      // Petite pause entre les batches pour ne pas surcharger
      if (i + batchSize < missingUserIds.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_chatState.isLoading || !_chatState.hasMoreMessages) return;

    try {
      final oldestMessage = _chatState.messages.first;
      final response = await _chatService.getMessages(
        before: oldestMessage.createdAt.toIso8601String(),
        limit: 20,
      );

      setState(() {
        _chatState = _chatState.copyWith(
          messages: [...response.messages, ..._chatState.messages],
          hasMoreMessages: response.pagination.hasMore,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _refreshMessages();
    });
  }

  Future<void> _refreshMessages() async {
    try {
      final response = await _chatService.getMessages(limit: 50);
      
      debugPrint('🔄 Refresh: ${response.messages.length} messages reçus');
      
      // Toujours mettre à jour les messages pour afficher les nouveaux
      if (mounted) {
        setState(() {
          _chatState = _chatState.copyWith(messages: response.messages);
        });
        
        debugPrint('✅ Messages mis à jour dans l\'état');
        
        // Recharger les profils utilisateurs pour les nouveaux messages
        _preloadUserProfiles(response.messages);
        
        // Auto-scroll si l'utilisateur est en bas
        if (mounted && _scrollController.hasClients &&
            _scrollController.offset >= _scrollController.position.maxScrollExtent - 100) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur de rafraîchissement: $e');
      // Ignorer les erreurs de refresh silencieuses
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100) {
      _loadMoreMessages();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ========================================
  // ENVOI DE MESSAGES
  // ========================================

  Future<void> _sendTextMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text.trim();
    _messageController.clear();
    
    setState(() {
      _isComposingMessage = false;
    });

    try {
      debugPrint('📤 Envoi du message: $content');
      
      final sentMessage = await _chatService.sendTextMessage(
        content,
        replyToId: _chatState.replyingTo?.id,
      );
      
      debugPrint('✅ Message envoyé avec succès: ${sentMessage.id}');
      
      setState(() {
        _chatState = _chatState.copyWith(clearReply: true);
      });
      
      // Rafraîchir immédiatement pour afficher le nouveau message
      await _refreshMessages();
      _scrollToBottom();
      
    } catch (e) {
      debugPrint('❌ Erreur envoi message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'envoi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMediaMessage() async {
    // Afficher un dialogue pour choisir le type de média
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Galerie de photos', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Prendre une photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.red),
              title: const Text('Enregistrer une vidéo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.orange),
              title: const Text('Fichier', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    try {
      File? file;
      
      switch (choice) {
        case 'gallery':
          final pickedFile = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
          );
          if (pickedFile != null) file = File(pickedFile.path);
          break;
          
        case 'camera':
          final pickedFile = await _imagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
          );
          if (pickedFile != null) file = File(pickedFile.path);
          break;
          
        case 'video':
          final pickedFile = await _imagePicker.pickVideo(
            source: ImageSource.camera,
            maxDuration: const Duration(minutes: 5),
          );
          if (pickedFile != null) file = File(pickedFile.path);
          break;
          
        case 'file':
          final result = await FilePicker.platform.pickFiles(
            type: FileType.any,
            allowMultiple: false,
          );
          if (result != null && result.files.single.path != null) {
            file = File(result.files.single.path!);
          }
          break;
      }

      if (file == null) return;
      
      if (!_chatService.isFileTypeSupported(file)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Type de fichier non supporté'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Afficher un indicateur de chargement
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Envoi du média en cours...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final mediaType = _chatService.getMediaTypeFromFile(file);
      await _chatService.sendMediaMessage(
        file,
        mediaType,
        replyToId: _chatState.replyingTo?.id,
      );
      
      setState(() {
        _chatState = _chatState.copyWith(clearReply: true);
      });
      
      _refreshMessages();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'envoi du média: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========================================
  // ENREGISTREMENT AUDIO (COMME WHATSAPP)
  // ========================================

  Future<void> _startRecording() async {
    try {
      if (!_isRecorderInitialized) {
        await _initRecorder();
      }

      // Vérifier et demander les permissions
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission microphone refusée'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Créer le chemin du fichier audio
      final directory = await Directory.systemTemp.createTemp('audio_');
      _recordingPath = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

      // Démarrer l'enregistrement
      await _audioRecorder.startRecorder(
        toFile: _recordingPath!,
        codec: Codec.aacADTS,
      );

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      // Timer pour afficher la durée
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
        });
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'enregistrement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    try {
      _recordingTimer?.cancel();
      
      final path = await _audioRecorder.stopRecorder();
      
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
      });

      if (send && path != null && path.isNotEmpty) {
        final audioFile = File(path);
        
        if (audioFile.existsSync()) {
          // Afficher un indicateur de chargement
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Envoi de l\'audio en cours...'),
                duration: Duration(seconds: 2),
              ),
            );
          }

          await _chatService.sendMediaMessage(
            audioFile,
            'audio',
            replyToId: _chatState.replyingTo?.id,
          );
          
          setState(() {
            _chatState = _chatState.copyWith(clearReply: true);
          });
          
          _refreshMessages();
          _scrollToBottom();
        }
      }
      
      _recordingPath = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'arrêt de l\'enregistrement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    await _stopRecording(send: false);
  }

  // ========================================
  // MISE À JOUR DE LA PHOTO DE PROFIL
  // ========================================

  Future<void> _updateProfilePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      // Créer un fichier à partir de XFile
      final File imageFile = File(image.path);

      // Appeler le service pour uploader la photo
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        throw Exception('Non authentifié');
      }

      // Upload via l'API
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:3000/api/users/profile-photo'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('profilePhoto', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Vider le cache pour forcer le rechargement
        _presenceService.clearCache();
        _userProfiles.clear();
        
        // Recharger les messages pour afficher la nouvelle photo
        await _loadMessages();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo de profil mise à jour !'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Erreur lors de l\'upload');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========================================
  // ACTIONS SUR LES MESSAGES
  // ========================================

  void _replyToMessage(ChatMessage message) {
    setState(() {
      _chatState = _chatState.copyWith(replyingTo: message);
    });
  }

  void _cancelReply() {
    setState(() {
      _chatState = _chatState.copyWith(clearReply: true);
    });
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Supprimer le message', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce message ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _chatService.deleteMessage(message.id);
        _refreshMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.content);
    
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Modifier le message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nouveau message...',
            hintStyle: TextStyle(color: Colors.white38),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Modifier', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (newContent != null && newContent.trim().isNotEmpty && newContent != message.content) {
      try {
        await _chatService.editMessage(message.id, newContent.trim());
        _refreshMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message modifié'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Afficher les options pour gérer la photo d'un message
  void _showPhotoOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!message.isMediaMessage)
            ListTile(
              leading: const Icon(Icons.add_photo_alternate, color: Colors.green),
              title: const Text('Ajouter une photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _addPhotoToMessage(message);
              },
            ),
          if (message.isMediaMessage) ...[
            ListTile(
              leading: const Icon(Icons.change_circle, color: Colors.blue),
              title: const Text('Remplacer la photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _replaceMessagePhoto(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Supprimer la photo', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _removeMessagePhoto(message);
              },
            ),
          ],
        ],
      ),
    );
  }

  // Ajouter une photo à un message texte
  Future<void> _addPhotoToMessage(ChatMessage message) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      final File imageFile = File(image.path);
      
      // Appeler le service pour ajouter la photo
      final success = await _chatService.addPhotoToMessage(message.id, imageFile);
      
      if (success) {
        _refreshMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo ajoutée au message'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Échec de l\'ajout de la photo');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Remplacer la photo d'un message
  Future<void> _replaceMessagePhoto(ChatMessage message) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      final File imageFile = File(image.path);
      
      // Appeler le service pour remplacer la photo
      final success = await _chatService.replaceMessagePhoto(message.id, imageFile);
      
      if (success) {
        _refreshMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo remplacée'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Échec du remplacement de la photo');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Supprimer la photo d'un message
  Future<void> _removeMessagePhoto(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Supprimer la photo', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voulez-vous supprimer la photo de ce message ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _chatService.removeMessagePhoto(message.id);
        
        if (success) {
          _refreshMessages();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo supprimée'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Échec de la suppression de la photo');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _viewMedia(ChatMessage message) {
    if (message.isMediaMessage) {
      final mediaUrl = _chatService.getMediaUrl(message.mediaUrl);
      
      // Créer un MediaItem pour le visualiseur
      final mediaItem = MediaItem(
        id: message.id,
        title: message.fileName.isNotEmpty ? message.fileName : 'Média',
        description: message.content.isNotEmpty ? message.content : 'Partagé par ${message.senderName}',
        url: mediaUrl,
        filename: message.fileName,
        originalName: message.fileName,
        mimetype: _getMimeType(message.mediaType),
        size: message.fileSize,
        type: message.mediaType,
        tags: [],
        uploadedBy: message.senderName,
        isPublic: true,
        usageCount: 0,
        createdAt: message.createdAt,
        updatedAt: message.updatedAt,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Html5MediaViewer(
            media: mediaItem,
          ),
        ),
      );
    }
  }

  String _getMimeType(String mediaType) {
    switch (mediaType) {
      case 'image': return 'image/jpeg';
      case 'video': return 'video/mp4';
      case 'audio': return 'audio/mpeg';
      default: return 'application/octet-stream';
    }
  }

  // ========================================
  // INTERFACE UTILISATEUR
  // ========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: CSSBackgroundPattern(
        backgroundColor: const Color(0xFF121212),
        patternType: CSSPatternType.whatsappDots,
        child: Column(
          children: [
            // AppBar personnalisé avec fond sombre
            Container(
              color: const Color(0xFF1E1E1E),
              child: SafeArea(
                bottom: false,
                child: _buildAppBar(),
              ),
            ),
            // Contenu principal
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'Chat de Groupe 💬',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 12),
          
          // Affichage des utilisateurs connectés dans le header avec indicateur vert
          if (_onlineUsers.isNotEmpty)
            Expanded(
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _onlineUsers.length > 5 ? 5 : _onlineUsers.length,
                  itemBuilder: (context, index) {
                    final user = _onlineUsers[index];
                    final profileImage = _getProfileImageProvider(user.profilePhoto);
                    
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: user.id == _currentUserId 
                                ? _updateProfilePhoto 
                                : null,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF2D2D2D),
                              backgroundImage: profileImage,
                              child: profileImage == null
                                  ? Text(
                                      user.initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          // Indicateur vert de connexion
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF1E1E1E),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          
          // Badge avec le nombre total si plus de 5 utilisateurs
          if (_onlineUsers.length > 5)
            Container(
              margin: const EdgeInsets.only(left: 4, right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Text(
                '+${_onlineUsers.length - 5}',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          const Spacer(),
          
          if (_chatState.unreadNotificationsCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_chatState.unreadNotificationsCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          // Bouton pour afficher/masquer tous les utilisateurs connectés
          IconButton(
            icon: Icon(
              _showOnlineUsers ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _showOnlineUsers = !_showOnlineUsers),
            tooltip: _showOnlineUsers 
                ? 'Masquer utilisateurs' 
                : 'Afficher tous les utilisateurs',
          ),
          
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // Vider le cache des profils pour forcer le rechargement
              _userProfiles.clear();
              _presenceService.clearCache();
              _refreshMessages();
            },
            tooltip: 'Actualiser',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF2D2D2D),
            onSelected: (value) async {
              if (value == 'logout') {
                await _logout();
              } else if (value == 'stats') {
                await _showChatStats();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.white70),
                    SizedBox(width: 8),
                    Text('Statistiques', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Déconnexion', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Affichage des utilisateurs connectés
        if (_showOnlineUsers && _onlineUsers.isNotEmpty)
          Container(
            height: 80,
            color: const Color(0xFF1E1E1E).withValues(alpha: 0.8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: _onlineUsers.length,
              itemBuilder: (context, index) {
                final user = _onlineUsers[index];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: user.id == _currentUserId 
                                ? _updateProfilePhoto 
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: user.id == _currentUserId
                                    ? Border.all(color: Colors.blue, width: 2)
                                    : null,
                              ),
                              child: user.profilePhoto.isNotEmpty
                                  ? CircleAvatar(
                                      radius: 20,
                                      backgroundImage: NetworkImage(user.profilePhoto),
                                      backgroundColor: const Color(0xFF2D2D2D),
                                    )
                                  : CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFF2D2D2D),
                                      child: Text(
                                        user.initials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          // Indicateur vert pour utilisateur connecté
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
                              ),
                            ),
                          ),
                          // Icône de modification pour l'utilisateur actuel
                          if (user.id == _currentUserId)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF1E1E1E), width: 1),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.displayName.length > 8 
                          ? '${user.displayName.substring(0, 8)}...' 
                          : user.displayName,
                        style: TextStyle(
                          color: user.id == _currentUserId 
                              ? Colors.blue 
                              : Colors.white70,
                          fontSize: 10,
                          fontWeight: user.id == _currentUserId 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        // Zone des messages
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.transparent, // Laisse transparaître le motif
            ),
            child: _buildMessagesList(),
          ),
        ),
        
        // Indicateur de réponse
        if (_chatState.replyingTo != null)
          Container(
            color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
            child: _buildReplyIndicator(),
          ),
        
        // Zone de saisie (avec SafeArea intégré)
        Container(
          color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
          child: _buildMessageInput(),
        ),
      ],
    );
  }



  Widget _buildMessagesList() {
    if (_chatState.isLoading && _chatState.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }

    if (_chatState.hasError && _chatState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _chatState.errorMessage ?? '',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Vider le cache des profils pour forcer le rafraîchissement
        _presenceService.clearCache();
        _userProfiles.clear();
        await _loadMessages();
      },
      color: Colors.blue,
      backgroundColor: const Color(0xFF2D2D2D),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _chatState.messages.length + (_chatState.hasMoreMessages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0 && _chatState.hasMoreMessages) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: Colors.blue),
              ),
            );
          }

          final messageIndex = _chatState.hasMoreMessages ? index - 1 : index;
          final message = _chatState.messages[messageIndex];
        return _buildMessageBubble(message);
      },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = _currentUserId != null && message.senderId == _currentUserId;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Message de réponse (si applicable)
          if (message.hasReply)
            _buildReplyPreview(message),
          
          // Bulle principale du message
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar de l'expéditeur (pour les autres utilisateurs)
              if (!isMe) ...[
                FutureBuilder<UserProfile?>(
                  key: ValueKey('avatar_${message.senderId}_${message.id}'),
                  future: _getUserProfile(message.senderId),
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    final avatarImage = profile != null 
                        ? _getProfileImageProvider(profile.profilePhoto)
                        : null;
                    
                    final initials = profile?.name.isNotEmpty == true 
                        ? profile!.name[0].toUpperCase()
                        : (message.senderName.isNotEmpty 
                            ? message.senderName[0].toUpperCase() 
                            : '?');
                    
                    return CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
              
              // Contenu du message
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: () => _showMessageOptions(message),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue.shade600 : const Color(0xFF2D2D2D),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nom de l'expéditeur (si ce n'est pas moi)
                            if (!isMe)
                              FutureBuilder<UserProfile?>(
                                future: _getUserProfile(message.senderId),
                                builder: (context, snapshot) {
                                  final profile = snapshot.data;
                                  final displayName = profile?.name.isNotEmpty == true 
                                      ? profile!.name 
                                      : message.senderName;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      displayName,
                                      style: TextStyle(
                                        color: Colors.blue.shade300,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            
                            // Contenu du message
                            if (message.isTextMessage && message.content.isNotEmpty)
                              SelectableText(
                                message.content,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            
                            // Contenu média
                            if (message.isMediaMessage)
                              _buildMediaContent(message),
                            
                            // Informations du message (heure, statut)
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(message.createdAt),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                  ),
                                ),
                                if (message.isEdited) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ],
                                if (isMe && message.readBy.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.done_all,
                                    size: 12,
                                    color: Colors.blue.shade300,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Boutons d'action rapide pour mes messages
                    if (isMe)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Bouton pour ajouter/gérer une photo
                            InkWell(
                              onTap: () => _showPhotoOptions(message),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      message.isMediaMessage ? Icons.photo : Icons.add_photo_alternate,
                                      size: 12,
                                      color: Colors.green.shade300,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      message.isMediaMessage ? 'Photo' : '+ Photo',
                                      style: TextStyle(
                                        color: Colors.green.shade300,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (message.isTextMessage && message.content.isNotEmpty)
                              InkWell(
                                onTap: () => _editMessage(message),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: 12,
                                        color: Colors.blue.shade300,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Modifier',
                                        style: TextStyle(
                                          color: Colors.blue.shade300,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _deleteMessage(message),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.delete,
                                      size: 12,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Supprimer',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Avatar de l'utilisateur actuel (pour ses propres messages)
              if (isMe) ...[
                const SizedBox(width: 8),
                FutureBuilder<UserProfile?>(
                  future: _getUserProfile(_currentUserId ?? ''),
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    final hasProfilePhoto = profile?.profilePhoto.isNotEmpty == true;
                    
                    return GestureDetector(
                      onTap: _updateProfilePhoto,  // Modifier ma photo de profil
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue,
                            backgroundImage: hasProfilePhoto 
                                ? NetworkImage(profile!.profilePhoto)
                                : null,
                            child: !hasProfilePhoto
                                ? Text(
                                    profile?.name.isNotEmpty == true 
                                        ? profile!.name[0].toUpperCase()
                                        : (message.senderName.isNotEmpty 
                                            ? message.senderName[0].toUpperCase() 
                                            : '?'),
                                    style: const TextStyle(
                                      color: Colors.white, 
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          // Petit indicateur pour montrer que c'est cliquable
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF1E1E1E),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, left: 40),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: Colors.blue.shade400, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.replyToMessage?.senderName ?? 'Message original',
            style: TextStyle(
              color: Colors.blue.shade300,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyToContent.isNotEmpty 
                ? message.replyToContent 
                : '[Média]',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(ChatMessage message) {
    return GestureDetector(
      onTap: () => _viewMedia(message),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250, maxHeight: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF1E1E1E),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview du média
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: _buildMediaPreview(message),
              ),
            ),
            
            // Informations du fichier
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.fileName.isNotEmpty)
                    Text(
                      message.fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (message.fileSize > 0)
                    Text(
                      _chatService.formatFileSize(message.fileSize),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(ChatMessage message) {
    final mediaUrl = _chatService.getMediaUrl(message.mediaUrl);
    
    switch (message.mediaType) {
      case 'image':
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF2D2D2D),
                child: const Icon(
                  Icons.broken_image,
                  color: Colors.white70,
                  size: 48,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ],
        );
        
      case 'video':
        return Container(
          color: const Color(0xFF2D2D2D),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.videocam,
                color: Colors.white70,
                size: 48,
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Vidéo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        
      case 'audio':
        return Container(
          color: const Color(0xFF2D2D2D),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.audiotrack,
                  color: Colors.white70,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Audio',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
        
      default:
        return Container(
          color: const Color(0xFF2D2D2D),
          child: const Icon(
            Icons.insert_drive_file,
            color: Colors.white70,
            size: 48,
          ),
        );
    }
  }

  Widget _buildReplyIndicator() {
    final replyTo = _chatState.replyingTo!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: Colors.blue.shade400, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Répondre à ${replyTo.senderName}',
                  style: TextStyle(
                    color: Colors.blue.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyTo.displayContent,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelReply,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: _isRecording ? _buildRecordingBar() : _buildNormalInputBar(),
      ),
    );
  }

  // Barre d'enregistrement audio (style WhatsApp)
  Widget _buildRecordingBar() {
    return Row(
      children: [
        // Bouton annuler
        IconButton(
          onPressed: _cancelRecording,
          icon: const Icon(Icons.delete, color: Colors.red),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF2D2D2D),
            shape: const CircleBorder(),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Indicateur d'enregistrement
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Durée d'enregistrement
        Expanded(
          child: Text(
            _formatRecordingDuration(_recordingSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        // Bouton envoyer
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _stopRecording(send: true),
              child: const Center(
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Barre de saisie normale
  Widget _buildNormalInputBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Bouton média (photos/vidéos)
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: IconButton(
            onPressed: _sendMediaMessage,
            icon: const Icon(Icons.add_photo_alternate, color: Colors.white70, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF2D2D2D),
              shape: const CircleBorder(),
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Zone de saisie
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Tapez votre message...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 16),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              onChanged: (text) {
                setState(() {
                  _isComposingMessage = text.trim().isNotEmpty;
                });
              },
              onSubmitted: (_) {
                if (_isComposingMessage) {
                  _sendTextMessage();
                }
              },
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Bouton d'envoi ou microphone (style WhatsApp)
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: _isComposingMessage ? Colors.blue : const Color(0xFF2D2D2D),
            shape: BoxShape.circle,
            boxShadow: [
              if (_isComposingMessage)
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _isComposingMessage ? _sendTextMessage : _startRecording,
              child: Center(
                child: Icon(
                  _isComposingMessage ? Icons.send_rounded : Icons.mic,
                  color: _isComposingMessage ? Colors.white : Colors.white70,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatRecordingDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showMessageOptions(ChatMessage message) {
    final isMyMessage = message.senderId == _currentUserId;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.reply, color: Colors.white),
            title: const Text('Répondre', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _replyToMessage(message);
            },
          ),
          if (message.content.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white),
              title: const Text('Copier', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.content));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copié dans le presse-papier')),
                  );
                }
              },
            ),
          if (message.isMediaMessage)
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.white),
              title: const Text('Voir', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _viewMedia(message);
              },
            ),
          // Bouton Modifier (uniquement pour mes messages texte)
          if (isMyMessage && message.isTextMessage && message.content.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Modifier', style: TextStyle(color: Colors.blue)),
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
          // Bouton Supprimer (uniquement pour mes messages)
          if (isMyMessage)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}';
    } else if (difference.inHours > 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  // ========================================
  // MÉTHODES SUPPLÉMENTAIRES
  // ========================================

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Déconnecter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de déconnexion: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showChatStats() async {
    try {
      final stats = await _chatService.getChatStats();
      if (stats != null && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Statistiques du Chat',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Messages totaux', '${stats.totalMessages}'),
                _buildStatRow('Messages média', '${stats.totalMediaMessages}'),
                _buildStatRow('Utilisateurs actifs (24h)', '${stats.activeUsersLast24h}'),
                const SizedBox(height: 16),
                const Text(
                  'Messages par type:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...stats.messagesByType.map(
                  (typeCount) => _buildStatRow(
                    _getTypeDisplayName(typeCount.type),
                    '${typeCount.count}',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'text': return 'Texte';
      case 'image': return 'Images';
      case 'video': return 'Vidéos';
      case 'audio': return 'Audio';
      default: return type;
    }
  }
}