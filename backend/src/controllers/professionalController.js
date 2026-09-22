const fs = require('fs');
const path = require('path');
const pool = require('../config/db');
const { UPLOAD_DIR } = require('../middlewares/upload');

const VALID_SERVICE_MODES = ['presencial', 'remoto', 'hibrido'];
const VALID_PRICING_TYPES = ['por_hora', 'empreitada'];
const VALID_AVAILABILITY = [
  'Disponível agora',
  'Agenda nesta semana',
  'Agenda nas próximas semanas',
  'Somente com agendamento',
];

// Os mesmos 10 campos usados na indicação de "Perfil completo: XX%" (ver
// Etapa 16 do plano, na tela "Meu Perfil"). photo_url e portfólio não
// entram aqui como obrigatórios — o profissional pode ter um perfil
// funcional só de texto; a foto/portfólio ficam como incentivo à parte.
function calculateCompletion(row) {
  const fields = [
    row.bio,
    Array.isArray(row.skills) && row.skills.length > 0 ? 'ok' : null,
    row.pricing_type === 'empreitada' ? row.project_rate : row.hourly_rate,
    row.photo_url,
    row.experience,
    row.city,
    row.state,
    row.service_mode,
    row.availability,
    row.phone,
  ];
  const filled = fields.filter((value) => value !== null && value !== undefined && value !== '').length;
  return Math.round((filled / fields.length) * 100);
}

function normalizeTime(value) {
  const match = /^(\d{2}):(\d{2})(?::\d{2})?$/.exec(String(value || ''));
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return null;
  return {
    text: `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`,
    minutes: hour * 60 + minute,
  };
}

function validateAvailabilityPayload(body) {
  const bufferMinutes = Number(body.buffer_minutes ?? 0);
  const variableHours = body.variable_hours === true || String(body.variable_hours) === 'true';
  const rawSlots = body.slots ?? [];

  if (!Number.isInteger(bufferMinutes) || bufferMinutes < 0 || bufferMinutes > 240) {
    return { error: 'O intervalo entre trabalhos deve ficar entre 0 e 240 minutos.' };
  }
  if (!Array.isArray(rawSlots) || rawSlots.length > 35) {
    return { error: 'Informe uma lista válida com até 35 períodos semanais.' };
  }

  const slots = [];
  for (const raw of rawSlots) {
    const weekday = Number(raw.weekday);
    const start = normalizeTime(raw.start_time);
    const end = normalizeTime(raw.end_time);
    const endsNextDay = raw.ends_next_day === true || String(raw.ends_next_day) === 'true';
    if (!Number.isInteger(weekday) || weekday < 1 || weekday > 7 || !start || !end) {
      return { error: 'Existe um período com dia ou horário inválido.' };
    }
    let duration = end.minutes - start.minutes;
    if (endsNextDay) duration += 24 * 60;
    if (duration <= 0 || duration > 24 * 60) {
      return { error: 'Cada período deve terminar depois do início e durar no máximo 24 horas.' };
    }
    slots.push({
      weekday,
      start_time: start.text,
      end_time: end.text,
      ends_next_day: endsNextDay,
      absoluteStart: (weekday - 1) * 1440 + start.minutes,
      absoluteEnd: (weekday - 1) * 1440 + start.minutes + duration,
    });
  }

  const weekMinutes = 7 * 1440;
  for (let index = 0; index < slots.length; index += 1) {
    for (let otherIndex = index + 1; otherIndex < slots.length; otherIndex += 1) {
      const first = slots[index];
      const second = slots[otherIndex];
      for (const shift of [-weekMinutes, 0, weekMinutes]) {
        const shiftedStart = second.absoluteStart + shift;
        const shiftedEnd = second.absoluteEnd + shift;
        if (first.absoluteStart < shiftedEnd && first.absoluteEnd > shiftedStart) {
          return { error: 'Há períodos de disponibilidade que se sobrepõem.' };
        }
      }
    }
  }

  return {
    bufferMinutes,
    variableHours,
    slots: slots.map(({ absoluteStart, absoluteEnd, ...slot }) => slot),
  };
}

