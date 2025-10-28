// Script pour créer des données de test dans la base de données
require('dotenv').config();
const mongoose = require('mongoose');

// Connection MongoDB
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log('✅ MongoDB connected'))
  .catch(err => console.error('❌ MongoDB connection error:', err));

// Models (simplified versions)
const userSchema = new mongoose.Schema({
  email: String,
  name: String,
  profilePhoto: String,
  isVerified: { type: Boolean, default: true },
  role: { type: String, default: 'user' },
  status: { type: String, default: 'active' }
}, { timestamps: true });

const articleSchema = new mongoose.Schema({
  title: String,
  content: String,
  summary: String,
  published: { type: Boolean, default: true },
  tags: [String],
  authorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
}, { timestamps: true });

const mediaSchema = new mongoose.Schema({
  title: String,
  description: String,
  filename: String,
  originalName: String,
  url: String,
  mimetype: String,
  size: Number,
  type: String,
  tags: [String],
  uploadedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  isPublic: { type: Boolean, default: true }
}, { timestamps: true });

const User = mongoose.model('User', userSchema);
const Article = mongoose.model('Article', articleSchema);
const Media = mongoose.model('Media', mediaSchema);

// Create test data
const createTestData = async () => {
  try {
    // Clear existing data
    await User.deleteMany({});
    await Article.deleteMany({});
    await Media.deleteMany({});
    
    console.log('🧹 Cleared existing data');
    
    // Create test users
    const users = await User.insertMany([
      {
        email: 'admin@test.com',
        name: 'Administrateur',
        role: 'admin',
        profilePhoto: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=='
      },
      {
        email: 'john@test.com',
        name: 'John Doe',
        role: 'user'
      },
      {
        email: 'jane@test.com',
        name: 'Jane Smith',
        role: 'user'
      }
    ]);
    
    console.log(`✅ Created ${users.length} test users`);
    
    // Create test articles
    const articles = await Article.insertMany([
      {
        title: 'Bienvenue sur notre plateforme sociale',
        content: '<h2>Une nouvelle ère commence</h2><p>Nous sommes ravis de vous présenter notre nouvelle plateforme sociale d\'entreprise. Cette solution innovante vous permettra de partager des idées, collaborer et rester connectés avec vos collègues.</p><h3>Fonctionnalités principales</h3><ul><li>Feed social en temps réel</li><li>Système de likes et commentaires</li><li>Partage de contenu multimédia</li><li>Interaction entre utilisateurs</li></ul>',
        summary: 'Découvrez notre nouvelle plateforme sociale d\'entreprise avec toutes ses fonctionnalités.',
        tags: ['plateforme', 'social', 'entreprise'],
        authorId: users[0]._id,
        published: true
      },
      {
        title: 'Comment utiliser le système de likes ?',
        content: '<h2>Guide d\'utilisation</h2><p>Le système de likes vous permet d\'exprimer votre appréciation pour le contenu partagé par vos collègues.</p><h3>Comment ça marche ?</h3><ol><li>Cliquez sur le bouton "J\'aime" sous une publication</li><li>Votre like est comptabilisé en temps réel</li><li>Vous pouvez retirer votre like en cliquant à nouveau</li></ol><p>C\'est aussi simple que cela !</p>',
        summary: 'Apprenez à utiliser le système de likes pour interagir avec le contenu.',
        tags: ['guide', 'likes', 'interaction'],
        authorId: users[1]._id,
        published: true
      },
      {
        title: 'Les commentaires : restez connectés',
        content: '<h2>Système de commentaires</h2><p>Les commentaires vous permettent d\'engager des discussions constructives autour du contenu partagé.</p><h3>Bonnes pratiques</h3><ul><li>Soyez respectueux dans vos interactions</li><li>Apportez de la valeur à la conversation</li><li>Posez des questions pertinentes</li></ul><blockquote>Un bon commentaire peut transformer une simple publication en discussion riche et productive.</blockquote>',
        summary: 'Découvrez comment utiliser les commentaires pour enrichir vos interactions.',
        tags: ['commentaires', 'discussion', 'collaboration'],
        authorId: users[2]._id,
        published: true
      }
    ]);
    
    console.log(`✅ Created ${articles.length} test articles`);
    
    // Create test media
    const medias = await Media.insertMany([
      {
        title: 'Image de présentation',
        description: 'Une belle image pour illustrer notre plateforme',
        filename: 'presentation.png',
        originalName: 'presentation.png',
        url: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
        mimetype: 'image/png',
        size: 1024,
        type: 'image',
        tags: ['présentation', 'image'],
        uploadedBy: users[0]._id
      },
      {
        title: 'Vidéo tutoriel',
        description: 'Tutoriel vidéo pour bien débuter',
        filename: 'tutorial.mp4',
        originalName: 'tutorial.mp4',
        url: 'data:video/mp4;base64,AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAG1tZGF0',
        mimetype: 'video/mp4',
        size: 2048000,
        type: 'video',
        tags: ['tutoriel', 'vidéo'],
        uploadedBy: users[1]._id
      }
    ]);
    
    console.log(`✅ Created ${medias.length} test medias`);
    
    console.log('\n🎉 Test data created successfully!');
    console.log('Users:', users.map(u => ({ email: u.email, name: u.name, role: u.role })));
    console.log('Articles:', articles.map(a => ({ title: a.title, author: a.authorId })));
    console.log('Medias:', medias.map(m => ({ title: m.title, type: m.type })));
    
  } catch (error) {
    console.error('❌ Error creating test data:', error);
  } finally {
    mongoose.disconnect();
  }
};

createTestData();