const express = require('express');
const { requireAuth, requireRole } = require('../middlewares/auth');
const { handleUpload } = require('../middlewares/upload');
const {
  getMyProfile,
  updateMyProfile,
  uploadPhoto,
  addPortfolioItem,
  deletePortfolioItem,
  getMyAvailability,
  updateMyAvailability,
  getPublicAvailability,
  listProfessionals,
  getPublicProfile,
} = require('../controllers/professionalController');

const router = express.Router();

// '/me' e '/me/*' precisam continuar vindo antes de '/:id' — mesma
// pegadinha de ordenação já resolvida em serviceRoutes.js: rotas literais
// antes de rotas com parâmetro, senão '/:id' capturaria "me" como um id.
router.get('/me', requireAuth, requireRole('profissional'), getMyProfile);
router.put('/me', requireAuth, requireRole('profissional'), updateMyProfile);
router.post('/me/photo', requireAuth, requireRole('profissional'), handleUpload('photo'), uploadPhoto);
router.post('/me/portfolio', requireAuth, requireRole('profissional'), handleUpload('image'), addPortfolioItem);
router.delete('/me/portfolio/:itemId', requireAuth, requireRole('profissional'), deletePortfolioItem);
router.get('/me/availability', requireAuth, requireRole('profissional'), getMyAvailability);
router.put('/me/availability', requireAuth, requireRole('profissional'), updateMyAvailability);

// Públicas — descoberta de profissionais pelo cliente (Etapa 18).
router.get('/', listProfessionals);
router.get('/:id/availability', getPublicAvailability);
router.get('/:id', getPublicProfile);

module.exports = router;
