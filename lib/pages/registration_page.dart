import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../session_service.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  RegistrationPageState createState() => RegistrationPageState();
}

class RegistrationPageState extends State<RegistrationPage>
    with SingleTickerProviderStateMixin { // Ajout pour animation
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isRegisterMode = true; // true: inscription, false: connexion
  bool _isOtpStep = false;
  bool _isLoading = false;
  bool _isSendingEmail = false;
  String? _currentEmail;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward(); // Démarre l'animation d'entrée
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Bouton de nettoyage d'urgence
          IconButton(
            onPressed: _clearAllDataAndRestart,
            icon: const Icon(Icons.cleaning_services, color: Colors.white),
            tooltip: 'Nettoyer toutes les données (urgence)',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF667eea), // Bleu moderne
              Color(0xFF764ba2), // Violet puissant
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: AnimatedBuilder( // Animation fade-in pour modernité
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: 1.0 + (_fadeAnimation.value * 0.02), // Léger zoom d'entrée
                      child: Card(
                        elevation: 20 + (_fadeAnimation.value * 5), // Ombre dynamique
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Container( // Gradient interne pour profondeur
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white.withValues(alpha: 0.95),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Icône animée
                                Hero(
                                  tag: 'auth_icon',
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF667eea).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.lock_outline,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Titre dynamique avec style moderne
                                Text(
                                  _isRegisterMode ? 'Inscription' : 'Connexion',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2c3e50), // Gris foncé pour contraste
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isOtpStep
                                      ? 'Vérifiez votre code OTP'
                                      : _isRegisterMode
                                          ? 'Créez votre compte'
                                          : 'Accédez à votre compte',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Formulaire
                                if (!_isOtpStep) ...[
                                  // Email Field moderne
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF667eea)),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.9),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF667eea),
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Bouton principal avec effet
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleEmailSubmit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF667eea),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 8,
                                        shadowColor: const Color(0xFF764ba2).withValues(alpha: 0.3),
                                      ),
                                      child: _isLoading
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _isSendingEmail 
                                                    ? 'Envoi email...'
                                                    : 'Traitement...',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              _isRegisterMode ? 'S\'inscrire' : 'Se connecter',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Toggle mode avec icône
                                  TextButton.icon(
                                    onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
                                    icon: const Icon(Icons.swap_horiz, size: 20, color: Color(0xFF667eea)),
                                    label: Text(
                                      _isRegisterMode
                                          ? 'Déjà un compte ? Connexion'
                                          : 'Pas de compte ? Inscription',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  // OTP Field moderne
                                  TextField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    decoration: InputDecoration(
                                      labelText: 'Code OTP (envoyé par email)',
                                      prefixIcon: const Icon(Icons.verified_outlined, color: Color(0xFF27ae60)),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.9),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF27ae60),
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Bouton vérification
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleOtpSubmit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF27ae60), // Vert pour succès
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 8,
                                        shadowColor: Colors.green.withValues(alpha: 0.3),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Vérifier OTP',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Bouton retour
                                      TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _isOtpStep = false;
                                            _otpController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.arrow_back, size: 16, color: Color(0xFF667eea)),
                                        label: const Text(
                                          'Retour',
                                          style: TextStyle(
                                            color: Color(0xFF667eea),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      // Lien renvoi avec couleur accent
                                      TextButton(
                                        onPressed: _handleEmailSubmit, // Ré-envoi
                                        child: const Text(
                                          'Renvoyer le code',
                                          style: TextStyle(
                                            color: Color(0xFF667eea),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }

  Future<void> _handleEmailSubmit() async {
    if (_emailController.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _isSendingEmail = true;
    });
    
    try {
      debugPrint('Sending email: ${_emailController.text}');
      debugPrint('Mode: ${_isRegisterMode ? "Register" : "Login"}');
      
      // Petite pause pour permettre à l'UI de se mettre à jour
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (_isRegisterMode) {
        await _authService.register(_emailController.text);
      } else {
        await _authService.login(_emailController.text);
      }
      
      debugPrint('Email sent successfully, switching to OTP step');
      
      if (!mounted) return;
      setState(() {
        _isOtpStep = true;
        _currentEmail = _emailController.text;
        _isLoading = false;
        _isSendingEmail = false;
      });
      
      // Affichage d'un message de succès
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[400],
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Code OTP envoyé par email')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending email: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSendingEmail = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[400],
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(e.toString())),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _handleOtpSubmit() async {
    if (_otpController.text.isEmpty || _currentEmail == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      debugPrint('Verifying OTP: ${_otpController.text} for email: $_currentEmail');
      
      AuthTokens tokens;
      if (_isRegisterMode) {
        tokens = await _authService.verifyOtpForRegister(_currentEmail!, _otpController.text);
      } else {
        tokens = await _authService.verifyOtpForLogin(_currentEmail!, _otpController.text);
      }
      await AuthService.saveTokens(tokens.token, tokens.refreshToken);
      
      // Démarrer la session après une connexion réussie
      await SessionService.startSession();
      
      debugPrint('OTP verification successful, navigating to dashboard');
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[400],
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(e.toString())),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  /// Méthode d'urgence pour nettoyer toutes les données utilisateur
  Future<void> _clearAllDataAndRestart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Nettoyage d\'urgence'),
          ],
        ),
        content: const Text(
          'Cette action va supprimer TOUTES les données stockées localement '
          '(sessions, cache, tokens). Vous devrez vous reconnecter.\n\n'
          'Continuer ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Nettoyer tout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Nettoyage TOTAL des données
        await SessionService.clearAllUserData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Données nettoyées ! Vous pouvez maintenant vous connecter.'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          // Réinitialiser l'état de la page
          setState(() {
            _isRegisterMode = true;
            _isOtpStep = false;
            _isLoading = false;
            _isSendingEmail = false;
            _currentEmail = null;
            _emailController.clear();
            _otpController.clear();
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors du nettoyage: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}