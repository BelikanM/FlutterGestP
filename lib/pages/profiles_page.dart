import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; // Ajout pour ImagePicker
import 'package:file_picker/file_picker.dart'; // Ajout pour FilePicker PDF
import 'dart:io'; // Ajout pour File
import 'dart:convert'; // Ajout pour base64Encode
import 'dart:async'; // Pour les timers
import '../profile_service.dart'; // Import du service pour les appels API
import '../session_service.dart';
import '../employee_cache_service.dart';
import '../media_service.dart';

import 'blog_list_page.dart';
import 'blog_editor_page.dart';
import 'media_library_page.dart';
import 'admin_users_page.dart'; // Page de gestion des utilisateurs
class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});
  @override
  ProfilesPageState createState() => ProfilesPageState();
}
class ProfilesPageState extends State<ProfilesPage> with AutomaticKeepAliveClientMixin {
  final ProfileService _profileService = ProfileService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;
  String? _token;
  bool _isUpdating = false;
  File? _selectedImage; // Pour stocker l'image sélectionnée
  
  @override
  bool get wantKeepAlive => true;
  // Nouvelle section Employé
  final TextEditingController _employeeNameController = TextEditingController();
  final TextEditingController _employeePositionController = TextEditingController();
  final TextEditingController _employeeEmailController = TextEditingController();
  File? _employeePhoto;
  File? _employeeCertificate;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCreatingEmployee = false;
  Map<String, dynamic>? _createdEmployee;
  List<dynamic> _employees = [];
  bool _isLoadingEmployees = false;
  int _hoveredIndex = -1;
  Map<String, dynamic>? _selectedEmployee;
  File? _editPhoto;
  File? _editCertificate;
  
  // Variables pour la mise à jour automatique
  Timer? _autoRefreshTimer;
  bool _isAutoRefreshing = false;
  
