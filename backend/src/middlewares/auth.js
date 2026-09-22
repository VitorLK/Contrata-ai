const jwt = require('jsonwebtoken');
const pool = require('../config/db');

/**
 * Exige um JWT válido no header Authorization: Bearer <token>.
 * Em caso de sucesso, injeta { id, role } em req.user.
 */
async function requireAuth(req, res, next) {
  const header = req.headers.authorization;
  const token = header && header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Token de autenticação ausente.' });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const result = await pool.query(
      'SELECT id, role, is_active FROM users WHERE id = $1',
      [payload.id]
    );
    const user = result.rows[0];
    if (!user || !user.is_active) {
      return res.status(401).json({ error: 'Esta conta está inativa ou não existe mais.' });
    }
    req.user = { id: user.id, role: user.role };
    next();
  } catch (err) {
    if (err.code && String(err.code).startsWith('08')) {
      return res.status(503).json({ error: 'Não foi possível validar sua sessão agora.' });
    }
    return res.status(401).json({ error: 'Token inválido ou expirado.' });
  }
}

/**
 * Deve ser usado depois de requireAuth. Bloqueia usuários cujo role
 * não está na lista de papéis permitidos para a rota.
 */
function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Você não tem permissão para acessar este recurso.' });
    }
    next();
  };
}

module.exports = { requireAuth, requireRole };
