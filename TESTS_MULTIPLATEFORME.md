# Test de Configuration Multiplateforme

## 🧪 Tests à Effectuer

### Avant de Commencer

Assurez-vous que le backend Node.js est démarré :

```bash
cd backend
node server.js
```

Vous devriez voir :
```
🚀 Server running on http://localhost:5000
✅ MongoDB connected
```

---

## Test 1: Windows Desktop

```bash
flutter run -d windows
```

### Points de Vérification

- [ ] Login réussit
- [ ] Page d'accueil charge les articles
- [ ] Page de chat accessible
- [ ] Envoi de message texte fonctionne
- [ ] Envoi de photo fonctionne
- [ ] Modification de message fonctionne
- [ ] Photo de profil s'affiche
- [ ] Médias (images/vidéos) chargent

### URL Attendue dans les Logs
```
baseUrl devrait être: http://localhost:5000
```

---

## Test 2: Android Emulator

### Lancer l'émulateur

```bash
# Liste des émulateurs disponibles
flutter emulators

# Lancer un émulateur Android
flutter emulators --launch <nom_emulateur>

# OU depuis Android Studio: AVD Manager > Play
```

### Démarrer l'app

```bash
flutter run -d emulator-5554
```

### Points de Vérification

- [ ] L'app se lance sans crash
- [ ] Login réussit (connexion au backend)
- [ ] Page d'accueil charge les articles
- [ ] Images chargent correctement
- [ ] Page de chat accessible
- [ ] Envoi de message fonctionne
- [ ] Upload de photo depuis galerie fonctionne
- [ ] Enregistrement audio fonctionne
- [ ] Photo de profil s'affiche

### URL Attendue dans les Logs
```
baseUrl devrait être: http://10.0.2.2:5000
```

### Debug Android Emulator

Si problème de connexion au backend :

1. **Vérifier que le backend écoute sur toutes les interfaces**
   
   Dans `backend/server.js`, assurez-vous que :
   ```javascript
   app.listen(5000, '0.0.0.0', () => {
     console.log('Server running on port 5000');
   });
   ```

2. **Tester depuis l'émulateur**
   
   Ouvrez Chrome dans l'émulateur et visitez :
   ```
   http://10.0.2.2:5000/api/health
   ```
   
   Si cela fonctionne, le backend est accessible !

3. **Vérifier les logs Flutter**
   ```bash
   flutter logs
   ```
   
   Cherchez les erreurs de connexion réseau.

---

## Test 3: Web (Chrome)

```bash
flutter run -d chrome
```

### Points de Vérification

- [ ] Login réussit
- [ ] Page d'accueil charge
- [ ] Chat fonctionne
- [ ] Upload de médias fonctionne
- [ ] Pas d'erreurs CORS

### URL Attendue dans les Logs
```
baseUrl devrait être: http://localhost:5000
```

---

## 🔍 Vérifications Automatiques

### 1. Tester la Détection de Plateforme

Créez un fichier `test_platform_url.dart` :

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';

void main() {
  print('Platform test:');
  print('kIsWeb: $kIsWeb');
  if (!kIsWeb) {
    print('Platform.isAndroid: ${Platform.isAndroid}');
    print('Platform.isWindows: ${Platform.isWindows}');
    print('Platform.isIOS: ${Platform.isIOS}');
  }
  
  // Test URL helper
  final baseUrl = getBaseUrl();
  print('Base URL: $baseUrl');
}

String getBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost:5000';
  } else if (Platform.isAndroid) {
    return 'http://10.0.2.2:5000';
  } else {
    return 'http://localhost:5000';
  }
}
```

Exécutez :
```bash
dart run test_platform_url.dart
```

### 2. Vérifier les Logs de l'App

Dans votre app, ajoutez des logs pour debug :

```dart
import 'package:emploi/utils/url_helper.dart';

void main() {
  print('🔧 App starting with baseUrl: ${UrlHelper.baseUrl}');
  runApp(MyApp());
}
```

---

## ❌ Problèmes Courants et Solutions

### Problème 1: "Connection refused" sur Android

**Cause** : Backend n'écoute pas sur `0.0.0.0`

**Solution** :
```javascript
// backend/server.js
app.listen(5000, '0.0.0.0', () => {
  console.log('✅ Server listening on all interfaces (0.0.0.0:5000)');
});
```

---

### Problème 2: "Network unreachable" sur Android

**Cause** : Firewall Windows bloque Node.js

**Solution** :
1. Ouvrir "Firewall Windows"
2. "Autoriser une application"
3. Trouver "Node.js" et cocher "Privé" et "Public"

---

### Problème 3: Images ne chargent pas sur Android

**Cause** : URLs mal formées

**Debug** :
```bash
flutter logs | grep "🔗 Media URL"
```

Vérifiez que les URLs commencent par `http://10.0.2.2:5000/...`

---

### Problème 4: "Cleartext HTTP traffic not permitted"

**Cause** : Android bloque HTTP par défaut (sécurité)

**Solution** : Déjà configuré dans `android/app/src/main/AndroidManifest.xml` :
```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

---

## 📊 Résumé des Tests

| Plateforme | URL Backend | Statut |
|------------|-------------|--------|
| Windows    | http://localhost:5000 | ☐ |
| Android Emulator | http://10.0.2.2:5000 | ☐ |
| Web (Chrome) | http://localhost:5000 | ☐ |
| Android Device | http://[IP_PC]:5000 | ⚠️ Non configuré |

---

## 📝 Notes de Test

### Test Windows Desktop
- Date : __________
- Version Flutter : __________
- Résultat : ☐ PASS ☐ FAIL
- Notes : ___________________________

### Test Android Emulator
- Date : __________
- Version Flutter : __________
- API Level : __________
- Résultat : ☐ PASS ☐ FAIL
- Notes : ___________________________

### Test Web
- Date : __________
- Version Flutter : __________
- Browser : __________
- Résultat : ☐ PASS ☐ FAIL
- Notes : ___________________________

---

## 🚀 Prochaines Étapes

Une fois tous les tests passés :

1. ✅ Valider que toutes les fonctionnalités marchent sur chaque plateforme
2. ✅ Documenter les bugs trouvés
3. ✅ Configurer les variables d'environnement pour production
4. ✅ Préparer le déploiement

---

## 🔐 Configuration Production

Pour la production, créez un fichier `.env` :

```env
API_BASE_URL=https://your-production-api.com
```

Et modifiez `url_helper.dart` :

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UrlHelper {
  static String get baseUrl {
    // En production, utiliser la variable d'environnement
    if (dotenv.env['API_BASE_URL'] != null) {
      return dotenv.env['API_BASE_URL']!;
    }
    
    // Sinon, utiliser la logique de développement
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://localhost:5000';
    }
  }
}
```
