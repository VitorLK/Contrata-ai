const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

const VALID_ROLES = ['cliente', 'profissional'];
const SALT_ROUNDS = 10;
const TOKEN_TTL = '7d';

function signToken(user) {
  return jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: TOKEN_TTL });
}

function toPublicUser(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    role: row.role,
    phone: row.phone,
    is_active: row.is_active !== false,
  };
}

async function register(req, res) {
  const { name, email, password, role, phone } = req.body;

  if (!name || !email || !password || !role) {
    return res.status(400).json({ error: 'Nome, e-mail, senha e papel (role) são obrigatórios.' });
  }
  if (!VALID_ROLES.includes(role)) {
    return res.status(400).json({ error: `role deve ser um dos valores: ${VALID_ROLES.join(', ')}.` });
  }
  if (String(password).length < 6) {
    return res.status(400).json({ error: 'A senha deve ter pelo menos 6 caracteres.' });
  }

  const client = await pool.connect();
  try {
    const existing = await client.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rowCount > 0) {
      return res.status(409).json({ error: 'Já existe uma conta com este e-mail.' });
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    await client.query('BEGIN');
    const insertUser = await client.query(
      `INSERT INTO users (name, email, password_hash, role, phone)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, name, email, role, phone`,
      [name, email, passwordHash, role, phone || null]
    );
    const user = insertUser.rows[0];

    if (role === 'profissional') {
      await client.query('INSERT INTO professional_profiles (user_id) VALUES ($1)', [user.id]);
    }

    await client.query('COMMIT');

    const token = signToken(user);
    return res.status(201).json({ token, user: toPublicUser(user) });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao registrar usuário:', err);
    return res.status(500).json({ error: 'Não foi possível concluir o cadastro.' });
  } finally {
    client.release();
  }
}

async function login(req, res) {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'E-mail e senha são obrigatórios.' });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE lower(email) = lower($1)', [email]);
    const user = result.rows[0];

    if (!user) {
      return res.status(401).json({ error: 'E-mail ou senha inválidos.' });
    }
    if (!user.is_active) {
      return res.status(403).json({ error: 'Esta conta foi desativada. Entre em contato com a administração.' });
    }

    const passwordMatches = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatches) {
      return res.status(401).json({ error: 'E-mail ou senha inválidos.' });
    }

    const token = signToken(user);
    return res.json({ token, user: toPublicUser(user) });
  } catch (err) {
    console.error('Erro ao autenticar usuário:', err);
    return res.status(500).json({ error: 'Não foi possível concluir o login.' });
  }
}

module.exports = { register, login };
