// test_social_feed.js
const axios = require('axios');

const BASE_URL = 'http://localhost:5000';

async function testSocialFeed() {
    try {
        console.log('🔍 Test du feed social...\n');

        // Test de récupération du feed social sans authentification
        console.log('📡 Test GET /api/feed/social...');
        const response = await axios.get(`${BASE_URL}/api/feed/social`);
        
        console.log('✅ Status:', response.status);
        console.log('📊 Data:', JSON.stringify(response.data, null, 2));
        
    } catch (error) {
        console.log('❌ Erreur:', error.response?.status, error.response?.data || error.message);
    }

    try {
        // Test de récupération du feed média
        console.log('\n📡 Test GET /api/media/feed...');
        const response = await axios.get(`${BASE_URL}/api/media/feed`);
        
        console.log('✅ Status:', response.status);
        console.log('📊 Data:', JSON.stringify(response.data, null, 2));
        
    } catch (error) {
        console.log('❌ Erreur:', error.response?.status, error.response?.data || error.message);
    }
}

testSocialFeed();