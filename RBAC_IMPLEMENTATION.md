# Contrôle d'Accès Basé sur les Rôles (RBAC)

## 📋 Résumé

Implémentation d'un système de contrôle d'accès basé sur les rôles pour limiter les utilisateurs non-administrateurs aux sections : **Bibliothèque**, **Profil**, et **Blog**.

## 🔐 Niveaux d'Accès

### 👑 Administrateurs
**Email autorisé :** `nyundumathryme@gmail.com`  
**Ou rôle :** `admin`

**Accès complet à toutes les sections :**
- ✅ Dashboard
- ✅ Employés (création, modification, suppression)
- ✅ Certificats
- ✅ Médias (Bibliothèque)
- ✅ Blog (lecture, écriture, édition)
- ✅ Profil (complet avec gestion d'employés)

### 👤 Utilisateurs Standard
**Tous les autres utilisateurs**

**Accès limité aux sections :**
- ✅ **Accueil** (Dashboard) - Mur d'actualités avec feed du blog et des médias récents
- ✅ **Bibliothèque** (Médias) - Consultation et gestion des médias
- ✅ **Blog** - Lecture et création d'articles
- ✅ **Profil** - Informations personnelles uniquement

**Sections interdites :**
- ❌ Dashboard
- ❌ Employés
- ❌ Certificats
- ❌ Gestion administrative

## 🏗️ Architecture Technique

### 1. Service de Rôles (`role_service.dart`)
```dart
class RoleService {
  // Vérification admin par email ou rôle
  static Future<bool> isAdmin()
  
  // Récupération utilisateur avec flag admin
  static Future<Map<String, dynamic>?> getCurrentUser()
  
  // Vérification d'accès par section
  static Future<bool> canAccessSection(String sectionName)
  
  // Liste des sections accessibles
  static Future<List<String>> getAccessibleSections()
}
```

### 2. Navigation Adaptative (`bottom_navigation.dart`)
```dart
// Navigation pour admins (6 onglets)
static const List<BottomNavigationBarItem> adminItems = [
  Dashboard, Employés, Certificats, Médias, Blog, Profiles
];

// Navigation pour utilisateurs (3 onglets)
static const List<BottomNavigationBarItem> userItems = [
  Bibliothèque, Blog, Profil
];
```

### 3. Interface Utilisateur Dynamique (`dashboard_page.dart`)
```dart
// Pages différentes selon le rôle
final pages = _isAdmin ? _adminPages : _userPages;
final navigationItems = _isAdmin ? NavigationItems.adminItems : NavigationItems.userItems;

// Titres adaptés
final pageTitles = _isAdmin 
    ? ['Dashboard', 'Employés', 'Certificats', 'Médias', 'Blog', 'Profiles']
    : ['Bibliothèque', 'Blog', 'Profil'];
```

### 4. Contrôle Granulaire (`profiles_page.dart`)
```dart
// Section création employé (admin uniquement)
if (_isAdmin) ...[
  // Interface de création d'employé
]

// Section affichage employés (admin uniquement)  
if (_isAdmin) ...[
  // Liste et gestion des employés
]

// Chargement conditionnel des données
if (_isAdmin) {
  await _loadCachedEmployees();
  await _fetchEmployees();
}
```

## 🔄 Flux d'Authentification

1. **Connexion utilisateur** → Récupération du token JWT
2. **Vérification du profil** → Détermination du rôle (admin/user)
3. **Chargement interface** → Navigation adaptée au rôle
4. **Contrôle d'accès** → Affichage conditionnel des fonctionnalités

## 🛡️ Sécurité Côté Client

⚠️ **Important :** Cette implémentation fournit une **sécurité côté client** uniquement.

### Mesures Complémentaires Recommandées :
- ✅ **Validation serveur** : Vérifier les permissions pour chaque API
- ✅ **JWT avec rôles** : Inclure les rôles dans le token JWT
- ✅ **Middleware d'autorisation** : Contrôle d'accès côté serveur
- ✅ **Audit des actions** : Journalisation des accès sensibles

## 📁 Fichiers Modifiés

### Nouveaux Fichiers
- `lib/role_service.dart` - Service de gestion des rôles

### Fichiers Modifiés
- `lib/components/bottom_navigation.dart` - Navigation adaptative
- `lib/pages/dashboard_page.dart` - Interface basée sur les rôles
- `lib/pages/profiles_page.dart` - Contrôle d'accès granulaire

## 🧪 Test de l'Implémentation

### Tester en tant qu'Admin
1. Se connecter avec `nyundumathryme@gmail.com`
2. Vérifier l'accès aux 6 sections
3. Confirmer la visibilité des fonctions de gestion d'employés

### Tester en tant qu'Utilisateur Standard
1. Se connecter avec un autre email
2. Vérifier l'accès limité aux 3 sections seulement
3. Confirmer l'absence des sections administratives

## 🚀 Déploiement

L'application est maintenant configurée pour :
- ✅ Différencier automatiquement les utilisateurs admin/standard
- ✅ Adapter l'interface selon les permissions
- ✅ Cacher les fonctionnalités sensibles aux utilisateurs non-autorisés
- ✅ Maintenir une expérience utilisateur fluide pour tous les rôles

## 📝 Notes de Maintenance

- Le contrôle d'accès est centralisé dans `RoleService`
- Les permissions sont basées sur l'email ou le champ `role` du profil utilisateur
- L'interface s'adapte dynamiquement sans redémarrage
- Les données sensibles ne sont chargées que pour les utilisateurs autorisés