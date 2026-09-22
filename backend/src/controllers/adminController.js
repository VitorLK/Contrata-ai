const pool = require('../config/db');

const EDITABLE_USER_ROLES = ['cliente', 'profissional'];
const COMPANY_STATUSES = ['ativa', 'suspensa'];
const SERVICE_STATUSES = ['aberto', 'agendado', 'em_andamento', 'concluido', 'cancelado'];

function cleanText(value) {
  return value == null ? null : String(value).trim();
}

function publicUser(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    role: row.role,
    phone: row.phone,
    is_active: row.is_active,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

async function writeAudit(client, adminId, {
  action,
  entityType,
  entityId,
  summary,
  beforeData,
  afterData,
}) {
  await client.query(
    `INSERT INTO admin_audit_logs (
       admin_id, action, entity_type, entity_id, summary, before_data, after_data
     ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb)`,
    [
      adminId,
      action,
      entityType,
      entityId,
      summary,
      beforeData == null ? null : JSON.stringify(beforeData),
      afterData == null ? null : JSON.stringify(afterData),
    ]
  );
}

async function getOverview(req, res) {
  try {
    const [
      usersResult,
      companiesResult,
      servicesResult,
      workResult,
      statusResult,
      monthlyResult,
      activityResult,
    ] = await Promise.all([
      pool.query(
        `SELECT
           COUNT(*) FILTER (WHERE role <> 'administrador')::int AS total_users,
           COUNT(*) FILTER (WHERE role = 'cliente')::int AS clients,
           COUNT(*) FILTER (WHERE role = 'profissional')::int AS professionals,
           COUNT(*) FILTER (WHERE role <> 'administrador' AND is_active)::int AS active_users,
           COUNT(*) FILTER (
             WHERE role <> 'administrador' AND created_at >= now() - interval '30 days'
           )::int AS new_users_30d
         FROM users`
      ),
      pool.query(
        `SELECT COUNT(*)::int AS total,
                COUNT(*) FILTER (WHERE status = 'ativa')::int AS active
         FROM companies`
      ),
      pool.query(
        `SELECT COUNT(*)::int AS total,
                COUNT(*) FILTER (WHERE status = 'aberto')::int AS open,
                COUNT(*) FILTER (WHERE status = 'em_andamento')::int AS in_progress,
                COUNT(*) FILTER (WHERE status = 'concluido')::int AS completed,
                COUNT(*) FILTER (WHERE status = 'cancelado')::int AS cancelled
         FROM services`
      ),
      pool.query(
        `SELECT COUNT(*) FILTER (WHERE status = 'confirmado')::int AS completed_sessions,
                COALESCE(SUM(amount) FILTER (WHERE status = 'confirmado'), 0)::numeric(12, 2)
                  AS transacted_amount,
                COALESCE(SUM(duration_minutes) FILTER (WHERE status = 'confirmado'), 0)::int
                  AS worked_minutes
         FROM work_sessions`
      ),
      pool.query(
        `SELECT status, COUNT(*)::int AS total
         FROM services GROUP BY status ORDER BY status`
      ),
      pool.query(
        `WITH months AS (
           SELECT generate_series(
             date_trunc('month', CURRENT_DATE) - interval '5 months',
             date_trunc('month', CURRENT_DATE),
             interval '1 month'
           ) AS month
         )
         SELECT to_char(month, 'YYYY-MM') AS month,
                (SELECT COUNT(*)::int FROM users u
                 WHERE u.role <> 'administrador'
                   AND u.created_at >= month AND u.created_at < month + interval '1 month') AS new_users,
                (SELECT COUNT(*)::int FROM work_sessions ws
                 WHERE ws.status = 'confirmado'
                   AND ws.confirmed_at >= month AND ws.confirmed_at < month + interval '1 month') AS completed_services
         FROM months ORDER BY month`
      ),
      pool.query(
        `SELECT * FROM (
           SELECT 'auditoria'::text AS kind, summary AS title,
                  entity_type AS detail, created_at
           FROM admin_audit_logs
           UNION ALL
           SELECT 'usuario'::text, 'Novo cadastro: ' || name,
                  CASE role WHEN 'cliente' THEN 'Contratante' ELSE 'Profissional' END,
                  created_at
           FROM users WHERE role <> 'administrador'
           UNION ALL
           SELECT 'servico'::text, 'Serviço publicado: ' || title,
                  status::text, created_at
           FROM services
           UNION ALL
           SELECT 'empresa'::text, 'Empresa cadastrada: ' || COALESCE(trade_name, legal_name),
                  status, created_at
           FROM companies
         ) activity
         ORDER BY created_at DESC LIMIT 12`
      ),
    ]);

    const services = servicesResult.rows[0];
    const completed = Number(services.completed || 0);
    const totalClosed = completed + Number(services.cancelled || 0);

    return res.json({
      users: usersResult.rows[0],
      companies: companiesResult.rows[0],
      services: {
        ...services,
        completion_rate: totalClosed === 0 ? 0 : Number(((completed / totalClosed) * 100).toFixed(1)),
      },
      operation: workResult.rows[0],
      service_statuses: statusResult.rows,
      monthly: monthlyResult.rows,
      recent_activity: activityResult.rows,
    });
  } catch (err) {
    console.error('Erro ao carregar painel administrativo:', err);
    return res.status(500).json({ error: 'Não foi possível carregar o painel administrativo.' });
  }
}

async function listUsers(req, res) {
  const search = cleanText(req.query.search);
  const role = cleanText(req.query.role);
  const status = cleanText(req.query.status);
  const conditions = [];
  const params = [];

  if (search) {
    params.push(`%${search}%`);
    conditions.push(`(u.name ILIKE $${params.length} OR u.email ILIKE $${params.length})`);
  }
  if (role && ['cliente', 'profissional', 'administrador'].includes(role)) {
    params.push(role);
    conditions.push(`u.role = $${params.length}::user_role`);
  } else {
    conditions.push(`u.role <> 'administrador'`);
  }
  if (status === 'ativos' || status === 'inativos') {
    params.push(status === 'ativos');
    conditions.push(`u.is_active = $${params.length}`);
  }

  try {
    const result = await pool.query(
      `SELECT u.id, u.name, u.email, u.role, u.phone, u.is_active,
              u.created_at, u.updated_at,
              pp.city, pp.state, pp.skills, pp.hourly_rate,
              c.id AS company_id, COALESCE(c.trade_name, c.legal_name) AS company_name,
              (SELECT COUNT(*)::int FROM services s
               WHERE s.client_id = u.id OR s.accepted_professional_id = u.id) AS service_count,
              (SELECT COUNT(*)::int FROM work_sessions ws
               WHERE ws.professional_id = u.id AND ws.status = 'confirmado') AS completed_count
       FROM users u
       LEFT JOIN professional_profiles pp ON pp.user_id = u.id
       LEFT JOIN companies c ON c.owner_user_id = u.id
       ${conditions.length ? `WHERE ${conditions.join(' AND ')}` : ''}
       ORDER BY u.is_active DESC, u.created_at DESC
       LIMIT 250`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar usuários no painel:', err);
    return res.status(500).json({ error: 'Não foi possível carregar os usuários.' });
  }
}

async function updateUser(req, res) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const currentResult = await client.query(
      `SELECT id, name, email, role, phone, is_active, created_at, updated_at
       FROM users WHERE id = $1 FOR UPDATE`,
      [req.params.id]
    );
    const current = currentResult.rows[0];
    if (!current) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    const nextName = req.body.name === undefined ? current.name : cleanText(req.body.name);
    const nextEmail = req.body.email === undefined
      ? current.email
      : cleanText(req.body.email)?.toLowerCase();
    const nextPhone = req.body.phone === undefined ? current.phone : cleanText(req.body.phone);
    let nextRole = req.body.role === undefined ? current.role : cleanText(req.body.role);
    let nextActive = req.body.is_active === undefined ? current.is_active : req.body.is_active;

    if (!nextName || nextName.length < 3 || nextName.length > 150) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Informe um nome entre 3 e 150 caracteres.' });
    }
    if (!nextEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(nextEmail)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Informe um e-mail válido.' });
    }
    if (current.role === 'administrador') {
      nextRole = current.role;
      nextActive = current.is_active;
    } else if (!EDITABLE_USER_ROLES.includes(nextRole)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'O perfil deve ser contratante ou profissional.' });
    }
    if (typeof nextActive !== 'boolean') {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'O estado da conta deve ser verdadeiro ou falso.' });
    }

    const updatedResult = await client.query(
      `UPDATE users
       SET name = $2, email = $3, phone = $4, role = $5::user_role,
           is_active = $6, updated_at = now()
       WHERE id = $1
       RETURNING id, name, email, role, phone, is_active, created_at, updated_at`,
      [current.id, nextName, nextEmail, nextPhone || null, nextRole, nextActive]
    );
    const updated = updatedResult.rows[0];

    if (nextRole === 'profissional') {
      await client.query(
        `INSERT INTO professional_profiles (user_id) VALUES ($1)
         ON CONFLICT (user_id) DO NOTHING`,
        [current.id]
      );
    }

    await writeAudit(client, req.user.id, {
      action: 'usuario_atualizado',
      entityType: 'usuario',
      entityId: current.id,
      summary: `Cadastro de ${updated.name} atualizado`,
      beforeData: publicUser(current),
      afterData: publicUser(updated),
    });
    await client.query('COMMIT');
    return res.json(updated);
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Já existe uma conta com este e-mail.' });
    }
    console.error('Erro ao atualizar usuário:', err);
    return res.status(500).json({ error: 'Não foi possível atualizar o usuário.' });
  } finally {
    client.release();
  }
}

