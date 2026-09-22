const pool = require('../config/db');

function sessionSelect(whereClause) {
  return `SELECT ws.*, s.title AS service_title, s.category, s.scheduled_date,
                 s.scheduled_start, s.scheduled_end, s.is_all_day,
                 s.city, s.state, s.service_mode,
                 client_user.name AS client_name,
                 professional_user.name AS professional_name
          FROM work_sessions ws
          JOIN services s ON s.id = ws.service_id
          JOIN users client_user ON client_user.id = ws.client_id
          JOIN users professional_user ON professional_user.id = ws.professional_id
          ${whereClause}`;
}

function mapAssignment(row, professionalId) {
  return {
    service: {
      id: row.id,
      client_id: row.client_id,
      client_name: row.client_name,
      title: row.title,
      description: row.description,
      category: row.category,
      budget: row.budget,
      status: row.status,
      created_at: row.created_at,
      accepted_professional_id: row.accepted_professional_id,
      scheduled_date: row.scheduled_date,
      scheduled_start: row.scheduled_start,
      scheduled_end: row.scheduled_end,
      is_all_day: row.is_all_day,
      agreed_pricing_type: row.agreed_pricing_type,
      agreed_amount: row.agreed_amount,
      city: row.city,
      state: row.state,
      service_mode: row.service_mode,
      address: row.address,
      latitude: row.latitude,
      longitude: row.longitude,
      open_confirmed_at: row.open_confirmed_at,
      needs_open_confirmation: false,
    },
    session: row.work_session_id
      ? {
          id: row.work_session_id,
          service_id: row.id,
          professional_id: professionalId,
          client_id: row.client_id,
          service_title: row.title,
          client_name: row.client_name,
          category: row.category,
          scheduled_date: row.scheduled_date,
          scheduled_start: row.scheduled_start,
          scheduled_end: row.scheduled_end,
          is_all_day: row.is_all_day,
          started_at: row.started_at,
          ended_at: row.ended_at,
          duration_minutes: row.duration_minutes,
          hourly_rate_snapshot: row.hourly_rate_snapshot,
          fixed_amount_snapshot: row.fixed_amount_snapshot,
          amount_basis: row.amount_basis,
          amount: row.amount,
          provider_note: row.provider_note,
          evidence_photo_url: row.evidence_photo_url,
          status: row.work_session_status,
          confirmed_at: row.confirmed_at,
        }
      : null,
  };
}

async function queryAgenda(professionalId, from, to) {
  return pool.query(
    `SELECT s.*, client_user.name AS client_name,
            ws.id AS work_session_id, ws.started_at, ws.ended_at,
            ws.duration_minutes, ws.hourly_rate_snapshot,
            ws.fixed_amount_snapshot, ws.amount_basis, ws.amount,
            ws.provider_note, ws.evidence_photo_url,
            ws.status AS work_session_status, ws.confirmed_at
     FROM services s
     JOIN users client_user ON client_user.id = s.client_id
     LEFT JOIN work_sessions ws ON ws.service_id = s.id
     WHERE s.accepted_professional_id = $1
       AND s.status IN ('agendado', 'em_andamento')
       AND (
         (s.scheduled_start < $3::timestamptz AND s.scheduled_end > $2::timestamptz)
         OR ws.status = 'em_andamento'
       )
     ORDER BY (ws.status = 'em_andamento') DESC NULLS LAST,
              s.scheduled_start ASC, s.created_at ASC`,
    [professionalId, from, to]
  );
}

async function getSessionById(id) {
  const result = await pool.query(sessionSelect('WHERE ws.id = $1'), [id]);
  return result.rows[0] || null;
}

async function listTodayWork(req, res) {
  try {
    const boundaries = await pool.query(
      `SELECT CURRENT_DATE::timestamp AT TIME ZONE 'America/Sao_Paulo' AS day_start,
              (CURRENT_DATE + 1)::timestamp AT TIME ZONE 'America/Sao_Paulo' AS day_end`
    );
    const result = await queryAgenda(
      req.user.id,
      boundaries.rows[0].day_start,
      boundaries.rows[0].day_end
    );
    return res.json(result.rows.map((row) => mapAssignment(row, req.user.id)));
  } catch (err) {
    console.error('Erro ao carregar trabalho do dia:', err);
    return res.status(500).json({ error: 'Não foi possível carregar seu trabalho do dia.' });
  }
}

