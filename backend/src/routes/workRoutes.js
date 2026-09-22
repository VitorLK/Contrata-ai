const express = require('express');
const { requireAuth, requireRole } = require('../middlewares/auth');
const { handleUpload } = require('../middlewares/upload');
const {
  listTodayWork,
  listAgenda,
  startWork,
  withdrawScheduledWork,
  finishWork,
  listPendingConfirmations,
  confirmWork,
  getPreferences,
  updatePreferences,
  getPerformance,
  getReceipt,
  listNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} = require('../controllers/workController');

const router = express.Router();

router.get('/today', requireAuth, requireRole('profissional'), listTodayWork);
router.get('/agenda', requireAuth, requireRole('profissional'), listAgenda);
router.get('/performance', requireAuth, requireRole('profissional'), getPerformance);
router.get('/pending-confirmations', requireAuth, requireRole('cliente'), listPendingConfirmations);
router.get('/preferences', requireAuth, requireRole('cliente'), getPreferences);
router.put('/preferences', requireAuth, requireRole('cliente'), updatePreferences);
router.get('/notifications', requireAuth, listNotifications);
router.post('/notifications/read-all', requireAuth, markAllNotificationsRead);
router.post('/notifications/:id/read', requireAuth, markNotificationRead);
router.post('/services/:serviceId/start', requireAuth, requireRole('profissional'), startWork);
router.post(
  '/services/:serviceId/withdraw',
  requireAuth,
  requireRole('profissional'),
  withdrawScheduledWork
);
router.post('/:id/finish', requireAuth, requireRole('profissional'), handleUpload('evidence'), finishWork);
router.post('/:id/confirm', requireAuth, requireRole('cliente'), confirmWork);
router.get('/:id/receipt', requireAuth, getReceipt);

module.exports = router;
