# 📐 Tailles de Logos Nécessaires pour l'Application SETRAF

## 🎯 Logo de Base Requis

**Logo principal avec marges (fond blanc)** : **1024x1024 pixels**
- Ce sera le logo source pour générer toutes les autres tailles
- **Important** : Le logo SETRAF doit être centré avec au moins 20% de marge blanche de chaque côté
- Cela évite que le logo soit coupé dans les icônes circulaires

---

## 📱 **ANDROID** - Tailles Exactes

### Icônes Standard (ic_launcher.png)
Place ces fichiers dans `android/app/src/main/res/`:

1. **mipmap-mdpi/ic_launcher.png** : 48x48 pixels
2. **mipmap-hdpi/ic_launcher.png** : 72x72 pixels
3. **mipmap-xhdpi/ic_launcher.png** : 96x96 pixels
4. **mipmap-xxhdpi/ic_launcher.png** : 144x144 pixels
5. **mipmap-xxxhdpi/ic_launcher.png** : 192x192 pixels

### Icônes Adaptatives (Android 8.0+)
Place ces fichiers dans les mêmes dossiers mipmap :

1. **ic_launcher_foreground.png** (toutes densités) : Même taille que ic_launcher
2. **Fond blanc** pour adaptive_icon_background

---

## 🍎 **iOS** - Tailles Exactes

Place ces fichiers dans `ios/Runner/Assets.xcassets/AppIcon.appiconset/`:

1. **Icon-20@2x.png** : 40x40 pixels (iPhone Notification)
2. **Icon-20@3x.png** : 60x60 pixels (iPhone Notification)
3. **Icon-29@2x.png** : 58x58 pixels (Settings)
4. **Icon-29@3x.png** : 87x87 pixels (Settings)
5. **Icon-40@2x.png** : 80x80 pixels (Spotlight)
6. **Icon-40@3x.png** : 120x120 pixels (Spotlight)
7. **Icon-60@2x.png** : 120x120 pixels (App Icon)
8. **Icon-60@3x.png** : 180x180 pixels (App Icon)
9. **Icon-76.png** : 76x76 pixels (iPad)
10. **Icon-76@2x.png** : 152x152 pixels (iPad)
11. **Icon-83.5@2x.png** : 167x167 pixels (iPad Pro)
12. **Icon-1024.png** : 1024x1024 pixels (App Store)

---

## 🌐 **WEB** - Tailles Exactes

Place ces fichiers dans `web/icons/`:

1. **Icon-192.png** : 192x192 pixels (PWA standard)
2. **Icon-512.png** : 512x512 pixels (PWA haute résolution)
3. **Icon-maskable-192.png** : 192x192 pixels (PWA maskable)
4. **Icon-maskable-512.png** : 512x512 pixels (PWA maskable)

Place aussi :
- **web/favicon.png** : 32x32 pixels (Favicon navigateur)

---

## 💻 **WINDOWS** - Tailles Exactes

Place ces fichiers dans `windows/runner/resources/`:

1. **app_icon.ico** : Format ICO multi-tailles (16, 32, 48, 256 pixels)
   - Ou simplement **app_icon.png** : 256x256 pixels

---

## 🍎 **macOS** - Tailles Exactes

Place ces fichiers dans `macos/Runner/Assets.xcassets/AppIcon.appiconset/`:

1. **app_icon_16.png** : 16x16 pixels
2. **app_icon_32.png** : 32x32 pixels
3. **app_icon_64.png** : 64x64 pixels
4. **app_icon_128.png** : 128x128 pixels
5. **app_icon_256.png** : 256x256 pixels
6. **app_icon_512.png** : 512x512 pixels
7. **app_icon_1024.png** : 1024x1024 pixels

---

## ✨ **SOLUTION SIMPLE - Ce dont tu as besoin**

Si tu me donnes le **logo SETRAF 512x512** (centré avec marges blanches), je vais créer automatiquement toutes ces tailles.

### **Format à fournir** :

**Un seul fichier PNG :** `logo_1024x1024.png`
- Résolution : 1024x1024 pixels
- Fond : Blanc (#FFFFFF)
- Logo SETRAF : Centré avec au moins 150 pixels de marge de chaque côté
- Format : PNG avec transparence ou fond blanc

**OU plusieurs tailles pré-créées :**

Donne-moi ces 3 fichiers et je m'occupe du reste :
1. `logo_1024.png` (1024x1024) - Pour iOS App Store et base
2. `logo_512.png` (512x512) - Pour Web et génération
3. `logo_192.png` (192x192) - Pour Android xxxhdpi et Web

---

## 🚀 Commande pour générer automatiquement

Une fois les fichiers en place, lance :

```bash
flutter pub run flutter_launcher_icons
```

Et toutes les icônes seront générées automatiquement ! ✅
