// Test script pour les APIs média
// Usage: node test_media_api.js

const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://127.0.0.1:5000';
let authToken = '';

// Configuration de test
const testUser = {
  email: 'test@example.com'
};

// Fonctions utilitaires
const log = (message) => console.log(`[TEST] ${message}`);
const error = (message) => console.error(`[ERROR] ${message}`);

// Test de connexion et récupération du token
async function authenticate() {
  try {
    log('Tentative de connexion...');
    
    // Essayer de se connecter (si l'utilisateur existe déjà)
    const loginResponse = await axios.post(`${BASE_URL}/api/login`, {
      email: testUser.email
    });
    
    if (loginResponse.data.message === 'OTP sent to email') {
      error('Utilisateur existe, mais OTP requis. Utilisez l\'interface web pour vous connecter.');
      return false;
    }
    
  } catch (err) {
    if (err.response?.data?.error === 'User not found') {
      log('Utilisateur non trouvé, création d\'un nouveau compte...');
      
      try {
        // Créer un nouveau compte
        await axios.post(`${BASE_URL}/api/register`, {
          email: testUser.email
        });
        
        error('Compte créé, mais OTP requis. Utilisez l\'interface web pour vérifier et vous connecter.');
        return false;
      } catch (regErr) {
        error(`Erreur lors de la création du compte: ${regErr.response?.data?.error || regErr.message}`);
        return false;
      }
    } else {
      error(`Erreur de connexion: ${err.response?.data?.error || err.message}`);
      return false;
    }
  }
}

// Test des APIs media
async function testMediaAPIs() {
  if (!authToken) {
    log('Aucun token d\'authentification disponible. Tests des APIs authentifiées ignorés.');
    return;
  }

  const headers = { Authorization: `Bearer ${authToken}` };

  try {
    // Test 1: Récupérer tous les médias
    log('Test 1: Récupération de tous les médias...');
    const mediaResponse = await axios.get(`${BASE_URL}/api/media`, { headers });
    log(`✅ ${mediaResponse.data.medias.length} médias trouvés`);

    // Test 2: Statistiques des médias
    log('Test 2: Récupération des statistiques...');
    const statsResponse = await axios.get(`${BASE_URL}/api/media/stats`, { headers });
    log(`✅ Statistiques: ${statsResponse.data.totalMedias} médias, ${Math.round(statsResponse.data.totalSize / 1024)}KB total`);

    // Test 3: Récupérer les tags
    log('Test 3: Récupération des tags...');
    const tagsResponse = await axios.get(`${BASE_URL}/api/media/tags`, { headers });
    log(`✅ ${tagsResponse.data.tags.length} tags uniques trouvés`);

    // Test 4: Recherche de médias
    log('Test 4: Recherche de médias...');
    const searchResponse = await axios.get(`${BASE_URL}/api/media/search?q=test&type=image`, { headers });
    log(`✅ ${searchResponse.data.medias.length} résultats de recherche`);

    // Test 5: Upload d'un fichier de test (si disponible)
    const testImagePath = path.join(__dirname, 'test-image.png');
    if (fs.existsSync(testImagePath)) {
      log('Test 5: Upload d\'un fichier de test...');
      
      const formData = new FormData();
      formData.append('files', fs.createReadStream(testImagePath));
      formData.append('titles', 'Image de test');
      formData.append('descriptions', 'Description de test');
      formData.append('tags', 'test,api,upload');

      const uploadResponse = await axios.post(`${BASE_URL}/api/media/upload`, formData, {
        headers: {
          ...headers,
          ...formData.getHeaders()
        }
      });
      
      log(`✅ Fichier uploadé: ${uploadResponse.data.medias[0].url}`);
      
      // Test 6: Marquer comme utilisé
      const mediaId = uploadResponse.data.medias[0]._id;
      await axios.post(`${BASE_URL}/api/media/${mediaId}/use`, {}, { headers });
      log(`✅ Utilisation enregistrée pour le média ${mediaId}`);
      
    } else {
      log('Test 5: Aucun fichier de test trouvé, création d\'un fichier PNG simple...');
      
      // Créer un petit fichier PNG de test (1x1 pixel transparent)
      const pngBuffer = Buffer.from([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0xDA, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);
      
      const formData = new FormData();
      formData.append('files', pngBuffer, {
        filename: 'test-api.png',
        contentType: 'image/png'
      });
      formData.append('titles', 'PNG de test API');
      formData.append('descriptions', 'Fichier PNG créé pour tester l\'API');
      formData.append('tags', 'test,api,png,auto-generated');

      const uploadResponse = await axios.post(`${BASE_URL}/api/media/upload`, formData, {
        headers: {
          ...headers,
          ...formData.getHeaders()
        }
      });
      
      log(`✅ PNG de test uploadé: ${uploadResponse.data.medias[0].url}`);
      log(`✅ Type détecté: ${uploadResponse.data.medias[0].type}`);
    }

  } catch (err) {
    error(`Erreur lors des tests API: ${err.response?.data?.error || err.message}`);
    if (err.response?.data) {
      console.error('Détails de l\'erreur:', err.response.data);
    }
  }
}

// Test de connexion simple au serveur
async function testServerConnection() {
  try {
    log('Test de connexion au serveur...');
    const response = await axios.get(`${BASE_URL}/api/blog/stats`, {
      headers: { Authorization: 'Bearer invalid-token' }
    });
  } catch (err) {
    if (err.response?.status === 401) {
      log('✅ Serveur accessible (erreur d\'authentification attendue)');
      return true;
    } else {
      error(`Serveur inaccessible: ${err.message}`);
      return false;
    }
  }
}

// Test des APIs publiques (sans authentification)
async function testPublicAPIs() {
  try {
    log('Test des endpoints publics...');
    
    // Test de la route d'inscription (devrait échouer sans email)
    try {
      await axios.post(`${BASE_URL}/api/register`, {});
    } catch (err) {
      if (err.response?.data?.error === 'Email required') {
        log('✅ Route d\'inscription fonctionne (validation d\'email OK)');
      }
    }
    
    // Test de la route de connexion (devrait échouer sans email)
    try {
      await axios.post(`${BASE_URL}/api/login`, {});
    } catch (err) {
      if (err.response?.data?.error === 'Email required') {
        log('✅ Route de connexion fonctionne (validation d\'email OK)');
      }
    }
    
  } catch (err) {
    error(`Erreur lors des tests publics: ${err.message}`);
  }
}

// Fonction principale
async function runTests() {
  log('🚀 Démarrage des tests API Media...');
  
  // Test 1: Connexion serveur
  const serverOK = await testServerConnection();
  if (!serverOK) {
    error('Impossible de se connecter au serveur. Vérifiez qu\'il fonctionne sur le port 5000.');
    return;
  }
  
  // Test 2: APIs publiques
  await testPublicAPIs();
  
  // Test 3: Authentification
  const authOK = await authenticate();
  if (authOK) {
    await testMediaAPIs();
  } else {
    log('Tests d\'authentification ignorés. Utilisez l\'interface web pour vous connecter et obtenez un token.');
  }
  
  log('✅ Tests terminés !');
}

// Exécuter les tests si ce script est appelé directement
if (require.main === module) {
  runTests().catch(err => {
    error(`Erreur fatale: ${err.message}`);
    process.exit(1);
  });
}

module.exports = {
  runTests,
  testMediaAPIs,
  testServerConnection,
  testPublicAPIs
};