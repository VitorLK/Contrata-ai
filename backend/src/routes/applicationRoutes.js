const express = require('express');
const { requireAuth, requireRole } = require('../middlewares/auth');
const {
  listMyApplications,
  withdrawApplication,
} = require('../controllers/applicationController');

const router = express.Router();

router.get('/mine', requireAuth, requireRole('profissional'), listMyApplications);
router.delete('/:id', requireAuth, requireRole('profissional'), withdrawApplication);

module.exports = router;
