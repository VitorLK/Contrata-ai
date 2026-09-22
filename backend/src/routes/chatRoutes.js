const express = require('express');
const { requireAuth, requireRole } = require('../middlewares/auth');
const {
  listConversations,
  openConversation,
  getConversationMessages,
  sendMessage,
  createProposal,
  respondToProposal,
  getUnreadCount,
} = require('../controllers/chatController');

const router = express.Router();

router.get('/conversations', requireAuth, listConversations);
router.post(
  '/conversations',
  requireAuth,
  requireRole('cliente'),
  openConversation
);
router.get('/unread-count', requireAuth, getUnreadCount);
router.get('/conversations/:id/messages', requireAuth, getConversationMessages);
router.post('/conversations/:id/messages', requireAuth, sendMessage);
router.post(
  '/conversations/:id/proposals',
  requireAuth,
  requireRole('cliente'),
  createProposal
);
router.post(
  '/proposals/:id/respond',
  requireAuth,
  requireRole('profissional'),
  respondToProposal
);

module.exports = router;
