const pool = require('../config/db');
const fs = require('fs');
const path = require('path');
const { UPLOAD_DIR } = require('../middlewares/upload');
const {
  parseSchedulePayload,
  assertNoScheduleConflict,
} = require('./scheduleService');

const VALID_SERVICE_MODES = ['presencial', 'remoto', 'hibrido'];
const VALID_SERVICE_STATUSES = ['aberto', 'agendado', 'em_andamento', 'concluido', 'cancelado'];

function deleteUploadedFile(fileOrUrl) {
  if (!fileOrUrl) return;
  const filename = typeof fileOrUrl === 'string'
    ? path.basename(fileOrUrl)
    : fileOrUrl.filename;
  fs.unlink(path.join(UPLOAD_DIR, filename), () => {});
}

function rejectServicePayload(req, res, status, error) {
  deleteUploadedFile(req.file);
  return res.status(status).json({ error });
}

function validateServicePayload(req, res) {
  const {
    title,
    description,
    category,
    budget,
    scheduled_date: scheduledDate,
    city,
    state,
    service_mode: serviceMode,
    address,
    latitude,
    longitude,
  } = req.body;

  if (!title || !description || !category || !scheduledDate || !serviceMode) {
    rejectServicePayload(
      req,
      res,
      400,
      'Título, descrição, profissão, data e forma de atendimento são obrigatórios.'
    );
    return null;
  }
  if (String(title).trim().length < 5 || String(title).trim().length > 150) {
    rejectServicePayload(req, res, 400, 'O título deve ter entre 5 e 150 caracteres.');
    return null;
  }
  if (String(description).trim().length < 20) {
    rejectServicePayload(req, res, 400, 'A descrição deve ter pelo menos 20 caracteres.');
    return null;
  }
  if (!VALID_SERVICE_MODES.includes(serviceMode)) {
    rejectServicePayload(req, res, 400, 'Informe uma forma de atendimento válida.');
    return null;
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(scheduledDate))) {
    rejectServicePayload(req, res, 400, 'Informe a data do serviço no formato AAAA-MM-DD.');
    return null;
  }
  const schedule = parseSchedulePayload(req.body);
  if (schedule.error) {
    rejectServicePayload(req, res, 400, schedule.error);
    return null;
  }
  if (['presencial', 'hibrido'].includes(serviceMode) && (!city || !state)) {
    rejectServicePayload(req, res, 400, 'Cidade e estado são obrigatórios para atendimento presencial.');
    return null;
  }
  const hasLatitude = latitude !== '' && latitude !== undefined && latitude !== null;
  const hasLongitude = longitude !== '' && longitude !== undefined && longitude !== null;
  if (['presencial', 'hibrido'].includes(serviceMode) && (!hasLatitude || !hasLongitude)) {
    rejectServicePayload(req, res, 400, 'Localize o serviço no mapa antes de publicar.');
    return null;
  }
  if (state && !/^[A-Z]{2}$/.test(String(state).toUpperCase())) {
    rejectServicePayload(req, res, 400, 'Informe uma UF válida.');
    return null;
  }
  const normalizedBudget = budget === '' || budget === undefined || budget === null
    ? null
    : Number(budget);
  if (normalizedBudget !== null && (!Number.isFinite(normalizedBudget) || normalizedBudget <= 0)) {
    rejectServicePayload(req, res, 400, 'O valor fixo deve ser maior que zero.');
    return null;
  }
  if (address && String(address).trim().length > 220) {
    rejectServicePayload(req, res, 400, 'O endereço deve ter no máximo 220 caracteres.');
    return null;
  }
  const normalizedLatitude = hasLatitude ? Number(latitude) : null;
  const normalizedLongitude = hasLongitude ? Number(longitude) : null;
  if (
    (normalizedLatitude !== null && (!Number.isFinite(normalizedLatitude) || normalizedLatitude < -90 || normalizedLatitude > 90)) ||
    (normalizedLongitude !== null && (!Number.isFinite(normalizedLongitude) || normalizedLongitude < -180 || normalizedLongitude > 180))
  ) {
    rejectServicePayload(req, res, 400, 'As coordenadas informadas são inválidas.');
    return null;
  }

  return {
    title: String(title).trim(),
    description: String(description).trim(),
    category: String(category).trim(),
    budget: normalizedBudget,
    scheduledDate: schedule.scheduledDate,
    scheduledStart: schedule.scheduledStart,
    scheduledEnd: schedule.scheduledEnd,
    isAllDay: schedule.isAllDay,
    city: city?.trim() || null,
    state: state?.toUpperCase() || null,
    serviceMode,
    address: address?.trim() || null,
    latitude: serviceMode === 'remoto' ? null : normalizedLatitude,
    longitude: serviceMode === 'remoto' ? null : normalizedLongitude,
  };
}

