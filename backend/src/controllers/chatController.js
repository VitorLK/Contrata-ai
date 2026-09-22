const pool = require('../config/db');
const {
  parseSchedulePayload,
  assertNoScheduleConflict,
} = require('./scheduleService');

const VALID_SERVICE_MODES = ['presencial', 'remoto', 'hibrido'];
const VALID_PRICING_TYPES = ['por_hora', 'empreitada'];

async function getConversationForUser(database, conversationId, userId, lock = false) {
  const result = await database.query(
    `SELECT c.*
     FROM conversations c
     WHERE c.id = $1 AND (c.client_id = $2 OR c.professional_id = $2)
     ${lock ? 'FOR UPDATE' : ''}`,
    [conversationId, userId]
  );
  return result.rows[0] || null;
}

function conversationSelect(whereClause) {
  return `SELECT c.*,
                 client_user.name AS client_name,
                 professional_user.name AS professional_name,
                 profile.photo_url AS professional_photo_url,
                 (SELECT body FROM chat_messages latest
                  WHERE latest.conversation_id = c.id
                  ORDER BY latest.created_at DESC LIMIT 1) AS last_message,
                 (SELECT created_at FROM chat_messages latest
                  WHERE latest.conversation_id = c.id
                  ORDER BY latest.created_at DESC LIMIT 1) AS last_message_at,
                 (SELECT COUNT(*)::int FROM chat_messages unread
                  WHERE unread.conversation_id = c.id
                    AND unread.sender_id <> $1 AND unread.read_at IS NULL) AS unread_count
          FROM conversations c
          JOIN users client_user ON client_user.id = c.client_id
          JOIN users professional_user ON professional_user.id = c.professional_id
          LEFT JOIN professional_profiles profile ON profile.user_id = c.professional_id
          ${whereClause}`;
}

async function listConversations(req, res) {
  try {
    const result = await pool.query(
      `${conversationSelect('WHERE c.client_id = $1 OR c.professional_id = $1')}
       ORDER BY COALESCE(
         (SELECT MAX(created_at) FROM chat_messages m WHERE m.conversation_id = c.id),
         c.updated_at
       ) DESC`,
      [req.user.id]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar conversas:', err);
    return res.status(500).json({ error: 'Não foi possível carregar suas conversas.' });
  }
}

async function openConversation(req, res) {
  const professionalId = String(req.body?.professional_id || '').trim();
  if (!professionalId) {
    return res.status(400).json({ error: 'Informe o profissional da conversa.' });
  }

  try {
    const professionalResult = await pool.query(
      `SELECT id FROM users
       WHERE id = $1 AND role = 'profissional' AND is_active = TRUE`,
      [professionalId]
    );
    if (professionalResult.rowCount === 0) {
      return res.status(404).json({ error: 'Profissional não encontrado.' });
    }

    const inserted = await pool.query(
      `INSERT INTO conversations (client_id, professional_id)
       VALUES ($1, $2)
       ON CONFLICT (client_id, professional_id)
       DO UPDATE SET updated_at = conversations.updated_at
       RETURNING id`,
      [req.user.id, professionalId]
    );
    const result = await pool.query(
      conversationSelect('WHERE c.id = $2'),
      [req.user.id, inserted.rows[0].id]
    );
    return res.status(inserted.command === 'INSERT' ? 201 : 200).json(result.rows[0]);
  } catch (err) {
    console.error('Erro ao abrir conversa:', err);
    return res.status(500).json({ error: 'Não foi possível abrir a conversa.' });
  }
}

async function getConversationMessages(req, res) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const conversation = await getConversationForUser(
      client,
      req.params.id,
      req.user.id,
      true
    );
    if (!conversation) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Conversa não encontrada.' });
    }

    await client.query(
      `UPDATE chat_messages SET read_at = COALESCE(read_at, now())
       WHERE conversation_id = $1 AND sender_id <> $2 AND read_at IS NULL`,
      [conversation.id, req.user.id]
    );
    const [messages, proposals, details] = await Promise.all([
      client.query(
        `SELECT m.*, u.name AS sender_name
         FROM chat_messages m
         JOIN users u ON u.id = m.sender_id
         WHERE m.conversation_id = $1
         ORDER BY m.created_at ASC LIMIT 300`,
        [conversation.id]
      ),
      client.query(
        `SELECT * FROM job_proposals
         WHERE conversation_id = $1
         ORDER BY created_at ASC`,
        [conversation.id]
      ),
      client.query(
        `SELECT c.*, client_user.name AS client_name,
                professional_user.name AS professional_name,
                profile.photo_url AS professional_photo_url
         FROM conversations c
         JOIN users client_user ON client_user.id = c.client_id
         JOIN users professional_user ON professional_user.id = c.professional_id
         LEFT JOIN professional_profiles profile ON profile.user_id = c.professional_id
         WHERE c.id = $1`,
        [conversation.id]
      ),
    ]);
    await client.query('COMMIT');
    return res.json({
      conversation: details.rows[0],
      messages: messages.rows,
      proposals: proposals.rows,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao carregar conversa:', err);
    return res.status(500).json({ error: 'Não foi possível carregar a conversa.' });
  } finally {
    client.release();
  }
}