  // Variables pour l'administration
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchUser();
    _startAutoRefresh();
  }


  Future<void> _loadTokenAndFetchUser() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (_token == null) {
      if (!mounted) return; // Correction : Vérification mounted
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
    bool shouldUpdateUI = true; // Flag pour éviter return in finally
    try {
      setState(() => _isLoading = true);
      final userInfo = await _profileService.getUserInfo(_token!);
      if (!mounted) {
        shouldUpdateUI = false;
        return;
      }
      setState(() {
        _userData = userInfo;
        _nameController.text = userInfo['name'] ?? '';
        _error = null;
        // Vérifier les permissions admin
        _isAdmin = userInfo['email'] == 'nyundumathryme@gmail.com' || userInfo['role'] == 'admin';
      });
      
      // Charger les employés seulement si admin
      if (_isAdmin) {
        await _loadCachedEmployees();
        await _fetchEmployees();
      }
    } catch (e) {
      if (!mounted) {
        shouldUpdateUI = false;
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      if (shouldUpdateUI && mounted) { // Correction : Flag + mounted pour éviter control_flow_in_finally
        setState(() => _isLoading = false);
      }
    }
  }

  // Charge les employés depuis le cache local au démarrage
  Future<void> _loadCachedEmployees() async {
    try {
      final cachedEmployees = await EmployeeCacheService.getCachedEmployees();
      if (mounted && cachedEmployees.isNotEmpty) {
        setState(() {
          _employees = cachedEmployees;
        });
      }
    } catch (e) {
      // Gérer l'erreur silencieusement
    }
    // Puis charger depuis le serveur
    await _fetchEmployees();
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
      if (!_isAutoRefreshing) {
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
    if (_token == null) return;
    setState(() => _isLoadingEmployees = true);
    try {
      final employees = await _profileService.getEmployees(_token!);
      if (mounted) {
        setState(() {
          _employees = employees;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des employés: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
      }
    }
  }
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery); // ou ImageSource.camera pour caméra
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }
  Future<void> _pickEmployeePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _employeePhoto = File(image.path);
      });
    }
  }
  Future<void> _pickEditPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _editPhoto = File(image.path);
      });
    }
  }
  Future<void> _pickEmployeeCertificate() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _employeeCertificate = File(result.files.single.path!);
      });
    }
  }
  Future<void> _pickEditCertificate() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _editCertificate = File(result.files.single.path!);
      });
    }
  }
  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }
  Future<void> _selectEditStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }
  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }
  Future<void> _selectEditEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }
  Color _getExpirationColor() {
    if (_endDate == null) return Colors.grey;
    final now = DateTime.now();
    final diff = _endDate!.difference(now).inDays;
    if (diff > 30) return Colors.blue;
    if (diff > 7) return Colors.orange;
    return Colors.red;
  }
  double _getExpirationProgress() {
    if (_startDate == null || _endDate == null) return 0.0;
    final total = _endDate!.difference(_startDate!).inDays;
    final elapsed = DateTime.now().difference(_startDate!).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }
  Future<void> _createEmployee() async {
    if (_token == null ||
        _employeeNameController.text.isEmpty ||
        _employeePositionController.text.isEmpty ||
        _employeeEmailController.text.isEmpty ||
        _employeePhoto == null ||
        _employeeCertificate == null ||
        _startDate == null ||
        _endDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez remplir tous les champs'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    setState(() => _isCreatingEmployee = true);
    try {
      final photoBytes = await _employeePhoto!.readAsBytes();
      final photoBase64 = base64Encode(photoBytes);
      final certBytes = await _employeeCertificate!.readAsBytes();
      final certBase64 = base64Encode(certBytes);
      final created = await _profileService.createEmployee(
        _token!,
        name: _employeeNameController.text,
        position: _employeePositionController.text,
        email: _employeeEmailController.text,
        photo: photoBase64,
        certificate: certBase64,
        startDate: _startDate!.toIso8601String(),
        endDate: _endDate!.toIso8601String(),
      );
      if (!mounted) return;
      setState(() {
        _createdEmployee = created['employee'];
        _employeeNameController.clear();
        _employeePositionController.clear();
        _employeeEmailController.clear();
        _employeePhoto = null;
        _employeeCertificate = null;
        _startDate = null;
        _endDate = null;
      });
      await _fetchEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employé créé avec succès !'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingEmployee = false);
      }
    }
  }
  void _openCertificate() {
    if (_employeeCertificate != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Certificat'),
          content: const Text('Contenu du PDF (simulation)'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    }
  }
  void _downloadCertificate() {
    if (_employeeCertificate != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Téléchargement du certificat...')),
      );
    }
  }
  void _openEditCertificate() {
    if (_editCertificate != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Certificat'),
          content: const Text('Contenu du PDF (simulation)'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    }
  }
  void _downloadEditCertificate() {
    if (_editCertificate != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Téléchargement du certificat...')),
      );
    }
  }
  Future<void> _updateUserInfo() async {
    if (_token == null || _nameController.text.isEmpty) {
      return;
    }
    bool shouldUpdateUI = true; // Flag pour éviter return in finally
    setState(() => _isUpdating = true);
    try {
      String? base64Photo;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        base64Photo = base64Encode(bytes);
      }
      final updated = await _profileService.updateUserInfo(
        _token!,
        name: _nameController.text,
        profilePhoto: base64Photo, // Envoi de base64 si image sélectionnée
      );
      if (!mounted) {
        shouldUpdateUI = false;
        return;
      }
      setState(() => _userData = updated);
      
      // Prolonger la session car l'utilisateur est actif
      await SessionService.extendSession();
      
      if (mounted) { // Correction : use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour !'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
      await _fetchUser(); // Refresh
    } catch (e) {
      if (!mounted) {
        shouldUpdateUI = false;
        return;
      }
      if (mounted) { // Correction : use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (shouldUpdateUI && mounted) { // Correction : Flag + mounted pour éviter control_flow_in_finally
        setState(() => _isUpdating = false);
      }
    }
  }
  Future<void> _updatePassword() async {
    if (_token == null ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      if (mounted) { // Correction : use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Les nouveaux mots de passe ne correspondent pas'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    if (_newPasswordController.text.length < 6) {
      if (mounted) { // Correction : use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le mot de passe doit faire au moins 6 caractères'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    bool shouldUpdateUI = true; // Flag pour éviter return in finally
    setState(() => _isUpdating = true);
    try {
      await _profileService.updatePassword(
        _token!,
        _currentPasswordController.text,
        _newPasswordController.text,
      );
      if (!mounted) {
        shouldUpdateUI = false;
        return;
      }
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) { // Correction : use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour !'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (!mounted) {
        shouldUpdateUI = false;
        return;
      }
      if (mounted) { // Correction : use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (shouldUpdateUI && mounted) { // Correction : Flag + mounted pour éviter control_flow_in_finally
        setState(() => _isUpdating = false);
      }
    }
  }
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: const Text('Cette action est irréversible. Êtes-vous sûr ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || _token == null) {
      return;
    }
    bool shouldUpdateUI = true; // Flag pour éviter return in finally
    setState(() => _isUpdating = true);
    try {
      await _profileService.deleteAccount(_token!);
      if (!mounted) {
        shouldUpdateUI = false;
        return;
      }
      // Clear token et naviguer vers login
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      if (mounted) { // Correction : use_build_context_synchronously pour Navigator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte supprimé.'), backgroundColor: Colors.red),
        );
        Navigator.pushReplacementNamed(context, '/registration');
      }
    } catch (e) {
      if (!mounted) {
        shouldUpdateUI = false;
        return;
      }
      if (mounted) { // Correction : use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (shouldUpdateUI && mounted) { // Correction : Flag + mounted pour éviter control_flow_in_finally
        setState(() => _isUpdating = false);
      }
    }
  }
  void _showEmployeeDetails(Map<String, dynamic> employee) {
    _selectedEmployee = employee;
    _employeeNameController.text = employee['name'];
    _employeePositionController.text = employee['position'];
    _employeeEmailController.text = employee['email'];
    _startDate = DateTime.parse(employee['startDate']);
    _endDate = DateTime.parse(employee['endDate']);
    _editPhoto = null;
    _editCertificate = null;
    bool isEditing = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: MemoryImage(base64Decode(employee['photo'])),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(employee['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo
                  GestureDetector(
                    onTap: isEditing ? _pickEditPhoto : null,
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF2E7D32)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _editPhoto != null
                            ? Image.file(_editPhoto!, fit: BoxFit.cover)
                            : Image.memory(base64Decode(employee['photo']), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isEditing) ...[
                    _buildInfoRow(Icons.person, 'Nom:', employee['name']),
                    _buildInfoRow(Icons.work, 'Poste:', employee['position']),
                    _buildInfoRow(Icons.email, 'Email:', employee['email']),
                    _buildInfoRow(Icons.date_range, 'Début:', DateTime.parse(employee['startDate']).toLocal().toString().split(' ')[0]),
                    _buildInfoRow(Icons.event, 'Fin:', DateTime.parse(employee['endDate']).toLocal().toString().split(' ')[0]),
                    if (_endDate != null) ...[
                      LinearProgressIndicator(
                        value: _getExpirationProgress(),
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(_getExpirationColor()),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Expiration: ${_endDate!.difference(DateTime.now()).inDays.abs()} jours',
                        style: TextStyle(color: _getExpirationColor()),
                      ),
                    ],
                  ] else ...[
                    TextField(
                      controller: _employeeNameController,
                      decoration: InputDecoration(
                        labelText: 'Nom',
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF2E7D32)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFE8F5E8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _employeePositionController,
                      decoration: InputDecoration(
                        labelText: 'Poste',
                        prefixIcon: const Icon(Icons.work_outline, color: Color(0xFF2E7D32)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFE8F5E8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _employeeEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2E7D32)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFE8F5E8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Certificat
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickEditCertificate,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Color(0xFF2E7D32)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _editCertificate != null
                                  ? Text('PDF: ${_editCertificate!.path.split('/').last}')
                                  : const Text('Certificat actuel - Cliquer pour changer'),
                            ),
                          ),
                        ),
                        if (_editCertificate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(onPressed: _openEditCertificate, icon: const Icon(Icons.visibility)),
                          IconButton(onPressed: _downloadEditCertificate, icon: const Icon(Icons.download)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Dates
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date de début'),
                              GestureDetector(
                                onTap: _selectEditStartDate,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Color(0xFF2E7D32)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(_startDate == null ? 'Sélectionner' : _startDate!.toLocal().toString().split(' ')[0]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date de fin'),
                              GestureDetector(
                                onTap: _selectEditEndDate,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Color(0xFF2E7D32)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(_endDate == null ? 'Sélectionner' : _endDate!.toLocal().toString().split(' ')[0]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_endDate != null) ...[
                      LinearProgressIndicator(
                        value: _getExpirationProgress(),
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(_getExpirationColor()),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Expiration: ${_endDate!.difference(DateTime.now()).inDays.abs()} jours',
                        style: TextStyle(color: _getExpirationColor()),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              if (!isEditing) ...[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setDialogState(() => isEditing = true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                  child: const Text('Modifier', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: () => _deleteEmployee(employee['_id']),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                ),
              ] else ...[
                TextButton(
                  onPressed: () {
                    setDialogState(() => isEditing = false);
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _updateEmployee(employee['_id']);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    await _fetchEmployees();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                  child: const Text('Sauvegarder', style: TextStyle(color: Colors.white)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2E7D32), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _updateEmployee(String id) async {
    if (_token == null ||
        _employeeNameController.text.isEmpty ||
        _employeePositionController.text.isEmpty ||
        _employeeEmailController.text.isEmpty ||
        _startDate == null ||
        _endDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez remplir tous les champs'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      String photoBase64 = _selectedEmployee!['photo'];
      if (_editPhoto != null) {
        final photoBytes = await _editPhoto!.readAsBytes();
        photoBase64 = base64Encode(photoBytes);
      }
      String certBase64 = _selectedEmployee!['certificate'];
      if (_editCertificate != null) {
        final certBytes = await _editCertificate!.readAsBytes();
        certBase64 = base64Encode(certBytes);
      }
      await _profileService.updateEmployee(
        _token!,
        id,
        name: _employeeNameController.text,
        position: _employeePositionController.text,
        email: _employeeEmailController.text,
        photo: photoBase64,
        certificate: certBase64,
        startDate: _startDate!.toIso8601String(),
        endDate: _endDate!.toIso8601String(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employé mis à jour !'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
      setState(() {
        _editPhoto = null;
        _editCertificate = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  Future<void> _deleteEmployee(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'employé'),
        content: const Text('Cette action est irréversible. Êtes-vous sûr ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _profileService.deleteEmployee(_token!, id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employé supprimé !'), backgroundColor: Colors.red),
        );
        Navigator.pop(context); // Close details dialog
        await _fetchEmployees();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
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
        // Terminer la session
        await SessionService.endSession();
        // Vider le cache
        await EmployeeCacheService.clearCache();
        
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

  // Méthodes pour la section média
  Future<Map<String, dynamic>?> _getMediaStats() async {
    try {
      final stats = await MediaService.getMediaStats();
      return {
        'totalMedias': stats.totalMedias,
        'totalSize': stats.totalSize,
        'byType': stats.byType.map((ts) => {
          'type': ts.type,
          'count': ts.count,
          'totalSize': ts.totalSize,
        }).toList(),
      };
    } catch (e) {
      // Error loading media stats: $e
      return null;
    }
  }

  Widget _buildStatItem(String icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  int _getTypeCount(List<dynamic>? byType, String type) {
    if (byType == null) return 0;
    for (var item in byType) {
      if (item is Map<String, dynamic> && item['type'] == type) {
        return item['count'] as int? ?? 0;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Nécessaire pour AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E8), // Vert clair pour fond
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: const Color(0xFF2E7D32), // Vert foncé
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchUser();
              _fetchEmployees();
              SessionService.extendSession(); // Prolonger lors du refresh manuel
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Se déconnecter',
          ),
        ],
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
              : RefreshIndicator(
                  onRefresh: () async {
                    await _fetchUser();
                    await _fetchEmployees();
                  },
                  color: const Color(0xFF2E7D32),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Section Informations
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Informations Personnelles',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Photo de profil
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 60,
                                      backgroundColor: const Color(0xFFE8F5E8),
                                      backgroundImage: _userData?['profilePhoto'] != null && _userData!['profilePhoto'].isNotEmpty
                                          ? MemoryImage(base64Decode(_userData!['profilePhoto']))
                                          : null,
                                      child: _userData?['profilePhoto'] == null || _userData!['profilePhoto'].isEmpty
                                          ? const Icon(Icons.person, size: 60, color: Color(0xFF2E7D32))
                                          : null,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: _pickImage,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF2E7D32),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.edit, size: 20, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Nom éditable
                                TextField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Nom',
                                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF2E7D32)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: const Color(0xFFE8F5E8),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Email (non éditable)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF2E7D32), width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.email_outlined, color: Color(0xFF2E7D32)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _userData?['email'] ?? 'Non disponible',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Date d'inscription
                                Text(
                                  'Inscrit le: ${_userData?['createdAt'] != null ? DateTime.parse(_userData!['createdAt']).toLocal().toString().split(' ')[0] : 'Inconnue'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Bouton mise à jour infos
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isUpdating ? null : _updateUserInfo,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: _isUpdating
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text('Mettre à jour', style: TextStyle(color: Colors.white, fontSize: 16)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Section Mot de passe
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Changer le Mot de Passe',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _currentPasswordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Mot de passe actuel',
                                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF2E7D32)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: const Color(0xFFE8F5E8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _newPasswordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Nouveau mot de passe',
                                    prefixIcon: const Icon(Icons.lock, color: Color(0xFF2E7D32)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: const Color(0xFFE8F5E8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Confirmer nouveau mot de passe',
                                    prefixIcon: const Icon(Icons.lock, color: Color(0xFF2E7D32)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: const Color(0xFFE8F5E8),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isUpdating ? null : _updatePassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: _isUpdating
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text('Changer Mot de Passe', style: TextStyle(color: Colors.white, fontSize: 16)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Section Gestion des Médias
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.photo_library, 
                                         color: const Color(0xFF2E7D32), size: 28),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Bibliothèque Média',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const MediaLibraryPage(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.open_in_new, color: Colors.white),
                                      label: const Text('Ouvrir', 
                                                      style: TextStyle(color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E7D32),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Gérez vos médias (images, vidéos, documents) de manière centralisée.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Statistiques rapides des médias
                                FutureBuilder(
                                  future: _getMediaStats(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    
                                    if (snapshot.hasError || !snapshot.hasData) {
                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.info_outline, color: Colors.grey[600]),
                                            const SizedBox(width: 8),
                                            const Text('Aucun média trouvé'),
                                            const Spacer(),
                                            TextButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const MediaLibraryPage(),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.add),
                                              label: const Text('Ajouter'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    
                                    final stats = snapshot.data as Map<String, dynamic>;
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _buildStatItem(
                                              '📁', 
                                              'Total', 
                                              '${stats['totalMedias'] ?? 0} médias'
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildStatItem(
                                              '💾', 
                                              'Taille', 
                                              _formatFileSize(stats['totalSize'] ?? 0)
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildStatItem(
                                              '🖼️', 
                                              'Images', 
                                              '${_getTypeCount(stats['byType'], 'image')}'
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Actions rapides
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          final result = await FilePicker.platform.pickFiles(
                                            allowMultiple: true,
                                            type: FileType.any,
                                          );
                                          
                                          if (result != null && result.files.isNotEmpty && context.mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const MediaLibraryPage(),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Upload rapide'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const MediaLibraryPage(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.search),
                                        label: const Text('Parcourir'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Section Création Employé (Admin uniquement)
                        if (_isAdmin) ...[
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Créer un Employé',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Nom Employé
                                TextField(
                                  controller: _employeeNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Nom de l\'employé',
                                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF2E7D32)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: const Color(0xFFE8F5E8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Poste
                                TextField(
                                  controller: _employeePositionController,
                                  decoration: InputDecoration(
                                    labelText: 'Poste',
                                    prefixIcon: const Icon(Icons.work_outline, color: Color(0xFF2E7D32)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: const Color(0xFFE8F5E8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Email Employé
                                TextField(
                                  controller: _employeeEmailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email de l\'employé',
                                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2E7D32)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: const Color(0xFFE8F5E8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Photo Employé
                                GestureDetector(
                                  onTap: _pickEmployeePhoto,
                                  child: Container(
                                    height: 100,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Color(0xFF2E7D32)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: _employeePhoto != null
                                        ? Image.file(_employeePhoto!, fit: BoxFit.cover)
                                        : const Icon(Icons.add_photo_alternate, size: 50, color: Color(0xFF2E7D32)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Certificat PDF
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: _pickEmployeeCertificate,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Color(0xFF2E7D32)),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: _employeeCertificate != null
                                              ? Text('PDF sélectionné: ${_employeeCertificate!.path.split('/').last}')
                                              : const Text('Sélectionner PDF'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_employeeCertificate != null) ...[
                                      IconButton(
                                        onPressed: _openCertificate,
                                        icon: const Icon(Icons.visibility),
                                      ),
                                      IconButton(
                                        onPressed: _downloadCertificate,
                                        icon: const Icon(Icons.download),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Dates
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Date de début'),
                                          GestureDetector(
                                            onTap: _selectStartDate,
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Color(0xFF2E7D32)),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(_startDate == null ? 'Sélectionner' : _startDate!.toLocal().toString().split(' ')[0]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Date de fin'),
                                          GestureDetector(
                                            onTap: _selectEndDate,
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Color(0xFF2E7D32)),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(_endDate == null ? 'Sélectionner' : _endDate!.toLocal().toString().split(' ')[0]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Compte à rebours graphique
                                if (_endDate != null) ...[
                                  LinearProgressIndicator(
                                    value: _getExpirationProgress(),
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(_getExpirationColor()),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Expiration: ${DateTime.now().difference(_endDate!).inDays.abs()} jours',
                                    style: TextStyle(color: _getExpirationColor()),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                // Bouton Créer
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isCreatingEmployee ? null : _createEmployee,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: _isCreatingEmployee
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text('Créer Employé', style: TextStyle(color: Colors.white, fontSize: 16)),
                                  ),
                                ),
                                if (_createdEmployee != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50).withAlpha((0.1 * 255).round()),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('Employé créé: ${_createdEmployee!['name']}'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        ], // Fin de la section création employé (admin)
                        const SizedBox(height: 16),
                        
                        // Section Affichage Employés (Admin uniquement)  
                        if (_isAdmin) ...[
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Employés Créés',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_isLoadingEmployees)
                                  const Center(child: CircularProgressIndicator())
                                else if (_employees.isEmpty)
                                  const Text('Aucun employé créé')
                                else
                                  SizedBox(
                                    height: 300,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _employees.length,
                                      itemBuilder: (context, index) {
                                        final employee = _employees[index];
                                        final endDate = DateTime.parse(employee['endDate']);
                                        final diff = endDate.difference(DateTime.now()).inDays;
                                        final color = diff > 30 ? Colors.blue : diff > 7 ? Colors.orange : Colors.red;
                                        return MouseRegion(
                                          onEnter: (_) => setState(() => _hoveredIndex = index),
                                          onExit: (_) => setState(() => _hoveredIndex = -1),
                                          child: GestureDetector(
                                            onTap: () => _showEmployeeDetails(employee),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              transform: _hoveredIndex == index
                                                  ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
                                                  : Matrix4.identity(),
                                              width: 200,
                                              margin: const EdgeInsets.only(right: 16),
                                              child: Card(
                                                elevation: 4,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Column(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 30,
                                                        backgroundImage: MemoryImage(base64Decode(employee['photo'])),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(employee['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                                      Text(employee['position']),
                                                      Text(employee['email']),
                                                      Text('Début: ${DateTime.parse(employee['startDate']).toLocal().toString().split(' ')[0]}'),
                                                      Text('Fin: ${DateTime.parse(employee['endDate']).toLocal().toString().split(' ')[0]}'),
                                                      Text('$diff jours restants', style: TextStyle(color: color)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        ], // Fin de la section affichage employés (admin)
                        const SizedBox(height: 16),

                        // Section Administration (visible uniquement pour l'admin)
                        if (_isAdmin) ...[
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.admin_panel_settings, 
                                           color: Color(0xFF2E7D32), size: 28),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Administration',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.star, size: 16, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text(
                                              'ADMIN',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.amber.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Text(
                                      'En tant qu\'administrateur, vous avez accès à toutes les fonctionnalités de l\'application et pouvez gérer les utilisateurs, leurs permissions et leurs accès.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1B5E20),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const AdminUsersPage(),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.people_alt),
                                          label: const Text('Gérer les Utilisateurs'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2E7D32),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Fonctionnalité à venir : Logs système'),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.list_alt),
                                          label: const Text('Logs Système'),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF2E7D32)),
                                            foregroundColor: const Color(0xFF2E7D32),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Fonctionnalité à venir : Statistiques'),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.analytics),
                                          label: const Text('Statistiques'),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF2E7D32)),
                                            foregroundColor: const Color(0xFF2E7D32),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Section Blog Entreprise
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.article, color: Color(0xFF2E7D32), size: 28),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Blog & Actualités Entreprise',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D32).withAlpha(26),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF2E7D32).withAlpha(77),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'Partagez les actualités et informations importantes de votre entreprise avec vos employés. '
                                    'Créez des articles avec du contenu riche (texte, images, liens) pour tenir votre équipe informée.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF1B5E20),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const BlogListPage(),
                                          ),
                                        ),
                                        icon: const Icon(Icons.view_list, size: 20),
                                        label: const Text('Voir tous les articles'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2E7D32),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const BlogEditorPage(),
                                          ),
                                        ),
                                        icon: const Icon(Icons.add, size: 20),
                                        label: const Text('Nouvel article'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF388E3C),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Bouton suppression (rouge pour contraste)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isUpdating ? null : _deleteAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Supprimer le Compte', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _employeeNameController.dispose();
    _employeePositionController.dispose();
    _employeeEmailController.dispose();
    super.dispose();
  }
}