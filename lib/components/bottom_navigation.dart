import 'package:flutter/material.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationBarItem> items;

  const BottomNavigation({
    super.key, 
    required this.currentIndex, 
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      items: items,
    );
  }
}

// Définitions des éléments de navigation pour différents rôles
class NavigationItems {
  static const List<BottomNavigationBarItem> adminItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Employés'),
    BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Certificats'),
    BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'Médias'),
    BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Blog'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profiles'),
  ];

  static const List<BottomNavigationBarItem> userItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Accueil'),
    BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'Bibliothèque'),
    BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Blog'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
  ];
}