const express = require('express');
const cors = require('cors');

const app = express();
const PORT = 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Mock data pour tester
const mockArticles = [
  {
    _id: '1',
    title: 'Article de test 1',
    content: 'Contenu de l\'article de test 1',
    summary: 'Résumé de l\'article 1',
    tags: ['test', 'article'],
    createdAt: new Date().toISOString(),
    author: {
      _id: 'user1',
      name: 'Auteur Test',
      email: 'auteur@test.com',
      role: 'user'
    },
    published: true,
    likesCount: 5,
    commentsCount: 2,
    viewsCount: 100
  },
  {
    _id: '2',
    title: 'Article de test 2',
    content: 'Contenu de l\'article de test 2',
    summary: 'Résumé de l\'article 2',
    tags: ['flutter', 'mobile'],
    createdAt: new Date(Date.now() - 86400000).toISOString(), // Hier
    author: {
      _id: 'user2',
      name: 'Développeur Mobile',
      email: 'dev@test.com',
      role: 'admin'
    },
    published: true,
    likesCount: 12,
    commentsCount: 8,
    viewsCount: 250
  }
];

const mockMedias = [
  {
    _id: 'm1',
    title: 'Image de test',
    description: 'Une belle image de test',
    url: 'https://picsum.photos/400/300',
    mimetype: 'image/jpeg',
    tags: ['image', 'test'],
    createdAt: new Date().toISOString(),
    uploadedBy: {
      _id: 'user1',
      name: 'Photographe Test',
      email: 'photo@test.com',
      role: 'user'
    },
    isPublic: true,
    usageCount: 15
  },
  {
    _id: 'm2',
    title: 'Vidéo exemple',
    description: 'Vidéo de démonstration',
    url: 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4',
    mimetype: 'video/mp4',
    tags: ['video', 'demo'],
    createdAt: new Date(Date.now() - 43200000).toISOString(), // Il y a 12h
    uploadedBy: {
      _id: 'user2',
      name: 'Vidéaste Pro',
      email: 'video@test.com',
      role: 'user'
    },
    isPublic: true,
    usageCount: 8
  }
];

// Endpoints publics (sans authentification)

