// server.js
require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const cors = require('cors');
const crypto = require('crypto');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const compression = require('compression');
const sharp = require('sharp'); // Pour traitement d'images

// Port from env
const PORT = process.env.PORT || 5000;

// Helper pour générer les URLs dynamiques selon la requête
const getBaseUrl = (req) => {
  const host = req.get('host');
  const protocol = req.protocol;
  
  // Si on vient de l'émulateur Android (10.0.2.2), utiliser cette IP
  if (host && host.includes('10.0.2.2')) {
    return `${protocol}://10.0.2.2:${PORT}`;
  }
  
  // Si on vient de localhost ou 127.0.0.1, utiliser localhost
  if (host && (host.includes('localhost') || host.includes('127.0.0.1'))) {
    return `${protocol}://localhost:${PORT}`;
  }
  
  // Par défaut, utiliser l'host de la requête
  return `${protocol}://${host}`;
};

// Migration automatique pour configurer l'administrateur
const setupAdminUser = async () => {
  try {
    const adminEmail = 'nyundumathryme@gmail.com';
    const adminUser = await User.findOne({ email: adminEmail });
    
    if (adminUser) {
      // Mettre à jour l'utilisateur existant
      adminUser.role = 'admin';
      adminUser.status = 'active';
      adminUser.permissions = {
        canCreateArticles: true,
        canManageEmployees: true,
        canAccessMedia: true,
        canAccessAnalytics: true
      };
      await adminUser.save();
      console.log(`👑 Utilisateur administrateur mis à jour: ${adminEmail}`);
    } else {
      console.log(`ℹ️ Utilisateur administrateur ${adminEmail} n'existe pas encore. Il sera configuré lors de l'inscription.`);
    }
  } catch (error) {
    console.error('❌ Erreur lors de la configuration de l\'administrateur:', error.message);
  }
};
// MongoDB Connection avec optimisations performance
const MONGO_URI = process.env.MONGO_URI;
console.log('🔍 Environment variables check:');
console.log('PORT:', PORT);
console.log('MONGO_URI:', MONGO_URI ? 'Set ✅' : 'Not set ❌');
console.log('JWT_SECRET:', process.env.JWT_SECRET ? 'Set ✅' : 'Not set ❌');

if (!MONGO_URI) {
  console.error('❌ MONGO_URI not found in environment variables');
  process.exit(1);
}

mongoose.connect(MONGO_URI, {
  maxPoolSize: 10, // Limite le nombre de connexions simultanées
  serverSelectionTimeoutMS: 5000, // Timeout pour la sélection du serveur
  socketTimeoutMS: 45000, // Timeout pour les opérations socket
})
  .then(() => console.log('✅ MongoDB connected with optimizations'))
  .catch(err => console.error('❌ MongoDB connection error:', err));
// User Model (Étendu pour profile, password, name)
const userSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  name: { type: String, default: '' }, // Nom/prénom
  password: { type: String, required: false, default: '' }, // Haché
  profilePhoto: { type: String, default: '' }, // Base64 ou URL
  isVerified: { type: Boolean, default: false },
  role: { type: String, enum: ['user', 'admin'], default: 'user' }, // Rôle utilisateur
  status: { type: String, enum: ['active', 'blocked', 'suspended'], default: 'active' }, // Statut du compte
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
// Nouveau Model Employé
const employeeSchema = new mongoose.Schema({
  name: { type: String, required: true },
  position: { type: String, required: true },
  email: { type: String, required: true },
  photo: { type: String, required: true }, // Base64
  certificate: { type: String, required: true }, // Base64 PDF
  startDate: { type: Date, required: true },
  endDate: { type: Date, required: true },
}, { timestamps: true });
const Employee = mongoose.model('Employee', employeeSchema);

// Nouveau Model Article pour le Blog
const articleSchema = new mongoose.Schema({
  title: { type: String, required: true },
  content: { type: String, required: true }, // HTML content
  summary: { type: String, default: '' }, // Résumé optionnel
  published: { type: Boolean, default: false }, // Publié ou brouillon
  tags: [{ type: String }], // Tags pour catégorisation
  authorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }
}, { timestamps: true });
const Article = mongoose.model('Article', articleSchema);

// Nouveau Model Media pour gérer les médias séparément
const mediaSchema = new mongoose.Schema({
  title: { type: String, required: true }, // Titre du média
  description: { type: String, default: '' }, // Description optionnelle
  filename: { type: String, required: true }, // Nom du fichier sur le serveur
  originalName: { type: String, required: true }, // Nom original du fichier
  url: { type: String, required: true }, // URL d'accès au fichier
  mimetype: { type: String, required: true }, // Type MIME (image/png, etc.)
  size: { type: Number, required: true }, // Taille en octets
  type: { 
    type: String, 
    required: true, 
    enum: ['image', 'video', 'audio', 'document'] 
  }, // Catégorie du média
  tags: [{ type: String }], // Tags pour organisation
  uploadedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  isPublic: { type: Boolean, default: true }, // Média public ou privé
  usageCount: { type: Number, default: 0 }, // Compteur d'utilisation dans les articles
}, { timestamps: true });

// Index pour optimiser les requêtes
mediaSchema.index({ uploadedBy: 1, type: 1 });
mediaSchema.index({ tags: 1 });
mediaSchema.index({ createdAt: -1 });

const Media = mongoose.model('Media', mediaSchema);

// Schéma pour les likes
const likeSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  targetType: { type: String, required: true, enum: ['article', 'media', 'comment'] },
  targetId: { type: mongoose.Schema.Types.ObjectId, required: true }, // ID de l'article, media ou comment
  isActive: { type: Boolean, default: true }, // Pour permettre soft delete des likes
}, { timestamps: true });

// Index composé pour éviter les doublons et optimiser les requêtes
likeSchema.index({ userId: 1, targetType: 1, targetId: 1 }, { unique: true });
likeSchema.index({ targetType: 1, targetId: 1 });
likeSchema.index({ userId: 1 });

const Like = mongoose.model('Like', likeSchema);

// Schéma pour les commentaires
const commentSchema = new mongoose.Schema({
  content: { type: String, required: true, maxlength: 1000 },
  authorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  targetType: { type: String, required: true, enum: ['article', 'media'] },
  targetId: { type: mongoose.Schema.Types.ObjectId, required: true }, // ID de l'article ou media
  parentCommentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Comment', default: null }, // Pour les réponses
  isEdited: { type: Boolean, default: false },
  editedAt: { type: Date },
  isDeleted: { type: Boolean, default: false },
  deletedAt: { type: Date },
  likesCount: { type: Number, default: 0 }, // Cache du nombre de likes
  repliesCount: { type: Number, default: 0 }, // Cache du nombre de réponses
}, { timestamps: true });

// Index pour optimiser les requêtes
commentSchema.index({ targetType: 1, targetId: 1, createdAt: -1 });
commentSchema.index({ authorId: 1 });
commentSchema.index({ parentCommentId: 1 });

const Comment = mongoose.model('Comment', commentSchema);

// Schéma pour les statistiques de contenu (cache des compteurs)
const contentStatsSchema = new mongoose.Schema({
  contentType: { type: String, required: true, enum: ['article', 'media'] },
  contentId: { type: mongoose.Schema.Types.ObjectId, required: true },
  likesCount: { type: Number, default: 0 },
  commentsCount: { type: Number, default: 0 },
  viewsCount: { type: Number, default: 0 },
  sharesCount: { type: Number, default: 0 },
}, { timestamps: true });

// Index composé unique pour éviter les doublons
contentStatsSchema.index({ contentType: 1, contentId: 1 }, { unique: true });

const ContentStats = mongoose.model('ContentStats', contentStatsSchema);

// Middleware
const authMiddleware = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      console.log('❌ Auth middleware - No token provided');
      return res.status(401).json({ error: 'Access denied' });
    }
    
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    const user = await User.findById(decoded.id);
    if (!user) {
      console.log(`❌ Auth middleware - User not found for ID: ${decoded.id}`);
      return res.status(401).json({ error: 'User not found' });
    }
    
    // Vérifier si le token existe dans la liste des tokens de l'utilisateur
    const tokenExists = user.tokens.some(t => t.token === token);
    if (!tokenExists) {
      console.log(`❌ Auth middleware - Invalid token for user: ${user.email}`);
      return res.status(401).json({ error: 'Token expired or invalid' });
    }
    
    // Vérifier le statut du compte
    if (user.status === 'blocked') {
      return res.status(403).json({ error: 'Compte bloqué. Contactez l\'administrateur.' });
    }
    
    if (user.status === 'suspended') {
      return res.status(403).json({ error: 'Compte suspendu. Contactez l\'administrateur.' });
    }
    
    // Log minimal - seulement en cas de débogage
    // console.log(`✅ Authenticated: ${user.email}`);
    req.user = user;
    next();
  } catch (err) {
    console.log(`❌ Auth middleware error: ${err.message}`);
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Middleware pour vérifier les permissions spécifiques
const permissionMiddleware = (permission) => {
  return (req, res, next) => {
    try {
      // L'admin a toutes les permissions
      if (req.user.email === 'nyundumathryme@gmail.com' || req.user.role === 'admin') {
        return next();
      }
      
      // Mapper les permissions aux noms dans la DB
      const permissionMap = {
        'blog': 'canCreateArticles',
        'media': 'canAccessMedia',
        'employees': 'canManageEmployees',
        'analytics': 'canAccessAnalytics'
      };
      
      const dbPermission = permissionMap[permission];
      if (!dbPermission) {
        console.log(`❌ Permission inconnue: ${permission}`);
        return res.status(403).json({ 
          error: `Permission inconnue: ${permission}` 
        });
      }
      
      // Pour les utilisateurs standards, donner accès par défaut au blog et aux médias
      // Les employés peuvent être consultés par tous (lecture seule)
      const defaultPermissions = ['blog', 'media'];
      if (defaultPermissions.includes(permission)) {
        console.log(`✅ Permission accordée par défaut pour: ${permission} à ${req.user.email}`);
        return next();
      }
      
      // Accès en lecture seule aux employés pour tous les utilisateurs
      // (la modification reste réservée aux admins)
      if (permission === 'employees' && req.method === 'GET') {
        console.log(`✅ Permission de lecture accordée pour: ${permission} à ${req.user.email}`);
        return next();
      }
      
      // Vérifier si l'utilisateur a la permission requise
      if (!req.user.permissions || !req.user.permissions[dbPermission]) {
        console.log(`❌ Permission refusée: ${permission} (${dbPermission}) pour ${req.user.email}`);
        return res.status(403).json({ 
          error: `Permission requise: ${permission}. Contactez votre administrateur.` 
        });
      }
      
      console.log(`✅ Permission accordée: ${permission} à ${req.user.email}`);
      next();
    } catch (error) {
      console.error('Erreur de vérification des permissions:', error);
      res.status(500).json({ error: 'Erreur de vérification des permissions' });
    }
  };
};

// Configuration Multer pour l'upload de fichiers
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = path.join(__dirname, 'uploads');
    // Créer le dossier s'il n'existe pas
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    // Générer un nom de fichier unique
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const extension = path.extname(file.originalname);
    cb(null, file.fieldname + '-' + uniqueSuffix + extension);
  }
});

// Configuration Multer spécialisée pour les médias de chat
const chatMediaStorage = multer.diskStorage({
  destination: function (req, file, cb) {
    let subDir = '';
    if (file.mimetype.startsWith('image/')) {
      subDir = 'chat-images';
    } else if (file.mimetype.startsWith('audio/')) {
      subDir = 'chat-audio';
    } else if (file.mimetype.startsWith('video/')) {
      subDir = 'chat-videos';
    } else {
      subDir = 'chat-files';
    }
    
    const uploadDir = path.join(__dirname, 'uploads', subDir);
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const extension = path.extname(file.originalname);
    const sanitizedName = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    cb(null, `chat-${uniqueSuffix}-${sanitizedName}`);
  }
});

// Configuration Multer pour les photos de profil
const profileStorage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = path.join(__dirname, 'uploads', 'profiles');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, `profile-${req.user?.id || 'anonymous'}-${uniqueSuffix}.jpg`);
  }
});

// Fonction utilitaire pour déterminer le type de média basé sur mimetype
const getMediaTypeFromMimetype = (mimetype) => {
  if (mimetype.startsWith('image/')) return 'image';
  if (mimetype.startsWith('video/')) return 'video';
  if (mimetype.startsWith('audio/')) return 'audio';
  
  // Types de documents spécifiques
  const documentMimetypes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/markdown',
    'text/csv',
    'application/json',
    'application/xml',
    'text/xml'
  ];
  
  if (documentMimetypes.includes(mimetype)) return 'document';
  
  return 'document'; // Par défaut
};

// Filtres de fichiers pour les différents types d'upload
const chatMediaFilter = (req, file, cb) => {
  // Accepter images, audio, vidéos et documents
  const allowedMimes = [
    // Images
    'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp',
    // Audio
    'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/m4a', 'audio/aac', 'audio/webm',
    // Vidéos
    'video/mp4', 'video/mpeg', 'video/quicktime', 'video/webm', 'video/avi',
    // Documents
    'application/pdf', 'text/plain'
  ];

  if (allowedMimes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`Type de fichier non supporté: ${file.mimetype}`), false);
  }
};

const profileImageFilter = (req, file, cb) => {
  // Seulement les images pour les profils
  const allowedMimes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
  
  if (allowedMimes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Seules les images sont autorisées pour les photos de profil'), false);
  }
};

// Instances multer configurées
const generalUpload = multer({ 
  storage: storage,
  limits: { fileSize: 50 * 1024 * 1024 } // 50MB
});

const chatMediaUpload = multer({
  storage: chatMediaStorage,
  fileFilter: chatMediaFilter,
  limits: { 
    fileSize: 100 * 1024 * 1024, // 100MB pour vidéos
    files: 10 // Max 10 fichiers par upload
  }
});

const profileUpload = multer({
  storage: profileStorage,
  fileFilter: profileImageFilter,
  limits: { 
    fileSize: 5 * 1024 * 1024 // 5MB pour photos de profil
  }
});

// Fonction utilitaire pour déterminer le type basé sur l'extension
const getMediaTypeFromExtension = (filename) => {
  const ext = filename.toLowerCase().split('.').pop();
  
  const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'ico'];
  const videoExts = ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv', '3gp'];
  const audioExts = ['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a', 'wma'];
  const documentExts = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md', 'csv', 'json', 'xml'];
  
  if (imageExts.includes(ext)) return 'image';
  if (videoExts.includes(ext)) return 'video';
  if (audioExts.includes(ext)) return 'audio';
  if (documentExts.includes(ext)) return 'document';
  
  return 'document';
};

// Filtrer les types de fichiers autorisés (étendu)
const fileFilter = (req, file, cb) => {
  console.log(`📋 File upload - Original name: ${file.originalname}`);
  console.log(`📋 File upload - Mimetype: ${file.mimetype}`);
  
  // Extensions autorisées (étendu pour inclure documents)
  const allowedExtensions = /\.(jpeg|jpg|png|gif|webp|bmp|svg|ico|mp4|avi|mov|wmv|flv|webm|mkv|3gp|mp3|wav|ogg|flac|aac|m4a|wma|pdf|doc|docx|xls|xlsx|ppt|pptx|txt|md|csv|json|xml)$/i;
  
  // Mimetypes autorisés (étendu)
  const allowedMimetypes = [
    // Images
    'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp', 'image/bmp', 'image/svg+xml', 'image/x-icon',
    // Vidéos
    'video/mp4', 'video/avi', 'video/quicktime', 'video/x-msvideo', 'video/x-flv', 'video/webm', 'video/x-matroska', 'video/3gpp',
    // Audio
    'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/flac', 'audio/aac', 'audio/x-m4a', 'audio/x-ms-wma',
    // Documents
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/markdown',
    'text/csv',
    'application/json',
    'application/xml',
    'text/xml',
    // Fallback
    'application/octet-stream'
  ];
  
  const extname = allowedExtensions.test(file.originalname);
  const mimetype = allowedMimetypes.includes(file.mimetype.toLowerCase()) || 
                  file.mimetype.startsWith('image/') || 
                  file.mimetype.startsWith('video/') ||
                  file.mimetype.startsWith('audio/') ||
                  (file.mimetype === 'application/octet-stream' && extname);
  
  console.log(`📋 File upload - Extension OK: ${extname}, Mimetype OK: ${mimetype}`);
  
  if (extname && mimetype) {
    console.log(`✅ File upload - File accepted: ${file.originalname}`);
    return cb(null, true);
  } else {
    console.log(`❌ File upload - File rejected: ${file.originalname} (ext: ${extname}, mime: ${mimetype})`);
    cb(new Error(`Type de fichier non autorisé: ${file.mimetype}`), false);
  }
};

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 50 * 1024 * 1024 // Limite augmentée à 50MB pour les médias
  },
  fileFilter: fileFilter
});

