import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Pour base64Decode
import 'dart:async'; // Pour les timers
import 'dart:io'; // Pour File
import 'package:path_provider/path_provider.dart';
import '../profile_service.dart'; // Import du service pour les appels API
import '../session_service.dart';
import '../components/pdf_viewer_widget.dart';
import '../components/certificate_analytics_widget.dart';
import '../models/certificate.dart';

class CertificatsPage extends StatefulWidget {
  const CertificatsPage({super.key});

  @override
  CertificatsPageState createState() => CertificatsPageState();
}

class CertificatsPageState extends State<CertificatsPage> with AutomaticKeepAliveClientMixin {
  final ProfileService _profileService = ProfileService();
  bool _isLoading = true;
  String? _error;
  String? _token;
  bool _isAdmin = false;
  List<dynamic> _employees = [];
  bool _isLoadingEmployees = false;

  // Variables pour la mise à jour automatique
  Timer? _autoRefreshTimer;
  bool _isAutoRefreshing = false;

  // Variables pour la recherche
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredEmployees = [];
  String _searchTerm = '';
  
  // Garder la page en vie pour conserver le scroll
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _filteredEmployees = _employees;
    _loadTokenAndFetchUser();
    _startAutoRefresh();
  }

  Future<void> _loadTokenAndFetchUser() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (_token == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Token manquant. Reconnectez-vous.';
        _isLoading = false;
      });
      return;
    }
    await _fetchUser();
  }

  Future<void> _fetchUser() async {
    if (_token == null) {
      return;
    }
    bool shouldUpdateUI = true;
    try {
      setState(() => _isLoading = true);
      final userInfo = await _profileService.getUserInfo(_token!);
      if (!mounted) {
        shouldUpdateUI = false;
        return;
      }
      setState(() {
        _error = null;
        _isAdmin = userInfo['email'] == 'nyundumathryme@gmail.com' || userInfo['role'] == 'admin';
      });

      // Charger les employés seulement si admin
      if (_isAdmin) {
        await _fetchEmployees();
      } else {
        // Redirection silencieuse pour les non-admin
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          });
        }
        return;
      }
    } catch (e) {
      if (!mounted) {
        shouldUpdateUI = false;
        return;
      }
      // Ne pas afficher d'erreur si redirection en cours
      if (_isAdmin) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (shouldUpdateUI && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Démarre la mise à jour automatique toutes les 30 secondes
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Vérifier si la session est toujours valide
      final isValidSession = await SessionService.isSessionValid();
      if (!isValidSession) {
        timer.cancel();
        _handleSessionExpired();
        return;
      }

      // Rafraîchir les employés en arrière-plan
      if (!_isAutoRefreshing && _isAdmin) {
        _isAutoRefreshing = true;
        try {
          await _fetchEmployees();
        } catch (e) {
          // Ignorer les erreurs de mise à jour automatique
        } finally {
          _isAutoRefreshing = false;
        }
      }
    });
  }

  void _handleSessionExpired() {
    if (mounted) {
      SessionService.endSession().then((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/registration');
        }
      });
    }
  }

  Future<void> _fetchEmployees() async {
    if (_token == null || !_isAdmin) return;
    setState(() => _isLoadingEmployees = true);
    try {
      final employees = await _profileService.getEmployees(_token!);
      if (mounted) {
        setState(() {
          _employees = employees;
          _filterEmployees();
          _error = null; // Effacer l'erreur en cas de succès
        });
      }
    } on TimeoutException {
      // En cas de timeout, afficher un message mais garder les données en cache
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Chargement lent. Données en cache affichées.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception:', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: _fetchEmployees,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
      }
    }
  }

  void _filterEmployees() {
    setState(() {
      if (_searchTerm.isEmpty) {
        _filteredEmployees = _employees;
      } else {
        _filteredEmployees = _employees.where((employee) {
          final name = employee['name'].toString().toLowerCase();
          final email = employee['email'].toString().toLowerCase();
          final position = employee['position'].toString().toLowerCase();
          final searchLower = _searchTerm.toLowerCase();
          
          return name.contains(searchLower) || 
                 email.contains(searchLower) ||
                 position.contains(searchLower);
        }).toList();
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchTerm = value;
    });
    _filterEmployees();
  }

  Future<void> _viewCertificate(String base64Pdf, String employeeName) async {
    try {
      // Vérifier que le base64 n'est pas vide
      if (base64Pdf.isEmpty) {
        throw Exception('Aucun certificat disponible pour cet employé');
      }

      // Afficher un indicateur de chargement
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Préparation du PDF...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Convertir base64 en fichier temporaire
      debugPrint('📄 Conversion du certificat pour: $employeeName');
      debugPrint('📏 Taille base64: ${base64Pdf.length} caractères');
      
      final bytes = base64Decode(base64Pdf);
      debugPrint('📦 Taille bytes: ${bytes.length} octets');
      
      final dir = await getTemporaryDirectory();
      final fileName = 'certificate_${employeeName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      debugPrint('✅ Fichier créé: ${file.path}');
      debugPrint('📊 Fichier existe: ${await file.exists()}');
      
      if (!mounted) return;
      
      // Ouvrir le viewer PDF en plein écran
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerWidget(
            pdfUrl: file.path,
            title: 'Certificat de $employeeName',
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Erreur viewCertificate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _downloadCertificate(String base64Pdf, String employeeName) async {
    try {
      // Convertir base64 en fichier
      final bytes = base64Decode(base64Pdf);
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'Certificate_${employeeName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Certificat téléchargé: $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Ouvrir',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfViewerWidget(
                      pdfUrl: file.path,
                      title: 'Certificat de $employeeName',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getExpirationColor(DateTime endDate) {
    final now = DateTime.now();
    final diff = endDate.difference(now).inDays;
    if (diff > 30) return Colors.blue;
    if (diff > 7) return Colors.orange;
    return Colors.red;
  }

  double _getExpirationProgress(DateTime startDate, DateTime endDate) {
    final total = endDate.difference(startDate).inDays;
    final elapsed = DateTime.now().difference(startDate).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String _getExpirationText(DateTime endDate) {
    final diff = endDate.difference(DateTime.now()).inDays;
    if (diff > 0) {
      return '$diff jours restants';
    } else if (diff == 0) {
      return 'Expire aujourd\'hui';
    } else {
      return 'Expiré depuis ${-diff} jours';
    }
  }

  List<Certificate> get _certificatesList {
    return _employees.map((employee) => Certificate.fromEmployee(employee)).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Nécessaire pour AutomaticKeepAliveClientMixin
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFE8F5E8),
        appBar: AppBar(
          title: const Text('Certificats'),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _fetchUser();
                if (_isAdmin) _fetchEmployees();
                SessionService.extendSession();
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Se déconnecter',
            ),
          ],
          bottom: _isAdmin && !_isLoading && _error == null ? const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: Icon(Icons.list),
                text: 'Liste des Certificats',
              ),
              Tab(
                icon: Icon(Icons.analytics),
                text: 'Analyses & Statistiques',
              ),
            ],
          ) : null,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2E7D32),
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(_error!, style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/registration'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                          child: const Text('Se connecter', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                        children: [
                          // Onglet Liste des Certificats
                          Column(
                            children: [
                              // Barre de recherche et statistiques
                              Container(
                                color: Colors.white,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    // Barre de recherche
                                    TextField(
                                      controller: _searchController,
                                      onChanged: _onSearchChanged,
                                      decoration: InputDecoration(
                                        hintText: 'Rechercher par nom, email ou poste...',
                                        prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                                        suffixIcon: _searchTerm.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  _onSearchChanged('');
                                                },
                                              )
                                            : null,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Statistiques
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2E7D32),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  '${_filteredEmployees.length}',
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const Text(
                                                  'Certificats trouvés',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[600],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  '${_employees.length}',
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const Text(
                                                  'Total certificats',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Liste filtrée
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: () async {
                                    await _fetchEmployees();
                                  },
                                  color: const Color(0xFF2E7D32),
                                  child: _isLoadingEmployees
                                      ? const Center(child: CircularProgressIndicator())
                                      : _filteredEmployees.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    _searchTerm.isNotEmpty 
                                                        ? 'Aucun certificat trouvé pour "$_searchTerm"'
                                                        : 'Aucun certificat disponible',
                                                    style: TextStyle(color: Colors.grey[600]),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : ListView.builder(
                                              key: const PageStorageKey<String>('certificats_list'),
                                              padding: const EdgeInsets.all(16),
                                              itemCount: _filteredEmployees.length,
                                              itemBuilder: (context, index) {
                                                final employee = _filteredEmployees[index];
                                          final startDate = DateTime.parse(employee['startDate']);
                                          final endDate = DateTime.parse(employee['endDate']);
                                          final expirationColor = _getExpirationColor(endDate);
                                          return Card(
                                            elevation: 8,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            color: Colors.white,
                                            margin: const EdgeInsets.only(bottom: 16),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 30,
                                                        backgroundImage: MemoryImage(base64Decode(employee['photo'])),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              employee['name'],
                                                              style: const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight: FontWeight.bold,
                                                                color: Color(0xFF2E7D32),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              'Poste: ${employee['position']}',
                                                              style: TextStyle(color: Colors.grey[600]),
                                                            ),
                                                            Text(
                                                              'Email: ${employee['email']}',
                                                              style: TextStyle(color: Colors.grey[600]),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'Début: ${startDate.toLocal().toString().split(' ')[0]}',
                                                    style: TextStyle(color: Colors.grey[600]),
                                                  ),
                                                  Text(
                                                    'Fin: ${endDate.toLocal().toString().split(' ')[0]}',
                                                    style: TextStyle(color: Colors.grey[600]),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    _getExpirationText(endDate),
                                                    style: TextStyle(
                                                      color: expirationColor,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  // Barre de progression avec animation et temps écoulé
                                                  Column(
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            'Progression:',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey[600],
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          Text(
                                                            '${(_getExpirationProgress(startDate, endDate) * 100).toStringAsFixed(1)}%',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: expirationColor,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      LinearProgressIndicator(
                                                        value: _getExpirationProgress(startDate, endDate),
                                                        backgroundColor: Colors.grey[300],
                                                        valueColor: AlwaysStoppedAnimation<Color>(expirationColor),
                                                        minHeight: 8,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            'Écoulé: ${DateTime.now().difference(startDate).inDays} jours',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors.grey[500],
                                                            ),
                                                          ),
                                                          Text(
                                                            'Total: ${endDate.difference(startDate).inDays} jours',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors.grey[500],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      ElevatedButton.icon(
                                                        onPressed: () => _viewCertificate(employee['certificate'], employee['name']),
                                                        icon: const Icon(Icons.visibility),
                                                        label: const Text('Prévisualiser'),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF2E7D32),
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      OutlinedButton.icon(
                                                        onPressed: () => _downloadCertificate(employee['certificate'], employee['name']),
                                                        icon: const Icon(Icons.download),
                                                        label: const Text('Télécharger'),
                                                        style: OutlinedButton.styleFrom(
                                                          side: const BorderSide(color: Color(0xFF2E7D32)),
                                                          foregroundColor: const Color(0xFF2E7D32),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                ),
                              ),
                            ],
                          ),
                          
                          // Onglet Analyses & Statistiques
                          _isLoadingEmployees
                              ? const Center(child: CircularProgressIndicator())
                              : CertificateAnalyticsWidget(
                                  certificates: _certificatesList,
                                ),
                        ],
                      ),
      ),
    );
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
        await SessionService.endSession();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/registration');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la déconnexion: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}