async function loadAvailabilitySchedule(professionalId, database = pool) {
  const [preferenceResult, slotResult] = await Promise.all([
    database.query(
      `SELECT COALESCE(buffer_minutes, 0)::int AS buffer_minutes,
              COALESCE(variable_hours, FALSE) AS variable_hours
       FROM professional_profiles WHERE user_id = $1`,
      [professionalId]
    ),
    database.query(
      `SELECT id, weekday, to_char(start_time, 'HH24:MI') AS start_time,
              to_char(end_time, 'HH24:MI') AS end_time, ends_next_day
       FROM professional_availability_slots
       WHERE professional_id = $1
       ORDER BY weekday, start_time`,
      [professionalId]
    ),
  ]);

  return {
    buffer_minutes: preferenceResult.rows[0]?.buffer_minutes ?? 0,
    variable_hours: preferenceResult.rows[0]?.variable_hours ?? false,
    slots: slotResult.rows,
  };
}

async function getMyProfile(req, res) {
  try {
    const result = await pool.query(
      `SELECT u.id AS user_id, u.name, u.email, u.phone,
              p.bio, p.skills, p.hourly_rate, p.pricing_type, p.project_rate,
              p.photo_url, p.experience,
              p.city, p.state, p.service_mode, p.availability
       FROM users u
       JOIN professional_profiles p ON p.user_id = u.id
       WHERE u.id = $1`,
      [req.user.id]
    );
    const profile = result.rows[0];

    if (!profile) {
      return res.status(404).json({ error: 'Perfil profissional não encontrado.' });
    }

    // Sem essa lista, a tela "Meu Perfil" não teria como saber o que já
    // foi enviado ao carregar (o único jeito de "ler" o portfólio hoje).
    const [portfolioResult, availabilitySchedule] = await Promise.all([
      pool.query(
        'SELECT * FROM portfolio_items WHERE professional_id = $1 ORDER BY created_at ASC',
        [req.user.id]
      ),
      loadAvailabilitySchedule(req.user.id),
    ]);

    return res.json({
      ...profile,
      profile_completion: calculateCompletion(profile),
      portfolio: portfolioResult.rows,
      availability_schedule: availabilitySchedule,
    });
  } catch (err) {
    console.error('Erro ao buscar perfil profissional:', err);
    return res.status(500).json({ error: 'Não foi possível carregar o perfil.' });
  }
}

async function updateMyProfile(req, res) {
  const {
    bio, skills, hourly_rate, pricing_type, project_rate, experience,
    city, state, service_mode, availability, phone,
  } = req.body;

  if (service_mode !== undefined && service_mode !== null && !VALID_SERVICE_MODES.includes(service_mode)) {
    return res.status(400).json({ error: `service_mode deve ser um dos valores: ${VALID_SERVICE_MODES.join(', ')}.` });
  }
  if (skills !== undefined && skills !== null && !Array.isArray(skills)) {
    return res.status(400).json({ error: 'skills deve ser uma lista de textos.' });
  }
  if (Array.isArray(skills) && (skills.length === 0 || skills.length > 6)) {
    return res.status(400).json({ error: 'Escolha entre 1 e 6 áreas de atuação.' });
  }
  if (state !== undefined && state !== null && !/^[A-Z]{2}$/.test(String(state).toUpperCase())) {
    return res.status(400).json({ error: 'Informe uma UF válida com duas letras.' });
  }
  if (availability !== undefined && availability !== null && !VALID_AVAILABILITY.includes(availability)) {
    return res.status(400).json({ error: 'Informe uma opção válida de disponibilidade.' });
  }
  if (bio !== undefined && bio !== null && String(bio).trim().length < 60) {
    return res.status(400).json({ error: 'A apresentação profissional deve ter pelo menos 60 caracteres.' });
  }

  if (pricing_type !== undefined && !VALID_PRICING_TYPES.includes(pricing_type)) {
    return res.status(400).json({ error: 'Escolha uma forma de cobrança válida.' });
  }

  const hourlyRateValue = hourly_rate === '' || hourly_rate == null ? null : Number(hourly_rate);
  const projectRateValue = project_rate === '' || project_rate == null ? null : Number(project_rate);
  if (pricing_type === 'por_hora' && (!Number.isFinite(hourlyRateValue) || hourlyRateValue <= 0)) {
    return res.status(400).json({ error: 'Informe um valor por hora maior que zero.' });
  }
  if (pricing_type === 'empreitada' && (!Number.isFinite(projectRateValue) || projectRateValue <= 0)) {
    return res.status(400).json({ error: 'Informe um valor de empreitada maior que zero.' });
  }

  // Evita erro de cast no Postgres se o campo numérico chegar como string
  // vazia (formulário limpo no front). COALESCE abaixo trata `null`/campo
  // ausente como "não alterar" — para limpar um campo de texto, o front
  // envia string vazia; hourly_rate não tem um caminho de "limpar" ainda.
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(
      `UPDATE professional_profiles
       SET bio = COALESCE($2, bio),
           skills = COALESCE($3, skills),
           experience = COALESCE($5, experience),
           city = COALESCE($6, city),
           state = COALESCE($7, state),
           service_mode = COALESCE($8, service_mode),
           availability = COALESCE($9, availability),
           pricing_type = COALESCE($10, pricing_type),
           hourly_rate = CASE
             WHEN $10 = 'empreitada' THEN NULL
             WHEN $10 = 'por_hora' THEN $4
             ELSE COALESCE($4, hourly_rate)
           END,
           project_rate = CASE
             WHEN $10 = 'por_hora' THEN NULL
             WHEN $10 = 'empreitada' THEN $11
             ELSE COALESCE($11, project_rate)
           END
       WHERE user_id = $1`,
      [
        req.user.id,
        bio?.trim(),
        skills?.map((skill) => String(skill).trim()).filter(Boolean),
        hourlyRateValue,
        experience?.trim(),
        city?.trim(),
        state?.toUpperCase(),
        service_mode,
        availability,
        pricing_type,
        projectRateValue,
      ]
    );

    if (phone !== undefined) {
      await client.query('UPDATE users SET phone = COALESCE($2, phone) WHERE id = $1', [req.user.id, phone]);
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao atualizar perfil profissional:', err);
    return res.status(500).json({ error: 'Não foi possível atualizar o perfil.' });
  } finally {
    client.release();
  }

  return getMyProfile(req, res);
}