// Nodemailer Transporter optimisé pour performance
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS
  },
  // Optimisations de performance
  pool: true, // Utilise un pool de connexions
  maxConnections: 5, // Limite les connexions simultanées
  maxMessages: 10, // Messages par connexion
  rateDelta: 20000, // 20 secondes entre les batches
  rateLimit: 5, // 5 emails max par rateDelta
  // Timeouts pour éviter les blocages
  connectionTimeout: 5000, // 5 secondes max pour se connecter
  greetingTimeout: 3000, // 3 secondes max pour greeting
  socketTimeout: 10000, // 10 secondes max pour socket
});
// Generate OTP
const generateOTP = () => {
  return crypto.randomBytes(3).toString('hex').toUpperCase().slice(0, 6);
};
// Send OTP Email optimisé (non-bloquant)
const sendOTP = async (email, otp) => {
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject: 'Votre code OTP pour vérification',
    text: `Votre code OTP est: ${otp}. Il expire dans 10 minutes.`,
    // Optimisations
    priority: 'high', // Priorité haute pour OTP
    headers: {
      'X-Priority': '1',
      'X-MSMail-Priority': 'High'
    }
  };
  
  // Timeout sur l'envoi d'email pour éviter les blocages
  return Promise.race([
    transporter.sendMail(mailOptions),
    new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Email timeout - taking too long')), 15000)
    )
  ]);
};
// Send Profile Update Notification
const sendProfileUpdateNotification = async (email, name, profilePhotoChanged = false) => {
  const subject = 'Mise à jour de votre profil';
  const text = profilePhotoChanged
    ? `Bonjour,\n\nVotre profil a été mis à jour. Nouveau nom: ${name}.\n\nVotre photo de profil a été modifiée.\n\nCordialement,`
    : `Bonjour,\n\nVotre profil a été mis à jour. Nouveau nom: ${name}.\n\nCordialement,`;
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject,
    text
  };
  await transporter.sendMail(mailOptions);
};
// Send Password Update Notification
const sendPasswordUpdateNotification = async (email) => {
  const subject = 'Changement de mot de passe';
  const text = `Bonjour,\n\nVotre mot de passe a été mis à jour avec succès.\n\nSi ce n'était pas vous, contactez-nous immédiatement.\n\nCordialement,`;
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject,
    text
  };
  await transporter.sendMail(mailOptions);
};
// Send Account Deletion Notification
const sendAccountDeletionNotification = async (email) => {
  const subject = 'Suppression de votre compte';
  const text = `Bonjour,\n\nVotre compte a été supprimé définitivement.\n\nSi ce n'était pas votre intention, contactez-nous.\n\nAu revoir,`;
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject,
    text
  };
  await transporter.sendMail(mailOptions);
};
// Nouvelle fonction envoi notification employé
const sendEmployeeNotification = async (email, name, position, startDate, endDate) => {
  const subject = 'Bienvenue dans l\'équipe';
  const text = `Bonjour ${name},\n\nVous avez été embauché en tant que ${position}.\nDate de début: ${startDate}\nDate de fin: ${endDate}\n\nCordialement,`;
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject,
    text
  };
  await transporter.sendMail(mailOptions);
};
// Send Employee Update Notification
const sendEmployeeUpdateNotification = async (email, name, position) => {
  const subject = 'Mise à jour de vos informations';
  const text = `Bonjour ${name},\n\nVos informations ont été mises à jour. Poste: ${position}.\n\nCordialement,`;
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject,
    text
  };
  await transporter.sendMail(mailOptions);
};
// Send Employee Deletion Notification
const sendEmployeeDeletionNotification = async (email, name) => {
  const subject = 'Fin de contrat';
  const text = `Bonjour ${name},\n\nVotre contrat a été terminé.\n\nCordialement,`;
  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: email,
    subject,
    text
  };
  await transporter.sendMail(mailOptions);
};
// Express App avec optimisations
const app = express();

// Activer la compression GZIP pour toutes les réponses
app.use(compression({
  filter: (req, res) => {
    if (req.headers['x-no-compression']) {
      return false;
    }
    return compression.filter(req, res);
  },
  level: 6 // Niveau de compression (1-9, 6 est un bon compromis)
}));

// Configuration CORS optimisée
app.use(cors({
  origin: ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://localhost:*'],
  credentials: true,
  maxAge: 86400, // Cache preflight requests for 24 hours
}));

// Middleware de parsing optimisé
app.use(express.json({ limit: '50mb', parameterLimit: 5000 }));
app.use(express.urlencoded({ extended: true, limit: '50mb', parameterLimit: 5000 }));

// Servir les fichiers statiques du dossier uploads avec cache et CORS
app.use('/uploads', (req, res, next) => {
  // Headers CORS spécifiques pour les médias
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  console.log(`📁 Serving media file: ${req.path}`);
  next();
}, express.static(path.join(__dirname, 'uploads'), {
  maxAge: '1d', // Cache les fichiers statiques pour 1 jour
  etag: true,
  lastModified: true
}));

// Headers de sécurité et performance
app.use((req, res, next) => {
  res.set('X-Content-Type-Options', 'nosniff');
  res.set('X-Frame-Options', 'DENY');
  res.set('X-XSS-Protection', '1; mode=block');
  next();
});

// Routes
// Register: Create user and send OTP
app.post('/api/register', async (req, res) => {
  try {
    const startTime = Date.now();
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email required' });
    
    let user = await User.findOne({ email });
    if (user) return res.status(400).json({ error: 'User already exists' });
    
    const otp = generateOTP();
    const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 min
    
    // Configuration automatique pour l'administrateur
    const isAdmin = email === 'nyundumathryme@gmail.com';
    const userData = { 
      email, 
      otp, 
      otpExpiry,
      role: isAdmin ? 'admin' : 'user',
      status: 'active',
      permissions: isAdmin ? {
        canCreateArticles: true,
        canManageEmployees: true,
        canAccessMedia: true,
        canAccessAnalytics: true
      } : {
        canCreateArticles: true,  // Permettre par défaut pour tous les utilisateurs
        canManageEmployees: false,
        canAccessMedia: true,     // Permettre par défaut pour tous les utilisateurs
        canAccessAnalytics: false
      }
    };
    
    user = new User(userData);
    await user.save();
    
    console.log(`📧 Registering user ${email} and sending OTP...`);
    
    // Répondre immédiatement
    res.status(201).json({ message: 'User registered. OTP sent to email.' });
    
    // Envoi d'email asynchrone (non-bloquant)
    sendOTP(email, otp)
      .then(() => {
        const duration = Date.now() - startTime;
        console.log(`✅ Registration OTP sent successfully to ${email} in ${duration}ms`);
      })
      .catch(err => {
        console.error(`❌ Failed to send registration OTP to ${email}:`, err.message);
      });
      
  } catch (err) {
    console.error('❌ Registration error:', err.message);
    res.status(500).json({ error: err.message });
  }
});
// Verify OTP for Registration
app.post('/api/verify-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) return res.status(400).json({ error: 'Email and OTP required' });
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });
    if (user.isVerified) return res.status(400).json({ error: 'User already verified' });
    if (user.otp !== otp || user.otpExpiry < new Date()) {
      return res.status(400).json({ error: 'Invalid or expired OTP' });
    }
    user.isVerified = true;
    user.otp = undefined;
    user.otpExpiry = undefined;
    // Generate JWT and Refresh Token
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1h' });
    const refreshToken = jwt.sign({ id: user._id }, process.env.JWT_REFRESH_SECRET, { expiresIn: '7d' });
    user.tokens.push({ token, refreshToken });
    await user.save();
    res.json({ message: 'Verified successfully', token, refreshToken });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
// Login: Send OTP to email
app.post('/api/login', async (req, res) => {
  try {
    const startTime = Date.now();
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email required' });
    
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });
    if (!user.isVerified) return res.status(400).json({ error: 'Please verify your account first' });
    
    const otp = generateOTP();
    const otpExpiry = new Date(Date.now() + 10 * 60 * 1000);
    user.otp = otp;
    user.otpExpiry = otpExpiry;
    await user.save();
    
    console.log(`📧 Sending OTP to ${email}...`);
    
    // Répondre immédiatement, puis envoyer l'email en arrière-plan
    res.json({ message: 'OTP sent to email' });
    
    // Envoi d'email asynchrone (non-bloquant)
    sendOTP(email, otp)
      .then(() => {
        const duration = Date.now() - startTime;
        console.log(`✅ OTP email sent successfully to ${email} in ${duration}ms`);
      })
      .catch(err => {
        console.error(`❌ Failed to send OTP email to ${email}:`, err.message);
        // Note: L'utilisateur a déjà reçu la réponse, donc on ne peut plus renvoyer d'erreur
        // En production, on pourrait logger cela ou implémenter un retry
      });
      
  } catch (err) {
    console.error('❌ Login error:', err.message);
    res.status(500).json({ error: err.message });
  }
});
// Verify OTP for Login
app.post('/api/login-verify', async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) return res.status(400).json({ error: 'Email and OTP required' });
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ error: 'User not found' });
    if (user.otp !== otp || user.otpExpiry < new Date()) {
      return res.status(400).json({ error: 'Invalid or expired OTP' });
    }
    // Clear OTP
    user.otp = undefined;
    user.otpExpiry = undefined;
    await user.save();
    // Generate new tokens
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1h' });
    const refreshToken = jwt.sign({ id: user._id }, process.env.JWT_REFRESH_SECRET, { expiresIn: '7d' });
    // Update tokens (remove old if needed, but for simplicity, push new)
    user.tokens.push({ token, refreshToken });
    await user.save();
    res.json({ message: 'Login successful', token, refreshToken });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
// Refresh Token Route
app.post('/api/refresh-token', async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(401).json({ error: 'Refresh token required' });
    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    const user = await User.findById(decoded.id);
    if (!user) return res.status(401).json({ error: 'Invalid refresh token' });
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1h' });
    const newRefreshToken = jwt.sign({ id: user._id }, process.env.JWT_REFRESH_SECRET, { expiresIn: '7d' });
    // Update tokens
    user.tokens = user.tokens.filter(t => t.refreshToken !== refreshToken);
    user.tokens.push({ token, refreshToken: newRefreshToken });
    await user.save();
    res.json({ token, refreshToken: newRefreshToken });
  } catch (err) {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});
// Protected Route Example
app.get('/api/profile', authMiddleware, async (req, res) => {
  res.json({ user: req.user.email });
});
// Logout: Clear token (client-side, but server can blacklist if needed)
app.post('/api/logout', authMiddleware, async (req, res) => {
  req.user.tokens = req.user.tokens.filter(t => t.token !== req.headers.authorization.replace('Bearer ', ''));
  await req.user.save();
  res.json({ message: 'Logged out' });
});
// Nouvelles routes pour profile
// GET /api/user : Récupère infos utilisateur
app.get('/api/user', authMiddleware, async (req, res) => {
  try {
    console.log(`👤 Fetch user: ${req.user.email}`);
    let user = await User.findById(req.user._id).select('-password -otp -tokens');
    
    if (!user) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }
    
    // Auto-upgrade admin principal s'il n'a pas encore le rôle admin
    if (user.email === 'nyundumathryme@gmail.com' && user.role !== 'admin') {
      user = await User.findByIdAndUpdate(
        user._id,
        {
          role: 'admin',
          permissions: {
            canCreateArticles: true,
            canManageEmployees: true,
            canAccessMedia: true,
            canAccessAnalytics: true
          }
        },
        { new: true }
      ).select('-password -otp -tokens');
      console.log(`✅ Auto-upgraded ${user.email} to admin with full permissions`);
    }
    
    res.json(user);
  } catch (err) {
    console.error('❌ Get user error:', err.message);
    res.status(500).json({ error: err.message });
  }
});
// PUT /api/user : Met à jour infos (name, profilePhoto)
app.put('/api/user', authMiddleware, async (req, res) => {
  try {
    const { name, profilePhoto } = req.body;
    if (profilePhoto && profilePhoto.length > 5000000) { // Limite ~5MB base64
      return res.status(400).json({ error: 'Photo too large' });
    }
    console.log(`✏️ Update user: ${req.user.email}, name: ${name}`); // Log
    const updates = {};
    const oldName = req.user.name;
    const oldPhoto = req.user.profilePhoto;
    let nameChanged = false;
    let photoChanged = false;
    if (name && name !== oldName) {
      updates.name = name;
      nameChanged = true;
    }
    if (profilePhoto && profilePhoto !== oldPhoto) {
      updates.profilePhoto = profilePhoto;
      photoChanged = true;
    }
    const updatedUser = await User.findByIdAndUpdate(
      req.user._id,
      updates,
      { new: true, runValidators: true }
    );
    // Envoyer notification email si changements
    if (nameChanged || photoChanged) {
      await sendProfileUpdateNotification(req.user.email, updatedUser.name, photoChanged);
    }
    res.json({
      user: {
        email: updatedUser.email,
        name: updatedUser.name,
        profilePhoto: updatedUser.profilePhoto,
      },
      message: 'User updated successfully'
    });
  } catch (err) {
    console.error('❌ Update user error:', err.message); // Log
    res.status(500).json({ error: err.message });
  }
});
// PUT /api/user/password : Met à jour mot de passe (vérifie ancien)
app.put('/api/user/password', authMiddleware, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ error: 'Invalid new password' });
    }
    console.log(`🔒 Update password for: ${req.user.email}`); // Log
    let isMatch = true;
    if (req.user.password && req.user.password !== '') {
      if (!currentPassword) {
        return res.status(400).json({ error: 'Current password required' });
      }
      isMatch = await bcrypt.compare(currentPassword, req.user.password);
    }
    if (!isMatch) {
      return res.status(400).json({ error: 'Current password incorrect' });
    }
    const hashedNewPassword = await bcrypt.hash(newPassword, 12);
    const updatedUser = await User.findByIdAndUpdate(
      req.user._id,
      { password: hashedNewPassword },
      { new: true }
    );
    // Envoyer notification email
    await sendPasswordUpdateNotification(req.user.email);
    res.json({ message: 'Password updated successfully' });
  } catch (err) {
    console.error('❌ Update password error:', err.message); // Log
    res.status(500).json({ error: err.message });
  }
});
// DELETE /api/user : Supprime compte
app.delete('/api/user', authMiddleware, async (req, res) => {
  try {
    console.log(`🗑️ Delete user: ${req.user.email}`); // Log
    // Envoyer notification email AVANT suppression
    await sendAccountDeletionNotification(req.user.email);
    await User.findByIdAndDelete(req.user._id);
    res.json({ message: 'Account deleted successfully' });
  } catch (err) {
    console.error('❌ Delete user error:', err.message); // Log
    res.status(500).json({ error: err.message });
  }
});
// Nouvelles routes pour employé
// POST /api/employee : Créer employé
app.post('/api/employee', authMiddleware, permissionMiddleware('employees'), async (req, res) => {
  try {
    const { name, position, email, photo, certificate, startDate, endDate } = req.body;
    if (!name || !position || !email || !photo || !certificate || !startDate || !endDate) {
      return res.status(400).json({ error: 'Tous les champs sont requis' });
    }
    if (photo.length > 5000000 || certificate.length > 10000000) {
      return res.status(400).json({ error: 'Fichiers trop volumineux' });
    }
    const employee = new Employee({
      name,
      position,
      email,
      photo,
      certificate,
      startDate: new Date(startDate),
      endDate: new Date(endDate),
    });
    await employee.save();
    // Envoyer notification
    await sendEmployeeNotification(email, name, position, startDate, endDate);
    res.status(201).json({ message: 'Employé créé', employee });
  } catch (err) {
    console.error('❌ Create employee error:', err.message);
    res.status(500).json({ error: err.message });
  }
});
// PUT /api/employee/:id : Mettre à jour employé
app.put('/api/employee/:id', authMiddleware, permissionMiddleware('employees'), async (req, res) => {
  try {
    const { id } = req.params;
    const { name, position, email, photo, certificate, startDate, endDate } = req.body;
    if (photo && photo.length > 5000000 || certificate && certificate.length > 10000000) {
      return res.status(400).json({ error: 'Fichiers trop volumineux' });
    }
    const updates = {};
    if (name) updates.name = name;
    if (position) updates.position = position;
    if (email) updates.email = email;
    if (photo) updates.photo = photo;
    if (certificate) updates.certificate = certificate;
    if (startDate) updates.startDate = new Date(startDate);
    if (endDate) updates.endDate = new Date(endDate);
    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ error: 'Aucune information à mettre à jour' });
    }
    const updatedEmployee = await Employee.findByIdAndUpdate(id, updates, { new: true, runValidators: true });
    if (!updatedEmployee) {
      return res.status(404).json({ error: 'Employé non trouvé' });
    }
    // Envoyer notification si changements significatifs
    if (name || position) {
      await sendEmployeeUpdateNotification(updatedEmployee.email, updatedEmployee.name, updatedEmployee.position);
    }
    res.json({ message: 'Employé mis à jour', employee: updatedEmployee });
  } catch (err) {
    console.error('❌ Update employee error:', err.message);
    res.status(500).json({ error: err.message });
  }
});
// DELETE /api/employee/:id : Supprimer employé
app.delete('/api/employee/:id', authMiddleware, permissionMiddleware('employees'), async (req, res) => {
  try {
    const { id } = req.params;
    const employee = await Employee.findById(id);
    if (!employee) {
      return res.status(404).json({ error: 'Employé non trouvé' });
    }
    // Envoyer notification AVANT suppression
    await sendEmployeeDeletionNotification(employee.email, employee.name);
    await Employee.findByIdAndDelete(id);
    res.json({ message: 'Employé supprimé' });
  } catch (err) {
    console.error('❌ Delete employee error:', err.message);
    res.status(500).json({ error: err.message });
  }
});
// GET /api/employees : Récupérer tous les employés (OPTIMISÉ)
app.get('/api/employees', authMiddleware, permissionMiddleware('employees'), async (req, res) => {
  try {
    // Cache headers pour optimiser
    res.set('Cache-Control', 'private, max-age=300'); // 5 minutes de cache
    
    // Pagination optionnelle
    const page = parseInt(req.query.page) || 0;
    const limit = parseInt(req.query.limit) || 100;
    const skip = page * limit;
    
    // Requête optimisée avec lean() pour des objets JavaScript simples
    const employees = await Employee.find({})
      .select('-__v') // Exclure les champs inutiles
      .skip(skip)
      .limit(limit)
      .lean() // Retourne des objets JavaScript simples (plus rapide)
      .exec();
    
    console.log(`✅ Returned ${employees.length} employees (page ${page}, limit ${limit})`);
    
    res.json({ 
      employees,
      pagination: {
        page,
        limit,
        total: await Employee.countDocuments()
      }
    });
  } catch (err) {
    console.error('❌ Get employees error:', err.message);
    res.status(500).json({ error: err.message });
  }
});
// ================ BLOG/ARTICLES APIs ================

