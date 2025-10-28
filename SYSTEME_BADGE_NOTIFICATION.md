# 🔴 Système de Badge de Notification Push

## Vue d'ensemble

Le système de badge rouge sur l'icône de l'application permet d'indiquer aux utilisateurs le nombre de messages non lus dans les chats de groupe.

## Package utilisé

- **app_badge_plus**: ^1.1.6 (compatible Android/iOS)

## Architecture

### 1. Service de Badge (`lib/services/app_badge_service.dart`)

Gère tous les aspects des badges de notification :

```dart
import 'package:emploi/services/app_badge_service.dart';

// Vérifier si le device supporte les badges
bool supported = await AppBadgeService.isSupported();

// Mettre à jour le badge avec un nombre
await AppBadgeService.updateBadge(5); // Badge rouge avec "5"

// Effacer le badge
await AppBadgeService.clearBadge(); // Badge disparaît
```

### 2. Gestion par Groupe

Chaque groupe de chat a son propre compteur :

```dart
// Nouveau message dans le groupe "group_chat"
await AppBadgeService.incrementGroupUnread('group_chat');

// L'utilisateur ouvre le chat (marquer comme lu)
await AppBadgeService.clearGroupUnread('group_chat');

// Définir directement le nombre de messages non lus
await AppBadgeService.setGroupUnreadCount('group_chat', 3);
```

### 3. Notifications de Chat

Utiliser `NotificationService.notifyGroupMessage()` pour envoyer une notification :

```dart
import 'package:emploi/notification_service.dart';

// Envoyer une notification de message de groupe
await NotificationService.notifyGroupMessage(
  senderName: "Jean Dupont",
  message: "Bonjour tout le monde!",
  groupId: "group_chat", // Important pour le badge
);
```

## Intégration dans le Chat de Groupe

### Quand l'utilisateur ouvre le chat

Le badge est automatiquement réinitialisé dans `initState()` :

```dart
// Dans group_chat_page.dart
@override
void initState() {
  super.initState();
  // ... autres initialisations
  _clearChatBadge(); // ← Réinitialise le badge
}

Future<void> _clearChatBadge() async {
  await AppBadgeService.clearGroupUnread('group_chat');
}
```

### Quand un nouveau message arrive

Dans le système de rafraîchissement automatique ou via WebSocket :

```dart
// Détection d'un nouveau message
if (nouveauMessage) {
  // Notifier l'utilisateur
  await NotificationService.notifyGroupMessage(
    senderName: message.senderName,
    message: message.content,
    groupId: 'group_chat',
  );
  // Le badge est automatiquement incrémenté dans showLocalNotification()
}
```

## API Complète

### AppBadgeService

#### Méthodes principales

| Méthode | Description | Exemple |
|---------|-------------|---------|
| `isSupported()` | Vérifie si le device supporte les badges | `bool ok = await AppBadgeService.isSupported()` |
| `updateBadge(int)` | Met à jour le badge avec un nombre | `await AppBadgeService.updateBadge(5)` |
| `incrementBadge()` | Incrémente le badge de 1 | `await AppBadgeService.incrementBadge()` |
| `decrementBadge()` | Décrémente le badge de 1 | `await AppBadgeService.decrementBadge()` |
| `clearBadge()` | Efface complètement le badge | `await AppBadgeService.clearBadge()` |
| `getUnreadCount()` | Obtient le nombre total de messages non lus | `int count = await AppBadgeService.getUnreadCount()` |

#### Méthodes par groupe

| Méthode | Description | Exemple |
|---------|-------------|---------|
| `setGroupUnreadCount(groupId, count)` | Définit le nombre de messages non lus pour un groupe | `await AppBadgeService.setGroupUnreadCount('group_1', 3)` |
| `incrementGroupUnread(groupId)` | Incrémente le compteur d'un groupe | `await AppBadgeService.incrementGroupUnread('group_1')` |
| `clearGroupUnread(groupId)` | Réinitialise le compteur d'un groupe | `await AppBadgeService.clearGroupUnread('group_1')` |
| `getAllGroupUnreadCounts()` | Obtient tous les compteurs de groupes | `Map<String, int> counts = await AppBadgeService.getAllGroupUnreadCounts()` |

## Workflow Complet

### Scénario 1 : Nouveau message reçu

```dart
// 1. L'application reçoit un nouveau message (WebSocket/polling)
void onNewMessage(ChatMessage message) {
  // 2. Afficher une notification locale avec badge
  NotificationService.notifyGroupMessage(
    senderName: message.senderName,
    message: message.content,
    groupId: message.groupId,
  );
  // → Le badge passe à 1, 2, 3...
}
```

### Scénario 2 : Utilisateur ouvre le chat

```dart
// 1. L'utilisateur tape sur la notification ou ouvre la page
class GroupChatPage extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    // 2. Réinitialiser le badge pour ce groupe
    AppBadgeService.clearGroupUnread('group_chat');
    // → Le badge disparaît ou décrémente selon les autres groupes
  }
}
```

