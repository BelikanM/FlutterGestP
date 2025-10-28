// session_status_widget.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../session_service.dart';

class SessionStatusWidget extends StatefulWidget {
  const SessionStatusWidget({super.key});

  @override
  SessionStatusWidgetState createState() => SessionStatusWidgetState();
}

class SessionStatusWidgetState extends State<SessionStatusWidget> {
  Timer? _statusTimer;
  bool _isSessionValid = true;
  int _remainingMinutes = 60;

  @override
  void initState() {
    super.initState();
    _startStatusTimer();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusTimer() {
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      await _updateSessionStatus();
    });
    
    // Mise à jour immédiate
    _updateSessionStatus();
  }

  Future<void> _updateSessionStatus() async {
    try {
      final isValid = await SessionService.isSessionValid();
      
      if (mounted) {
        setState(() {
          _isSessionValid = isValid;
          if (isValid) {
            _calculateRemainingTime();
          }
        });
      }
      
      if (!isValid && mounted) {
        Navigator.pushReplacementNamed(context, '/registration');
      }
    } catch (e) {
      // Gérer les erreurs silencieusement
    }
  }

  Future<void> _calculateRemainingTime() async {
    try {
      // Calculer le temps restant basé sur le timestamp de session
      // Cette logique peut être améliorée selon vos besoins
      _remainingMinutes = 60; // Valeur par défaut
    } catch (e) {
      _remainingMinutes = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSessionValid) {
      return const SizedBox.shrink();
    }

    Color statusColor = _remainingMinutes > 15 
        ? Colors.green 
        : _remainingMinutes > 5 
            ? Colors.orange 
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(51), // 0.2 opacity
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            '${_remainingMinutes}min',
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}