const fs = require('fs');
const path = require('path');

// Créer le dossier uploads s'il n'existe pas
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir);
}

// Créer quelques fichiers de test (vides) pour la démonstration
const testFiles = [
  'files-001.png',
  'files-002.jpg',
  'files-003.mp4',
  'files-004.pdf',
  'files-005.wav'
];

testFiles.forEach(filename => {
  const filepath = path.join(uploadsDir, filename);
  if (!fs.existsSync(filepath)) {
    // Créer un petit fichier de test avec quelques octets
    const content = `Test file: ${filename}\nCreated: ${new Date().toISOString()}`;
    fs.writeFileSync(filepath, content);
    console.log(`✓ Created test file: ${filename}`);
  } else {
    console.log(`- File already exists: ${filename}`);
  }
});

console.log('\n🎉 Test files ready for media library!');
console.log('You can now test the HTML5 media viewer with these files.');