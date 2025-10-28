import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  // ignore: avoid_print
  print('🎨 Création du logo avec marges pour icônes...');
  
  // Charger le logo original
  final originalFile = File('LOGO VECTORISE PNG.png');
  if (!await originalFile.exists()) {
    // ignore: avoid_print
    print('❌ Fichier logo non trouvé: LOGO VECTORISE PNG.png');
    return;
  }
  
  final bytes = await originalFile.readAsBytes();
  final original = img.decodeImage(bytes);
  
  if (original == null) {
    // ignore: avoid_print
    print('❌ Impossible de décoder l\'image');
    return;
  }
  
  // ignore: avoid_print
  print('📐 Taille originale: ${original.width}x${original.height}');
  
  // Calculer la nouvelle taille avec 20% de marge de chaque côté
  // Pour les icônes circulaires, on a besoin d'au moins 20% de marge
  final margin = (original.width * 0.25).round(); // 25% de marge
  final newSize = original.width + (margin * 2);
  
  // ignore: avoid_print
  print('📐 Nouvelle taille avec marges: $newSize x $newSize');
  
  // Créer une nouvelle image avec fond blanc
  final newImage = img.Image(width: newSize, height: newSize);
  
  // Remplir avec du blanc
  img.fill(newImage, color: img.ColorRgb8(255, 255, 255));
  
  // Copier le logo original au centre
  img.compositeImage(
    newImage,
    original,
    dstX: margin,
    dstY: margin,
  );
  
  // Sauvegarder la nouvelle image
  final output = File('logo_with_padding.png');
  await output.writeAsBytes(img.encodePng(newImage));
  
  // ignore: avoid_print
  print('✅ Logo avec marges créé: logo_with_padding.png');
  // ignore: avoid_print
  print('   Vous pouvez maintenant l\'utiliser dans flutter_launcher_icons.yaml');
}
