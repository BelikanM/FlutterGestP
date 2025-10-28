import 'package:flutter/material.dart';
import '../widgets/background_pattern.dart';

class PatternTestPage extends StatefulWidget {
  const PatternTestPage({super.key});

  @override
  State<PatternTestPage> createState() => _PatternTestPageState();
}

class _PatternTestPageState extends State<PatternTestPage> {
  CSSPatternType _currentPattern = CSSPatternType.whatsappDots;
  bool _useAnimated = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test des Motifs de Fond'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: _useAnimated 
        ? AnimatedBackgroundPattern(
            backgroundColor: const Color(0xFF121212),
            child: _buildContent(),
          )
        : CSSBackgroundPattern(
            backgroundColor: const Color(0xFF121212),
            patternType: _currentPattern,
            child: _buildContent(),
          ),
    );
  }

  Widget _buildContent() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.8),
      ),
      child: Column(
        children: [
          // Contrôles des motifs
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white.withValues(alpha: 0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sélectionnez un motif :',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Switch pour animation
                Row(
                  children: [
                    Switch(
                      value: _useAnimated,
                      onChanged: (value) {
                        setState(() {
                          _useAnimated = value;
                        });
                      },
                      activeTrackColor: const Color(0xFF2E7D32),
                      activeThumbColor: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    const Text('Motif animé'),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Sélecteur de motifs (si pas animé)
                if (!_useAnimated) ...[
                  const Text('Type de motif :'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: CSSPatternType.values.map((pattern) {
                      return ChoiceChip(
                        label: Text(_getPatternName(pattern)),
                        selected: _currentPattern == pattern,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _currentPattern = pattern;
                            });
                          }
                        },
                        selectedColor: const Color(0xFF2E7D32),
                        labelStyle: TextStyle(
                          color: _currentPattern == pattern 
                            ? Colors.white 
                            : Colors.black87,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          
          // Zone de démonstration
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Motif Actuel : ${_useAnimated ? "Animé" : _getPatternName(_currentPattern)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getPatternDescription(_currentPattern),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Cartes de démonstration
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        _buildDemoCard('Card 1', 'Contenu d\'exemple', Colors.blue),
                        _buildDemoCard('Card 2', 'Interface utilisateur', Colors.green),
                        _buildDemoCard('Card 3', 'Design moderne', Colors.orange),
                        _buildDemoCard('Card 4', 'Expérience fluide', Colors.purple),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoCard(String title, String content, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withValues(alpha: 0.1),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              content,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _getPatternName(CSSPatternType pattern) {
    switch (pattern) {
      case CSSPatternType.whatsappDots:
        return 'WhatsApp Dots';
      case CSSPatternType.subtleDots:
        return 'Dots Subtils';
      case CSSPatternType.gridLines:
        return 'Grille';
      case CSSPatternType.diagonalLines:
        return 'Lignes Diagonales';
    }
  }

  String _getPatternDescription(CSSPatternType pattern) {
    switch (pattern) {
      case CSSPatternType.whatsappDots:
        return 'Points décalés inspirés de WhatsApp. Parfait pour les interfaces de chat et messaging.';
      case CSSPatternType.subtleDots:
        return 'Points réguliers très discrets. Idéal pour les pages d\'information et formulaires.';
      case CSSPatternType.gridLines:
        return 'Grille de lignes fines. Excellent pour les applications de design et média.';
      case CSSPatternType.diagonalLines:
        return 'Lignes diagonales modernes. Parfait pour les dashboards et pages d\'accueil.';
    }
  }
}