async function sendMessage(req, res) {
  const body = String(req.body?.body || '').trim();
  if (!body || body.length > 2000) {
    return res.status(400).json({ error: 'A mensagem deve ter entre 1 e 2.000 caracteres.' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const conversation = await getConversationForUser(
      client,
      req.params.id,
      req.user.id,
      true
    );
    if (!conversation) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Conversa não encontrada.' });
    }
    const result = await client.query(
      `INSERT INTO chat_messages (conversation_id, sender_id, body)
       VALUES ($1, $2, $3) RETURNING *`,
      [conversation.id, req.user.id, body]
    );
    await client.query('UPDATE conversations SET updated_at = now() WHERE id = $1', [
      conversation.id,
    ]);

    const recipientId = conversation.client_id === req.user.id
      ? conversation.professional_id
      : conversation.client_id;
    await client.query(
      `INSERT INTO notifications (user_id, type, title, message, data)
       VALUES ($1, 'nova_mensagem', 'Nova mensagem', $2, $3::jsonb)`,
      [
        recipientId,
        body.length > 100 ? `${body.slice(0, 97)}...` : body,
        JSON.stringify({ conversation_id: conversation.id }),
      ]
    );
    await client.query('COMMIT');
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao enviar mensagem:', err);
    return res.status(500).json({ error: 'Não foi possível enviar a mensagem.' });
  } finally {
    client.release();
  }
}

function validateProposal(body) {
  const title = String(body.title || '').trim();
  const description = String(body.description || '').trim();
  const category = String(body.category || '').trim();
  const serviceMode = String(body.service_mode || 'presencial');
  const pricingType = String(body.pricing_type || 'empreitada');
  const amount = Number(body.amount);
  const schedule = parseSchedulePayload(body);

  if (title.length < 5 || title.length > 150) {
    return { error: 'O título da proposta deve ter entre 5 e 150 caracteres.' };
  }
  if (description.length < 10 || description.length > 2000) {
    return { error: 'Descreva o trabalho em pelo menos 10 caracteres.' };
  }
  if (!VALID_SERVICE_MODES.includes(serviceMode)) {
    return { error: 'Informe uma forma de atendimento válida.' };
  }
  if (!VALID_PRICING_TYPES.includes(pricingType)) {
    return { error: 'Informe uma forma de cobrança válida.' };
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    return { error: 'O valor da proposta deve ser maior que zero.' };
  }
  if (schedule.error) return schedule;

  const city = String(body.city || '').trim() || null;
  const state = String(body.state || '').trim().toUpperCase() || null;
  const address = String(body.address || '').trim() || null;
  if (serviceMode !== 'remoto' && (!city || !state)) {
    return { error: 'Informe cidade e estado para o trabalho presencial.' };
  }
  if (state && !/^[A-Z]{2}$/.test(state)) {
    return { error: 'Informe uma UF válida.' };
  }

  return {
    title,
    description,
    category: category || null,
    serviceMode,
    pricingType,
    amount,
    city,
    state,
    address,
    ...schedule,
  };
}

async function createProposal(req, res) {
  const payload = validateProposal(req.body || {});
  if (payload.error) return res.status(400).json({ error: payload.error });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const conversation = await getConversationForUser(
      client,
      req.params.id,
      req.user.id,
      true
    );
    if (!conversation) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Conversa não encontrada.' });
    }
    if (conversation.client_id !== req.user.id) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Somente o contratante pode enviar a proposta formal.' });
    }

    const result = await client.query(
      `INSERT INTO job_proposals (
         conversation_id, proposed_by, client_id, professional_id,
         title, description, category, service_mode, city, state, address,
         pricing_type, amount, scheduled_start, scheduled_end, is_all_day
       ) VALUES (
         $1, $2, $2, $3, $4, $5, $6, $7, $8, $9, $10,
         $11, $12, $13, $14, $15
       ) RETURNING *`,
      [
        conversation.id,
        req.user.id,
        conversation.professional_id,
        payload.title,
        payload.description,
        payload.category,
        payload.serviceMode,
        payload.city,
        payload.state,
        payload.address,
        payload.pricingType,
        payload.amount,
        payload.scheduledStart,
        payload.scheduledEnd,
        payload.isAllDay,
      ]
    );
    await client.query('UPDATE conversations SET updated_at = now() WHERE id = $1', [
      conversation.id,
    ]);
    await client.query(
      `INSERT INTO notifications (user_id, type, title, message, data)
       VALUES ($1, 'nova_proposta', 'Nova proposta de trabalho', $2, $3::jsonb)`,
      [
        conversation.professional_id,
        `Você recebeu uma proposta para “${payload.title}”.`,
        JSON.stringify({ conversation_id: conversation.id, proposal_id: result.rows[0].id }),
      ]
    );
    await client.query('COMMIT');
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao criar proposta:', err);
    return res.status(500).json({ error: 'Não foi possível enviar a proposta.' });
  } finally {
    client.release();
  }
}