function serviceSelect() {
  return `SELECT s.*, u.name AS client_name,
          (s.status = 'aberto'
            AND s.scheduled_date < CURRENT_DATE
            AND s.open_confirmed_at::date < CURRENT_DATE) AS needs_open_confirmation,
          (SELECT COUNT(*)::int FROM service_applications sa WHERE sa.service_id = s.id) AS application_count
          FROM services s
          JOIN users u ON u.id = s.client_id`;
}

async function listOpenServices(req, res) {
  const {
    q,
    category,
    city,
    state,
    service_mode: serviceMode,
    status = 'aberto',
    date_scope: dateScope = 'hoje',
    min_budget: minBudget,
    max_budget: maxBudget,
  } = req.query;

  const conditions = [];
  const params = [];

  if (status === 'fechados') {
    conditions.push(`s.status IN ('concluido', 'cancelado')`);
  } else if (status !== 'todos') {
    if (!VALID_SERVICE_STATUSES.includes(status)) {
      return res.status(400).json({ error: 'Informe um status de serviço válido.' });
    }
    params.push(status);
    conditions.push(`s.status = $${params.length}`);
  }

  if (!['hoje', 'proximos', 'todos'].includes(dateScope)) {
    return res.status(400).json({ error: 'Informe um período válido: hoje, proximos ou todos.' });
  }
  if (dateScope === 'hoje') {
    conditions.push(`(
      s.scheduled_date = CURRENT_DATE
      OR (s.scheduled_date < CURRENT_DATE AND s.open_confirmed_at::date = CURRENT_DATE)
    )`);
  } else if (dateScope === 'proximos') {
    conditions.push('s.scheduled_date > CURRENT_DATE');
  }

  // Um anúncio aberto com data vencida só volta à descoberta depois de o
  // contratante confirmar explicitamente que a vaga continua disponível.
  conditions.push(`(
    s.status <> 'aberto'
    OR s.scheduled_date >= CURRENT_DATE
    OR s.open_confirmed_at::date = CURRENT_DATE
  )`);

  if (q) {
    params.push(`%${String(q).trim()}%`);
    conditions.push(`(s.title ILIKE $${params.length} OR s.description ILIKE $${params.length})`);
  }
  if (category) {
    params.push(String(category).trim());
    conditions.push(`LOWER(s.category) = LOWER($${params.length})`);
  }
  if (city) {
    params.push(String(city).trim());
    conditions.push(`LOWER(s.city) = LOWER($${params.length})`);
  }
  if (state) {
    const normalizedState = String(state).trim().toUpperCase();
    if (!/^[A-Z]{2}$/.test(normalizedState)) {
      return res.status(400).json({ error: 'O filtro de estado deve ser uma UF válida.' });
    }
    params.push(normalizedState);
    conditions.push(`s.state = $${params.length}`);
  }
  if (serviceMode) {
    if (!VALID_SERVICE_MODES.includes(serviceMode)) {
      return res.status(400).json({ error: 'Informe uma forma de atendimento válida.' });
    }
    params.push(serviceMode);
    conditions.push(`s.service_mode = $${params.length}`);
  }
  if (minBudget !== undefined) {
    const value = Number(minBudget);
    if (!Number.isFinite(value) || value < 0) {
      return res.status(400).json({ error: 'O orçamento mínimo deve ser um número válido.' });
    }
    params.push(value);
    conditions.push(`s.budget >= $${params.length}`);
  }
  if (maxBudget !== undefined) {
    const value = Number(maxBudget);
    if (!Number.isFinite(value) || value <= 0) {
      return res.status(400).json({ error: 'O orçamento máximo deve ser maior que zero.' });
    }
    params.push(value);
    conditions.push(`s.budget <= $${params.length}`);
  }

  try {
    const result = await pool.query(
      `${serviceSelect()}
       WHERE ${conditions.join(' AND ')}
       ORDER BY s.scheduled_date ASC, s.created_at DESC`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar serviços abertos:', err);
    return res.status(500).json({ error: 'Não foi possível carregar os serviços.' });
  }
}

async function listMyServices(req, res) {
  try {
    const result = await pool.query(
      `${serviceSelect()}
       WHERE s.client_id = $1
       ORDER BY s.scheduled_date DESC, s.created_at DESC`,
      [req.user.id]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar meus serviços:', err);
    return res.status(500).json({ error: 'Não foi possível carregar seus serviços.' });
  }
}

async function getServiceById(req, res) {
  const { id } = req.params;

  try {
    const result = await pool.query(
      `${serviceSelect()}
       WHERE s.id = $1`,
      [id]
    );

    const service = result.rows[0];
    if (!service) {
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    }

    return res.json(service);
  } catch (err) {
    console.error('Erro ao buscar serviço:', err);
    return res.status(500).json({ error: 'Não foi possível carregar o serviço.' });
  }
}

async function listApplicationsForService(req, res) {
  const { id: serviceId } = req.params;

  try {
    const serviceResult = await pool.query('SELECT client_id FROM services WHERE id = $1', [serviceId]);
    const service = serviceResult.rows[0];

    if (!service) {
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    }
    if (service.client_id !== req.user.id) {
      return res.status(403).json({ error: 'Você não tem permissão para ver os candidatos deste serviço.' });
    }

    const result = await pool.query(
      `SELECT sa.*, u.name AS professional_name, p.photo_url,
              p.skills AS professional_skills, p.pricing_type,
              p.hourly_rate, p.project_rate,
              ROUND(AVG(r.rating), 2) AS rating_average,
              COUNT(r.id)::int AS rating_count
       FROM service_applications sa
       JOIN users u ON u.id = sa.professional_id
       JOIN professional_profiles p ON p.user_id = sa.professional_id
       LEFT JOIN reviews r ON r.professional_id = sa.professional_id
       WHERE sa.service_id = $1
       GROUP BY sa.id, u.id, p.user_id
       ORDER BY sa.created_at ASC`,
      [serviceId]
    );

    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar candidatos do serviço:', err);
    return res.status(500).json({ error: 'Não foi possível carregar os candidatos.' });
  }
}

async function acceptApplication(req, res) {
  const { id: serviceId, applicationId } = req.params;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // FOR UPDATE trava a linha do serviço dentro da transação, para que
    // duas aceitações concorrentes no mesmo serviço não passem as duas
    // pela checagem de status === 'aberto' antes de qualquer uma commitar.
    const serviceResult = await client.query(
      `SELECT client_id, status, title, budget, scheduled_date,
              scheduled_start, scheduled_end, open_confirmed_at,
              (scheduled_date < CURRENT_DATE AND open_confirmed_at::date < CURRENT_DATE) AS stale
       FROM services WHERE id = $1 FOR UPDATE`,
      [serviceId]
    );
    const service = serviceResult.rows[0];

    if (!service) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    }
    if (service.client_id !== req.user.id) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Você não tem permissão para gerenciar este serviço.' });
    }
    if (service.status !== 'aberto') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Este serviço não está mais aberto para escolher um profissional.' });
    }
    if (service.stale) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: 'Confirme que o serviço continua aberto antes de aceitar um profissional.',
      });
    }

    const applicationResult = await client.query(
      'SELECT id, professional_id, status FROM service_applications WHERE id = $1 AND service_id = $2 FOR UPDATE',
      [applicationId, serviceId]
    );
    const application = applicationResult.rows[0];

    if (!application) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Candidatura não encontrada.' });
    }
    if (application.status !== 'pendente') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Esta candidatura já foi processada.' });
    }

    await assertNoScheduleConflict(client, {
      professionalId: application.professional_id,
      scheduledStart: service.scheduled_start,
      scheduledEnd: service.scheduled_end,
      excludeServiceId: serviceId,
    });

    const pricingResult = await client.query(
      `SELECT pricing_type, hourly_rate, project_rate
       FROM professional_profiles WHERE user_id = $1`,
      [application.professional_id]
    );
    const pricing = pricingResult.rows[0];
    const agreedPricingType = pricing?.pricing_type || 'empreitada';
    const agreedAmount = agreedPricingType === 'por_hora'
      ? pricing?.hourly_rate
      : (service.budget ?? pricing?.project_rate);

    await client.query(`UPDATE service_applications SET status = 'aceito' WHERE id = $1`, [applicationId]);

    await client.query(
      `UPDATE service_applications
       SET status = 'recusado'
       WHERE service_id = $1 AND id != $2 AND status = 'pendente'`,
      [serviceId, applicationId]
    );

    const updatedServiceResult = await client.query(
      `UPDATE services
       SET status = 'agendado', accepted_professional_id = $1,
           agreed_pricing_type = $3, agreed_amount = $4
       WHERE id = $2
       RETURNING *`,
      [application.professional_id, serviceId, agreedPricingType, agreedAmount]
    );

    await client.query(
      `INSERT INTO notifications (user_id, type, title, message, data)
       VALUES ($1, 'servico_agendado', 'Novo trabalho agendado', $2, $3::jsonb)`,
      [
        application.professional_id,
        `Sua candidatura para “${service.title}” foi aceita. Confira o horário na Agenda.`,
        JSON.stringify({ service_id: serviceId }),
      ]
    );

    await client.query('COMMIT');

    const userResult = await pool.query('SELECT name FROM users WHERE id = $1', [service.client_id]);
    const updatedService = { ...updatedServiceResult.rows[0], client_name: userResult.rows[0]?.name ?? null };

    return res.json({ service: updatedService });
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.code === 'SCHEDULE_CONFLICT') {
      return res.status(409).json({
        error: err.message,
        conflict: err.conflict,
      });
    }
    console.error('Erro ao aceitar candidatura:', err);
    return res.status(500).json({ error: 'Não foi possível aceitar a candidatura.' });
  } finally {
    client.release();
  }
}

