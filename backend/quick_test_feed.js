// quick_test_feed.js
const axios = require('axios');

const BASE_URL = 'http://localhost:5000';

// Token d'exemple (vous devrez le remplacer par un vrai token)
const TEST_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiI2OGZlODBhNjhlZDE1M2M4ZWU4NGQxNzIiLCJlbWFpbCI6Im55dW5kdW1hdGhyeW1lQGdtYWlsLmNvbSIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTczNTA0MTc4MiwiZXhwIjoxNzM1MTI4MTgyfQ';

async function quickTestFeed() {
    try {
        console.log('🌟 Test du mur social unifié\n');

        // Test du feed social complet
        console.log('📡 Test GET /api/feed/social...');
        const socialResponse = await axios.get(`${BASE_URL}/api/feed/social?page=1&limit=10`, {
            headers: {
                'Authorization': `Bearer ${TEST_TOKEN}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('✅ Status:', socialResponse.status);
        console.log('📊 Feed items count:', socialResponse.data.feed?.length || 0);
        console.log('👥 Sample data:', JSON.stringify(socialResponse.data.feed?.slice(0, 1) || [], null, 2));
        
    } catch (error) {
        if (error.response) {
            console.log('❌ Erreur HTTP:', error.response.status, error.response.data);
        } else {
            console.log('❌ Erreur réseau:', error.message);
        }
    }

    try {
        // Test du feed média
        console.log('\n📸 Test GET /api/media/feed...');
        const mediaResponse = await axios.get(`${BASE_URL}/api/media/feed?page=1&limit=10`, {
            headers: {
                'Authorization': `Bearer ${TEST_TOKEN}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('✅ Status:', mediaResponse.status);
        console.log('📊 Media items count:', mediaResponse.data.medias?.length || 0);
        console.log('🎨 Sample data:', JSON.stringify(mediaResponse.data.medias?.slice(0, 1) || [], null, 2));
        
    } catch (error) {
        if (error.response) {
            console.log('❌ Erreur HTTP:', error.response.status, error.response.data);
        } else {
            console.log('❌ Erreur réseau:', error.message);
        }
    }

    try {
        // Test simple sans authentification pour vérifier si le serveur répond
        console.log('\n🏥 Test sanité serveur...');
        const healthResponse = await axios.get(`${BASE_URL}/api/health`);
        console.log('✅ Serveur accessible:', healthResponse.status);
        
    } catch (error) {
        // Test alternative
        try {
            const altResponse = await axios.get(`${BASE_URL}/`);
            console.log('✅ Serveur accessible (route racine):', altResponse.status);
        } catch (altError) {
            console.log('❌ Serveur inaccessible');
        }
    }
}

console.log('🚀 Démarrage des tests...\n');
quickTestFeed();