async function listAgenda(req, res) {
  const from = new Date(String(req.query.from || ''));
  const to = new Date(String(req.query.to || ''));
  if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime()) || to <= from) {
    return res.status(400).json({ error: 'Informe um intervalo válido para consultar a agenda.' });
  }
  if (to.getTime() - from.getTime() > 45 * 24 * 60 * 60 * 1000) {
    return res.status(400).json({ error: 'Consulte no máximo 45 dias por vez.' });
  }

  try {
    const result = await queryAgenda(req.user.id, from.toISOString(), to.toISOString());
    return res.json(result.rows.map((row) => mapAssignment(row, req.user.id)));
  } catch (err) {
    console.error('Erro ao carregar agenda:', err);
    return res.status(500).json({ error: 'Não foi possível carregar sua agenda.' });
  }
}

async function startWork(req, res) {
  const { serviceId } = req.params;
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const serviceResult = await client.query(
      `SELECT s.*, p.hourly_rate, p.pricing_type, p.project_rate,
              u.name AS professional_name
       FROM services s
       JOIN professional_profiles p ON p.user_id = $1
       JOIN users u ON u.id = $1
       WHERE s.id = $2
       FOR UPDATE OF s`,
      [req.user.id, serviceId]
    );
    const service = serviceResult.rows[0];

    if (!service) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    }
    if (service.accepted_professional_id !== req.user.id) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Este serviço não foi atribuído a você.' });
    }
    if (!['agendado', 'em_andamento'].includes(service.status)) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Este serviço não está disponível para iniciar.' });
    }

    const futureResult = await client.query(
      `SELECT now() < $1::timestamptz - interval '30 minutes' AS is_too_early`,
      [service.scheduled_start]
    );
    if (futureResult.rows[0].is_too_early) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: 'O trabalho poderá ser iniciado 30 minutos antes do horário combinado.',
      });
    }

    const runningResult = await client.query(
      `SELECT id FROM work_sessions
       WHERE professional_id = $1 AND status = 'em_andamento'
       FOR UPDATE`,
      [req.user.id]
    );
    if (runningResult.rowCount > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Finalize o trabalho em andamento antes de iniciar outro.' });
    }

    const effectivePricingType = service.agreed_pricing_type || service.pricing_type;
    const usesProjectRate = effectivePricingType === 'empreitada';
    const hourlySource = service.agreed_amount ?? service.hourly_rate;
    const fixedSource = service.agreed_amount ?? service.budget ?? service.project_rate;
    const hourlyRate = !usesProjectRate && hourlySource != null
      ? Number(hourlySource)
      : null;
    const fixedAmount = usesProjectRate && fixedSource != null
      ? Number(fixedSource)
      : null;
    if (
      (hourlyRate == null || !Number.isFinite(hourlyRate) || hourlyRate <= 0)
      && (fixedAmount == null || !Number.isFinite(fixedAmount) || fixedAmount <= 0)
    ) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: usesProjectRate
          ? 'Defina o valor da empreitada no seu perfil antes de iniciar.'
          : 'Defina seu valor por hora no perfil antes de iniciar.',
      });
    }

    const amountBasis = hourlyRate != null ? 'por_hora' : 'valor_fixo';
    const inserted = await client.query(
      `INSERT INTO work_sessions (
         service_id, professional_id, client_id,
         hourly_rate_snapshot, fixed_amount_snapshot, amount_basis
       )
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id`,
      [service.id, req.user.id, service.client_id, hourlyRate, fixedAmount, amountBasis]
    );

    await client.query(
      `UPDATE services SET status = 'em_andamento' WHERE id = $1`,
      [service.id]
    );

    await client.query(
      `INSERT INTO notifications (user_id, type, title, message, data)
       VALUES ($1, 'trabalho_iniciado', 'Trabalho iniciado', $2, $3::jsonb)`,
      [
        service.client_id,
        `${service.professional_name} iniciou “${service.title}”.`,
        JSON.stringify({ service_id: service.id, work_session_id: inserted.rows[0].id }),
      ]
    );

    await client.query('COMMIT');
    return res.status(201).json(await getSessionById(inserted.rows[0].id));
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Já existe uma jornada registrada para este serviço.' });
    }
    console.error('Erro ao iniciar trabalho:', err);
    return res.status(500).json({ error: 'Não foi possível iniciar o trabalho.' });
  } finally {
    client.release();
  }
}