async function rejectApplication(req, res) {
  const { id: serviceId, applicationId } = req.params;

  try {
    const serviceResult = await pool.query('SELECT client_id FROM services WHERE id = $1', [serviceId]);
    const service = serviceResult.rows[0];

    if (!service) {
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    }
    if (service.client_id !== req.user.id) {
      return res.status(403).json({ error: 'Você não tem permissão para gerenciar este serviço.' });
    }

    const result = await pool.query(
      `UPDATE service_applications
       SET status = 'recusado'
       WHERE id = $1 AND service_id = $2 AND status = 'pendente'
       RETURNING *`,
      [applicationId, serviceId]
    );

    if (result.rowCount === 0) {
      const existsResult = await pool.query(
        'SELECT status FROM service_applications WHERE id = $1 AND service_id = $2',
        [applicationId, serviceId]
      );
      if (existsResult.rowCount === 0) {
        return res.status(404).json({ error: 'Candidatura não encontrada.' });
      }
      return res.status(409).json({ error: 'Esta candidatura já foi processada.' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Erro ao recusar candidatura:', err);
    return res.status(500).json({ error: 'Não foi possível recusar a candidatura.' });
  }
}

async function completeService(req, res) {
  const { id: serviceId } = req.params;

  try {
    const serviceResult = await pool.query('SELECT client_id, status FROM services WHERE id = $1', [serviceId]);
    const service = serviceResult.rows[0];

    if (!service) {
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    }
    if (service.client_id !== req.user.id) {
      return res.status(403).json({ error: 'Você não tem permissão para gerenciar este serviço.' });
    }
    if (service.status !== 'em_andamento') {
      return res.status(409).json({ error: 'Só é possível concluir um serviço que está em andamento.' });
    }

    return res.status(409).json({
      error: 'A conclusão é feita pelo encerramento da jornada e pela confirmação na Central de trabalho.',
    });
  } catch (err) {
    console.error('Erro ao concluir serviço:', err);
    return res.status(500).json({ error: 'Não foi possível concluir o serviço.' });
  }
}

async function cancelService(req, res) {
  const { id: serviceId } = req.params;
  const cancellationReason = String(req.body?.reason || '').trim();
  if (cancellationReason.length > 500) {
    return res.status(400).json({ error: 'O motivo deve ter no máximo 500 caracteres.' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const serviceResult = await client.query('SELECT client_id, status, title, accepted_professional_id FROM services WHERE id = $1 FOR UPDATE', [
      serviceId,
    ]);
    const service = serviceResult.rows[0];

    if (!service) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    }
    if (service.client_id !== req.user.id) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Você não tem permissão para gerenciar este serviço.' });
    }
    if (!['aberto', 'agendado', 'em_andamento'].includes(service.status)) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Este serviço não pode mais ser cancelado.' });
    }

    const workResult = await client.query(
      `SELECT status FROM work_sessions
       WHERE service_id = $1 AND status IN ('em_andamento', 'aguardando_confirmacao')`,
      [serviceId]
    );
    if (workResult.rowCount > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: 'Não é possível cancelar enquanto existe uma jornada ativa ou aguardando confirmação.',
      });
    }

    const updatedServiceResult = await client.query(
      `UPDATE services
       SET status = 'cancelado', cancellation_reason = NULLIF($2, ''),
           cancelled_by = $3, cancelled_at = now()
       WHERE id = $1 RETURNING *`,
      [serviceId, cancellationReason, req.user.id]
    );
    // Candidaturas ainda pendentes ficam órfãs sem sentido num serviço
    // cancelado — são recusadas em cascata.
    await client.query(
      `UPDATE service_applications SET status = 'recusado' WHERE service_id = $1 AND status = 'pendente'`,
      [serviceId]
    );
    if (service.accepted_professional_id) {
      await client.query(
        `INSERT INTO notifications (user_id, type, title, message, data)
         VALUES ($1, 'servico_cancelado', 'Agendamento cancelado', $2, $3::jsonb)`,
        [
          service.accepted_professional_id,
          `O contratante cancelou “${service.title}”. O horário voltou a ficar livre.`,
          JSON.stringify({ service_id: serviceId, reason: cancellationReason || null }),
        ]
      );
    }

    await client.query('COMMIT');

    const userResult = await pool.query('SELECT name FROM users WHERE id = $1', [service.client_id]);
    const updatedService = { ...updatedServiceResult.rows[0], client_name: userResult.rows[0]?.name ?? null };

    return res.json({ service: updatedService });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao cancelar serviço:', err);
    return res.status(500).json({ error: 'Não foi possível cancelar o serviço.' });
  } finally {
    client.release();
  }
}

