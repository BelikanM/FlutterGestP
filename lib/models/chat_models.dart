// Modèles de données pour le système de chat de groupe

// ========================================
// MESSAGE DE CHAT
// ========================================

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderPhoto;
  final String content;
  final String mediaUrl;
  final String mediaType; // 'text', 'image', 'video', 'audio'
  final String fileName;
  final int fileSize;
  final String? replyToId;
  final String replyToContent;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final List<MessageRead> readBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? blogArticleId; // ID de l'article de blog si c'est un partage

  // Message de réponse (si applicable)
  final ChatMessage? replyToMessage;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhoto = '',
    this.content = '',
    this.mediaUrl = '',
    this.mediaType = 'text',
    this.fileName = '',
    this.fileSize = 0,
    this.replyToId,
    this.replyToContent = '',
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.readBy = const [],
    required this.createdAt,
    required this.updatedAt,
    this.replyToMessage,
    this.blogArticleId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderPhoto: json['senderPhoto'] ?? '',
      content: json['content'] ?? '',
      mediaUrl: json['mediaUrl'] ?? '',
      mediaType: json['mediaType'] ?? 'text',
      fileName: json['fileName'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      replyToId: json['replyTo'],
      replyToContent: json['replyToContent'] ?? '',
      isEdited: json['isEdited'] ?? false,
      editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt']) : null,
      isDeleted: json['isDeleted'] ?? false,
      deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt']) : null,
      readBy: (json['readBy'] as List<dynamic>? ?? [])
          .map((item) => MessageRead.fromJson(item))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      replyToMessage: json['replyTo'] != null && json['replyTo'] is Map
          ? ChatMessage.fromJson(json['replyTo'])
          : null,
      blogArticleId: json['blogArticleId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'fileName': fileName,
      'fileSize': fileSize,
      'replyTo': replyToId,
      'replyToContent': replyToContent,
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'readBy': readBy.map((read) => read.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'blogArticleId': blogArticleId,
    };
  }

  // Méthodes utilitaires
  bool get isMediaMessage => mediaType != 'text' && mediaUrl.isNotEmpty;
  bool get isTextMessage => mediaType == 'text';
  bool get isImageMessage => mediaType == 'image';
  bool get isVideoMessage => mediaType == 'video';
  bool get isAudioMessage => mediaType == 'audio';
  bool get hasReply => replyToId != null;
  bool get isBlogShare => blogArticleId != null && blogArticleId!.isNotEmpty;
  
  String get displayContent {
    if (isDeleted) return '[Message supprimé]';
    if (content.isNotEmpty) return content;
    switch (mediaType) {
      case 'image': return '📷 Image';
      case 'video': return '🎥 Vidéo';
      case 'audio': return '🎵 Audio';
      default: return '[Média]';
    }
  }
}

// ========================================
// LECTURE DE MESSAGE
// ========================================

class MessageRead {
  final String userId;
  final DateTime readAt;

  MessageRead({
    required this.userId,
    required this.readAt,
  });

  factory MessageRead.fromJson(Map<String, dynamic> json) {
    return MessageRead(
      userId: json['userId'] ?? '',
      readAt: DateTime.parse(json['readAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'readAt': readAt.toIso8601String(),
    };
  }
}

// ========================================
// RÉPONSE PAGINÉE DES MESSAGES
// ========================================

class ChatMessagesResponse {
  final bool success;
  final List<ChatMessage> messages;
  final ChatPagination pagination;

  ChatMessagesResponse({
    required this.success,
    required this.messages,
    required this.pagination,
  });

  factory ChatMessagesResponse.fromJson(Map<String, dynamic> json) {
    return ChatMessagesResponse(
      success: json['success'] ?? false,
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((item) => ChatMessage.fromJson(item))
          .toList(),
      pagination: ChatPagination.fromJson(json['pagination'] ?? {}),
    );
  }
}

// ========================================
// PAGINATION DU CHAT
// ========================================

class ChatPagination {
  final int currentPage;
  final int totalPages;
  final int totalMessages;
  final bool hasMore;

  ChatPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalMessages,
    required this.hasMore,
  });

  factory ChatPagination.fromJson(Map<String, dynamic> json) {
    return ChatPagination(
      currentPage: json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? 1,
      totalMessages: json['totalMessages'] ?? 0,
      hasMore: json['hasMore'] ?? false,
    );
  }
}

// ========================================
// NOTIFICATION DE GROUPE
// ========================================

class GroupNotification {
  final String id;
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final String mediaType;
  final DateTime sentAt;
  final List<MessageRead> readBy;
  final DateTime createdAt;

  GroupNotification({
    required this.id,
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.mediaType = 'text',
    required this.sentAt,
    this.readBy = const [],
    required this.createdAt,
  });

  factory GroupNotification.fromJson(Map<String, dynamic> json) {
    return GroupNotification(
      id: json['_id'] ?? '',
      messageId: json['messageId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      content: json['content'] ?? '',
      mediaType: json['mediaType'] ?? 'text',
      sentAt: DateTime.parse(json['sentAt']),
      readBy: (json['readBy'] as List<dynamic>? ?? [])
          .map((item) => MessageRead.fromJson(item))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'mediaType': mediaType,
      'sentAt': sentAt.toIso8601String(),
      'readBy': readBy.map((read) => read.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// ========================================
// STATISTIQUES DU CHAT
// ========================================

class ChatStats {
  final int totalMessages;
  final int totalMediaMessages;
  final int activeUsersLast24h;
  final List<MessageTypeCount> messagesByType;

  ChatStats({
    required this.totalMessages,
    required this.totalMediaMessages,
    required this.activeUsersLast24h,
    required this.messagesByType,
  });

  factory ChatStats.fromJson(Map<String, dynamic> json) {
    return ChatStats(
      totalMessages: json['totalMessages'] ?? 0,
      totalMediaMessages: json['totalMediaMessages'] ?? 0,
      activeUsersLast24h: json['activeUsersLast24h'] ?? 0,
      messagesByType: (json['messagesByType'] as List<dynamic>? ?? [])
          .map((item) => MessageTypeCount.fromJson(item))
          .toList(),
    );
  }
}

// ========================================
// COMPTEUR PAR TYPE DE MESSAGE
// ========================================

class MessageTypeCount {
  final String type;
  final int count;

  MessageTypeCount({
    required this.type,
    required this.count,
  });

  factory MessageTypeCount.fromJson(Map<String, dynamic> json) {
    return MessageTypeCount(
      type: json['_id'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

// ========================================
// ÉTAT DU CHAT (pour l'interface)
// ========================================

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final bool hasMoreMessages;
  final ChatMessage? replyingTo;
  final int unreadNotificationsCount;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.hasMoreMessages = true,
    this.replyingTo,
    this.unreadNotificationsCount = 0,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    bool? hasMoreMessages,
    ChatMessage? replyingTo,
    int? unreadNotificationsCount,
    bool clearReply = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
      unreadNotificationsCount: unreadNotificationsCount ?? this.unreadNotificationsCount,
    );
  }
}