async function deleteUser(req, res) {
  if (req.params.id === req.user.id) {
    return res.status(409).json({ error: 'Você não pode excluir a própria conta administrativa.' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const currentResult = await client.query(
      `SELECT id, name, email, role, phone, is_active, created_at, updated_at
       FROM users WHERE id = $1 FOR UPDATE`,
      [req.params.id]
    );
    const current = currentResult.rows[0];
    if (!current) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }
    if (current.role === 'administrador') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Contas administrativas não podem ser excluídas por este painel.' });
    }

    const historyResult = await client.query(
      `SELECT
         (SELECT COUNT(*) FROM services WHERE client_id = $1 OR accepted_professional_id = $1) +
         (SELECT COUNT(*) FROM work_sessions WHERE client_id = $1 OR professional_id = $1) +
         (SELECT COUNT(*) FROM service_applications WHERE professional_id = $1) +
         (SELECT COUNT(*) FROM reviews WHERE client_id = $1 OR professional_id = $1)
         AS total`,
      [current.id]
    );
    const hasHistory = Number(historyResult.rows[0].total) > 0;
    let mode;

    if (hasHistory) {
      await client.query(
        `UPDATE users SET is_active = FALSE, updated_at = now() WHERE id = $1`,
        [current.id]
      );
      mode = 'desativado';
    } else {
      await client.query('DELETE FROM users WHERE id = $1', [current.id]);
      mode = 'excluido';
    }

    await writeAudit(client, req.user.id, {
      action: hasHistory ? 'usuario_desativado' : 'usuario_excluido',
      entityType: 'usuario',
      entityId: current.id,
      summary: hasHistory
        ? `${current.name} foi desativado para preservar o histórico`
        : `${current.name} foi excluído da plataforma`,
      beforeData: publicUser(current),
      afterData: hasHistory ? { ...publicUser(current), is_active: false } : null,
    });
    await client.query('COMMIT');
    return res.json({ mode, preserved_history: hasHistory });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao excluir usuário:', err);
    return res.status(500).json({ error: 'Não foi possível excluir o usuário.' });
  } finally {
    client.release();
  }
}

