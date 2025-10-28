import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../profile_service.dart';
import '../widgets/background_pattern.dart';

// Modèle pour les employés
class Employee {
  final String id;
  final String name;
  final String email;
  final String role;
  final String position;
  final String photo;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.position,
    required this.photo,
    required this.isActive,
    required this.createdAt,
    this.startDate,
    this.endDate,
  });

  // Factory pour créer un Employee depuis les données de l'API
  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      position: json['position'] ?? '',
      photo: json['photo'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      startDate: json['startDate'] != null 
          ? DateTime.parse(json['startDate'])
          : null,
      endDate: json['endDate'] != null 
          ? DateTime.parse(json['endDate'])
          : null,
    );
  }
}

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final ProfileService _profileService = ProfileService();
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _token;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  
  // Filtres
  bool? _activeFilter;
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _loadTokenAndEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTokenAndEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    
    if (_token == null) {
      setState(() {
        _error = 'Token manquant. Veuillez vous reconnecter.';
        _isLoading = false;
      });
      return;
    }

    await _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    if (_token == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final employeesData = await _profileService.getEmployees(_token!);
      
      setState(() {
        _employees = employeesData.map<Employee>((json) => Employee.fromJson(json)).toList();
        _filterEmployees();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur lors du chargement des employés: $e';
        _isLoading = false;
      });
    }
  }

  void _filterEmployees() {
    setState(() {
      _filteredEmployees = _employees.where((employee) {
        // Filtre par recherche textuelle
        final matchesSearch = _searchQuery.isEmpty ||
            employee.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            employee.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            employee.role.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            employee.position.toLowerCase().contains(_searchQuery.toLowerCase());
        
        // Filtre par statut actif
        final matchesActive = _activeFilter == null || employee.isActive == _activeFilter;
        
        // Filtre par rôle
        final matchesRole = _roleFilter == null || employee.role == _roleFilter;
        
        return matchesSearch && matchesActive && matchesRole;
      }).toList();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _filterEmployees();
  }

  // Fonction pour envoyer un email
  Future<void> _sendEmail(String email, String name) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Message pour $name',
        'body': 'Bonjour $name,\n\n',
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossible d\'ouvrir l\'application email pour $email'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture de l\'email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CSSBackgroundPattern(
      backgroundColor: const Color(0xFF121212),
      patternType: CSSPatternType.subtleDots,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Laisse transparaître le motif
        appBar: AppBar(
          title: const Text('Employés'),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadEmployees,
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E8).withValues(alpha: 0.8), // Semi-transparent pour les motifs
          ),
          child: Column(
            children: [
              // Barre de recherche
              Container(
                color: Colors.white.withValues(alpha: 0.9),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom, email ou poste...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    const SizedBox(height: 16),
                    
                    // Filtres
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Tous', null),
                          const SizedBox(width: 8),
                          _buildFilterChip('Actifs', true),
                          const SizedBox(width: 8),
                          _buildFilterChip('Inactifs', false),
                          const SizedBox(width: 8),
                          _buildRoleFilter(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Affichage des erreurs
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    color: Colors.red.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadEmployees,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Liste des employés
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredEmployees.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty 
                                      ? 'Aucun employé trouvé pour "$_searchQuery"'
                                      : 'Aucun employé disponible',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadEmployees,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredEmployees.length,
                              itemBuilder: (context, index) {
                                final employee = _filteredEmployees[index];
                                return _buildEmployeeCard(employee);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool? activeValue) {
    final isSelected = _activeFilter == activeValue;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _activeFilter = selected ? activeValue : null;
        });
        _filterEmployees();
      },
      selectedColor: const Color(0xFF2E7D32),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildRoleFilter() {
    final roles = _employees.map((e) => e.role).toSet().toList();
    
    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(20),
          color: _roleFilter != null ? const Color(0xFF2E7D32) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.work,
              size: 16,
              color: _roleFilter != null ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 4),
            Text(
              _roleFilter ?? 'Rôle',
              style: TextStyle(
                color: _roleFilter != null ? Colors.white : Colors.grey[700],
                fontWeight: _roleFilter != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: _roleFilter != null ? Colors.white : Colors.grey[700],
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: '',
          child: Text('Tous les rôles'),
        ),
        ...roles.map((role) => PopupMenuItem<String>(
          value: role,
          child: Text(role),
        )),
      ],
      onSelected: (value) {
        setState(() {
          _roleFilter = value.isEmpty ? null : value;
        });
        _filterEmployees();
      },
    );
  }

  Widget _buildEmployeeCard(Employee employee) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              employee.isActive ? Colors.green.shade50.withValues(alpha: 0.95) : Colors.grey.shade50.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar de l'employé
                  Builder(
                    builder: (context) {
                      // Déterminer l'image de profil
                      ImageProvider? profileImage;
                      if (employee.photo.isNotEmpty) {
                        if (employee.photo.startsWith('http://') || employee.photo.startsWith('https://')) {
                          profileImage = NetworkImage(employee.photo);
                        } else {
                          try {
                            profileImage = MemoryImage(base64Decode(employee.photo));
                          } catch (e) {
                            debugPrint('Erreur décodage base64: $e');
                            profileImage = null;
                          }
                        }
                      }
                      
                      return CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF2E7D32),
                        backgroundImage: profileImage,
                        child: profileImage == null
                            ? Text(
                                employee.name.isNotEmpty 
                                    ? employee.name[0].toUpperCase() 
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  
                  // Informations principales
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                employee.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            // Badge de statut
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: employee.isActive ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                employee.isActive ? 'Actif' : 'Inactif',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          employee.position,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          employee.role,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Informations de contact
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.email, size: 16, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            employee.email,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _sendEmail(employee.email, employee.name),
                          icon: const Icon(Icons.send, color: Color(0xFF2E7D32)),
                          tooltip: 'Envoyer un email',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Dates importantes
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Membre depuis',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          _formatDate(employee.createdAt),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (employee.startDate != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date d\'embauche',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            _formatDate(employee.startDate!),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}