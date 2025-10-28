// test_permissions.js
require('dotenv').config();
const mongoose = require('mongoose');

// User Model (même schéma que dans server.js)
const userSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  name: { type: String, default: '' },
  password: { type: String, required: false, default: '' },
  profilePhoto: { type: String, default: '' },
  isVerified: { type: Boolean, default: false },
  role: { type: String, enum: ['user', 'admin'], default: 'user' },
  status: { type: String, enum: ['active', 'blocked', 'suspended'], default: 'active' },
  permissions: {
    canCreateArticles: { type: Boolean, default: false },
    canManageEmployees: { type: Boolean, default: false },
    canAccessMedia: { type: Boolean, default: false },
    canAccessAnalytics: { type: Boolean, default: false }
  },
  otp: { type: String },
  otpExpiry: { type: Date },
  tokens: [{
    token: { type: String },
    refreshToken: { type: String }
  }]
}, { timestamps: true });

const User = mongoose.model('User', userSchema);

async function testAndUpdatePermissions() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Connecté à MongoDB');
    
    // Récupérer tous les utilisateurs
    const users = await User.find({});
    console.log(`📋 Trouvé ${users.length} utilisateurs`);
    
    for (const user of users) {
      console.log(`\n👤 Utilisateur: ${user.email}`);
      console.log(`   Rôle: ${user.role}`);
      console.log(`   Permissions actuelles:`, user.permissions);
      
      // Mettre à jour les permissions si nécessaire
      const isAdmin = user.email === 'nyundumathryme@gmail.com' || user.role === 'admin';
      
      user.permissions = isAdmin ? {
        canCreateArticles: true,
        canManageEmployees: true,
        canAccessMedia: true,
        canAccessAnalytics: true
      } : {
        canCreateArticles: true,  // Accès par défaut pour tous
        canManageEmployees: false,
        canAccessMedia: true,     // Accès par défaut pour tous
        canAccessAnalytics: false
      };
      
      await user.save();
      console.log(`✅ Permissions mises à jour pour: ${user.email}`);
      console.log(`   Nouvelles permissions:`, user.permissions);
    }
    
    console.log('\n🎉 Toutes les permissions ont été mises à jour !');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

testAndUpdatePermissions();