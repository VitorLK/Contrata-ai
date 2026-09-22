const express = require('express');
const { requireAuth, requireRole } = require('../middlewares/auth');
const { handleUpload } = require('../middlewares/upload');
const {
  listOpenServices,
  listMyServices,
  getServiceById,
  listApplicationsForService,
  acceptApplication,
  rejectApplication,
  completeService,
  cancelService,
  createService,
  updateService,
  applyToService,
  renewOpenService,
  createReview,
} = require('../controllers/serviceController');

const router = express.Router();

router.get('/', listOpenServices);
router.get('/mine', requireAuth, requireRole('cliente'), listMyServices);
// Precisa vir depois de '/mine': em Express, uma rota com parâmetro
// (':id') captura qualquer segmento — inclusive "mine" — se vier antes.
router.get('/:id', getServiceById);
router.get('/:id/applications', requireAuth, requireRole('cliente'), listApplicationsForService);
router.post('/', requireAuth, requireRole('cliente'), handleUpload('image'), createService);
router.put('/:id', requireAuth, requireRole('cliente'), handleUpload('image'), updateService);
router.post('/:id/apply', requireAuth, requireRole('profissional'), applyToService);
router.post('/:id/renew', requireAuth, requireRole('cliente'), renewOpenService);
router.post('/:id/applications/:applicationId/accept', requireAuth, requireRole('cliente'), acceptApplication);
router.post('/:id/applications/:applicationId/reject', requireAuth, requireRole('cliente'), rejectApplication);
router.post('/:id/complete', requireAuth, requireRole('cliente'), completeService);
router.post('/:id/cancel', requireAuth, requireRole('cliente'), cancelService);
router.post('/:id/review', requireAuth, requireRole('cliente'), createReview);

module.exports = router;