async function uploadPhoto(req, res) {
  if (!req.file) {
    return res.status(400).json({ error: 'Nenhum arquivo enviado.' });
  }

  const photoUrl = `/uploads/${req.file.filename}`;

  try {
    const previous = await pool.query('SELECT photo_url FROM professional_profiles WHERE user_id = $1', [
      req.user.id,
    ]);
    const previousPhotoUrl = previous.rows[0]?.photo_url;

    await pool.query('UPDATE professional_profiles SET photo_url = $2 WHERE user_id = $1', [
      req.user.id,
      photoUrl,
    ]);

    // Best-effort: se der errado, sobra um arquivo órfão em uploads/, mas
    // isso não deve impedir a resposta de sucesso ao usuário.
    if (previousPhotoUrl) {
      fs.unlink(path.join(UPLOAD_DIR, path.basename(previousPhotoUrl)), () => {});
    }

    return res.json({ photo_url: photoUrl });
  } catch (err) {
    console.error('Erro ao salvar foto de perfil:', err);
    return res.status(500).json({ error: 'Não foi possível salvar a foto.' });
  }
}

async function addPortfolioItem(req, res) {
  if (!req.file) {
    return res.status(400).json({ error: 'Nenhum arquivo enviado.' });
  }

  const imageUrl = `/uploads/${req.file.filename}`;

  try {
    const result = await pool.query(
      `INSERT INTO portfolio_items (professional_id, image_url) VALUES ($1, $2) RETURNING *`,
      [req.user.id, imageUrl]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Erro ao adicionar item de portfólio:', err);
    return res.status(500).json({ error: 'Não foi possível salvar a imagem no portfólio.' });
  }
}

async function deletePortfolioItem(req, res) {
  const { itemId } = req.params;

  try {
    const result = await pool.query(
      `DELETE FROM portfolio_items WHERE id = $1 AND professional_id = $2 RETURNING image_url`,
      [itemId, req.user.id]
    );
    const deleted = result.rows[0];

    if (!deleted) {
      return res.status(404).json({ error: 'Item de portfólio não encontrado.' });
    }

    fs.unlink(path.join(UPLOAD_DIR, path.basename(deleted.image_url)), () => {});

    return res.status(204).send();
  } catch (err) {
    console.error('Erro ao remover item de portfólio:', err);
    return res.status(500).json({ error: 'Não foi possível remover o item.' });
  }
}

async function getMyAvailability(req, res) {
  try {
    return res.json(await loadAvailabilitySchedule(req.user.id));
  } catch (err) {
    console.error('Erro ao carregar agenda semanal:', err);
    return res.status(500).json({ error: 'Não foi possível carregar sua disponibilidade.' });
  }
}

async function updateMyAvailability(req, res) {
  const payload = validateAvailabilityPayload(req.body || {});
  if (payload.error) return res.status(400).json({ error: payload.error });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE professional_profiles
       SET buffer_minutes = $2, variable_hours = $3,
           availability = $4
       WHERE user_id = $1`,
      [
        req.user.id,
        payload.bufferMinutes,
        payload.variableHours,
        payload.variableHours || payload.slots.length === 0
          ? 'Somente com agendamento'
          : 'Agenda nesta semana',
      ]
    );
    await client.query(
      'DELETE FROM professional_availability_slots WHERE professional_id = $1',
      [req.user.id]
    );
    for (const slot of payload.slots) {
      await client.query(
        `INSERT INTO professional_availability_slots
           (professional_id, weekday, start_time, end_time, ends_next_day)
         VALUES ($1, $2, $3::time, $4::time, $5)`,
        [
          req.user.id,
          slot.weekday,
          slot.start_time,
          slot.end_time,
          slot.ends_next_day,
        ]
      );
    }
    await client.query('COMMIT');
    return res.json(await loadAvailabilitySchedule(req.user.id));
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao salvar agenda semanal:', err);
    return res.status(500).json({ error: 'Não foi possível salvar sua disponibilidade.' });
  } finally {
    client.release();
  }
}

async function getPublicAvailability(req, res) {
  try {
    const exists = await pool.query(
      `SELECT 1 FROM users u
       JOIN professional_profiles p ON p.user_id = u.id
       WHERE u.id = $1 AND u.is_active = TRUE`,
      [req.params.id]
    );
    if (exists.rowCount === 0) {
      return res.status(404).json({ error: 'Profissional não encontrado.' });
    }
    return res.json(await loadAvailabilitySchedule(req.params.id));
  } catch (err) {
    console.error('Erro ao carregar disponibilidade pública:', err);
    return res.status(500).json({ error: 'Não foi possível carregar a disponibilidade.' });
  }
}

async function listProfessionals(req, res) {
  const {
    q, category, city, state, service_mode, pricing_type,
    max_rate, max_price, availability, sort,
  } = req.query;

  const conditions = [];
  const params = [];

  if (q) {
    params.push(`%${String(q).trim()}%`);
    conditions.push(`(
      u.name ILIKE $${params.length}
      OR p.bio ILIKE $${params.length}
      OR EXISTS (
        SELECT 1 FROM unnest(p.skills) AS skill
        WHERE skill ILIKE $${params.length}
      )
    )`);
  }
  if (category) {
    params.push(String(category).trim());
    conditions.push(`EXISTS (
      SELECT 1 FROM unnest(p.skills) AS skill
      WHERE LOWER(skill) = LOWER($${params.length})
    )`);
  }
  if (city) {
    params.push(String(city).trim());
    conditions.push(`LOWER(p.city) = LOWER($${params.length})`);
  }
  if (state) {
    const normalizedState = String(state).trim().toUpperCase();
    if (!/^[A-Z]{2}$/.test(normalizedState)) {
      return res.status(400).json({ error: 'O filtro de estado deve ser uma UF válida.' });
    }
    params.push(normalizedState);
    conditions.push(`p.state = $${params.length}`);
  }
  if (service_mode) {
    const modes = String(service_mode).split(',').filter((mode) => VALID_SERVICE_MODES.includes(mode));
    if (modes.length === 0) {
      return res.status(400).json({ error: 'Informe uma forma de atendimento válida.' });
    }
    params.push(modes);
    conditions.push(`p.service_mode = ANY($${params.length}::text[])`);
  }
  if (pricing_type) {
    if (!VALID_PRICING_TYPES.includes(pricing_type)) {
      return res.status(400).json({ error: 'Informe uma forma de cobrança válida.' });
    }
    params.push(pricing_type);
    conditions.push(`p.pricing_type = $${params.length}`);
  }
  const priceLimit = max_price ?? max_rate;
  if (priceLimit !== undefined) {
    const maxRate = Number(priceLimit);
    if (!Number.isFinite(maxRate) || maxRate <= 0) {
      return res.status(400).json({ error: 'O valor máximo deve ser maior que zero.' });
    }
    params.push(maxRate);
    conditions.push(`CASE
      WHEN p.pricing_type = 'empreitada' THEN p.project_rate
      ELSE p.hourly_rate
    END <= $${params.length}`);
  }
  if (availability) {
    if (!VALID_AVAILABILITY.includes(availability)) {
      return res.status(400).json({ error: 'Informe uma disponibilidade válida.' });
    }
    params.push(availability);
    conditions.push(`p.availability = $${params.length}`);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const orderBy = {
    rating: 'rating_average DESC NULLS LAST, rating_count DESC, u.name ASC',
    price_asc: `CASE WHEN p.pricing_type = 'empreitada' THEN p.project_rate
      ELSE p.hourly_rate END ASC NULLS LAST, u.name ASC`,
    price_desc: `CASE WHEN p.pricing_type = 'empreitada' THEN p.project_rate
      ELSE p.hourly_rate END DESC NULLS LAST, u.name ASC`,
    name: 'u.name ASC',
    recommended: `(p.availability = 'Disponível agora') DESC,
      rating_average DESC NULLS LAST,
      CARDINALITY(p.skills) DESC,
      u.name ASC`,
  }[sort] || `(p.availability = 'Disponível agora') DESC,
    rating_average DESC NULLS LAST,
    CARDINALITY(p.skills) DESC,
    u.name ASC`;

  try {
    const result = await pool.query(
      `SELECT u.id AS user_id, u.name, p.bio, p.skills, p.hourly_rate,
              p.pricing_type, p.project_rate, p.photo_url,
              p.city, p.state, p.service_mode, p.availability,
              ROUND(AVG(r.rating), 2) AS rating_average,
              COUNT(r.id)::int AS rating_count
       FROM users u
       JOIN professional_profiles p ON p.user_id = u.id
       LEFT JOIN reviews r ON r.professional_id = u.id
       ${whereClause}
       GROUP BY u.id, p.user_id
       ORDER BY ${orderBy}`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar profissionais:', err);
    return res.status(500).json({ error: 'Não foi possível carregar os profissionais.' });
  }
}

// Agrega as notas em média/total/distribuição por estrela (1-5), para o
// perfil público mostrar um resumo sem o front precisar recalcular a
// partir da lista bruta de avaliações.
function summarizeRatings(reviews) {
  const distribution = { '1': 0, '2': 0, '3': 0, '4': 0, '5': 0 };
  let sum = 0;

  for (const review of reviews) {
    const key = String(review.rating);
    distribution[key] = (distribution[key] ?? 0) + 1;
    sum += review.rating;
  }

  const total = reviews.length;
  const average = total > 0 ? Number((sum / total).toFixed(2)) : null;
  return { average, total, distribution };
}

async function getPublicProfile(req, res) {
  const { id } = req.params;

  try {
    // O join com professional_profiles já garante 404 se o id não for de
    // um profissional (ex.: id de um cliente) — não precisa de checagem
    // de role separada.
    const profileResult = await pool.query(
      `SELECT u.id AS user_id, u.name, p.bio, p.skills, p.hourly_rate,
              p.pricing_type, p.project_rate,
              p.photo_url, p.experience, p.city, p.state, p.service_mode, p.availability
       FROM users u
       JOIN professional_profiles p ON p.user_id = u.id
       WHERE u.id = $1`,
      [id]
    );
    const profile = profileResult.rows[0];

    if (!profile) {
      return res.status(404).json({ error: 'Profissional não encontrado.' });
    }

    const [portfolioResult, availabilitySchedule] = await Promise.all([
      pool.query(
        'SELECT * FROM portfolio_items WHERE professional_id = $1 ORDER BY created_at ASC',
        [id]
      ),
      loadAvailabilitySchedule(id),
    ]);

    const reviewsResult = await pool.query(
      `SELECT r.id, r.rating, r.comment, r.created_at, u.name AS client_name
       FROM reviews r
       JOIN users u ON u.id = r.client_id
       WHERE r.professional_id = $1
       ORDER BY r.created_at DESC`,
      [id]
    );

    return res.json({
      ...profile,
      portfolio: portfolioResult.rows,
      availability_schedule: availabilitySchedule,
      rating: summarizeRatings(reviewsResult.rows),
      reviews: reviewsResult.rows,
    });
  } catch (err) {
    console.error('Erro ao buscar perfil público do profissional:', err);
    return res.status(500).json({ error: 'Não foi possível carregar o perfil.' });
  }
}

module.exports = {
  getMyProfile,
  updateMyProfile,
  uploadPhoto,
  addPortfolioItem,
  deletePortfolioItem,
  getMyAvailability,
  updateMyAvailability,
  getPublicAvailability,
  listProfessionals,
  getPublicProfile,
};
