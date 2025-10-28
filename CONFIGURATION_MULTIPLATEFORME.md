# Configuration Multiplateforme - URLs Adaptatives

## 📋 Objectif

Adapter automatiquement les URLs du backend selon la plateforme d'exécution pour permettre les tests sur Android, Windows et Web sans modification manuelle.

## 🎯 Problème Résolu

- **Avant** : Les URLs étaient codées en dur avec `localhost` ou `127.0.0.1:5000`
- **Problème** : Sur Android Emulator, `localhost` ne fonctionne pas (il pointe vers l'émulateur lui-même)
- **Solution** : Détection automatique de la plateforme et adaptation de l'URL

## 🔧 Implementation

### Principe

Chaque service utilise maintenant un **getter** au lieu d'une constante pour `baseUrl` :

```dart
static String get baseUrl {
  if (kIsWeb) {
    return 'http://localhost:5000';
  } else if (Platform.isAndroid) {
    return 'http://10.0.2.2:5000';  // IP spéciale pour Android Emulator
  } else {
    return 'http://localhost:5000';
  }
}
```

### Imports Requis

Chaque service nécessite maintenant :

```dart
import 'dart:io';                      // Pour Platform.isAndroid
import 'package:flutter/foundation.dart';  // Pour kIsWeb
```

## 📂 Fichiers Modifiés

### Utilitaire Central

0. ✅ **lib/utils/url_helper.dart** (NOUVEAU)
   - Classe helper centralisée pour la gestion des URLs
   - Méthodes : `baseUrl`, `getFullUrl()`, `getUploadUrl()`
   - Utilisé par tous les composants média

### Services Backend (15 fichiers)

1. ✅ **lib/auth_service.dart**
   - URL de base : `http://localhost:5000` ou `http://10.0.2.2:5000`

2. ✅ **lib/services/chat_service.dart**
   - URL de base : `http://localhost:5000/api` ou `http://10.0.2.2:5000/api`
   - Méthode `getAbsoluteUrl()` aussi mise à jour

3. ✅ **lib/admin_service.dart**
   - URL de base : `http://localhost:5000` ou `http://10.0.2.2:5000`

4. ✅ **lib/blog_service.dart**
   - URL de base : `http://localhost:5000` ou `http://10.0.2.2:5000`

5. ✅ **lib/social_interactions_service.dart**
   - URL de base : `http://localhost:5000` ou `http://10.0.2.2:5000`

6. ✅ **lib/services/user_presence_service.dart**
   - URL de base : `http://localhost:5000/api` ou `http://10.0.2.2:5000/api`

7. ✅ **lib/services/unified_feed_service.dart**
   - URL de base : `http://localhost:5000` ou `http://10.0.2.2:5000`

8. ✅ **lib/services/social_service.dart**
   - URL de base : `http://localhost:5000` ou `http://10.0.2.2:5000`

9. ✅ **lib/services/simplified_feed_service.dart**
   - URL de base : `http://localhost:5000` ou `http://10.0.2.2:5000`

10. ✅ **lib/services/public_feed_service.dart**
    - URL de base : `http://localhost:5000` ou `http://10.0.2.2:5000`

11. ✅ **lib/services/optimized_feed_service.dart**
    - URL de base : `http://localhost:5000` ou `http://10.0.2.2:5000`

12. ✅ **lib/social_feed_service.dart**
    - URL de base : `http://localhost:5000/api` ou `http://10.0.2.2:5000/api`

13. ✅ **lib/profile_service.dart**
    - URL de base : `http://localhost:5000` ou `http://10.0.2.2:5000`

14. ✅ **lib/notification_service.dart**
    - Propriété privée `_baseUrl` convertie en getter
    - URL de base : `http://localhost:5000` ou `http://10.0.2.2:5000`

15. ✅ **lib/media_service.dart**
    - URL de base : `http://localhost:5000/api/media` ou `http://10.0.2.2:5000/api/media`

### Pages UI (3 fichiers)

16. ✅ **lib/pages/blog_list_page.dart**
    - Ajout de getter `_serverBaseUrl` pour construire les URLs d'images
    - Remplace `http://127.0.0.1:5000` par `$_serverBaseUrl`

17. ✅ **lib/pages/blog_detail_page.dart**
    - Ajout de getter `_serverBaseUrl` pour construire les URLs d'images
    - Remplace `http://127.0.0.1:5000` par `$_serverBaseUrl`

18. ✅ **lib/pages/home_page.dart**
    - Ajout de getter `_serverBaseUrl`
    - Mise à jour de `_buildLibraryStyleMediaCard()`
    - Mise à jour de `_viewMedia()`

### Composants Média (7 fichiers)

19. ✅ **lib/components/html5_media_viewer.dart**
    - Utilise `UrlHelper.getFullUrl()` au lieu de URLs codées en dur

20. ✅ **lib/components/mediakit_audio_player.dart**
    - Utilise `UrlHelper.getFullUrl()` pour les URLs audio

21. ✅ **lib/components/mediakit_video_player.dart**
    - Utilise `UrlHelper.getFullUrl()` pour les URLs vidéo

22. ✅ **lib/components/pdf_viewer_widget.dart**
    - Utilise `UrlHelper.getFullUrl()` pour télécharger les PDFs

23. ✅ **lib/components/windows_video_player.dart**
    - Utilise `UrlHelper.getFullUrl()` pour lancer les vidéos

24. ✅ **lib/components/simple_audio_player.dart**
    - Utilise `UrlHelper.getFullUrl()` pour les URLs audio

25. ✅ **lib/components/simple_video_player.dart**
    - Utilise `UrlHelper.getFullUrl()` pour les URLs vidéo

## ✅ Avantages de l'Architecture avec UrlHelper

1. **Centralisation** : Un seul endroit pour la logique de génération d'URL
2. **Réutilisabilité** : Tous les composants utilisent le même helper
3. **Maintenabilité** : Changement d'URL en un seul fichier
4. **Cohérence** : Garantit que toutes les URLs suivent la même logique
5. **Testabilité** : Facile de mocker le helper pour les tests

## 🌐 URLs par Plateforme

| Plateforme | URL Backend | Raison |
|------------|-------------|--------|
| **Web** | `http://localhost:5000` | Browser sur même machine |
| **Windows** | `http://localhost:5000` | App desktop sur même machine |
| **Android Emulator** | `http://10.0.2.2:5000` | IP spéciale qui redirige vers la machine hôte |
| **Android Device** | `http://<IP_LOCAL>:5000` | ⚠️ Nécessite IP du PC (ex: `192.168.1.100:5000`) |

## 📱 Configuration Android Emulator

L'IP `10.0.2.2` est une **adresse spéciale** fournie par Android Emulator :

- `10.0.2.2` = `localhost` de la machine hôte (le PC)
- `127.0.0.1` = l'émulateur lui-même ❌
- `localhost` = l'émulateur lui-même ❌

### Pour Tester sur Appareil Réel

Si vous testez sur un **appareil Android physique**, vous devrez :

1. Connecter le téléphone au même réseau WiFi que le PC
2. Trouver l'IP locale du PC (ex: `192.168.1.100`)
3. Modifier temporairement le code :

```dart
static String get baseUrl {
  if (kIsWeb) {
    return 'http://localhost:5000';
  } else if (Platform.isAndroid) {
    return 'http://192.168.1.100:5000';  // Remplacer par votre IP
  } else {
    return 'http://localhost:5000';
  }
}
```

## ✅ Tests à Effectuer

### Sur Windows/Desktop
```bash
flutter run -d windows
```
- ✅ Login fonctionne
- ✅ Chat charge les messages
- ✅ Upload de photos
- ✅ Profil utilisateur visible

### Sur Android Emulator
```bash
flutter run -d emulator-5554
```
- ✅ Backend accessible via `10.0.2.2:5000`
- ✅ Toutes les APIs fonctionnent
- ✅ Images chargent correctement
- ✅ Médias accessibles

### Sur Web
```bash
flutter run -d chrome
```
- ✅ Utilise `localhost:5000`
- ✅ Aucun problème CORS

## 🚀 Démarrage Backend

Avant de tester sur n'importe quelle plateforme, assurez-vous que le backend Node.js tourne :

```bash
cd backend
node server.js
```

Le serveur doit afficher :
```
🚀 Server running on http://localhost:5000
✅ MongoDB connected
```

## 🔍 Debug

Si vous avez des problèmes de connexion, vérifiez :

1. **Backend lancé ?**
   ```bash
   curl http://localhost:5000/api/health
   ```

2. **Sur Android Emulator ?**
   ```bash
   # Dans l'émulateur, ouvrez Chrome et visitez :
   http://10.0.2.2:5000/api/health
   ```

3. **Firewall Windows ?**
   - Autoriser Node.js dans le pare-feu
   - Port 5000 doit être ouvert

## 📝 Notes Importantes

1. **Ne pas utiliser** `127.0.0.1` ou `localhost` sur Android
2. **Toujours tester** sur émulateur avant appareil réel
3. **CORS** : Le backend doit autoriser toutes les origines pour le développement
4. **Production** : Utiliser des variables d'environnement au lieu de URLs codées en dur

## 🔐 Sécurité

⚠️ **Cette configuration est pour le DÉVELOPPEMENT uniquement !**

En production, vous devriez :
- Utiliser HTTPS
- Configurer les URLs via variables d'environnement
- Restreindre les CORS
- Utiliser un domaine/IP publique

## 📚 Références

- [Android Network Configuration](https://developer.android.com/studio/run/emulator-networking)
- [Flutter Platform Detection](https://api.flutter.dev/flutter/foundation/kIsWeb-constant.html)
- [Dart Platform](https://api.dart.dev/stable/dart-io/Platform-class.html)