### Scénario 3 : Plusieurs groupes

```dart
// Groupe 1 : 3 messages non lus
await AppBadgeService.incrementGroupUnread('group_1'); // 1
await AppBadgeService.incrementGroupUnread('group_1'); // 2
await AppBadgeService.incrementGroupUnread('group_1'); // 3

// Groupe 2 : 2 messages non lus
await AppBadgeService.incrementGroupUnread('group_2'); // 4
await AppBadgeService.incrementGroupUnread('group_2'); // 5

// Badge total = 5 (3 + 2)

// L'utilisateur ouvre le groupe 1
await AppBadgeService.clearGroupUnread('group_1');
// Badge total = 2 (seulement groupe 2 reste)
```

## Plateforme Support

| Plateforme | Support | Notes |
|------------|---------|-------|
| Android | ✅ Oui | Nécessite un launcher compatible (Samsung, Xiaomi, etc.) |
| iOS | ✅ Oui | Support natif complet |
| Web | ❌ Non | Les badges ne sont pas supportés sur navigateur |
| Windows | ❌ Non | Pas de support natif |
| macOS | ✅ Oui | Support natif |
| Linux | ❌ Non | Pas de support natif |

## Configuration Android

### AndroidManifest.xml

Aucune configuration spéciale nécessaire. Le package `app_badge_plus` gère automatiquement les permissions.

### Launchers compatibles

Le badge fonctionne sur la plupart des launchers Android modernes :
- Samsung One UI ✅
- Xiaomi MIUI ✅
- OnePlus OxygenOS ✅
- Google Pixel Launcher ✅
- Nova Launcher ✅
- Stock Android 8.0+ ✅

## Configuration iOS

### Info.plist

Aucune configuration supplémentaire nécessaire si `flutter_local_notifications` est déjà configuré.

### Permissions

Les badges iOS nécessitent que l'utilisateur ait accepté les notifications. Ceci est géré automatiquement lors de l'initialisation de `flutter_local_notifications`.

## Débogage

### Vérifier le support

```dart
bool supported = await AppBadgeService.isSupported();
if (!supported) {
  debugPrint('⚠️ Les badges ne sont pas supportés sur ce device');
}
```

### Afficher tous les compteurs

```dart
Map<String, int> groupCounts = await AppBadgeService.getAllGroupUnreadCounts();
int totalCount = await AppBadgeService.getUnreadCount();

debugPrint('📊 Compteurs par groupe: $groupCounts');
debugPrint('📊 Total: $totalCount');
```

### Forcer la mise à jour

```dart
// Recalculer le badge total manuellement
await AppBadgeService.updateBadge(0);  // Reset
await AppBadgeService._recalculateTotalBadge();  // Recalcul
```

## Exemples d'utilisation

### Chat simple

```dart
class SimpleChatPage extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    // Effacer le badge à l'ouverture
    AppBadgeService.clearBadge();
  }
  
  void onMessageReceived() {
    // Nouveau message → incrémenter
    AppBadgeService.incrementBadge();
  }
}
```

### Chat avec plusieurs groupes

```dart
class MultiGroupChatPage extends StatefulWidget {
  final String groupId;
  
  @override
  void initState() {
    super.initState();
    // Effacer uniquement ce groupe
    AppBadgeService.clearGroupUnread(groupId);
  }
  
  void onMessageReceived(String fromGroupId) {
    // Incrémenter le bon groupe
    AppBadgeService.incrementGroupUnread(fromGroupId);
  }
}
```

## Troubleshooting

### Le badge ne s'affiche pas

1. Vérifier que le device supporte les badges :
   ```dart
   bool ok = await AppBadgeService.isSupported();
   ```

2. Vérifier les permissions de notification (iOS) :
   ```dart
   await NotificationService.initialize();
   ```

3. Vérifier que le launcher Android supporte les badges (voir liste ci-dessus)

### Le badge ne se met pas à jour

1. Vérifier que `flutter pub get` a bien installé `app_badge_plus`
2. Redémarrer l'application (pas seulement hot reload)
3. Vérifier les logs avec `debugPrint()` dans `app_badge_service.dart`

### Le badge reste affiché après lecture

Vérifier que `clearGroupUnread()` est bien appelé dans `initState()` :
```dart
@override
void initState() {
  super.initState();
  _clearChatBadge(); // Important!
}
```

## Bonnes pratiques

1. **Toujours vérifier le support** avant d'utiliser les badges
2. **Effacer le badge** quand l'utilisateur ouvre le chat
3. **Utiliser des groupId uniques** pour chaque chat/groupe
4. **Tester sur device réel** (les émulateurs peuvent ne pas supporter les badges)
5. **Ne pas abuser des badges** (limiter à 99 max pour la lisibilité)

## Évolutions futures

- [ ] Support des badges Web (PWA)
- [ ] Synchronisation entre devices
- [ ] Badges personnalisés (couleurs, formes)
- [ ] Analytics sur les interactions avec les badges
- [ ] Badges par type de notification (messages, alertes, etc.)