async function listCompanies(req, res) {
  const search = cleanText(req.query.search);
  const status = cleanText(req.query.status);
  const conditions = [];
  const params = [];
  if (search) {
    params.push(`%${search}%`);
    conditions.push(
      `(c.legal_name ILIKE $${params.length} OR c.trade_name ILIKE $${params.length}
        OR c.document ILIKE $${params.length})`
    );
  }
  if (COMPANY_STATUSES.includes(status)) {
    params.push(status);
    conditions.push(`c.status = $${params.length}`);
  }

  try {
    const result = await pool.query(
      `SELECT c.*, u.name AS owner_name, u.email AS owner_email,
              (SELECT COUNT(*)::int FROM services s WHERE s.client_id = c.owner_user_id) AS service_count
       FROM companies c
       LEFT JOIN users u ON u.id = c.owner_user_id
       ${conditions.length ? `WHERE ${conditions.join(' AND ')}` : ''}
       ORDER BY c.status ASC, COALESCE(c.trade_name, c.legal_name) ASC
       LIMIT 250`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar empresas:', err);
    return res.status(500).json({ error: 'Não foi possível carregar as empresas.' });
  }
}

async function validateCompanyOwner(client, ownerUserId) {
  if (!ownerUserId) return null;
  const result = await client.query(
    `SELECT id FROM users WHERE id = $1 AND role = 'cliente' AND is_active = TRUE`,
    [ownerUserId]
  );
  return result.rows[0]?.id || null;
}

function normalizeCompanyPayload(body, current = {}) {
  return {
    legalName: body.legal_name === undefined ? current.legal_name : cleanText(body.legal_name),
    tradeName: body.trade_name === undefined ? current.trade_name : cleanText(body.trade_name),
    document: body.document === undefined
      ? current.document
      : String(body.document || '').replace(/\D/g, ''),
    email: body.email === undefined ? current.email : cleanText(body.email)?.toLowerCase(),
    phone: body.phone === undefined ? current.phone : cleanText(body.phone),
    city: body.city === undefined ? current.city : cleanText(body.city),
    state: body.state === undefined ? current.state : cleanText(body.state)?.toUpperCase(),
    status: body.status === undefined ? (current.status || 'ativa') : cleanText(body.status),
    ownerUserId: body.owner_user_id === undefined ? current.owner_user_id : cleanText(body.owner_user_id),
  };
}

function validateCompanyPayload(payload) {
  if (!payload.legalName || payload.legalName.length < 3 || payload.legalName.length > 180) {
    return 'Informe uma razão social entre 3 e 180 caracteres.';
  }
  if (!/^\d{14}$/.test(payload.document || '')) return 'Informe um CNPJ com 14 dígitos.';
  if (payload.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(payload.email)) {
    return 'Informe um e-mail válido para a empresa.';
  }
  if (payload.state && !/^[A-Z]{2}$/.test(payload.state)) return 'Informe uma UF válida.';
  if (!COMPANY_STATUSES.includes(payload.status)) return 'Informe um status de empresa válido.';
  return null;
}

async function createCompany(req, res) {
  const payload = normalizeCompanyPayload(req.body);
  const validationError = validateCompanyPayload(payload);
  if (validationError) return res.status(400).json({ error: validationError });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const ownerId = await validateCompanyOwner(client, payload.ownerUserId);
    if (payload.ownerUserId && !ownerId) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'O responsável deve ser um contratante ativo.' });
    }
    const result = await client.query(
      `INSERT INTO companies (
         owner_user_id, legal_name, trade_name, document, email, phone, city, state, status
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        ownerId,
        payload.legalName,
        payload.tradeName || null,
        payload.document,
        payload.email || null,
        payload.phone || null,
        payload.city || null,
        payload.state || null,
        payload.status,
      ]
    );
    const company = result.rows[0];
    await writeAudit(client, req.user.id, {
      action: 'empresa_criada',
      entityType: 'empresa',
      entityId: company.id,
      summary: `Empresa ${company.trade_name || company.legal_name} cadastrada`,
      afterData: company,
    });
    await client.query('COMMIT');
    return res.status(201).json(company);
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Este CNPJ ou responsável já está vinculado a outra empresa.' });
    }
    console.error('Erro ao criar empresa:', err);
    return res.status(500).json({ error: 'Não foi possível cadastrar a empresa.' });
  } finally {
    client.release();
  }
}

async function updateCompany(req, res) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const currentResult = await client.query(
      'SELECT * FROM companies WHERE id = $1 FOR UPDATE',
      [req.params.id]
    );
    const current = currentResult.rows[0];
    if (!current) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Empresa não encontrada.' });
    }
    const payload = normalizeCompanyPayload(req.body, current);
    const validationError = validateCompanyPayload(payload);
    if (validationError) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: validationError });
    }
    const ownerId = await validateCompanyOwner(client, payload.ownerUserId);
    if (payload.ownerUserId && !ownerId) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'O responsável deve ser um contratante ativo.' });
    }
    const result = await client.query(
      `UPDATE companies SET
         owner_user_id = $2, legal_name = $3, trade_name = $4,
         document = $5, email = $6, phone = $7, city = $8,
         state = $9, status = $10, updated_at = now()
       WHERE id = $1 RETURNING *`,
      [
        current.id,
        ownerId,
        payload.legalName,
        payload.tradeName || null,
        payload.document,
        payload.email || null,
        payload.phone || null,
        payload.city || null,
        payload.state || null,
        payload.status,
      ]
    );
    const updated = result.rows[0];
    await writeAudit(client, req.user.id, {
      action: 'empresa_atualizada',
      entityType: 'empresa',
      entityId: current.id,
      summary: `Empresa ${updated.trade_name || updated.legal_name} atualizada`,
      beforeData: current,
      afterData: updated,
    });
    await client.query('COMMIT');
    return res.json(updated);
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Este CNPJ ou responsável já está vinculado a outra empresa.' });
    }
    console.error('Erro ao atualizar empresa:', err);
    return res.status(500).json({ error: 'Não foi possível atualizar a empresa.' });
  } finally {
    client.release();
  }
}

async function deleteCompany(req, res) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query('SELECT * FROM companies WHERE id = $1 FOR UPDATE', [req.params.id]);
    const company = result.rows[0];
    if (!company) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Empresa não encontrada.' });
    }
    await writeAudit(client, req.user.id, {
      action: 'empresa_excluida',
      entityType: 'empresa',
      entityId: company.id,
      summary: `Empresa ${company.trade_name || company.legal_name} excluída`,
      beforeData: company,
    });
    await client.query('DELETE FROM companies WHERE id = $1', [company.id]);
    await client.query('COMMIT');
    return res.status(204).send();
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao excluir empresa:', err);
    return res.status(500).json({ error: 'Não foi possível excluir a empresa.' });
  } finally {
    client.release();
  }
}

async function listServices(req, res) {
  const search = cleanText(req.query.search);
  const status = cleanText(req.query.status);
  const conditions = [];
  const params = [];
  if (search) {
    params.push(`%${search}%`);
    conditions.push(`(s.title ILIKE $${params.length} OR c.name ILIKE $${params.length})`);
  }
  if (SERVICE_STATUSES.includes(status)) {
    params.push(status);
    conditions.push(`s.status = $${params.length}::service_status`);
  }

  try {
    const result = await pool.query(
      `SELECT s.id, s.title, s.category, s.budget, s.status, s.scheduled_date,
              s.city, s.state, s.service_mode, s.created_at,
              c.name AS client_name, p.name AS professional_name,
              ws.status AS work_status
       FROM services s
       JOIN users c ON c.id = s.client_id
       LEFT JOIN users p ON p.id = s.accepted_professional_id
       LEFT JOIN work_sessions ws ON ws.service_id = s.id
       ${conditions.length ? `WHERE ${conditions.join(' AND ')}` : ''}
       ORDER BY s.created_at DESC LIMIT 250`,
      params
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar serviços para administração:', err);
    return res.status(500).json({ error: 'Não foi possível carregar os registros de serviço.' });
  }
}

async function updateService(req, res) {
  const reason = cleanText(req.body.reason);
  if (!reason || reason.length < 8) {
    return res.status(400).json({ error: 'Explique o motivo da alteração em pelo menos 8 caracteres.' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const currentResult = await client.query('SELECT * FROM services WHERE id = $1 FOR UPDATE', [req.params.id]);
    const current = currentResult.rows[0];
    if (!current) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Serviço não encontrado.' });
    }

    const nextStatus = req.body.status === undefined ? current.status : cleanText(req.body.status);
    const nextDate = req.body.scheduled_date === undefined
      ? current.scheduled_date
      : cleanText(req.body.scheduled_date);
    const nextBudget = req.body.budget === undefined
      ? current.budget
      : (req.body.budget === null || req.body.budget === '' ? null : Number(req.body.budget));

    if (!SERVICE_STATUSES.includes(nextStatus)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Informe um status de serviço válido.' });
    }
    const dateText = nextDate instanceof Date ? nextDate.toISOString().slice(0, 10) : String(nextDate).slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateText)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Informe a data no formato AAAA-MM-DD.' });
    }
    if (nextBudget !== null && (!Number.isFinite(nextBudget) || nextBudget <= 0)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'O orçamento deve ser maior que zero.' });
    }

    const sessionResult = await client.query(
      `SELECT status FROM work_sessions WHERE service_id = $1`,
      [current.id]
    );
    const workStatus = sessionResult.rows[0]?.status;
    if (nextStatus === 'concluido' && workStatus !== 'confirmado') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Só é possível concluir um serviço com jornada confirmada.' });
    }
    if (['agendado', 'em_andamento'].includes(nextStatus) && !current.accepted_professional_id) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'O serviço precisa ter um profissional aceito para entrar em andamento.' });
    }
    if (nextStatus === 'aberto' && (current.accepted_professional_id || workStatus)) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Um serviço com profissional ou jornada vinculada não pode ser reaberto.' });
    }
    if (nextStatus === 'cancelado' && workStatus === 'confirmado') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Uma jornada confirmada não pode ser cancelada.' });
    }

    const updatedResult = await client.query(
      `UPDATE services
       SET status = $2::service_status, budget = $3, scheduled_date = $4::date,
           scheduled_end = (
             (($4::date + (scheduled_start AT TIME ZONE 'America/Sao_Paulo')::time)
               AT TIME ZONE 'America/Sao_Paulo')
             + (scheduled_end - scheduled_start)
           ),
           scheduled_start = (
             ($4::date + (scheduled_start AT TIME ZONE 'America/Sao_Paulo')::time)
               AT TIME ZONE 'America/Sao_Paulo'
           )
       WHERE id = $1 RETURNING *`,
      [current.id, nextStatus, nextBudget, dateText]
    );
    const updated = updatedResult.rows[0];
    await writeAudit(client, req.user.id, {
      action: 'servico_ajustado',
      entityType: 'servico',
      entityId: current.id,
      summary: `Serviço “${current.title}” ajustado: ${reason}`,
      beforeData: current,
      afterData: updated,
    });
    await client.query('COMMIT');
    return res.json(updated);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao ajustar serviço:', err);
    return res.status(500).json({ error: 'Não foi possível atualizar o registro de serviço.' });
  } finally {
    client.release();
  }
}

async function listAudit(req, res) {
  try {
    const result = await pool.query(
      `SELECT l.*, u.name AS admin_name
       FROM admin_audit_logs l
       LEFT JOIN users u ON u.id = l.admin_id
       ORDER BY l.created_at DESC LIMIT 100`
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar auditoria:', err);
    return res.status(500).json({ error: 'Não foi possível carregar a auditoria.' });
  }
}

module.exports = {
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
};