// GET /api/public/articles : Récupérer les articles publiés (public)
app.get('/api/public/articles', (req, res) => {
  try {
    const { limit = 20, page = 1, search } = req.query;
    
    console.log(`📖 Public articles request: page=${page}, limit=${limit}, search="${search || 'none'}"`);
    
    const limitNum = parseInt(limit);
    const pageNum = parseInt(page);
    
    let filteredArticles = mockArticles.filter(article => article.published);
    
    // Ajouter la recherche si fournie
    if (search && search.trim().length > 0) {
      const searchLower = search.toLowerCase();
      filteredArticles = filteredArticles.filter(article =>
        article.title.toLowerCase().includes(searchLower) ||
        article.summary.toLowerCase().includes(searchLower) ||
        article.content.toLowerCase().includes(searchLower) ||
        article.tags.some(tag => tag.toLowerCase().includes(searchLower))
      );
    }
    
    const total = filteredArticles.length;
    const startIndex = (pageNum - 1) * limitNum;
    const articles = filteredArticles.slice(startIndex, startIndex + limitNum);
    
    console.log(`✅ Public articles: ${articles.length} found, ${total} total`);
    
    res.json({
      articles,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum),
        hasMore: (pageNum * limitNum) < total
      },
      stats: {
        total: articles.length,
        totalAvailable: total
      }
    });
  } catch (err) {
    console.error('❌ Public articles error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/public/medias : Récupérer les médias publics
app.get('/api/public/medias', (req, res) => {
  try {
    const { limit = 20, page = 1, type, search } = req.query;
    
    console.log(`🖼️ Public medias request: page=${page}, limit=${limit}, type=${type || 'all'}, search="${search || 'none'}"`);
    
    const limitNum = parseInt(limit);
    const pageNum = parseInt(page);
    
    let filteredMedias = mockMedias.filter(media => media.isPublic);
    
    // Ajouter le filtre de type si spécifié
    if (type && type !== 'all') {
      filteredMedias = filteredMedias.filter(media => media.mimetype.startsWith(type + '/'));
    }
    
    // Ajouter la recherche si fournie
    if (search && search.trim().length > 0) {
      const searchLower = search.toLowerCase();
      filteredMedias = filteredMedias.filter(media =>
        media.title.toLowerCase().includes(searchLower) ||
        (media.description && media.description.toLowerCase().includes(searchLower)) ||
        media.tags.some(tag => tag.toLowerCase().includes(searchLower))
      );
    }
    
    const total = filteredMedias.length;
    const startIndex = (pageNum - 1) * limitNum;
    const medias = filteredMedias.slice(startIndex, startIndex + limitNum);
    
    console.log(`✅ Public medias: ${medias.length} found, ${total} total`);
    
    res.json({
      medias,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum),
        hasMore: (pageNum * limitNum) < total
      },
      stats: {
        total: medias.length,
        totalAvailable: total,
        byType: mockMedias.reduce((acc, media) => {
          const type = media.mimetype.split('/')[0];
          acc[type] = (acc[type] || 0) + 1;
          return acc;
        }, {})
      }
    });
  } catch (err) {
    console.error('❌ Public medias error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/public/feed : Feed public combiné (articles + médias)
app.get('/api/public/feed', (req, res) => {
  try {
    const { limit = 20, page = 1, search } = req.query;
    
    console.log(`🌐 Public feed request: page=${page}, limit=${limit}, search="${search || 'none'}"`);
    
    const limitNum = parseInt(limit);
    const pageNum = parseInt(page);
    
    // Construire les filtres de recherche
    let feedItems = [];
    
    // Ajouter les articles
    const articles = mockArticles.filter(article => article.published);
    articles.forEach(article => {
      feedItems.push({
        ...article,
        feedType: 'article',
        author: article.author
      });
    });
    
    // Ajouter les médias
    const medias = mockMedias.filter(media => media.isPublic);
    medias.forEach(media => {
      feedItems.push({
        ...media,
        feedType: 'media',
        author: media.uploadedBy
      });
    });
    
    // Filtrer par recherche si nécessaire
    if (search && search.trim().length > 0) {
      const searchLower = search.toLowerCase();
      feedItems = feedItems.filter(item =>
        item.title.toLowerCase().includes(searchLower) ||
        (item.summary && item.summary.toLowerCase().includes(searchLower)) ||
        (item.description && item.description.toLowerCase().includes(searchLower)) ||
        (item.content && item.content.toLowerCase().includes(searchLower)) ||
        item.tags.some(tag => tag.toLowerCase().includes(searchLower))
      );
    }
    
    // Trier par date de création (plus récent en premier)
    feedItems.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    
    // Paginer les résultats combinés
    const total = feedItems.length;
    const startIndex = (pageNum - 1) * limitNum;
    const paginatedItems = feedItems.slice(startIndex, startIndex + limitNum);
    
    const articlesCount = paginatedItems.filter(item => item.feedType === 'article').length;
    const mediasCount = paginatedItems.filter(item => item.feedType === 'media').length;
    
    console.log(`✅ Public feed: ${articlesCount} articles + ${mediasCount} medias = ${paginatedItems.length} items`);
    
    res.json({
      feed: paginatedItems,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum),
        hasMore: (pageNum * limitNum) < total
      },
      stats: {
        articles: articlesCount,
        medias: mediasCount,
        total: paginatedItems.length
      }
    });
    
  } catch (err) {
    console.error('❌ Public feed error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Endpoint de test de santé
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    message: 'Serveur de test public en fonctionnement'
  });
});

// Démarrage du serveur
app.listen(PORT, () => {
  console.log(`🚀 Serveur de test démarré sur le port ${PORT}`);
  console.log(`📖 Endpoints disponibles:`);
  console.log(`   - GET http://localhost:${PORT}/api/health`);
  console.log(`   - GET http://localhost:${PORT}/api/public/articles`);
  console.log(`   - GET http://localhost:${PORT}/api/public/medias`);
  console.log(`   - GET http://localhost:${PORT}/api/public/feed`);
  console.log(`✅ Prêt à recevoir les requêtes du dashboard Flutter!`);
});

// Gestion gracieuse de l'arrêt
process.on('SIGINT', () => {
  console.log('\n👋 Arrêt du serveur de test...');
  process.exit(0);
});