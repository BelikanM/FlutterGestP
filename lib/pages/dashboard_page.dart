import 'package:flutter/material.dart';
import '../components/bottom_navigation.dart';
import '../components/session_status_widget.dart';
import '../session_service.dart';
import '../employee_cache_service.dart';
import '../role_service.dart';
import '../widgets/background_pattern.dart';
import 'employees_page.dart';
import 'certificats_page.dart';
import 'media_library_page.dart';
import 'profiles_page.dart';
import 'blog_list_page.dart';
import 'group_chat_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key}); // Constructeur avec key (correction précédente)

  @override
  DashboardPageState createState() => DashboardPageState(); // Classe d'état publique (correction précédente)
}

class DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;
  
  void navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  
  // Pages pour les admins
  List<Widget> get _adminPages => [
    const GroupChatPage(), // Chat de groupe (page d'accueil)
    const EmployeesPage(),    // Employés
    const CertificatsPage(),  // Certificats
    const MediaLibraryPage(), // Médias
    const BlogListPage(),     // Blog
    const ProfilesPage(),     // Profiles
  ];
  
  // Pages pour les utilisateurs non-admin
  List<Widget> get _userPages => [
    const GroupChatPage(), // Chat de groupe (page d'accueil)
    const MediaLibraryPage(),     // Bibliothèque (index 1)
    const BlogListPage(),         // Blog (index 2)
    const ProfilesPage(),         // Profil (index 3)
  ];
  
  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }
  
  Future<void> _checkUserRole() async {
    try {
      final isAdmin = await RoleService.isAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _isLoadingRole = false;
          // Réinitialiser l'index si nécessaire
          if (!isAdmin && _currentIndex >= _userPages.length) {
            _currentIndex = 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _isLoadingRole = false;
          _currentIndex = 0;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Nettoyage complet de toutes les données utilisateur
        await SessionService.clearAllUserData();
        await EmployeeCacheService.clearCache();
        
        if (mounted) {
          // Redémarrer complètement l'application
          Navigator.pushNamedAndRemoveUntil(context, '/registration', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return CSSBackgroundPattern(
        backgroundColor: const Color(0xFF121212),
        patternType: CSSPatternType.gridLines,
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.blue),
                SizedBox(height: 16),
                Text(
                  'Vérification des permissions...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    final pages = _isAdmin ? _adminPages : _userPages;
    final navigationItems = _isAdmin ? NavigationItems.adminItems : NavigationItems.userItems;
    final pageTitles = _isAdmin 
        ? ['Dashboard', 'Employés', 'Certificats', 'Médias', 'Blog', 'Profiles']
        : ['Accueil', 'Certificats', 'Bibliothèque', 'Blog', 'Profil'];
    
    return CSSBackgroundPattern(
      backgroundColor: const Color(0xFF121212),
      patternType: CSSPatternType.diagonalLines,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(pageTitles[_currentIndex]),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          actions: [
            const SessionStatusWidget(),
            const SizedBox(width: 16),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E8).withValues(alpha: 0.7),
          ),
          child: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
        ),
        bottomNavigationBar: BottomNavigation(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: navigationItems,
        ),
        floatingActionButton: _currentIndex == 0 ? null : FloatingActionButton(
          onPressed: _logout,
          backgroundColor: Colors.red,
          tooltip: 'Se déconnecter',
          child: const Icon(Icons.logout, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      ),
    );
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key}); // Constructeur avec key (correction précédente)

  @override
  Widget build(BuildContext context) {
    return const Center( // const pour optimisation
      child: Text(
        'Bienvenue sur le Dashboard !',
        style: TextStyle(fontSize: 24), // Ajusté pour headlineMedium-like
      ),
    );
  }
}