async function withdrawScheduledWork(req, res) {
  const { serviceId } = req.params;
  const reason = String(req.body?.reason || '').trim();
  if (reason.length < 5 || reason.length > 500) {
    return res.status(400).json({
      error: 'Explique o motivo da desistência em 5 a 500 caracteres.',
    });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      `SELECT id, client_id, title, status, accepted_professional_id
       FROM services WHERE id = $1 FOR UPDATE`,
      [serviceId]
    );
    const service = result.rows[0];
    if (!service) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    }
    if (service.accepted_professional_id !== req.user.id) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Este trabalho não está atribuído a você.' });
    }
    if (service.status !== 'agendado') {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: 'A desistência só pode ser registrada antes do início da jornada.',
      });
    }
    const session = await client.query(
      'SELECT 1 FROM work_sessions WHERE service_id = $1',
      [serviceId]
    );
    if (session.rowCount > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Este trabalho já possui uma jornada registrada.' });
    }

    await client.query(
      `UPDATE services
       SET status = 'cancelado', cancellation_reason = $2,
           cancelled_by = $3, cancelled_at = now()
       WHERE id = $1`,
      [serviceId, reason, req.user.id]
    );
    await client.query(
      `INSERT INTO notifications (user_id, type, title, message, data)
       VALUES ($1, 'profissional_desistiu', 'Profissional indisponível', $2, $3::jsonb)`,
      [
        service.client_id,
        `O profissional desistiu de “${service.title}”. O período foi liberado.`,
        JSON.stringify({ service_id: serviceId, reason }),
      ]
    );
    await client.query('COMMIT');
    return res.status(204).send();
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao desistir de trabalho agendado:', err);
    return res.status(500).json({ error: 'Não foi possível registrar a desistência.' });
  } finally {
    client.release();
  }
}

async function finishWork(req, res) {
  const { id } = req.params;
  const note = String(req.body?.note || '').trim();
  const evidencePhotoUrl = req.file ? `/uploads/${req.file.filename}` : null;
  const client = await pool.connect();

  if (note.length > 1200) {
    return res.status(400).json({ error: 'A observação deve ter no máximo 1.200 caracteres.' });
  }

  try {
    await client.query('BEGIN');
    const sessionResult = await client.query(
      `SELECT ws.*, s.title
       FROM work_sessions ws
       JOIN services s ON s.id = ws.service_id
       WHERE ws.id = $1
       FOR UPDATE OF ws`,
      [id]
    );
    const session = sessionResult.rows[0];

    if (!session) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Jornada não encontrada.' });
    }
    if (session.professional_id !== req.user.id) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Você não pode encerrar esta jornada.' });
    }
    if (session.status !== 'em_andamento') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Esta jornada já foi encerrada.' });
    }

    const durationMinutes = Math.max(1, Math.ceil((Date.now() - new Date(session.started_at).getTime()) / 60000));
    const amount = session.amount_basis === 'por_hora'
      ? Number((Number(session.hourly_rate_snapshot) * durationMinutes / 60).toFixed(2))
      : Number(session.fixed_amount_snapshot);

    const preferenceResult = await client.query(
      `SELECT COALESCE(
         (SELECT require_work_confirmation FROM client_preferences WHERE user_id = $1),
         TRUE
       ) AS require_confirmation`,
      [session.client_id]
    );
    const requireConfirmation = preferenceResult.rows[0].require_confirmation;
    const nextStatus = requireConfirmation ? 'aguardando_confirmacao' : 'confirmado';

    await client.query(
      `UPDATE work_sessions
       SET ended_at = now(), duration_minutes = $2, amount = $3,
           provider_note = NULLIF($4, ''), evidence_photo_url = $5,
           status = $6::work_session_status,
           confirmed_at = CASE WHEN $7::boolean THEN now() ELSE NULL END,
           updated_at = now()
       WHERE id = $1`,
      [id, durationMinutes, amount, note, evidencePhotoUrl, nextStatus, !requireConfirmation]
    );

    if (!requireConfirmation) {
      await client.query(`UPDATE services SET status = 'concluido' WHERE id = $1`, [session.service_id]);
    }

    await client.query(
      `INSERT INTO notifications (user_id, type, title, message, data)
       VALUES ($1, $2, $3, $4, $5::jsonb)`,
      [
        session.client_id,
        requireConfirmation ? 'confirmacao_pendente' : 'trabalho_finalizado',
        requireConfirmation ? 'Confirmação de jornada pendente' : 'Trabalho finalizado',
        requireConfirmation
          ? `O profissional finalizou “${session.title}”. Confira os dados e confirme.`
          : `O profissional finalizou “${session.title}”. A jornada foi confirmada automaticamente.`,
        JSON.stringify({ service_id: session.service_id, work_session_id: id }),
      ]
    );

    await client.query('COMMIT');
    return res.json(await getSessionById(id));
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao finalizar trabalho:', err);
    return res.status(500).json({ error: 'Não foi possível finalizar o trabalho.' });
  } finally {
    client.release();
  }
}