async function createService(req, res) {
  const payload = validateServicePayload(req, res);
  if (!payload) return;
  const imageUrl = req.file ? `/uploads/${req.file.filename}` : null;

  try {
    const dateResult = await pool.query('SELECT $1::date < CURRENT_DATE AS is_past', [payload.scheduledDate]);
    if (dateResult.rows[0].is_past) {
      return rejectServicePayload(req, res, 400, 'A data do serviço não pode estar no passado.');
    }

    const result = await pool.query(
      `INSERT INTO services (
         client_id, title, description, category, budget, scheduled_date,
         city, state, service_mode, address, image_url, latitude, longitude,
         open_confirmed_at, scheduled_start, scheduled_end, is_all_day
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13,
               now(), $14, $15, $16)
       RETURNING *`,
      [
        req.user.id,
        payload.title,
        payload.description,
        payload.category,
        payload.budget,
        payload.scheduledDate,
        payload.city,
        payload.state,
        payload.serviceMode,
        payload.address,
        imageUrl,
        payload.latitude,
        payload.longitude,
        payload.scheduledStart,
        payload.scheduledEnd,
        payload.isAllDay,
      ]
    );

    // Devolve também o nome do cliente para o app não precisar de outra chamada.
    const userResult = await pool.query('SELECT name FROM users WHERE id = $1', [req.user.id]);
    const service = { ...result.rows[0], client_name: userResult.rows[0]?.name ?? null };

    return res.status(201).json(service);
  } catch (err) {
    deleteUploadedFile(req.file);
    console.error('Erro ao criar serviço:', err);
    return res.status(500).json({ error: 'Não foi possível criar o serviço.' });
  }
}

