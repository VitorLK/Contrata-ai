const express = require('express');
const { requireAuth, requireRole } = require('../middlewares/auth');
const { geocodeAddress } = require('../controllers/locationController');

const router = express.Router();

router.get(
  '/geocode',
  requireAuth,
  requireRole('cliente'),
  geocodeAddress
);

module.exports = router;