async function listPendingConfirmations(req, res) {
  try {
    const result = await pool.query(
      sessionSelect(`WHERE ws.client_id = $1 AND ws.status = 'aguardando_confirmacao'
                     ORDER BY ws.ended_at ASC`),
      [req.user.id]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar confirmações:', err);
    return res.status(500).json({ error: 'Não foi possível carregar as confirmações pendentes.' });
  }
}

async function confirmWork(req, res) {
  const { id } = req.params;
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    const result = await client.query(
      `SELECT ws.*, s.title
       FROM work_sessions ws
       JOIN services s ON s.id = ws.service_id
       WHERE ws.id = $1
       FOR UPDATE OF ws`,
      [id]
    );
    const session = result.rows[0];

    if (!session) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Jornada não encontrada.' });
    }
    if (session.client_id !== req.user.id) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Você não pode confirmar esta jornada.' });
    }
    if (session.status !== 'aguardando_confirmacao') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Esta jornada não aguarda confirmação.' });
    }

    await client.query(
      `UPDATE work_sessions
       SET status = 'confirmado', confirmed_at = now(), updated_at = now()
       WHERE id = $1`,
      [id]
    );
    await client.query(`UPDATE services SET status = 'concluido' WHERE id = $1`, [session.service_id]);
    await client.query(
      `UPDATE notifications
       SET read_at = COALESCE(read_at, now())
       WHERE user_id = $1
         AND type = 'confirmacao_pendente'
         AND data->>'work_session_id' = $2`,
      [session.client_id, id]
    );
    await client.query(
      `INSERT INTO notifications (user_id, type, title, message, data)
       VALUES ($1, 'jornada_confirmada', 'Jornada confirmada', $2, $3::jsonb)`,
      [
        session.professional_id,
        `O contratante confirmou a jornada de “${session.title}”.`,
        JSON.stringify({ service_id: session.service_id, work_session_id: id }),
      ]
    );

    await client.query('COMMIT');
    return res.json(await getSessionById(id));
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao confirmar jornada:', err);
    return res.status(500).json({ error: 'Não foi possível confirmar a jornada.' });
  } finally {
    client.release();
  }
}

async function getPreferences(req, res) {
  try {
    const result = await pool.query(
      `SELECT COALESCE(
         (SELECT require_work_confirmation FROM client_preferences WHERE user_id = $1),
         TRUE
       ) AS require_work_confirmation`,
      [req.user.id]
    );
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Erro ao carregar preferências:', err);
    return res.status(500).json({ error: 'Não foi possível carregar suas preferências.' });
  }
}