async function updateService(req, res) {
  const payload = validateServicePayload(req, res);
  if (!payload) return;
  const { id: serviceId } = req.params;
  const newImageUrl = req.file ? `/uploads/${req.file.filename}` : null;

  try {
    const dateResult = await pool.query('SELECT $1::date < CURRENT_DATE AS is_past', [payload.scheduledDate]);
    if (dateResult.rows[0].is_past) {
      return rejectServicePayload(req, res, 400, 'A data do serviço não pode estar no passado.');
    }

    const existingResult = await pool.query(
      'SELECT client_id, status, image_url FROM services WHERE id = $1',
      [serviceId]
    );
    const existing = existingResult.rows[0];
    if (!existing) return rejectServicePayload(req, res, 404, 'Serviço não encontrado.');
    if (existing.client_id !== req.user.id) {
      return rejectServicePayload(req, res, 403, 'Você não tem permissão para editar este serviço.');
    }
    if (existing.status !== 'aberto') {
      return rejectServicePayload(req, res, 409, 'Somente serviços abertos podem ser editados.');
    }

    const result = await pool.query(
      `UPDATE services
       SET title = $1, description = $2, category = $3, budget = $4,
           scheduled_date = $5, city = $6, state = $7, service_mode = $8,
           address = $9, image_url = COALESCE($10, image_url),
           latitude = $11, longitude = $12,
           scheduled_start = $13, scheduled_end = $14, is_all_day = $15
       WHERE id = $16
       RETURNING *`,
      [
        payload.title,
        payload.description,
        payload.category,
        payload.budget,
        payload.scheduledDate,
        payload.city,
        payload.state,
        payload.serviceMode,
        payload.address,
        newImageUrl,
        payload.latitude,
        payload.longitude,
        payload.scheduledStart,
        payload.scheduledEnd,
        payload.isAllDay,
        serviceId,
      ]
    );

    if (newImageUrl && existing.image_url) deleteUploadedFile(existing.image_url);
    const userResult = await pool.query('SELECT name FROM users WHERE id = $1', [req.user.id]);
    return res.json({
      ...result.rows[0],
      client_name: userResult.rows[0]?.name ?? null,
    });
  } catch (err) {
    deleteUploadedFile(req.file);
    console.error('Erro ao editar serviço:', err);
    return res.status(500).json({ error: 'Não foi possível editar o serviço.' });
  }
}

