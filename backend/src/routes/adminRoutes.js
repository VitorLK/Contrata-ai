const express = require('express');
const { requireAuth, requireRole } = require('../middlewares/auth');
const {
  getOverview,
  listUsers,
  updateUser,
  deleteUser,
  listCompanies,
  createCompany,
  updateCompany,
  deleteCompany,
  listServices,
  updateService,
  listAudit,
} = require('../controllers/adminController');

const router = express.Router();

router.use(requireAuth, requireRole('administrador'));

router.get('/overview', getOverview);
router.get('/users', listUsers);
router.patch('/users/:id', updateUser);
router.delete('/users/:id', deleteUser);
router.get('/companies', listCompanies);
router.post('/companies', createCompany);
router.patch('/companies/:id', updateCompany);
router.delete('/companies/:id', deleteCompany);
router.get('/services', listServices);
router.patch('/services/:id', updateService);
router.get('/audit', listAudit);

module.exports = router;