// POST /api/blog/articles : Créer un nouvel article
app.post('/api/blog/articles', authMiddleware, permissionMiddleware('blog'), async (req, res) => {
  try {
    const { title, content, summary, published, tags } = req.body;
    
    if (!title || !content) {
      return res.status(400).json({ error: 'Titre et contenu requis' });
    }
    
    console.log(`📝 Create article: "${title}" by ${req.user.email}`);
    
    const article = new Article({
      title,
      content,
      summary: summary || '',
      published: published || false,
      tags: tags || [],
      authorId: req.user._id
    });
    
    await article.save();
    
    // Envoyer notification automatique pour le nouvel article
    if (article.published) {
      const authorName = `${req.user.firstName || ''} ${req.user.lastName || ''}`.trim() || req.user.email;
      await sendAutoNotification('article', {
        title: article.title,
        author: authorName,
        articleId: article._id
      });
    }
    
    console.log(`✅ Article created successfully`);
    
    res.status(201).json({ 
      message: 'Article créé avec succès', 
      article 
    });
  } catch (err) {
    console.error('❌ Create article error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/blog/articles : Récupérer tous les articles (optimisé)
app.get('/api/blog/articles', authMiddleware, permissionMiddleware('blog'), async (req, res) => {
  try {
    const startTime = Date.now();
    const { published, limit = 50, page = 1 } = req.query;
    
    const filter = {};
    if (published !== undefined) {
      filter.published = published === 'true';
    }
    
    console.log(`📖 Fetch articles for ${req.user.email} (page ${page}, limit ${limit})`);
    
    const limitNum = parseInt(limit);
    const pageNum = parseInt(page);
    const skip = (pageNum - 1) * limitNum;
    
    // Optimisation: projection pour ne récupérer que les champs nécessaires pour la liste
    const articles = await Article.find(filter, {
      title: 1,
      summary: 1,
      published: 1,
      tags: 1,
      createdAt: 1,
      updatedAt: 1,
      mediaFiles: 1,
      authorId: 1
      // Exclure le contenu HTML qui peut être volumineux
    })
      .populate('authorId', 'name email')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean(); // Améliore les performances en retournant des objets JS purs
    
    const endTime = Date.now();
    console.log(`⚡ Articles fetched in ${endTime - startTime}ms (${articles.length} items)`);
    
    // Log des médias pour debugging
    articles.forEach(article => {
      if (article.mediaFiles && article.mediaFiles.length > 0) {
        console.log(`📎 Article "${article.title}" has ${article.mediaFiles.length} media files:`);
        article.mediaFiles.forEach(media => {
          console.log(`  - ${media.filename}: ${media.url} (${media.type})`);
        });
      } else {
        console.log(`📎 Article "${article.title}" has no media files`);
      }
    });
    
    res.json(articles);
  } catch (err) {
    console.error('❌ Get articles error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/blog/articles/:id : Récupérer un article spécifique
app.get('/api/blog/articles/:id', authMiddleware, permissionMiddleware('blog'), async (req, res) => {
  try {
    const { id } = req.params;
    
    console.log(`📄 Fetch article ${id} for ${req.user.email}`);
    
    const article = await Article.findById(id).populate('authorId', 'name email');
    
    if (!article) {
      return res.status(404).json({ error: 'Article non trouvé' });
    }
    
    res.json(article);
  } catch (err) {
    console.error('❌ Get article error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/blog/articles/:id : Mettre à jour un article
app.put('/api/blog/articles/:id', authMiddleware, permissionMiddleware('blog'), async (req, res) => {
  try {
    const { id } = req.params;
    const { title, content, summary, published, tags } = req.body;
    
    console.log(`✏️ Update article ${id} by ${req.user.email}`);
    
    const article = await Article.findById(id);
    
    if (!article) {
      return res.status(404).json({ error: 'Article non trouvé' });
    }
    
    // Vérifier que l'utilisateur est l'auteur (ou admin)
    if (article.authorId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Non autorisé à modifier cet article' });
    }
    
    const updates = {};
    if (title) updates.title = title;
    if (content) updates.content = content;
    if (summary !== undefined) updates.summary = summary;
    if (published !== undefined) updates.published = published;
    if (tags !== undefined) updates.tags = tags;
    
    const updatedArticle = await Article.findByIdAndUpdate(
      id,
      updates,
      { new: true, runValidators: true }
    ).populate('authorId', 'name email');
    
    res.json({ 
      message: 'Article mis à jour avec succès',
      article: updatedArticle 
    });
  } catch (err) {
    console.error('❌ Update article error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/blog/articles/:id : Supprimer un article
app.delete('/api/blog/articles/:id', authMiddleware, permissionMiddleware('blog'), async (req, res) => {
  try {
    const { id } = req.params;
    
    console.log(`🗑️ Delete article ${id} by ${req.user.email}`);
    
    const article = await Article.findById(id);
    
    if (!article) {
      return res.status(404).json({ error: 'Article non trouvé' });
    }
    
    // Vérifier que l'utilisateur est l'auteur (ou admin)
    if (article.authorId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Non autorisé à supprimer cet article' });
    }
    
    await Article.findByIdAndDelete(id);
    
    res.json({ message: 'Article supprimé avec succès' });
  } catch (err) {
    console.error('❌ Delete article error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ==========================================
// ENDPOINTS PUBLICS (SANS AUTHENTIFICATION)
// ==========================================

// GET /api/public/articles : Récupérer les articles publiés (public)
app.get('/api/public/articles', async (req, res) => {
  try {
    const { limit = 20, page = 1, search } = req.query;
    
    console.log(`📖 Public articles request: page=${page}, limit=${limit}, search="${search || 'none'}"`);
    
    const limitNum = parseInt(limit);
    const pageNum = parseInt(page);
    const skip = (pageNum - 1) * limitNum;
    
    // Filtrer seulement les articles publiés
    const filter = { published: true };
    
    // Ajouter la recherche si fournie
    if (search && search.trim().length > 0) {
      filter.$or = [
        { title: { $regex: search, $options: 'i' } },
        { summary: { $regex: search, $options: 'i' } },
        { content: { $regex: search, $options: 'i' } },
        { tags: { $in: [new RegExp(search, 'i')] } }
      ];
    }
    
    const articles = await Article.find(filter, {
      title: 1,
      summary: 1,
      content: 1,
      tags: 1,
      createdAt: 1,
      updatedAt: 1,
      mediaFiles: 1,
      authorId: 1
    })
      .populate('authorId', 'name email role')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();
    
    const total = await Article.countDocuments(filter);
    
    console.log(`✅ Public articles: ${articles.length} found, ${total} total`);
    
    res.json({
      articles: articles.map(article => ({
        ...article,
        author: article.authorId,
        authorId: undefined // Nettoyer pour éviter la duplication
      })),
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
app.get('/api/public/medias', async (req, res) => {
  try {
    const { limit = 20, page = 1, type, search } = req.query;
    
    console.log(`🖼️ Public medias request: page=${page}, limit=${limit}, type=${type || 'all'}, search="${search || 'none'}"`);
    
    const limitNum = parseInt(limit);
    const pageNum = parseInt(page);
    const skip = (pageNum - 1) * limitNum;
    
    // Filtrer seulement les médias publics
    const filter = { isPublic: true };
    
    // Ajouter le filtre de type si spécifié
    if (type && type !== 'all') {
      filter.type = type;
    }
    
    // Ajouter la recherche si fournie
    if (search && search.trim().length > 0) {
      filter.$or = [
        { title: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
        { originalName: { $regex: search, $options: 'i' } },
        { tags: { $in: [new RegExp(search, 'i')] } }
      ];
    }
    
    const medias = await Media.find(filter)
      .populate('uploadedBy', 'name email role')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();
    
    const total = await Media.countDocuments(filter);
    
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
        byType: await Media.aggregate([
          { $match: filter },
          { $group: { _id: '$type', count: { $sum: 1 } } }
        ])
      }
    });
  } catch (err) {
    console.error('❌ Public medias error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/public/feed : Feed public combiné (articles + médias)
app.get('/api/public/feed', async (req, res) => {
  try {
    const { limit = 20, page = 1, search } = req.query;
    
    console.log(`🌐 Public feed request: page=${page}, limit=${limit}, search="${search || 'none'}"`);
    
    const limitNum = parseInt(limit);
    const pageNum = parseInt(page);
    
    // Construire les filtres de recherche
    const searchFilter = search && search.trim().length > 0 ? {
      $or: [
        { title: { $regex: search, $options: 'i' } },
        { summary: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
        { content: { $regex: search, $options: 'i' } },
        { tags: { $in: [new RegExp(search, 'i')] } }
      ]
    } : {};
    
    // Récupérer les articles et médias en parallèle
    const [articles, medias] = await Promise.all([
      Article.find({ published: true, ...searchFilter })
        .populate('authorId', 'name email role')
        .sort({ createdAt: -1 })
        .limit(Math.ceil(limitNum * 0.6)) // 60% articles
        .lean(),
      
      Media.find({ isPublic: true, ...searchFilter })
        .populate('uploadedBy', 'name email role')
        .sort({ createdAt: -1 })
        .limit(Math.ceil(limitNum * 0.4)) // 40% médias
        .lean()
    ]);
    
    // Combiner et formater les résultats
    const feedItems = [];
    
    // Ajouter les articles
    articles.forEach(article => {
      feedItems.push({
        ...article,
        feedType: 'article',
        author: article.authorId,
        authorId: undefined
      });
    });
    
    // Ajouter les médias
    medias.forEach(media => {
      feedItems.push({
        ...media,
        feedType: 'media',
        author: media.uploadedBy,
        uploadedBy: undefined
      });
    });
    
    // Trier par date de création
    feedItems.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    
    // Paginer les résultats combinés
    const skip = (pageNum - 1) * limitNum;
    const paginatedItems = feedItems.slice(skip, skip + limitNum);
    
    console.log(`✅ Public feed: ${articles.length} articles + ${medias.length} medias = ${paginatedItems.length} items`);
    
    res.json({
      feed: paginatedItems,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total: feedItems.length,
        pages: Math.ceil(feedItems.length / limitNum),
        hasMore: (pageNum * limitNum) < feedItems.length
      },
      stats: {
        articles: articles.length,
        medias: medias.length,
        total: paginatedItems.length
      }
    });
    
  } catch (err) {
    console.error('❌ Public feed error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/blog/search : Rechercher des articles
app.get('/api/blog/search', authMiddleware, permissionMiddleware('blog'), async (req, res) => {
  try {
    const { q, tags, published = true } = req.query;
    
    if (!q && !tags) {
      return res.status(400).json({ error: 'Paramètre de recherche requis (q ou tags)' });
    }
    
    console.log(`🔍 Search articles: "${q}" tags: "${tags}" by ${req.user.email}`);
    
    const filter = {};
    
    // Filtre par statut de publication
    if (published !== undefined) {
      filter.published = published === 'true';
    }
    
    // Recherche textuelle
    if (q) {
      filter.$or = [
        { title: { $regex: q, $options: 'i' } },
        { content: { $regex: q, $options: 'i' } },
        { summary: { $regex: q, $options: 'i' } }
      ];
    }
    
    // Filtre par tags
    if (tags) {
      const tagArray = tags.split(',').map(tag => tag.trim());
      filter.tags = { $in: tagArray };
    }
    
    const articles = await Article.find(filter)
      .populate('authorId', 'name email')
      .sort({ createdAt: -1 })
      .limit(50);
    
    res.json(articles);
  } catch (err) {
    console.error('❌ Search articles error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/blog/upload : Télécharger des fichiers media pour le blog
app.post('/api/blog/upload', (req, res, next) => {
  console.log(`📤 Upload request received from ${req.ip}`);
  console.log(`📤 Headers:`, req.headers);
  next();
}, authMiddleware, upload.array('files', 10), async (req, res) => {
  try {
    console.log(`📎 Upload middleware passed, checking files...`);
    
    if (!req.files || req.files.length === 0) {
      console.log(`❌ No files received`);
      return res.status(400).json({ error: 'Aucun fichier téléchargé' });
    }
    
    console.log(`📎 Upload ${req.files.length} file(s) by ${req.user.email}`);
    
    const uploadedFiles = req.files.map(file => {
      const fileUrl = `${getBaseUrl(req)}/uploads/${file.filename}`;
      console.log(`✅ File uploaded: ${file.originalname} -> ${fileUrl}`);
      
      return {
        filename: file.originalname,
        url: fileUrl,
        type: file.mimetype.startsWith('image/') ? 'image' : 'video',
        size: file.size,
        uploadedBy: req.user._id,
        uploadedAt: new Date()
      };
    });
    
    res.json({ 
      message: 'Fichier(s) téléchargé(s) avec succès',
      urls: uploadedFiles.map(f => f.url),
      files: uploadedFiles
    });
  } catch (err) {
    console.error('❌ Upload file error:', err.message);
    console.error('❌ Upload error stack:', err.stack);
    res.status(500).json({ error: err.message });
  }
});

// Gestion d'erreur spécifique pour multer et upload
app.use('/api/blog/upload', (error, req, res, next) => {
  console.error('❌ Upload error caught:', error.message);
  
  if (error instanceof multer.MulterError) {
    return res.status(400).json({ error: `Erreur multer: ${error.message}` });
  }
  
  if (error.message && error.message.includes('Type de fichier non autorisé')) {
    return res.status(400).json({ error: error.message });
  }
  
  return res.status(500).json({ error: `Erreur upload: ${error.message}` });
});

// Gestion d'erreur générale
app.use((error, req, res, next) => {
  console.error('❌ General error:', error.message);
  if (res.headersSent) {
    return next(error);
  }
  res.status(500).json({ error: error.message });
});

// POST /api/blog/articles/:id/media : Associer des médias à un article
app.post('/api/blog/articles/:id/media', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { mediaUrls } = req.body;
    
    if (!mediaUrls || !Array.isArray(mediaUrls)) {
      return res.status(400).json({ error: 'URLs de médias requis' });
    }
    
    console.log(`📎 Adding ${mediaUrls.length} media to article ${id} by ${req.user.email}`);
    
    const article = await Article.findById(id);
    
    if (!article) {
      return res.status(404).json({ error: 'Article non trouvé' });
    }
    
    // Vérifier que l'utilisateur est l'auteur
    if (article.authorId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Non autorisé à modifier cet article' });
    }
    
    // Traiter les nouvelles URLs de médias
    const newMediaFiles = mediaUrls.map(url => ({
      filename: url.split('/').pop() || 'unknown',
      url: url,
      type: url.startsWith('data:image/') ? 'image' : 
            url.includes('.mp4') || url.includes('.avi') ? 'video' : 'image'
    }));
    
    // Ajouter aux médias existants (éviter les doublons)
    const existingUrls = article.mediaFiles.map(media => media.url);
    const filteredNewMedia = newMediaFiles.filter(media => !existingUrls.includes(media.url));
    
    article.mediaFiles.push(...filteredNewMedia);
    await article.save();
    
    console.log(`✅ Added ${filteredNewMedia.length} new media files to article`);
    
    res.json({
      message: `${filteredNewMedia.length} médias ajoutés à l'article`,
      article
    });
  } catch (err) {
    console.error('❌ Add media to article error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/uploads : Lister les fichiers uploadés disponibles
app.get('/api/uploads', authMiddleware, permissionMiddleware('media'), async (req, res) => {
  try {
    const uploadsDir = path.join(__dirname, 'uploads');
    
    if (!fs.existsSync(uploadsDir)) {
      return res.json({ files: [] });
    }
    
    const files = fs.readdirSync(uploadsDir);
    const fileList = files.map(filename => ({
      filename,
      url: `${getBaseUrl(req)}/uploads/${filename}`,
      size: fs.statSync(path.join(uploadsDir, filename)).size,
      created: fs.statSync(path.join(uploadsDir, filename)).birthtime
    }));
    
    console.log(`📁 Listed ${fileList.length} uploaded files`);
    
    res.json({
      files: fileList,
      total: fileList.length
    });
  } catch (err) {
    console.error('❌ List uploads error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/blog/seed-data : Créer des articles de test (développement uniquement)
app.post('/api/blog/seed-data', authMiddleware, async (req, res) => {
  try {
    console.log(`🌱 Creating seed articles for ${req.user.email}`);
    
    // Images de test en base64 (petites images 1x1)
    const testImages = [
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==', // Rouge
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', // Vert
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAGA60e6kgAAAABJRU5ErkJggg==', // Bleu
    ];
    
    const seedArticles = [
      {
        title: 'Bienvenue dans notre nouvelle plateforme',
        content: '<h2>Une nouvelle ère commence</h2><p>Nous sommes ravis de vous présenter notre nouvelle plateforme de gestion d\'entreprise. Cette solution innovante vous permettra de gérer efficacement vos employés, vos projets et votre communication interne.</p><h3>Fonctionnalités principales</h3><ul><li>Gestion des employés</li><li>Système de blog d\'entreprise</li><li>Bibliothèque de médias</li><li>Certificats numériques</li></ul>',
        summary: 'Découvrez notre nouvelle plateforme de gestion d\'entreprise avec toutes ses fonctionnalités innovantes.',
        published: true,
        tags: ['annonce', 'plateforme', 'nouveau'],
        mediaFiles: [
          {
            filename: 'welcome-image.png',
            url: testImages[0],
            type: 'image'
          },
          {
            filename: 'dashboard-preview.png',
            url: testImages[1],
            type: 'image'
          }
        ]
      },
      {
        title: 'Guide de démarrage rapide',
        content: '<h2>Comment commencer ?</h2><p>Ce guide vous aidera à prendre en main rapidement notre plateforme.</p><h3>Étapes à suivre</h3><ol><li>Créer votre profil</li><li>Ajouter vos employés</li><li>Configurer les paramètres</li><li>Commencer à utiliser les fonctionnalités</li></ol><p>N\'hésitez pas à consulter la documentation complète pour plus de détails.</p>',
        summary: 'Un guide simple pour débuter avec notre plateforme en quelques étapes.',
        published: true,
        tags: ['guide', 'démarrage', 'tutoriel'],
        mediaFiles: [
          {
            filename: 'guide-step1.png',
            url: testImages[2],
            type: 'image'
          }
        ]
      },
      {
        title: 'Nouveautés de la version 2.0',
        content: '<h2>Quoi de neuf ?</h2><p>La version 2.0 apporte de nombreuses améliorations et nouvelles fonctionnalités.</p><h3>Nouvelles fonctionnalités</h3><ul><li>Interface utilisateur redessinée</li><li>Meilleure performance</li><li>Nouvelles options de personnalisation</li><li>Support multi-langue</li></ul><blockquote>Cette mise à jour révolutionnaire améliore considérablement l\'expérience utilisateur.</blockquote>',
        summary: 'Découvrez toutes les nouveautés et améliorations de notre dernière version.',
        published: false, // Brouillon
        tags: ['version', 'nouveautés', 'mise-à-jour'],
        mediaFiles: [
          {
            filename: 'v2-features.png',
            url: testImages[0],
            type: 'image'
          },
          {
            filename: 'new-ui.png',
            url: testImages[1],
            type: 'image'
          },
          {
            filename: 'performance-chart.png',
            url: testImages[2],
            type: 'image'
          }
        ]
      }
    ];
    
    // Créer les articles de test
    const createdArticles = [];
    for (const articleData of seedArticles) {
      const article = new Article({
        ...articleData,
        authorId: req.user._id
      });
      await article.save();
      createdArticles.push(article);
    }
    
    console.log(`✅ Created ${createdArticles.length} seed articles`);
    
    res.json({
      message: `${createdArticles.length} articles de test créés`,
      articles: createdArticles.map(a => ({ id: a._id, title: a.title }))
    });
  } catch (err) {
    console.error('❌ Seed data error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/blog/stats : Statistiques des articles (optionnel)
app.get('/api/blog/stats', authMiddleware, async (req, res) => {
  try {
    console.log(`📊 Get blog stats for ${req.user.email}`);
    
    const totalArticles = await Article.countDocuments();
    const publishedArticles = await Article.countDocuments({ published: true });
    const draftArticles = await Article.countDocuments({ published: false });
    const myArticles = await Article.countDocuments({ authorId: req.user._id });
    
    res.json({
      total: totalArticles,
      published: publishedArticles,
      drafts: draftArticles,
      myArticles: myArticles
    });
  } catch (err) {
    console.error('❌ Get blog stats error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ==========================================
// ROUTES MÉDIAS - Gestion séparée des médias
// ==========================================

// POST /api/media/upload : Uploader un nouveau média avec métadonnées
app.post('/api/media/upload', authMiddleware, permissionMiddleware('media'), upload.array('files', 10), async (req, res) => {
  try {
    console.log(`📎 Media upload by ${req.user.email}`);
    
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: 'Aucun fichier téléchargé' });
    }
    
    const { titles, descriptions, tags } = req.body;
    const titlesArray = Array.isArray(titles) ? titles : [titles];
    const descriptionsArray = Array.isArray(descriptions) ? descriptions : [descriptions];
    const tagsArray = Array.isArray(tags) ? tags : [tags];
    
    const uploadedMedias = [];
    
    for (let i = 0; i < req.files.length; i++) {
      const file = req.files[i];
      const fileUrl = `${getBaseUrl(req)}/uploads/${file.filename}`;
      
      // Détection intelligente du type
      let mediaType = getMediaTypeFromMimetype(file.mimetype);
      if (mediaType === 'document' && file.mimetype === 'application/octet-stream') {
        // Fallback sur l'extension si mimetype n'est pas fiable
        mediaType = getMediaTypeFromExtension(file.originalname);
      }
      
      console.log(`🔍 File type detection: ${file.originalname} (${file.mimetype}) -> ${mediaType}`);
      
      const media = new Media({
        title: titlesArray[i] || file.originalname,
        description: descriptionsArray[i] || '',
        filename: file.filename,
        originalName: file.originalname,
        url: fileUrl,
        mimetype: file.mimetype,
        size: file.size,
        type: mediaType,
        tags: tagsArray[i] ? tagsArray[i].split(',').map(t => t.trim()) : [],
        uploadedBy: req.user._id,
        isPublic: true
      });
      
      await media.save();
      uploadedMedias.push(media);
      
      // Envoyer notification automatique pour le nouveau média
      const uploaderName = `${req.user.firstName || ''} ${req.user.lastName || ''}`.trim() || req.user.email;
      await sendAutoNotification('media', {
        filename: media.originalName,
        type: media.mimetype,
        uploadedBy: uploaderName,
        mediaId: media._id
      });
      
      console.log(`✅ Media saved: ${media.title} (${media.type}) -> ${fileUrl}`);
    }
    
    res.json({
      message: 'Médias téléchargés avec succès',
      medias: uploadedMedias
    });
  } catch (err) {
    console.error('❌ Media upload error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/media/feed : Feed social avec médias de tous les utilisateurs
app.get('/api/media/feed', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    
    console.log(`📱 Get social feed for ${req.user.email}`);
    
    const limitNum = parseInt(limit);
    const skip = (parseInt(page) - 1) * limitNum;
    
    // Récupérer les médias de tous les utilisateurs avec informations de profil
    const medias = await Media.aggregate([
      {
        $lookup: {
          from: 'users',
          localField: 'uploadedBy',
          foreignField: '_id',
          as: 'user'
        }
      },
      {
        $unwind: '$user'
      },
      {
        $project: {
          _id: 1,
          title: 1,
          description: 1,
          filename: 1,
          originalName: 1,
          url: 1,
          mimetype: 1,
          size: 1,
          type: 1,
          tags: 1,
          isPublic: 1,
          usageCount: 1,
          createdAt: 1,
          updatedAt: 1,
          uploadedBy: 1,
          'user._id': 1,
          'user.name': 1,
          'user.email': 1,
          'user.profilePhoto': 1,
          'user.role': 1
        }
      },
      {
        $sort: { createdAt: -1 }
      },
      {
        $skip: skip
      },
      {
        $limit: limitNum
      }
    ]);
    
    const total = await Media.countDocuments({});
    
    console.log(`✅ Found ${medias.length} medias for social feed`);
    
    res.json({
      medias,
      pagination: {
        page: parseInt(page),
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum)
      }
    });
  } catch (err) {
    console.error('❌ Social feed error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/feed/social : Feed social combiné (articles + médias) avec profils utilisateurs
app.get('/api/feed/social', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    
    console.log(`🌐 Get combined social feed for ${req.user.email}`);
    
    const limitNum = parseInt(limit);
    const skip = (parseInt(page) - 1) * limitNum;
    
    // Récupérer les articles avec informations utilisateur et stats
    const articles = await Article.aggregate([
      {
        $lookup: {
          from: 'users',
          localField: 'authorId',
          foreignField: '_id',
          as: 'author'
        }
      },
      {
        $unwind: '$author'
      },
      {
        $match: { published: true } // Seulement les articles publiés
      },
      {
        $lookup: {
          from: 'contentstats',
          let: { articleId: '$_id' },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    { $eq: ['$contentId', '$$articleId'] },
                    { $eq: ['$contentType', 'article'] }
                  ]
                }
              }
            }
          ],
          as: 'stats'
        }
      },
      {
        $project: {
          _id: 1,
          title: 1,
          summary: 1,
          content: { $substr: ['$content', 0, 200] }, // Tronquer le contenu pour le feed
          tags: 1,
          mediaFiles: 1,
          createdAt: 1,
          type: { $literal: 'article' }, // Ajouter type pour différencier
          'author._id': 1,
          'author.name': 1,
          'author.email': 1,
          'author.profilePhoto': 1,
          'author.role': 1,
          likesCount: { $ifNull: [{ $arrayElemAt: ['$stats.likesCount', 0] }, 0] },
          commentsCount: { $ifNull: [{ $arrayElemAt: ['$stats.commentsCount', 0] }, 0] },
          viewsCount: { $ifNull: [{ $arrayElemAt: ['$stats.viewsCount', 0] }, 0] }
        }
      },
      {
        $sort: { createdAt: -1 }
      },
      {
        $limit: Math.ceil(limitNum / 2) // Moitié d'articles
      }
    ]);
    
    // Récupérer les médias avec informations utilisateur et stats
    const medias = await Media.aggregate([
      {
        $lookup: {
          from: 'users',
          localField: 'uploadedBy',
          foreignField: '_id',
          as: 'author'
        }
      },
      {
        $unwind: '$author'
      },
      {
        $lookup: {
          from: 'contentstats',
          let: { mediaId: '$_id' },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    { $eq: ['$contentId', '$$mediaId'] },
                    { $eq: ['$contentType', 'media'] }
                  ]
                }
              }
            }
          ],
          as: 'stats'
        }
      },
      {
        $project: {
          _id: 1,
          title: 1,
          description: 1,
          url: 1,
          mimetype: 1,
          type: 1,
          tags: 1,
          createdAt: 1,
          feedType: { $literal: 'media' }, // Ajouter type pour différencier
          'author._id': 1,
          'author.name': 1,
          'author.email': 1,
          'author.profilePhoto': 1,
          'author.role': 1,
          likesCount: { $ifNull: [{ $arrayElemAt: ['$stats.likesCount', 0] }, 0] },
          commentsCount: { $ifNull: [{ $arrayElemAt: ['$stats.commentsCount', 0] }, 0] },
          viewsCount: { $ifNull: [{ $arrayElemAt: ['$stats.viewsCount', 0] }, 0] }
        }
      },
      {
        $sort: { createdAt: -1 }
      },
      {
        $limit: Math.ceil(limitNum / 2) // Moitié de médias
      }
    ]);
    
    // Combiner et trier par date
    let combinedFeed = [...articles, ...medias]
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, limitNum);
    
    // Ajouter les informations de like pour l'utilisateur actuel
    const userId = req.userId;
    for (let item of combinedFeed) {
      const targetType = item.type || item.feedType;
      const userLike = await Like.findOne({
        userId,
        targetType: targetType === 'media' ? 'media' : 'article',
        targetId: item._id,
        isActive: true
      });
      item.isLiked = !!userLike;
    }
    
    const totalArticles = await Article.countDocuments({ published: true });
    const totalMedias = await Media.countDocuments({});
    const total = totalArticles + totalMedias;
    
    console.log(`✅ Combined feed: ${articles.length} articles + ${medias.length} medias = ${combinedFeed.length} items`);
    
    res.json({
      feed: combinedFeed,
      pagination: {
        page: parseInt(page),
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum)
      },
      stats: {
        articles: articles.length,
        medias: medias.length
      }
    });
  } catch (err) {
    console.error('❌ Combined social feed error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/feed/unified : Feed unifié optimisé (articles + médias + blogs)
app.get('/api/feed/unified', authMiddleware, async (req, res) => {
  try {
    const { 
      page = 1, 
      limit = 20, 
      search = '', 
      includeMedia = 'true',
      includeArticles = 'true',
      includeBlog = 'true'
    } = req.query;
    
    console.log(`🚀 Unified feed request: page=${page}, limit=${limit}, search="${search}"`);
    
    const limitNum = parseInt(limit);
    const skip = (parseInt(page) - 1) * limitNum;
    const userId = req.userId;
    
    // Construire la requête de recherche si fournie
    const searchFilter = search ? {
      $or: [
        { title: { $regex: search, $options: 'i' } },
        { content: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
        { tags: { $in: [new RegExp(search, 'i')] } }
      ]
    } : {};
    
    const results = { articles: [], medias: [], blogs: [] };
    
    // Pipeline optimisé pour les articles
    if (includeArticles === 'true') {
      const articlePipeline = [
        { $match: { published: true, ...searchFilter } },
        {
          $lookup: {
            from: 'users',
            localField: 'authorId',
            foreignField: '_id',
            as: 'author'
          }
        },
        { $unwind: { path: '$author', preserveNullAndEmptyArrays: true } },
        {
          $lookup: {
            from: 'contentstats',
            let: { contentId: '$_id' },
            pipeline: [
              { $match: { $expr: { $and: [{ $eq: ['$contentId', '$$contentId'] }, { $eq: ['$contentType', 'article'] }] } } }
            ],
            as: 'stats'
          }
        },
        {
          $lookup: {
            from: 'likes',
            let: { contentId: '$_id' },
            pipeline: [
              { $match: { $expr: { $and: [{ $eq: ['$targetId', '$$contentId'] }, { $eq: ['$targetType', 'article'] }, { $eq: ['$userId', userId] }, { $eq: ['$isActive', true] }] } } }
            ],
            as: 'userLike'
          }
        },
        {
          $project: {
            title: 1,
            content: { $substr: ['$content', 0, 300] },
            description: 1,
            tags: 1,
            mediaFiles: 1,
            createdAt: 1,
            updatedAt: 1,
            feedType: { $literal: 'article' },
            author: {
              _id: '$author._id',
              name: '$author.name',
              email: '$author.email',
              profilePhoto: '$author.profilePhoto',
              role: '$author.role'
            },
            likesCount: { $ifNull: [{ $arrayElemAt: ['$stats.likesCount', 0] }, 0] },
            commentsCount: { $ifNull: [{ $arrayElemAt: ['$stats.commentsCount', 0] }, 0] },
            viewsCount: { $ifNull: [{ $arrayElemAt: ['$stats.viewsCount', 0] }, 0] },
            isLiked: { $gt: [{ $size: '$userLike' }, 0] }
          }
        },
        { $sort: { createdAt: -1 } },
        { $limit: Math.ceil(limitNum * 0.4) } // 40% articles
      ];
      
      results.articles = await Article.aggregate(articlePipeline);
    }
    
    // Pipeline optimisé pour les médias
    if (includeMedia === 'true') {
      const mediaPipeline = [
        { $match: { ...searchFilter } },
        {
          $lookup: {
            from: 'users',
            localField: 'uploadedBy',
            foreignField: '_id',
            as: 'uploader'
          }
        },
        { $unwind: { path: '$uploader', preserveNullAndEmptyArrays: true } },
        {
          $lookup: {
            from: 'contentstats',
            let: { contentId: '$_id' },
            pipeline: [
              { $match: { $expr: { $and: [{ $eq: ['$contentId', '$$contentId'] }, { $eq: ['$contentType', 'media'] }] } } }
            ],
            as: 'stats'
          }
        },
        {
          $lookup: {
            from: 'likes',
            let: { contentId: '$_id' },
            pipeline: [
              { $match: { $expr: { $and: [{ $eq: ['$targetId', '$$contentId'] }, { $eq: ['$targetType', 'media'] }, { $eq: ['$userId', userId] }, { $eq: ['$isActive', true] }] } } }
            ],
            as: 'userLike'
          }
        },
        {
          $project: {
            title: 1,
            description: 1,
            filename: 1,
            originalName: 1,
            url: 1,
            mimetype: 1,
            type: 1,
            size: 1,
            tags: 1,
            isPublic: 1,
            usageCount: 1,
            createdAt: 1,
            updatedAt: 1,
            feedType: { $literal: 'media' },
            uploadedBy: {
              _id: '$uploader._id',
              name: '$uploader.name',
              email: '$uploader.email',
              profilePhoto: '$uploader.profilePhoto',
              role: '$uploader.role'
            },
            likesCount: { $ifNull: [{ $arrayElemAt: ['$stats.likesCount', 0] }, 0] },
            commentsCount: { $ifNull: [{ $arrayElemAt: ['$stats.commentsCount', 0] }, 0] },
            viewsCount: { $ifNull: ['$usageCount', 0] },
            isLiked: { $gt: [{ $size: '$userLike' }, 0] }
          }
        },
        { $sort: { createdAt: -1 } },
        { $limit: Math.ceil(limitNum * 0.5) } // 50% médias
      ];
      
      results.medias = await Media.aggregate(mediaPipeline);
    }
    
    // TODO: Pipeline pour les blogs quand le modèle sera prêt
    if (includeBlog === 'true') {
      results.blogs = [];
    }
    
    // Calculer les totaux pour la pagination
    const totalPromises = [];
    if (includeArticles === 'true') {
      totalPromises.push(Article.countDocuments({ published: true, ...searchFilter }));
    } else {
      totalPromises.push(Promise.resolve(0));
    }
    
    if (includeMedia === 'true') {
      totalPromises.push(Media.countDocuments(searchFilter));
    } else {
      totalPromises.push(Promise.resolve(0));
    }
    
    const [totalArticles, totalMedias] = await Promise.all(totalPromises);
    const totalItems = totalArticles + totalMedias;
    
    console.log(`✅ Unified feed: ${results.articles.length} articles + ${results.medias.length} medias + ${results.blogs.length} blogs`);
    
    res.json({
      articles: results.articles,
      medias: results.medias,
      blogs: results.blogs,
      pagination: {
        page: parseInt(page),
        limit: limitNum,
        total: totalItems,
        pages: Math.ceil(totalItems / limitNum),
        hasMore: (parseInt(page) * limitNum) < totalItems
      },
      stats: {
        totalArticles,
        totalMedias,
        totalBlogs: results.blogs.length,
        currentPage: {
          articles: results.articles.length,
          medias: results.medias.length,
          blogs: results.blogs.length
        }
      }
    });
    
  } catch (err) {
    console.error('❌ Unified feed error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/search : Recherche rapide dans tous les contenus
app.get('/api/search', authMiddleware, async (req, res) => {
  try {
    const { q: query, limit = 20, includeAll = 'false' } = req.query;
    
    if (!query || query.trim().length < 2) {
      return res.json({ articles: [], medias: [], blogs: [], total: 0 });
    }
    
    console.log(`🔍 Quick search for: "${query}"`);
    
    const limitNum = parseInt(limit);
    const userId = req.userId;
    
    const searchFilter = {
      $or: [
        { title: { $regex: query, $options: 'i' } },
        { content: { $regex: query, $options: 'i' } },
        { description: { $regex: query, $options: 'i' } },
        { tags: { $in: [new RegExp(query, 'i')] } }
      ]
    };
    
    // Recherche dans les articles
    const articles = await Article.aggregate([
      { $match: { published: true, ...searchFilter } },
      {
        $lookup: {
          from: 'users',
          localField: 'authorId',
          foreignField: '_id',
          as: 'author'
        }
      },
      { $unwind: { path: '$author', preserveNullAndEmptyArrays: true } },
      {
        $project: {
          title: 1,
          content: { $substr: ['$content', 0, 200] },
          tags: 1,
          createdAt: 1,
          feedType: { $literal: 'article' },
          author: {
            _id: '$author._id',
            name: '$author.name',
            email: '$author.email',
            role: '$author.role'
          }
        }
      },
      { $sort: { createdAt: -1 } },
      { $limit: Math.ceil(limitNum / 3) }
    ]);
    
    // Recherche dans les médias
    const medias = await Media.aggregate([
      { $match: searchFilter },
      {
        $lookup: {
          from: 'users',
          localField: 'uploadedBy',
          foreignField: '_id',
          as: 'uploader'
        }
      },
      { $unwind: { path: '$uploader', preserveNullAndEmptyArrays: true } },
      {
        $project: {
          title: 1,
          description: 1,
          url: 1,
          mimetype: 1,
          type: 1,
          tags: 1,
          createdAt: 1,
          feedType: { $literal: 'media' },
          uploadedBy: {
            _id: '$uploader._id',
            name: '$uploader.name',
            email: '$uploader.email',
            role: '$uploader.role'
          }
        }
      },
      { $sort: { createdAt: -1 } },
      { $limit: Math.ceil(limitNum / 3) }
    ]);
    
    const blogs = []; // Placeholder pour les blogs
    
    console.log(`✅ Search results: ${articles.length} articles + ${medias.length} medias`);
    
    res.json({
      articles,
      medias,
      blogs,
      total: articles.length + medias.length + blogs.length,
      query
    });
    
  } catch (err) {
    console.error('❌ Search error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/media : Récupérer tous les médias de l'utilisateur
app.get('/api/media', authMiddleware, async (req, res) => {
  try {
    const { type, tags, page = 1, limit = 20, search } = req.query;
    
    console.log(`📂 Get medias for ${req.user.email}`);
    
    const filter = { uploadedBy: req.user._id };
    
    if (type && type !== 'all') {
      filter.type = type;
    }
    
    if (tags) {
      filter.tags = { $in: tags.split(',') };
    }
    
    if (search) {
      filter.$or = [
        { title: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } }
      ];
    }
    
    const limitNum = parseInt(limit);
    const skip = (parseInt(page) - 1) * limitNum;
    
    const medias = await Media.find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();
    
    const total = await Media.countDocuments(filter);
    
    console.log(`✅ Found ${medias.length} medias`);
    
    res.json({
      medias,
      pagination: {
        page: parseInt(page),
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum)
      }
    });
  } catch (err) {
    console.error('❌ Get medias error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/media/stats : Statistiques des médias
app.get('/api/media/stats', authMiddleware, async (req, res) => {
  try {
    console.log(`📊 Get media stats for ${req.user.email}`);
    
    const stats = await Media.aggregate([
      { $match: { uploadedBy: req.user._id } },
      {
        $group: {
          _id: '$type',
          count: { $sum: 1 },
          totalSize: { $sum: '$size' }
        }
      }
    ]);
    
    const totalMedias = await Media.countDocuments({ uploadedBy: req.user._id });
    const totalSize = await Media.aggregate([
      { $match: { uploadedBy: req.user._id } },
      { $group: { _id: null, total: { $sum: '$size' } } }
    ]);
    
    // Statistiques par mois (derniers 6 mois)
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
    
    const monthlyStats = await Media.aggregate([
      { 
        $match: { 
          uploadedBy: req.user._id,
          createdAt: { $gte: sixMonthsAgo }
        } 
      },
      {
        $group: {
          _id: {
            year: { $year: '$createdAt' },
            month: { $month: '$createdAt' }
          },
          count: { $sum: 1 },
          size: { $sum: '$size' }
        }
      },
      { $sort: { '_id.year': 1, '_id.month': 1 } }
    ]);
    
    // Tags les plus utilisés
    const popularTags = await Media.aggregate([
      { $match: { uploadedBy: req.user._id } },
      { $unwind: '$tags' },
      { $group: { _id: '$tags', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 10 }
    ]);
    
    console.log(`✅ Stats calculated: ${totalMedias} total medias`);
    
    res.json({
      totalMedias,
      totalSize: totalSize[0]?.total || 0,
      byType: stats,
      monthlyStats,
      popularTags
    });
  } catch (err) {
    console.error('❌ Media stats error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/media/search : Recherche avancée de médias
app.get('/api/media/search', authMiddleware, async (req, res) => {
  try {
    const { 
      q, 
      type, 
      tags, 
      dateFrom, 
      dateTo, 
      sizeMin, 
      sizeMax, 
      page = 1, 
      limit = 20,
      sortBy = 'createdAt',
      sortOrder = 'desc'
    } = req.query;
    
    console.log(`🔍 Advanced search by ${req.user.email}: "${q}"`);
    
    const filter = { uploadedBy: req.user._id };
    
    // Recherche textuelle
    if (q) {
      filter.$or = [
        { title: { $regex: q, $options: 'i' } },
        { description: { $regex: q, $options: 'i' } },
        { originalName: { $regex: q, $options: 'i' } }
      ];
    }
    
    // Filtre par type
    if (type && type !== 'all') {
      filter.type = type;
    }
    
    // Filtre par tags
    if (tags) {
      filter.tags = { $in: tags.split(',').map(t => t.trim()) };
    }
    
    // Filtre par date
    if (dateFrom || dateTo) {
      filter.createdAt = {};
      if (dateFrom) filter.createdAt.$gte = new Date(dateFrom);
      if (dateTo) filter.createdAt.$lte = new Date(dateTo);
    }
    
    // Filtre par taille
    if (sizeMin || sizeMax) {
      filter.size = {};
      if (sizeMin) filter.size.$gte = parseInt(sizeMin);
      if (sizeMax) filter.size.$lte = parseInt(sizeMax);
    }
    
    const limitNum = parseInt(limit);
    const skip = (parseInt(page) - 1) * limitNum;
    
    // Tri
    const sort = {};
    sort[sortBy] = sortOrder === 'desc' ? -1 : 1;
    
    const medias = await Media.find(filter)
      .sort(sort)
      .skip(skip)
      .limit(limitNum)
      .lean();
    
    const total = await Media.countDocuments(filter);
    
    console.log(`✅ Search completed: ${medias.length} results found`);
    
    res.json({
      medias,
      pagination: {
        page: parseInt(page),
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum)
      }
    });
  } catch (err) {
    console.error('❌ Advanced search error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/media/tags : Récupérer tous les tags disponibles
app.get('/api/media/tags', authMiddleware, async (req, res) => {
  try {
    console.log(`🏷️ Get all tags for ${req.user.email}`);
    
    const tags = await Media.aggregate([
      { $match: { uploadedBy: req.user._id } },
      { $unwind: '$tags' },
      { 
        $group: { 
          _id: '$tags', 
          count: { $sum: 1 },
          lastUsed: { $max: '$createdAt' }
        } 
      },
      { $sort: { count: -1 } }
    ]);
    
    console.log(`✅ Found ${tags.length} unique tags`);
    
    res.json({ tags });
  } catch (err) {
    console.error('❌ Get tags error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/media/:id : Récupérer un média spécifique
app.get('/api/media/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    
    const media = await Media.findOne({
      _id: id,
      $or: [
        { uploadedBy: req.user._id },
        { isPublic: true }
      ]
    });
    
    if (!media) {
      return res.status(404).json({ error: 'Média non trouvé' });
    }
    
    res.json(media);
  } catch (err) {
    console.error('❌ Get media error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/media/:id : Mettre à jour un média
app.put('/api/media/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, tags, isPublic } = req.body;
    
    const media = await Media.findOne({
      _id: id,
      uploadedBy: req.user._id
    });
    
    if (!media) {
      return res.status(404).json({ error: 'Média non trouvé' });
    }
    
    const updates = {};
    if (title) updates.title = title;
    if (description !== undefined) updates.description = description;
    if (tags) updates.tags = tags.split(',').map(t => t.trim());
    if (isPublic !== undefined) updates.isPublic = isPublic;
    
    const updatedMedia = await Media.findByIdAndUpdate(id, updates, { new: true });
    
    console.log(`✅ Media updated: ${updatedMedia.title}`);
    
    res.json({
      message: 'Média mis à jour avec succès',
      media: updatedMedia
    });
  } catch (err) {
    console.error('❌ Update media error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/media/:id : Supprimer un média
app.delete('/api/media/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    
    const media = await Media.findOne({
      _id: id,
      uploadedBy: req.user._id
    });
    
    if (!media) {
      return res.status(404).json({ error: 'Média non trouvé' });
    }
    
    // Supprimer le fichier physique
    const fs = require('fs');
    const filePath = path.join(__dirname, 'uploads', media.filename);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      console.log(`🗑️ File deleted: ${filePath}`);
    }
    
    await Media.findByIdAndDelete(id);
    
    console.log(`✅ Media deleted: ${media.title}`);
    
    res.json({ message: 'Média supprimé avec succès' });
  } catch (err) {
    console.error('❌ Delete media error:', err.message);
    res.status(500).json({ error: err.message });
  }
});


// POST /api/media/bulk-action : Actions en lot sur les médias
app.post('/api/media/bulk-action', authMiddleware, async (req, res) => {
  try {
    const { action, mediaIds, data } = req.body;
    
    if (!action || !mediaIds || !Array.isArray(mediaIds)) {
      return res.status(400).json({ error: 'Action et IDs requis' });
    }
    
    console.log(`🔄 Bulk action ${action} on ${mediaIds.length} medias by ${req.user.email}`);
    
    const filter = {
      _id: { $in: mediaIds },
      uploadedBy: req.user._id
    };
    
    let result;
    
    switch (action) {
      case 'delete':
        // Récupérer les médias pour supprimer les fichiers
        const mediasToDelete = await Media.find(filter);
        
        // Supprimer les fichiers physiques
        for (const media of mediasToDelete) {
          const filePath = path.join(__dirname, 'uploads', media.filename);
          if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
            console.log(`🗑️ File deleted: ${filePath}`);
          }
        }
        
        result = await Media.deleteMany(filter);
        break;
        
      case 'updateTags':
        if (!data.tags) {
          return res.status(400).json({ error: 'Tags requis pour cette action' });
        }
        result = await Media.updateMany(filter, {
          $set: { tags: data.tags.split(',').map(t => t.trim()) }
        });
        break;
        
      case 'setPublic':
        result = await Media.updateMany(filter, {
          $set: { isPublic: data.isPublic !== false }
        });
        break;
        
      case 'addTags':
        if (!data.tags) {
          return res.status(400).json({ error: 'Tags requis pour cette action' });
        }
        result = await Media.updateMany(filter, {
          $addToSet: { tags: { $each: data.tags.split(',').map(t => t.trim()) } }
        });
        break;
        
      default:
        return res.status(400).json({ error: 'Action non supportée' });
    }
    
    console.log(`✅ Bulk action completed: ${result.modifiedCount || result.deletedCount} items affected`);
    
    res.json({
      message: `Action ${action} exécutée avec succès`,
      affected: result.modifiedCount || result.deletedCount
    });
  } catch (err) {
    console.error('❌ Bulk action error:', err.message);
    res.status(500).json({ error: err.message });
  }
});





// POST /api/media/:id/use : Marquer un média comme utilisé (incrémente le compteur)
app.post('/api/media/:id/use', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    
    const media = await Media.findOneAndUpdate(
      {
        _id: id,
        $or: [
          { uploadedBy: req.user._id },
          { isPublic: true }
        ]
      },
      { $inc: { usageCount: 1 } },
      { new: true }
    );
    
    if (!media) {
      return res.status(404).json({ error: 'Média non trouvé' });
    }
    
    console.log(`📈 Media usage incremented: ${media.title} (${media.usageCount} uses)`);
    
    res.json({
      message: 'Utilisation enregistrée',
      usageCount: media.usageCount
    });
  } catch (err) {
    console.error('❌ Record usage error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ========================
// ROUTES D'ADMINISTRATION
// ========================

// Middleware pour vérifier si l'utilisateur est admin
const adminMiddleware = async (req, res, next) => {
  try {
    if (req.user.email !== 'nyundumathryme@gmail.com' && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Accès administrateur requis' });
    }
    next();
  } catch (error) {
    res.status(500).json({ error: 'Erreur de vérification admin' });
  }
};

// GET /api/admin/users : Lister tous les utilisateurs (admin seulement)
app.get('/api/admin/users', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    console.log(`👥 Admin ${req.user.email} fetching all users`);
    
    const users = await User.find({})
      .select('-password -otp -tokens')
      .sort({ createdAt: -1 });
    
    console.log(`✅ Found ${users.length} users`);
    res.json({ users });
  } catch (error) {
    console.error('❌ Error fetching users:', error);
    res.status(500).json({ error: 'Erreur lors de la récupération des utilisateurs' });
  }
});

// PUT /api/admin/users/:id/status : Modifier le statut d'un utilisateur
app.put('/api/admin/users/:id/status', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    if (!['active', 'blocked', 'suspended'].includes(status)) {
      return res.status(400).json({ error: 'Statut invalide' });
    }
    
    console.log(`🔧 Admin ${req.user.email} changing user ${id} status to ${status}`);
    
    const user = await User.findByIdAndUpdate(
      id,
      { status },
      { new: true }
    ).select('-password -otp -tokens');
    
    if (!user) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }
    
    console.log(`✅ User ${user.email} status changed to ${status}`);
    res.json({ message: 'Statut mis à jour', user });
  } catch (error) {
    console.error('❌ Error updating user status:', error);
    res.status(500).json({ error: 'Erreur lors de la mise à jour du statut' });
  }
});

// PUT /api/admin/users/:id/permissions : Modifier les permissions d'un utilisateur
app.put('/api/admin/users/:id/permissions', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { permissions } = req.body;
    
    console.log(`🔧 Admin ${req.user.email} updating permissions for user ${id}`);
    
    const user = await User.findByIdAndUpdate(
      id,
      { permissions },
      { new: true }
    ).select('-password -otp -tokens');
    
    if (!user) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }
    
    console.log(`✅ Permissions updated for ${user.email}`);
    res.json({ message: 'Permissions mises à jour', user });
  } catch (error) {
    console.error('❌ Error updating permissions:', error);
    res.status(500).json({ error: 'Erreur lors de la mise à jour des permissions' });
  }
});

// DELETE /api/admin/users/:id : Supprimer un utilisateur
app.delete('/api/admin/users/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    
    console.log(`🗑️ Admin ${req.user.email} deleting user ${id}`);
    
    const user = await User.findById(id);
    if (!user) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }
    
    // Empêcher la suppression de l'admin principal
    if (user.email === 'nyundumathryme@gmail.com') {
      return res.status(403).json({ error: 'Impossible de supprimer l\'administrateur principal' });
    }
    
    await User.findByIdAndDelete(id);
    
    console.log(`✅ User ${user.email} deleted successfully`);
    res.json({ message: 'Utilisateur supprimé avec succès' });
  } catch (error) {
    console.error('❌ Error deleting user:', error);
    res.status(500).json({ error: 'Erreur lors de la suppression de l\'utilisateur' });
  }
});

// PUT /api/admin/users/:id/role : Modifier le rôle d'un utilisateur
app.put('/api/admin/users/:id/role', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.body;
    
    if (!['user', 'admin'].includes(role)) {
      return res.status(400).json({ error: 'Rôle invalide' });
    }
    
    console.log(`🔧 Admin ${req.user.email} changing user ${id} role to ${role}`);
    
    const user = await User.findByIdAndUpdate(
      id,
      { role },
      { new: true }
    ).select('-password -otp -tokens');
    
    if (!user) {
      return res.status(404).json({ error: 'Utilisateur non trouvé' });
    }
    
    console.log(`✅ User ${user.email} role changed to ${role}`);
    res.json({ message: 'Rôle mis à jour', user });
  } catch (error) {
    console.error('❌ Error updating user role:', error);
    res.status(500).json({ error: 'Erreur lors de la mise à jour du rôle' });
  }
});

// Migration des permissions pour les utilisateurs existants
const migrateUserPermissions = async () => {
  try {
    const users = await User.find({});
    let updated = 0;
    
    for (const user of users) {
      const isAdmin = user.email === 'nyundumathryme@gmail.com' || user.role === 'admin';
      
      // Vérifier si l'utilisateur a des permissions dans l'ancien format
      if (!user.permissions || (!user.permissions.hasOwnProperty('canCreateArticles'))) {
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
        updated++;
        console.log(`✅ Permissions mises à jour pour: ${user.email}`);
      }
    }
    
    if (updated > 0) {
      console.log(`✅ ${updated} utilisateur(s) mis à jour avec les nouvelles permissions`);
    }
  } catch (error) {
    console.error('❌ Erreur lors de la migration des permissions:', error);
  }
};

// ===================================
// ROUTES POUR LES INTERACTIONS SOCIALES
// ===================================

// POST /api/likes : Ajouter/Retirer un like
app.post('/api/likes', authMiddleware, async (req, res) => {
  try {
    const { targetType, targetId } = req.body;
    const userId = req.userId;

    if (!targetType || !targetId) {
      return res.status(400).json({ error: 'targetType et targetId sont requis' });
    }

    if (!['article', 'media', 'comment'].includes(targetType)) {
      return res.status(400).json({ error: 'targetType invalide' });
    }

    // Vérifier que la cible existe
    let target;
    if (targetType === 'article') {
      target = await Article.findById(targetId);
    } else if (targetType === 'media') {
      target = await Media.findById(targetId);
    } else if (targetType === 'comment') {
      target = await Comment.findById(targetId);
    }

    if (!target) {
      return res.status(404).json({ error: 'Contenu non trouvé' });
    }

    // Chercher un like existant
    const existingLike = await Like.findOne({
      userId,
      targetType,
      targetId
    });

    let action;
    let likesCount;

    if (existingLike) {
      // Toggle du like
      existingLike.isActive = !existingLike.isActive;
      await existingLike.save();
      action = existingLike.isActive ? 'liked' : 'unliked';
    } else {
      // Créer un nouveau like
      await Like.create({
        userId,
        targetType,
        targetId,
        isActive: true
      });
      action = 'liked';
    }

    // Mettre à jour les statistiques
    await updateContentStats(targetType, targetId);
    
    // Récupérer le nouveau nombre de likes
    likesCount = await Like.countDocuments({
      targetType,
      targetId,
      isActive: true
    });

    console.log(`👍 ${action} ${targetType} ${targetId} by user ${userId}`);

    res.json({ 
      message: `Contenu ${action}`,
      action,
      likesCount,
      isLiked: action === 'liked'
    });

  } catch (err) {
    console.error('❌ Like error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/likes/:targetType/:targetId : Obtenir les likes d'un contenu
app.get('/api/likes/:targetType/:targetId', authMiddleware, async (req, res) => {
  try {
    const { targetType, targetId } = req.params;
    const { page = 1, limit = 20 } = req.query;
    const userId = req.userId;

    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Obtenir les likes avec les informations utilisateur
    const likes = await Like.aggregate([
      {
        $match: {
          targetType,
          targetId: new mongoose.Types.ObjectId(targetId),
          isActive: true
        }
      },
      {
        $lookup: {
          from: 'users',
          localField: 'userId',
          foreignField: '_id',
          as: 'user'
        }
      },
      {
        $unwind: '$user'
      },
      {
        $project: {
          _id: 1,
          createdAt: 1,
          'user._id': 1,
          'user.name': 1,
          'user.email': 1,
          'user.profilePhoto': 1,
          'user.role': 1
        }
      },
      {
        $sort: { createdAt: -1 }
      },
      {
        $skip: skip
      },
      {
        $limit: parseInt(limit)
      }
    ]);

    const totalLikes = await Like.countDocuments({
      targetType,
      targetId,
      isActive: true
    });

    // Vérifier si l'utilisateur actuel a liké
    const userLike = await Like.findOne({
      userId,
      targetType,
      targetId,
      isActive: true
    });

    res.json({
      likes,
      totalLikes,
      isLiked: !!userLike,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalLikes,
        pages: Math.ceil(totalLikes / parseInt(limit))
      }
    });

  } catch (err) {
    console.error('❌ Get likes error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/comments : Ajouter un commentaire
app.post('/api/comments', authMiddleware, async (req, res) => {
  try {
    const { content, targetType, targetId, parentCommentId } = req.body;
    const authorId = req.userId;

    if (!content || !targetType || !targetId) {
      return res.status(400).json({ error: 'Contenu, targetType et targetId sont requis' });
    }

    if (!['article', 'media'].includes(targetType)) {
      return res.status(400).json({ error: 'targetType invalide' });
    }

    if (content.length > 1000) {
      return res.status(400).json({ error: 'Commentaire trop long (max 1000 caractères)' });
    }

    // Vérifier que la cible existe
    let target;
    if (targetType === 'article') {
      target = await Article.findById(targetId);
    } else {
      target = await Media.findById(targetId);
    }

    if (!target) {
      return res.status(404).json({ error: 'Contenu non trouvé' });
    }

    // Si c'est une réponse, vérifier que le commentaire parent existe
    if (parentCommentId) {
      const parentComment = await Comment.findById(parentCommentId);
      if (!parentComment) {
        return res.status(404).json({ error: 'Commentaire parent non trouvé' });
      }
    }

    // Créer le commentaire
    const comment = await Comment.create({
      content,
      authorId,
      targetType,
      targetId,
      parentCommentId: parentCommentId || null
    });

    // Mettre à jour les statistiques
    await updateContentStats(targetType, targetId);

    // Si c'est une réponse, mettre à jour le compteur du parent
    if (parentCommentId) {
      await Comment.findByIdAndUpdate(
        parentCommentId,
        { $inc: { repliesCount: 1 } }
      );
    }

    // Récupérer le commentaire avec les infos utilisateur
    const populatedComment = await Comment.findById(comment._id).populate('authorId', 'name email profilePhoto role');

    console.log(`💬 New comment on ${targetType} ${targetId} by user ${authorId}`);

    res.status(201).json({
      message: 'Commentaire ajouté',
      comment: populatedComment
    });

  } catch (err) {
    console.error('❌ Comment error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/comments/:targetType/:targetId : Obtenir les commentaires d'un contenu
app.get('/api/comments/:targetType/:targetId', authMiddleware, async (req, res) => {
  try {
    const { targetType, targetId } = req.params;
    const { page = 1, limit = 20, parentId } = req.query;

    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Construire le match selon si on veut les commentaires principaux ou les réponses
    const matchCondition = {
      targetType,
      targetId: new mongoose.Types.ObjectId(targetId),
      isDeleted: false
    };

    if (parentId === 'null' || !parentId) {
      matchCondition.parentCommentId = null;
    } else {
      matchCondition.parentCommentId = new mongoose.Types.ObjectId(parentId);
    }

    const comments = await Comment.aggregate([
      { $match: matchCondition },
      {
        $lookup: {
          from: 'users',
          localField: 'authorId',
          foreignField: '_id',
          as: 'author'
        }
      },
      { $unwind: '$author' },
      {
        $project: {
          _id: 1,
          content: 1,
          isEdited: 1,
          editedAt: 1,
          likesCount: 1,
          repliesCount: 1,
          createdAt: 1,
          updatedAt: 1,
          parentCommentId: 1,
          'author._id': 1,
          'author.name': 1,
          'author.email': 1,
          'author.profilePhoto': 1,
          'author.role': 1
        }
      },
      { $sort: { createdAt: -1 } },
      { $skip: skip },
      { $limit: parseInt(limit) }
    ]);

    // Ajouter les informations de like pour l'utilisateur actuel
    const userId = req.userId;
    for (let comment of comments) {
      const userLike = await Like.findOne({
        userId,
        targetType: 'comment',
        targetId: comment._id,
        isActive: true
      });
      comment.isLiked = !!userLike;
    }

    const totalComments = await Comment.countDocuments(matchCondition);

    res.json({
      comments,
      totalComments,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalComments,
        pages: Math.ceil(totalComments / parseInt(limit))
      }
    });

  } catch (err) {
    console.error('❌ Get comments error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/comments/:commentId : Modifier un commentaire
app.put('/api/comments/:commentId', authMiddleware, async (req, res) => {
  try {
    const { commentId } = req.params;
    const { content } = req.body;
    const userId = req.userId;

    if (!content) {
      return res.status(400).json({ error: 'Contenu requis' });
    }

    if (content.length > 1000) {
      return res.status(400).json({ error: 'Commentaire trop long (max 1000 caractères)' });
    }

    const comment = await Comment.findById(commentId);
    if (!comment) {
      return res.status(404).json({ error: 'Commentaire non trouvé' });
    }

    if (comment.authorId.toString() !== userId) {
      return res.status(403).json({ error: 'Vous ne pouvez modifier que vos propres commentaires' });
    }

    comment.content = content;
    comment.isEdited = true;
    comment.editedAt = new Date();
    await comment.save();

    res.json({
      message: 'Commentaire modifié',
      comment
    });

  } catch (err) {
    console.error('❌ Edit comment error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/comments/:commentId : Supprimer un commentaire
app.delete('/api/comments/:commentId', authMiddleware, async (req, res) => {
  try {
    const { commentId } = req.params;
    const userId = req.userId;

    const comment = await Comment.findById(commentId);
    if (!comment) {
      return res.status(404).json({ error: 'Commentaire non trouvé' });
    }

    if (comment.authorId.toString() !== userId) {
      return res.status(403).json({ error: 'Vous ne pouvez supprimer que vos propres commentaires' });
    }

    comment.isDeleted = true;
    comment.deletedAt = new Date();
    await comment.save();

    // Mettre à jour les statistiques
    await updateContentStats(comment.targetType, comment.targetId);

    res.json({ message: 'Commentaire supprimé' });

  } catch (err) {
    console.error('❌ Delete comment error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/stats/:targetType/:targetId : Obtenir les statistiques d'un contenu
app.get('/api/stats/:targetType/:targetId', authMiddleware, async (req, res) => {
  try {
    const { targetType, targetId } = req.params;
    const userId = req.userId;

    // Obtenir ou créer les statistiques
    let stats = await ContentStats.findOne({
      contentType: targetType,
      contentId: targetId
    });

    if (!stats) {
      // Calculer les stats en temps réel et créer l'entrée
      const likesCount = await Like.countDocuments({
        targetType,
        targetId,
        isActive: true
      });

      const commentsCount = await Comment.countDocuments({
        targetType,
        targetId,
        isDeleted: false
      });

      stats = await ContentStats.create({
        contentType: targetType,
        contentId: targetId,
        likesCount,
        commentsCount,
        viewsCount: 0,
        sharesCount: 0
      });
    }

    // Vérifier si l'utilisateur actuel a liké
    const userLike = await Like.findOne({
      userId,
      targetType,
      targetId,
      isActive: true
    });

    res.json({
      ...stats.toObject(),
      isLiked: !!userLike
    });

  } catch (err) {
    console.error('❌ Get stats error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ROUTES POUR LES NOTIFICATIONS
// Envoyer notification push à tous les utilisateurs
app.post('/api/notifications/send-to-all', authMiddleware, async (req, res) => {
  try {
    const { title, body, type, data } = req.body;
    
    // Ici on simule l'envoi de notifications push
    // Dans un vrai projet, on utiliserait Firebase Cloud Messaging
    console.log('📱 Envoi notification push:', { title, body, type });
    
    res.json({ 
      success: true, 
      message: 'Notifications push envoyées',
      recipients: 'all_users'
    });
  } catch (error) {
    console.error('❌ Erreur envoi notification push:', error);
    res.status(500).json({ error: 'Erreur lors de l\'envoi des notifications push' });
  }
});

// Envoyer email à tous les utilisateurs
app.post('/api/notifications/send-email-to-all', authMiddleware, async (req, res) => {
  try {
    const { subject, htmlContent, type } = req.body;
    
    // Récupérer tous les utilisateurs actifs
    const users = await User.find({ status: 'active' }, 'email firstName lastName');
    
    if (users.length === 0) {
      return res.json({ success: true, message: 'Aucun utilisateur à notifier' });
    }

    // Configuration du transporteur email
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER || 'votre-email@gmail.com',
        pass: process.env.EMAIL_PASS || 'votre-mot-de-passe'
      }
    });

    // Envoyer l'email à chaque utilisateur
    const emailPromises = users.map(async (user) => {
      try {
        const personalizedContent = htmlContent.replace(
          /\{userName\}/g, 
          `${user.firstName} ${user.lastName}`
        );

        await transporter.sendMail({
          from: process.env.EMAIL_USER || 'noreply@emploi.com',
          to: user.email,
          subject: subject,
          html: personalizedContent
        });

        console.log(`📧 Email envoyé à: ${user.email}`);
        return { email: user.email, status: 'sent' };
      } catch (error) {
        console.error(`❌ Erreur envoi email à ${user.email}:`, error);
        return { email: user.email, status: 'failed', error: error.message };
      }
    });

    const results = await Promise.allSettled(emailPromises);
    const successCount = results.filter(r => r.status === 'fulfilled').length;
    
    console.log(`📊 Emails envoyés: ${successCount}/${users.length}`);
    
    res.json({ 
      success: true, 
      message: `Emails envoyés à ${successCount} utilisateurs`,
      totalUsers: users.length,
      successCount,
      results: results.map(r => r.status === 'fulfilled' ? r.value : null).filter(Boolean)
    });
  } catch (error) {
    console.error('❌ Erreur envoi emails:', error);
    res.status(500).json({ error: 'Erreur lors de l\'envoi des emails' });
  }
});

// S'abonner aux notifications
app.post('/api/notifications/subscribe', authMiddleware, async (req, res) => {
  try {
    const { fcmToken, platform } = req.body;
    const userId = req.user.userId;
    
    // Mettre à jour l'utilisateur avec le token de notification
    await User.findByIdAndUpdate(userId, {
      $set: {
        notificationSettings: {
          fcmToken,
          platform,
          subscribedAt: new Date(),
          pushEnabled: true,
          emailEnabled: true
        }
      }
    });

    console.log(`🔔 Utilisateur ${userId} abonné aux notifications`);
    
    res.json({ 
      success: true, 
      message: 'Abonnement aux notifications réussi' 
    });
  } catch (error) {
    console.error('❌ Erreur abonnement notifications:', error);
    res.status(500).json({ error: 'Erreur lors de l\'abonnement aux notifications' });
  }
});

// Se désabonner des notifications
app.post('/api/notifications/unsubscribe', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    await User.findByIdAndUpdate(userId, {
      $unset: {
        'notificationSettings.fcmToken': 1
      },
      $set: {
        'notificationSettings.pushEnabled': false,
        'notificationSettings.unsubscribedAt': new Date()
      }
    });

    console.log(`🔕 Utilisateur ${userId} désabonné des notifications`);
    
    res.json({ 
      success: true, 
      message: 'Désabonnement des notifications réussi' 
    });
  } catch (error) {
    console.error('❌ Erreur désabonnement notifications:', error);
    res.status(500).json({ error: 'Erreur lors du désabonnement des notifications' });
  }
});

// Fonction utilitaire pour envoyer des notifications automatiques
async function sendAutoNotification(type, data) {
  try {
    let title, subject, htmlContent;
    
    if (type === 'article') {
      title = `📝 Nouvel Article: ${data.title}`;
      subject = `📝 Nouvel Article Publié: ${data.title}`;
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center;">
            <h1 style="margin: 0;">📝 Nouvel Article Publié</h1>
          </div>
          <div style="padding: 20px; background: #f9f9f9;">
            <h2 style="color: #333;">${data.title}</h2>
            <p style="color: #666; font-size: 16px;">Publié par <strong>${data.author}</strong></p>
            <p style="color: #666;">Un nouvel article vient d'être publié sur la plateforme. Connectez-vous pour le découvrir !</p>
            <div style="text-align: center; margin-top: 30px;">
              <a href="http://localhost:3000" style="background: #667eea; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">Voir l'article</a>
            </div>
          </div>
        </div>
      `;
    } else if (type === 'media') {
      const mediaIcon = getMediaIcon(data.type);
      const mediaTypeName = getMediaTypeName(data.type);
      
      title = `${mediaIcon} Nouveau Média: ${data.filename}`;
      subject = `${mediaIcon} Nouveau Média Ajouté: ${data.filename}`;
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 20px; text-align: center;">
            <h1 style="margin: 0;">${mediaIcon} Nouveau Média Ajouté</h1>
          </div>
          <div style="padding: 20px; background: #f9f9f9;">
            <h2 style="color: #333;">${data.filename}</h2>
            <p style="color: #666; font-size: 16px;">Type: <strong>${mediaTypeName}</strong></p>
            <p style="color: #666; font-size: 16px;">Ajouté par: <strong>${data.uploadedBy}</strong></p>
            <p style="color: #666;">Un nouveau média vient d'être ajouté sur la plateforme. Connectez-vous pour le découvrir !</p>
            <div style="text-align: center; margin-top: 30px;">
              <a href="http://localhost:3000" style="background: #f5576c; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">Voir le média</a>
            </div>
          </div>
        </div>
      `;
    }

    // Envoyer les notifications (simulation)
    console.log(`🔔 Notification automatique envoyée: ${title}`);
    
    // Ici on pourrait appeler les vraies APIs de notification
    // await sendPushNotificationToAll(title, data);
    // await sendEmailToAll(subject, htmlContent);
    
  } catch (error) {
    console.error('❌ Erreur notification automatique:', error);
  }
}

// Fonctions utilitaires pour les types de média
function getMediaIcon(type) {
  if (type && type.startsWith('video/')) return '🎥';
  if (type && type.startsWith('audio/')) return '🎵';
  if (type && type.startsWith('image/')) return '🖼️';
  if (type === 'application/pdf') return '📄';
  return '📎';
}

function getMediaTypeName(type) {
  if (type && type.startsWith('video/')) return 'Vidéo';
  if (type && type.startsWith('audio/')) return 'Audio';
  if (type && type.startsWith('image/')) return 'Image';
  if (type === 'application/pdf') return 'PDF';
  return 'Fichier';
}

// Fonction utilitaire pour mettre à jour les statistiques
async function updateContentStats(targetType, targetId) {
  try {
    const likesCount = await Like.countDocuments({
      targetType,
      targetId,
      isActive: true
    });

    const commentsCount = await Comment.countDocuments({
      targetType,
      targetId,
      isDeleted: false
    });

    await ContentStats.findOneAndUpdate(
      {
        contentType: targetType,
        contentId: targetId
      },
      {
        likesCount,
        commentsCount
      },
      {
        upsert: true,
        new: true
      }
    );
  } catch (error) {
    console.error('❌ Error updating content stats:', error);
  }
}

// ========================================
// MODELS POUR CHAT DE GROUPE
// ========================================

// Model pour les messages de chat
const chatMessageSchema = new mongoose.Schema({
  senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  senderName: { type: String, required: true },
  senderPhoto: { type: String, default: '' },
  content: { type: String, default: '' }, // Texte du message
  mediaUrl: { type: String, default: '' }, // URL du média (audio/video/image)
  mediaType: { type: String, enum: ['text', 'image', 'video', 'audio'], default: 'text' },
  fileName: { type: String, default: '' }, // Nom original du fichier
  fileSize: { type: Number, default: 0 }, // Taille du fichier en bytes
  replyTo: { type: mongoose.Schema.Types.ObjectId, ref: 'ChatMessage', default: null }, // ID du message auquel on répond
  replyToContent: { type: String, default: '' }, // Contenu du message original pour affichage
  isEdited: { type: Boolean, default: false },
  editedAt: { type: Date },
  isDeleted: { type: Boolean, default: false },
  deletedAt: { type: Date },
  readBy: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    readAt: { type: Date, default: Date.now }
  }]
}, { timestamps: true });

const ChatMessage = mongoose.model('ChatMessage', chatMessageSchema);

// Model pour les notifications push de groupe
const groupNotificationSchema = new mongoose.Schema({
  messageId: { type: mongoose.Schema.Types.ObjectId, ref: 'ChatMessage', required: true },
  senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  senderName: { type: String, required: true },
  content: { type: String, required: true },
  mediaType: { type: String, enum: ['text', 'image', 'video', 'audio'], default: 'text' },
  sentAt: { type: Date, default: Date.now },
  readBy: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    readAt: { type: Date }
  }]
}, { timestamps: true });

const GroupNotification = mongoose.model('GroupNotification', groupNotificationSchema);

// ========================================
// API ROUTES POUR CHAT DE GROUPE
// ========================================

// GET - Récupérer tous les messages du chat de groupe
app.get('/api/chat/messages', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 50, before } = req.query;
    const skip = (page - 1) * limit;

    let query = { isDeleted: false };
    
    // Si "before" est fourni, récupérer les messages avant cette date (pagination inverse)
    if (before) {
      query.createdAt = { $lt: new Date(before) };
    }

    const messages = await ChatMessage
      .find(query)
      .populate('replyTo', 'content senderName mediaType')
      .sort({ createdAt: -1 }) // Les plus récents en premier
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    // Inverser l'ordre pour affichage chronologique
    messages.reverse();

    const totalMessages = await ChatMessage.countDocuments({ isDeleted: false });

    res.json({
      success: true,
      messages,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(totalMessages / limit),
        totalMessages,
        hasMore: skip + messages.length < totalMessages
      }
    });
  } catch (error) {
    console.error('❌ Error fetching chat messages:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de la récupération des messages' 
    });
  }
});

// POST - Envoyer un nouveau message (texte ou média)
app.post('/api/chat/message', authMiddleware, upload.single('media'), async (req, res) => {
  try {
    const { content, replyToId } = req.body;
    const user = req.user;

    // Validation : soit du contenu texte, soit un fichier média
    if (!content && !req.file) {
      return res.status(400).json({
        success: false,
        message: 'Le message doit contenir du texte ou un média'
      });
    }

    let mediaUrl = '';
    let mediaType = 'text';
    let fileName = '';
    let fileSize = 0;

    // Traitement du fichier média si présent
    if (req.file) {
      mediaUrl = `/uploads/${req.file.filename}`;
      fileName = req.file.originalname;
      fileSize = req.file.size;

      // Déterminer le type de média
      const fileExt = path.extname(req.file.originalname).toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(fileExt)) {
        mediaType = 'image';
      } else if (['.mp4', '.avi', '.mov', '.webm'].includes(fileExt)) {
        mediaType = 'video';
      } else if (['.mp3', '.wav', '.ogg', '.m4a'].includes(fileExt)) {
        mediaType = 'audio';
      }
    }

    // Récupérer les infos du message auquel on répond (si applicable)
    let replyToContent = '';
    if (replyToId) {
      const replyMessage = await ChatMessage.findById(replyToId);
      if (replyMessage) {
        replyToContent = replyMessage.content || `[${replyMessage.mediaType}]`;
      }
    }

    // Créer le nouveau message
    const newMessage = new ChatMessage({
      senderId: user._id,
      senderName: user.name || user.email,
      senderPhoto: user.profilePhoto || '',
      content: content || '',
      mediaUrl,
      mediaType,
      fileName,
      fileSize,
      replyTo: replyToId || null,
      replyToContent
    });

    await newMessage.save();

    // Peupler les données pour la réponse
    const populatedMessage = await ChatMessage
      .findById(newMessage._id)
      .populate('replyTo', 'content senderName mediaType')
      .lean();

    // Créer une notification push de groupe pour tous les autres utilisateurs
    const notification = new GroupNotification({
      messageId: newMessage._id,
      senderId: user._id,
      senderName: user.name || user.email,
      content: content || `[${mediaType}]`,
      mediaType
    });

    await notification.save();

    // Envoyer notification push à tous les utilisateurs connectés (simulé)
    console.log(`📢 Notification de groupe: ${user.name || user.email} a envoyé un ${mediaType}`);

    res.status(201).json({
      success: true,
      message: populatedMessage,
      notification: 'Message envoyé avec succès'
    });

  } catch (error) {
    console.error('❌ Error sending chat message:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de l\'envoi du message' 
    });
  }
});

// POST - Upload de médias pour le chat (images, audios, vidéos)
app.post('/api/chat/upload-media', authMiddleware, chatMediaUpload.array('media', 10), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Aucun fichier fourni'
      });
    }

    const uploadedFiles = req.files.map(file => {
      const mediaUrl = `/uploads/${file.path.split('uploads')[1].replace(/\\/g, '/')}`;
      return {
        url: mediaUrl,
        type: getMediaTypeFromMimetype(file.mimetype),
        size: file.size,
        filename: file.originalname
      };
    });

    res.status(200).json({
      success: true,
      files: uploadedFiles,
      message: 'Médias uploadés avec succès'
    });

  } catch (error) {
    console.error('❌ Error uploading chat media:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de l\'upload des médias' 
    });
  }
});

// POST - Upload de photo de profil
app.post('/api/users/profile-photo', authMiddleware, profileUpload.single('photo'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Aucune photo fournie'
      });
    }

    const photoUrl = `/uploads/${req.file.path.split('uploads')[1].replace(/\\/g, '/')}`;
    
    // Mettre à jour la photo de profil de l'utilisateur
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    user.profilePhoto = photoUrl;
    await user.save();

    res.status(200).json({
      success: true,
      photoUrl: photoUrl,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        profilePhoto: user.profilePhoto
      },
      message: 'Photo de profil mise à jour avec succès'
    });

  } catch (error) {
    console.error('❌ Error uploading profile photo:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de l\'upload de la photo de profil' 
    });
  }
});

// GET - Récupérer le profil d'un utilisateur (pour le chat)
app.get('/api/users/:userId/profile', authMiddleware, async (req, res) => {
  try {
    const { userId } = req.params;
    
    const user = await User.findById(userId).select('name email profilePhoto');
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    res.json({
      success: true,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        profilePhoto: user.profilePhoto || '/default-avatar.png'
      }
    });

  } catch (error) {
    console.error('❌ Error fetching user profile:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de la récupération du profil' 
    });
  }
});

// PUT - Marquer un message comme lu
app.put('/api/chat/message/:messageId/read', authMiddleware, async (req, res) => {
  try {
    const { messageId } = req.params;
    const userId = req.user._id;

    const message = await ChatMessage.findById(messageId);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    // Vérifier si l'utilisateur a déjà lu ce message
    const alreadyRead = message.readBy.some(read => read.userId.toString() === userId.toString());
    
    if (!alreadyRead) {
      message.readBy.push({
        userId,
        readAt: new Date()
      });
      await message.save();
    }

    res.json({
      success: true,
      message: 'Message marqué comme lu'
    });

  } catch (error) {
    console.error('❌ Error marking message as read:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors du marquage du message' 
    });
  }
});

// DELETE - Supprimer un message (soft delete)
// PUT - Modifier un message
app.put('/api/chat/message/:messageId', authMiddleware, async (req, res) => {
  try {
    const { messageId } = req.params;
    const { content } = req.body;
    const userId = req.user._id;

    if (!content || content.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Le contenu du message ne peut pas être vide'
      });
    }

    const message = await ChatMessage.findById(messageId);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    // Vérifier que l'utilisateur est le propriétaire du message
    if (message.senderId.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Vous ne pouvez modifier que vos propres messages'
      });
    }

    // Vérifier que c'est un message texte
    if (message.mediaUrl) {
      return res.status(400).json({
        success: false,
        message: 'Les messages avec média ne peuvent pas être modifiés'
      });
    }

    // Mettre à jour le message
    message.content = content.trim();
    message.isEdited = true;
    message.editedAt = new Date();
    await message.save();

    res.json({
      success: true,
      message: 'Message modifié avec succès',
      data: message
    });

  } catch (error) {
    console.error('❌ Error editing message:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de la modification du message' 
    });
  }
});

// DELETE - Supprimer un message
app.delete('/api/chat/message/:messageId', authMiddleware, async (req, res) => {
  try {
    const { messageId } = req.params;
    const userId = req.user._id;

    const message = await ChatMessage.findById(messageId);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    // Vérifier que l'utilisateur est le propriétaire du message ou admin
    if (message.senderId.toString() !== userId.toString() && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Vous ne pouvez supprimer que vos propres messages'
      });
    }

    // Soft delete
    message.isDeleted = true;
    message.deletedAt = new Date();
    await message.save();

    res.json({
      success: true,
      message: 'Message supprimé avec succès'
    });

  } catch (error) {
    console.error('❌ Error deleting message:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de la suppression du message' 
    });
  }
});

// POST - Ajouter une photo à un message texte
app.post('/api/chat/message/:messageId/photo', authMiddleware, chatMediaUpload.single('photo'), async (req, res) => {
  try {
    const { messageId } = req.params;
    const userId = req.user._id;

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Aucune photo fournie'
      });
    }

    const message = await ChatMessage.findById(messageId);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    // Vérifier que l'utilisateur est le propriétaire du message
    if (message.senderId.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Vous ne pouvez modifier que vos propres messages'
      });
    }

    // Vérifier que le message n'a pas déjà une photo
    if (message.mediaUrl) {
      return res.status(400).json({
        success: false,
        message: 'Ce message a déjà une photo. Utilisez l\'option remplacer.'
      });
    }

    // Ajouter la photo au message
    const photoUrl = `/uploads/${req.file.path.split('uploads')[1].replace(/\\/g, '/')}`;
    message.mediaUrl = photoUrl;
    message.mediaType = 'image';
    message.fileName = req.file.originalname;
    message.fileSize = req.file.size;
    message.isEdited = true;
    message.editedAt = new Date();
    await message.save();

    res.json({
      success: true,
      message: 'Photo ajoutée avec succès',
      data: message
    });

  } catch (error) {
    console.error('❌ Error adding photo to message:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de l\'ajout de la photo' 
    });
  }
});

// PUT - Remplacer la photo d'un message
app.put('/api/chat/message/:messageId/photo', authMiddleware, chatMediaUpload.single('photo'), async (req, res) => {
  try {
    const { messageId } = req.params;
    const userId = req.user._id;

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Aucune photo fournie'
      });
    }

    const message = await ChatMessage.findById(messageId);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    // Vérifier que l'utilisateur est le propriétaire du message
    if (message.senderId.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Vous ne pouvez modifier que vos propres messages'
      });
    }

    // Supprimer l'ancienne photo si elle existe
    if (message.mediaUrl) {
      const oldPhotoPath = path.join(__dirname, message.mediaUrl);
      if (fs.existsSync(oldPhotoPath)) {
        fs.unlinkSync(oldPhotoPath);
      }
    }

    // Remplacer par la nouvelle photo
    const photoUrl = `/uploads/${req.file.path.split('uploads')[1].replace(/\\/g, '/')}`;
    message.mediaUrl = photoUrl;
    message.mediaType = 'image';
    message.fileName = req.file.originalname;
    message.fileSize = req.file.size;
    message.isEdited = true;
    message.editedAt = new Date();
    await message.save();

    res.json({
      success: true,
      message: 'Photo remplacée avec succès',
      data: message
    });

  } catch (error) {
    console.error('❌ Error replacing message photo:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors du remplacement de la photo' 
    });
  }
});

// DELETE - Supprimer la photo d'un message
app.delete('/api/chat/message/:messageId/photo', authMiddleware, async (req, res) => {
  try {
    const { messageId } = req.params;
    const userId = req.user._id;

    const message = await ChatMessage.findById(messageId);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message non trouvé'
      });
    }

    // Vérifier que l'utilisateur est le propriétaire du message
    if (message.senderId.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Vous ne pouvez modifier que vos propres messages'
      });
    }

    // Vérifier que le message a une photo
    if (!message.mediaUrl) {
      return res.status(400).json({
        success: false,
        message: 'Ce message n\'a pas de photo'
      });
    }

    // Supprimer le fichier photo
    const photoPath = path.join(__dirname, message.mediaUrl);
    if (fs.existsSync(photoPath)) {
      fs.unlinkSync(photoPath);
    }

    // Retirer la photo du message
    message.mediaUrl = null;
    message.mediaType = null;
    message.fileName = '';
    message.fileSize = 0;
    message.isEdited = true;
    message.editedAt = new Date();
    await message.save();

    res.json({
      success: true,
      message: 'Photo supprimée avec succès',
      data: message
    });

  } catch (error) {
    console.error('❌ Error removing message photo:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de la suppression de la photo' 
    });
  }
});

// GET - Récupérer les notifications de groupe non lues
app.get('/api/chat/notifications', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;

    const notifications = await GroupNotification
      .find({
        senderId: { $ne: userId }, // Exclure ses propres messages
        'readBy.userId': { $ne: userId } // Messages non lus par cet utilisateur
      })
      .populate('messageId', 'content mediaType')
      .sort({ createdAt: -1 })
      .limit(20)
      .lean();

    res.json({
      success: true,
      notifications,
      count: notifications.length
    });

  } catch (error) {
    console.error('❌ Error fetching group notifications:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de la récupération des notifications' 
    });
  }
});

// PUT - Marquer toutes les notifications comme lues
app.put('/api/chat/notifications/read-all', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;

    await GroupNotification.updateMany(
      {
        senderId: { $ne: userId },
        'readBy.userId': { $ne: userId }
      },
      {
        $push: {
          readBy: {
            userId,
            readAt: new Date()
          }
        }
      }
    );

    res.json({
      success: true,
      message: 'Toutes les notifications marquées comme lues'
    });

  } catch (error) {
    console.error('❌ Error marking notifications as read:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors du marquage des notifications' 
    });
  }
});

// GET - Statistiques du chat (nombre de messages, utilisateurs actifs, etc.)
app.get('/api/chat/stats', authMiddleware, async (req, res) => {
  try {
    const totalMessages = await ChatMessage.countDocuments({ isDeleted: false });
    const totalMediaMessages = await ChatMessage.countDocuments({ 
      isDeleted: false, 
      mediaType: { $ne: 'text' } 
    });
    
    const activeUsers = await ChatMessage.distinct('senderId', {
      isDeleted: false,
      createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) } // Dernières 24h
    });

    const messagesByType = await ChatMessage.aggregate([
      { $match: { isDeleted: false } },
      { $group: { _id: '$mediaType', count: { $sum: 1 } } }
    ]);

    res.json({
      success: true,
      stats: {
        totalMessages,
        totalMediaMessages,
        activeUsersLast24h: activeUsers.length,
        messagesByType
      }
    });

  } catch (error) {
    console.error('❌ Error fetching chat stats:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de la récupération des statistiques' 
    });
  }
});

// ========================================
// GESTION DES UTILISATEURS CONNECTÉS
// ========================================

// Stocker les utilisateurs connectés (en mémoire pour simplifier)
const connectedUsers = new Map(); // userId -> { lastSeen, isOnline, userInfo }

// Middleware pour mettre à jour l'activité utilisateur
const updateUserActivity = (req, res, next) => {
  if (req.user) {
    connectedUsers.set(req.user._id.toString(), {
      lastSeen: new Date(),
      isOnline: true,
      userInfo: {
        id: req.user._id,
        name: req.user.name || req.user.email,
        email: req.user.email,
        profilePhoto: req.user.profilePhoto || '',
        role: req.user.role || 'user'
      }
    });
  }
  next();
};

// Nettoyer les utilisateurs inactifs (plus de 5 minutes)
setInterval(() => {
  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
  for (const [userId, userData] of connectedUsers.entries()) {
    if (userData.lastSeen < fiveMinutesAgo) {
      connectedUsers.delete(userId);
    }
  }
}, 60000); // Vérifier chaque minute

// GET - Obtenir la liste des utilisateurs connectés
app.get('/api/users/online', authMiddleware, updateUserActivity, (req, res) => {
  try {
    const onlineUsers = Array.from(connectedUsers.values())
      .map(userData => userData.userInfo)
      .filter(user => user.id.toString() !== req.user._id.toString()); // Exclure soi-même

    res.json({
      success: true,
      users: onlineUsers,
      count: onlineUsers.length
    });
  } catch (error) {
    console.error('❌ Error fetching online users:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de la récupération des utilisateurs connectés' 
    });
  }
});

// GET - Obtenir les informations d'un utilisateur spécifique
app.get('/api/users/:userId', authMiddleware, updateUserActivity, async (req, res) => {
  try {
    const { userId } = req.params;
    
    const user = await User.findById(userId).select('name email profilePhoto role status createdAt');
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Vérifier si l'utilisateur est en ligne
    const isOnline = connectedUsers.has(userId);
    const lastSeen = connectedUsers.get(userId)?.lastSeen || null;

    res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name || user.email,
        email: user.email,
        profilePhoto: user.profilePhoto || '',
        role: user.role,
        status: user.status,
        createdAt: user.createdAt,
        isOnline,
        lastSeen
      }
    });
  } catch (error) {
    console.error('❌ Error fetching user info:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erreur lors de la récupération des informations utilisateur' 
    });
  }
});

// PUT - Mettre à jour le statut en ligne (heartbeat)
app.put('/api/users/heartbeat', authMiddleware, updateUserActivity, (req, res) => {
  res.json({
    success: true,
    message: 'Statut mis à jour',
    timestamp: new Date()
  });
});

// Appliquer le middleware d'activité aux routes de chat existantes
app.use('/api/chat', updateUserActivity);

// Start Server
const server = app.listen(PORT, async () => {
  console.log(`🚀 Server running on port ${PORT}`);
  
  // Configuration automatique de l'administrateur au démarrage
  await setupAdminUser();
  
  // Migration des permissions pour les utilisateurs existants
  await migrateUserPermissions();
});

// Augmenter le timeout pour les uploads de médias (3 minutes)
server.timeout = 180000; // 180 secondes = 3 minutes
server.keepAliveTimeout = 65000; // 65 secondes
server.headersTimeout = 66000; // 66 secondes (> keepAliveTimeout)