async function applyToService(req, res) {
  const { id: serviceId } = req.params;
  const { message } = req.body;

  try {
    const serviceResult = await pool.query(
      'SELECT id, status, scheduled_date, open_confirmed_at FROM services WHERE id = $1',
      [serviceId]
    );
    const service = serviceResult.rows[0];

    if (!service) {
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    }
    if (service.status !== 'aberto') {
      return res.status(409).json({ error: 'Este serviço não está mais aberto para candidaturas.' });
    }
    const staleResult = await pool.query(
      `SELECT ($1::date < CURRENT_DATE AND $2::timestamptz::date < CURRENT_DATE) AS stale`,
      [service.scheduled_date, service.open_confirmed_at]
    );
    if (staleResult.rows[0].stale) {
      return res.status(409).json({
        error: 'A data deste serviço passou. Aguarde o contratante confirmar que ele continua aberto.',
      });
    }

    const result = await pool.query(
      `INSERT INTO service_applications (service_id, professional_id, message)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [serviceId, req.user.id, message || null]
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      // unique_violation: já existe candidatura desse profissional para esse serviço
      return res.status(409).json({ error: 'Você já se candidatou a este serviço.' });
    }
    console.error('Erro ao candidatar-se ao serviço:', err);
    return res.status(500).json({ error: 'Não foi possível enviar a candidatura.' });
  }
}

async function renewOpenService(req, res) {
  const { id: serviceId } = req.params;

  try {
    const result = await pool.query(
      `UPDATE services
       SET open_confirmed_at = now()
       WHERE id = $1 AND client_id = $2 AND status = 'aberto'
       RETURNING *`,
      [serviceId, req.user.id]
    );

    if (result.rowCount === 0) {
      const existing = await pool.query('SELECT client_id, status FROM services WHERE id = $1', [serviceId]);
      if (existing.rowCount === 0) return res.status(404).json({ error: 'Serviço não encontrado.' });
      if (existing.rows[0].client_id !== req.user.id) {
        return res.status(403).json({ error: 'Você não tem permissão para renovar este serviço.' });
      }
      return res.status(409).json({ error: 'Somente serviços abertos podem ser renovados.' });
    }

    const userResult = await pool.query('SELECT name FROM users WHERE id = $1', [req.user.id]);
    return res.json({
      ...result.rows[0],
      client_name: userResult.rows[0]?.name ?? null,
      needs_open_confirmation: false,
    });
  } catch (err) {
    console.error('Erro ao renovar serviço:', err);
    return res.status(500).json({ error: 'Não foi possível manter o serviço aberto.' });
  }
}

async function createReview(req, res) {
  const { id: serviceId } = req.params;
  const { rating, comment } = req.body;

  const ratingNumber = Number(rating);
  if (!Number.isInteger(ratingNumber) || ratingNumber < 1 || ratingNumber > 5) {
    return res.status(400).json({ error: 'A nota deve ser um número inteiro entre 1 e 5.' });
  }

  try {
    const serviceResult = await pool.query(
      'SELECT client_id, status, accepted_professional_id FROM services WHERE id = $1',
      [serviceId]
    );
    const service = serviceResult.rows[0];

    if (!service) {
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    }
    if (service.client_id !== req.user.id) {
      return res.status(403).json({ error: 'Você não tem permissão para avaliar este serviço.' });
    }
    if (service.status !== 'concluido' || !service.accepted_professional_id) {
      return res.status(409).json({ error: 'Só é possível avaliar um serviço concluído.' });
    }

    const result = await pool.query(
      `INSERT INTO reviews (service_id, client_id, professional_id, rating, comment)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [serviceId, req.user.id, service.accepted_professional_id, ratingNumber, comment || null]
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      // unique_violation: já existe avaliação desse cliente para esse serviço
      return res.status(409).json({ error: 'Você já avaliou este serviço.' });
    }
    console.error('Erro ao criar avaliação:', err);
    return res.status(500).json({ error: 'Não foi possível registrar a avaliação.' });
  }
}

module.exports = {
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
};