async function respondToProposal(req, res) {
  const action = String(req.body?.action || '');
  if (!['aceitar', 'recusar'].includes(action)) {
    return res.status(400).json({ error: 'Informe se deseja aceitar ou recusar a proposta.' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const proposalResult = await client.query(
      `SELECT p.*, c.professional_id AS conversation_professional_id
       FROM job_proposals p
       JOIN conversations c ON c.id = p.conversation_id
       WHERE p.id = $1 FOR UPDATE OF p`,
      [req.params.id]
    );
    const proposal = proposalResult.rows[0];
    if (!proposal) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Proposta não encontrada.' });
    }
    if (proposal.professional_id !== req.user.id) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Esta proposta não foi enviada para você.' });
    }
    if (proposal.status !== 'pendente') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Esta proposta já foi respondida.' });
    }

    if (action === 'recusar') {
      const declined = await client.query(
        `UPDATE job_proposals
         SET status = 'recusada', responded_at = now()
         WHERE id = $1 RETURNING *`,
        [proposal.id]
      );
      await client.query('UPDATE conversations SET updated_at = now() WHERE id = $1', [
        proposal.conversation_id,
      ]);
      await client.query(
        `INSERT INTO notifications (user_id, type, title, message, data)
         VALUES ($1, 'proposta_recusada', 'Proposta recusada', $2, $3::jsonb)`,
        [
          proposal.client_id,
          `A proposta “${proposal.title}” não foi aceita. Vocês ainda podem negociar pelo chat.`,
          JSON.stringify({ conversation_id: proposal.conversation_id, proposal_id: proposal.id }),
        ]
      );
      await client.query('COMMIT');
      return res.json({ proposal: declined.rows[0], service: null });
    }

    await assertNoScheduleConflict(client, {
      professionalId: proposal.professional_id,
      scheduledStart: proposal.scheduled_start,
      scheduledEnd: proposal.scheduled_end,
    });

    const serviceResult = await client.query(
      `INSERT INTO services (
         client_id, title, description, category, budget, status,
         scheduled_date, city, state, service_mode, address,
         open_confirmed_at, accepted_professional_id,
         scheduled_start, scheduled_end, is_all_day,
         agreed_pricing_type, agreed_amount
       ) VALUES (
         $1, $2, $3, $4, $5, 'agendado',
         ($6::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date,
         $7, $8, $9, $10, now(), $11, $6, $12, $13, $14, $5
       ) RETURNING *`,
      [
        proposal.client_id,
        proposal.title,
        proposal.description,
        proposal.category,
        proposal.amount,
        proposal.scheduled_start,
        proposal.city,
        proposal.state,
        proposal.service_mode,
        proposal.address,
        proposal.professional_id,
        proposal.scheduled_end,
        proposal.is_all_day,
        proposal.pricing_type,
      ]
    );
    const accepted = await client.query(
      `UPDATE job_proposals
       SET status = 'aceita', responded_at = now(), service_id = $2
       WHERE id = $1 RETURNING *`,
      [proposal.id, serviceResult.rows[0].id]
    );
    await client.query('UPDATE conversations SET updated_at = now() WHERE id = $1', [
      proposal.conversation_id,
    ]);
    await client.query(
      `INSERT INTO notifications (user_id, type, title, message, data)
       VALUES ($1, 'proposta_aceita', 'Proposta aceita', $2, $3::jsonb)`,
      [
        proposal.client_id,
        `O profissional aceitou “${proposal.title}”. O horário está reservado.`,
        JSON.stringify({
          conversation_id: proposal.conversation_id,
          proposal_id: proposal.id,
          service_id: serviceResult.rows[0].id,
        }),
      ]
    );
    await client.query('COMMIT');
    return res.json({ proposal: accepted.rows[0], service: serviceResult.rows[0] });
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.code === 'SCHEDULE_CONFLICT') {
      return res.status(409).json({ error: err.message, conflict: err.conflict });
    }
    console.error('Erro ao responder proposta:', err);
    return res.status(500).json({ error: 'Não foi possível responder à proposta.' });
  } finally {
    client.release();
  }
}

async function getUnreadCount(req, res) {
  try {
    const result = await pool.query(
      `SELECT COUNT(*)::int AS unread_count
       FROM chat_messages m
       JOIN conversations c ON c.id = m.conversation_id
       WHERE (c.client_id = $1 OR c.professional_id = $1)
         AND m.sender_id <> $1 AND m.read_at IS NULL`,
      [req.user.id]
    );
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Erro ao contar mensagens:', err);
    return res.status(500).json({ error: 'Não foi possível verificar novas mensagens.' });
  }
}

module.exports = {
  listConversations,
  openConversation,
  getConversationMessages,
  sendMessage,
  createProposal,
  respondToProposal,
  getUnreadCount,
};
