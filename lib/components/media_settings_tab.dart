import 'package:flutter/material.dart';

class MediaSettingsTab extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  const MediaSettingsTab({
    super.key,
    required this.isLoading,
    this.error,
    required this.onRefresh,
  });

  @override
  State<MediaSettingsTab> createState() => _MediaSettingsTabState();
}

class _MediaSettingsTabState extends State<MediaSettingsTab> {
  // Paramètres de vue
  bool _autoPlayVideos = true;
  bool _showMetadata = true;
  bool _enableThumbnails = true;
  bool _highQualityThumbnails = false;
  
  // Paramètres de cache
  bool _enableCache = true;
  int _cacheSize = 100; // MB
  bool _autoCleanCache = true;
  
  // Paramètres d'upload
  int _maxFileSize = 50; // MB
  bool _compressImages = true;
  String _imageQuality = 'high';
  bool _generateThumbnails = true;
  
  // Paramètres de sécurité
  bool _requireAuthentication = false;
  bool _enableWatermark = false;
  bool _logMediaAccess = true;
  
  // Paramètres d'affichage
  String _defaultView = 'gallery';
  int _itemsPerPage = 20;
  String _sortBy = 'date_desc';
  
  @override
  Widget build(BuildContext context) {
    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text('Erreur de chargement des paramètres'),
            const SizedBox(height: 8),
            Text(widget.error!),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          _buildHeader(),
          const SizedBox(height: 24),
          
          // Paramètres d'affichage
          _buildDisplaySettings(),
          const SizedBox(height: 24),
          
          // Paramètres de performance
          _buildPerformanceSettings(),
          const SizedBox(height: 24),
          
          // Paramètres d'upload
          _buildUploadSettings(),
          const SizedBox(height: 24),
          
          // Paramètres de sécurité
          _buildSecuritySettings(),
          const SizedBox(height: 24),
          
          // Actions
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.settings,
                color: Colors.blue,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paramètres de la bibliothèque',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configurez l\'affichage et le comportement des médias',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySettings() {
    return _buildSettingsCard(
      'Affichage',
      Icons.visibility,
      Colors.blue,
      [
        _buildSwitchTile(
          'Lecture automatique des vidéos',
          'Les vidéos commencent automatiquement',
          _autoPlayVideos,
          (value) => setState(() => _autoPlayVideos = value),
          Icons.play_circle,
        ),
        _buildSwitchTile(
          'Afficher les métadonnées',
          'Taille, date, dimensions des fichiers',
          _showMetadata,
          (value) => setState(() => _showMetadata = value),
          Icons.info,
        ),
        _buildSwitchTile(
          'Miniatures activées',
          'Prévisualisation rapide des médias',
          _enableThumbnails,
          (value) => setState(() => _enableThumbnails = value),
          Icons.image,
        ),
        _buildSwitchTile(
          'Miniatures haute qualité',
          'Meilleure qualité mais plus lourd',
          _highQualityThumbnails,
          (value) => setState(() => _highQualityThumbnails = value),
          Icons.high_quality,
          enabled: _enableThumbnails,
        ),
        const Divider(),
        _buildDropdownTile(
          'Vue par défaut',
          'Mode d\'affichage au démarrage',
          _defaultView,
          [
            const DropdownMenuItem(value: 'gallery', child: Text('Galerie')),
            const DropdownMenuItem(value: 'list', child: Text('Liste')),
          ],
          (value) => setState(() => _defaultView = value!),
          Icons.view_module,
        ),
        _buildSliderTile(
          'Éléments par page',
          'Nombre de médias affichés simultanément',
          _itemsPerPage.toDouble(),
          10,
          100,
          5,
          (value) => setState(() => _itemsPerPage = value.round()),
          Icons.grid_view,
          valueFormat: (value) => '${value.round()} éléments',
        ),
        _buildDropdownTile(
          'Tri par défaut',
          'Ordre d\'affichage des médias',
          _sortBy,
          const [
            DropdownMenuItem(value: 'date_desc', child: Text('Plus récents')),
            DropdownMenuItem(value: 'date_asc', child: Text('Plus anciens')),
            DropdownMenuItem(value: 'name_asc', child: Text('Nom A-Z')),
            DropdownMenuItem(value: 'name_desc', child: Text('Nom Z-A')),
            DropdownMenuItem(value: 'size_desc', child: Text('Plus volumineux')),
            DropdownMenuItem(value: 'size_asc', child: Text('Plus légers')),
          ],
          (value) => setState(() => _sortBy = value!),
          Icons.sort,
        ),
      ],
    );
  }

  Widget _buildPerformanceSettings() {
    return _buildSettingsCard(
      'Performance',
      Icons.speed,
      Colors.green,
      [
        _buildSwitchTile(
          'Cache activé',
          'Améliore les performances de chargement',
          _enableCache,
          (value) => setState(() => _enableCache = value),
          Icons.cached,
        ),
        _buildSliderTile(
          'Taille du cache',
          'Espace disque utilisé pour le cache',
          _cacheSize.toDouble(),
          10,
          500,
          10,
          (value) => setState(() => _cacheSize = value.round()),
          Icons.storage,
          valueFormat: (value) => '${value.round()} MB',
          enabled: _enableCache,
        ),
        _buildSwitchTile(
          'Nettoyage automatique',
          'Supprime automatiquement les anciens caches',
          _autoCleanCache,
          (value) => setState(() => _autoCleanCache = value),
          Icons.auto_delete,
          enabled: _enableCache,
        ),
        const Divider(),
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cleaning_services, color: Colors.green, size: 20),
          ),
          title: const Text('Vider le cache'),
          subtitle: const Text('Libère l\'espace disque utilisé'),
          trailing: OutlinedButton(
            onPressed: _enableCache ? _clearCache : null,
            child: const Text('Vider'),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSettings() {
    return _buildSettingsCard(
      'Upload et traitement',
      Icons.cloud_upload,
      Colors.orange,
      [
        _buildSliderTile(
          'Taille maximale des fichiers',
          'Limite d\'upload par fichier',
          _maxFileSize.toDouble(),
          1,
          200,
          1,
          (value) => setState(() => _maxFileSize = value.round()),
          Icons.file_upload,
          valueFormat: (value) => '${value.round()} MB',
        ),
        _buildSwitchTile(
          'Compression des images',
          'Réduit la taille des images uploadées',
          _compressImages,
          (value) => setState(() => _compressImages = value),
          Icons.compress,
        ),
        _buildDropdownTile(
          'Qualité des images',
          'Niveau de compression appliqué',
          _imageQuality,
          const [
            DropdownMenuItem(value: 'low', child: Text('Basse (plus petit)')),
            DropdownMenuItem(value: 'medium', child: Text('Moyenne')),
            DropdownMenuItem(value: 'high', child: Text('Haute (plus gros)')),
          ],
          (value) => setState(() => _imageQuality = value!),
          Icons.tune,
          enabled: _compressImages,
        ),
        _buildSwitchTile(
          'Génération de miniatures',
          'Crée automatiquement des aperçus',
          _generateThumbnails,
          (value) => setState(() => _generateThumbnails = value),
          Icons.photo_size_select_small,
        ),
      ],
    );
  }

  Widget _buildSecuritySettings() {
    return _buildSettingsCard(
      'Sécurité et confidentialité',
      Icons.security,
      Colors.red,
      [
        _buildSwitchTile(
          'Authentification requise',
          'Demande une connexion pour accéder aux médias',
          _requireAuthentication,
          (value) => setState(() => _requireAuthentication = value),
          Icons.lock,
        ),
        _buildSwitchTile(
          'Filigrane sur les images',
          'Ajoute un filigrane sur les images affichées',
          _enableWatermark,
          (value) => setState(() => _enableWatermark = value),
          Icons.image_aspect_ratio,
        ),
        _buildSwitchTile(
          'Journal des accès',
          'Enregistre qui consulte quels médias',
          _logMediaAccess,
          (value) => setState(() => _logMediaAccess = value),
          Icons.history,
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Sauvegarder'),
                ),
                OutlinedButton.icon(
                  onPressed: _resetSettings,
                  icon: const Icon(Icons.restore),
                  label: const Text('Réinitialiser'),
                ),
                OutlinedButton.icon(
                  onPressed: _exportSettings,
                  icon: const Icon(Icons.download),
                  label: const Text('Exporter'),
                ),
                OutlinedButton.icon(
                  onPressed: _importSettings,
                  icon: const Icon(Icons.upload),
                  label: const Text('Importer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon, {
    bool enabled = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (enabled ? Colors.blue : Colors.grey).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.blue : Colors.grey,
          size: 16,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? null : Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDropdownTile<T>(
    String title,
    String subtitle,
    T value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
    IconData icon, {
    bool enabled = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (enabled ? Colors.blue : Colors.grey).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.blue : Colors.grey,
          size: 16,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? null : Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: SizedBox(
        width: 150,
        child: DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(),
          ),
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    double divisions,
    ValueChanged<double> onChanged,
    IconData icon, {
    String Function(double)? valueFormat,
    bool enabled = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (enabled ? Colors.blue : Colors.grey).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: enabled ? Colors.blue : Colors.grey,
              size: 16,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: enabled ? null : Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          trailing: Text(
            valueFormat?.call(value) ?? value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: enabled ? Colors.blue : Colors.grey,
            ),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / divisions).round(),
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }

  void _saveSettings() {
    // Sauvegarder les paramètres
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paramètres sauvegardés avec succès'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser les paramètres'),
        content: const Text(
          'Êtes-vous sûr de vouloir remettre tous les paramètres par défaut ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                // Réinitialiser tous les paramètres
                _autoPlayVideos = true;
                _showMetadata = true;
                _enableThumbnails = true;
                _highQualityThumbnails = false;
                _enableCache = true;
                _cacheSize = 100;
                _autoCleanCache = true;
                _maxFileSize = 50;
                _compressImages = true;
                _imageQuality = 'high';
                _generateThumbnails = true;
                _requireAuthentication = false;
                _enableWatermark = false;
                _logMediaAccess = true;
                _defaultView = 'gallery';
                _itemsPerPage = 20;
                _sortBy = 'date_desc';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Paramètres réinitialisés'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  void _exportSettings() {
    // Exporter les paramètres
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paramètres exportés dans le fichier de téléchargement'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _importSettings() {
    // Importer les paramètres
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonction d\'import à implémenter'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le cache'),
        content: const Text(
          'Cette action va supprimer tous les fichiers en cache. Continuer ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache vidé avec succès'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }
}