async function updatePreferences(req, res) {
  const { require_work_confirmation: requireConfirmation } = req.body;
  if (typeof requireConfirmation !== 'boolean') {
    return res.status(400).json({ error: 'A preferência de confirmação deve ser verdadeira ou falsa.' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO client_preferences (user_id, require_work_confirmation)
       VALUES ($1, $2)
       ON CONFLICT (user_id) DO UPDATE
       SET require_work_confirmation = EXCLUDED.require_work_confirmation,
           updated_at = now()
       RETURNING require_work_confirmation`,
      [req.user.id, requireConfirmation]
    );
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Erro ao salvar preferências:', err);
    return res.status(500).json({ error: 'Não foi possível salvar suas preferências.' });
  }
}

async function getPerformance(req, res) {
  const currentMonth = new Date().toISOString().slice(0, 7);
  const month = req.query.month || currentMonth;
  if (!/^\d{4}-\d{2}$/.test(String(month))) {
    return res.status(400).json({ error: 'Informe o mês no formato AAAA-MM.' });
  }
  const monthStart = `${month}-01`;

  try {
    const [weekResult, monthResult, dailyResult, historyResult] = await Promise.all([
      pool.query(
        `SELECT COUNT(*)::int AS service_count,
                COALESCE(SUM(duration_minutes), 0)::int AS total_minutes,
                COALESCE(SUM(amount), 0)::numeric(10, 2) AS total_amount
         FROM work_sessions
         WHERE professional_id = $1 AND status = 'confirmado'
           AND ended_at >= date_trunc('week', CURRENT_DATE)
           AND ended_at < date_trunc('week', CURRENT_DATE) + interval '7 days'`,
        [req.user.id]
      ),
      pool.query(
        `SELECT COUNT(*)::int AS service_count,
                COALESCE(SUM(duration_minutes), 0)::int AS total_minutes,
                COALESCE(SUM(amount), 0)::numeric(10, 2) AS total_amount
         FROM work_sessions
         WHERE professional_id = $1 AND status = 'confirmado'
           AND ended_at >= $2::date
           AND ended_at < $2::date + interval '1 month'`,
        [req.user.id, monthStart]
      ),
      pool.query(
        `SELECT ended_at::date AS day,
                COUNT(*)::int AS service_count,
                COALESCE(SUM(duration_minutes), 0)::int AS total_minutes,
                COALESCE(SUM(amount), 0)::numeric(10, 2) AS total_amount
         FROM work_sessions
         WHERE professional_id = $1 AND status = 'confirmado'
           AND ended_at >= $2::date
           AND ended_at < $2::date + interval '1 month'
         GROUP BY ended_at::date
         ORDER BY day ASC`,
        [req.user.id, monthStart]
      ),
      pool.query(
        sessionSelect(`WHERE ws.professional_id = $1 AND ws.status = 'confirmado'
                       ORDER BY ws.ended_at DESC LIMIT 50`),
        [req.user.id]
      ),
    ]);

    return res.json({
      month,
      week: weekResult.rows[0],
      month_summary: monthResult.rows[0],
      daily: dailyResult.rows,
      history: historyResult.rows,
    });
  } catch (err) {
    console.error('Erro ao carregar desempenho:', err);
    return res.status(500).json({ error: 'Não foi possível carregar seu desempenho.' });
  }
}

async function getReceipt(req, res) {
  try {
    const session = await getSessionById(req.params.id);
    if (!session) return res.status(404).json({ error: 'Comprovante não encontrado.' });
    if (![session.client_id, session.professional_id].includes(req.user.id)) {
      return res.status(403).json({ error: 'Você não pode consultar este comprovante.' });
    }
    if (session.status !== 'confirmado') {
      return res.status(409).json({ error: 'O comprovante fica disponível depois da confirmação da jornada.' });
    }

    const date = new Date(session.ended_at).toISOString().slice(0, 10).replaceAll('-', '');
    return res.json({
      ...session,
      receipt_number: `CA-${date}-${session.id.slice(0, 8).toUpperCase()}`,
      document_type: 'comprovante_nao_fiscal',
    });
  } catch (err) {
    console.error('Erro ao carregar comprovante:', err);
    return res.status(500).json({ error: 'Não foi possível carregar o comprovante.' });
  }
}

async function listNotifications(req, res) {
  try {
    const result = await pool.query(
      `SELECT n.*,
              CASE
                WHEN n.type = 'confirmacao_pendente'
                  THEN COALESCE(ws.status = 'aguardando_confirmacao', FALSE)
                ELSE FALSE
              END AS action_required
       FROM notifications n
       LEFT JOIN work_sessions ws
         ON ws.id::text = n.data->>'work_session_id'
       WHERE n.user_id = $1
       ORDER BY n.created_at DESC
       LIMIT 30`,
      [req.user.id]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar notificações:', err);
    return res.status(500).json({ error: 'Não foi possível carregar as notificações.' });
  }
}

async function markAllNotificationsRead(req, res) {
  try {
    const result = await pool.query(
      `UPDATE notifications
       SET read_at = COALESCE(read_at, now())
       WHERE user_id = $1 AND read_at IS NULL
       RETURNING id`,
      [req.user.id]
    );
    return res.json({ updated: result.rowCount });
  } catch (err) {
    console.error('Erro ao marcar notificações como lidas:', err);
    return res.status(500).json({ error: 'Não foi possível atualizar as notificações.' });
  }
}

async function markNotificationRead(req, res) {
  try {
    const result = await pool.query(
      `UPDATE notifications SET read_at = COALESCE(read_at, now())
       WHERE id = $1 AND user_id = $2 RETURNING *`,
      [req.params.id, req.user.id]
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'Notificação não encontrada.' });
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Erro ao marcar notificação:', err);
    return res.status(500).json({ error: 'Não foi possível atualizar a notificação.' });
  }
}

module.exports = {
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
};
