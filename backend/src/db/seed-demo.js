require('dotenv').config();

const bcrypt = require('bcryptjs');
const pool = require('../config/db');

const PASSWORD = 'demo123';

async function upsertUser(client, { name, email, role }) {
  const passwordHash = await bcrypt.hash(PASSWORD, 10);
  const result = await client.query(
    `INSERT INTO users (name, email, password_hash, role)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (email) DO UPDATE
     SET name = EXCLUDED.name, role = EXCLUDED.role, password_hash = EXCLUDED.password_hash
     RETURNING id`,
    [name, email, passwordHash, role]
  );
  return result.rows[0].id;
}

async function createService(client, clientId, professionalId, values) {
  const result = await client.query(
    `INSERT INTO services (
       client_id, title, description, category, budget, status,
       accepted_professional_id, scheduled_date, city, state,
       service_mode, address, latitude, longitude, open_confirmed_at, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'Joinville', 'SC',
                'presencial', 'Centro', -26.3045, -48.8487, now(), $9)
     RETURNING id`,
    [
      clientId,
      values.title,
      values.description,
      'Jardinagem',
      values.budget,
      values.status,
      values.status === 'aberto' ? null : professionalId,
      values.date,
      values.createdAt,
    ]
  );
  return result.rows[0].id;
}

async function run() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const clientId = await upsertUser(client, {
      name: 'Marina Contratante',
      email: 'cliente.demo@contrata.local',
      role: 'cliente',
    });
    const professionalId = await upsertUser(client, {
      name: 'João Profissional',
      email: 'profissional.demo@contrata.local',
      role: 'profissional',
    });
    const projectProfessionalId = await upsertUser(client, {
      name: 'Carlos Empreiteiro',
      email: 'empreitada.demo@contrata.local',
      role: 'profissional',
    });
    await upsertUser(client, {
      name: 'Ana Administradora',
      email: 'admin@contrata.local',
      role: 'administrador',
    });

    await client.query(
      `INSERT INTO companies (
         owner_user_id, legal_name, trade_name, document, email,
         phone, city, state, status
       ) VALUES (
         $1, 'Marina Serviços Residenciais LTDA', 'Casa em Ordem',
         '12345678000190', 'contato@casaemordem.demo',
         '(47) 3333-2026', 'Joinville', 'SC', 'ativa'
       )
       ON CONFLICT (document) DO UPDATE SET
         owner_user_id = EXCLUDED.owner_user_id,
         legal_name = EXCLUDED.legal_name,
         trade_name = EXCLUDED.trade_name,
         email = EXCLUDED.email,
         phone = EXCLUDED.phone,
         city = EXCLUDED.city,
         state = EXCLUDED.state,
         status = EXCLUDED.status,
         updated_at = now()`,
      [clientId]
    );

    await client.query(
      `INSERT INTO professional_profiles (
         user_id, bio, skills, hourly_rate, pricing_type, project_rate,
         experience, city, state, service_mode, availability
       ) VALUES (
         $1,
         'Profissional de jardinagem com experiência em manutenção residencial, poda segura e recuperação de áreas verdes.',
         ARRAY['Jardinagem', 'Limpeza'], 60, 'por_hora', NULL,
         'Oito anos atendendo residências e pequenos condomínios em Joinville.',
         'Joinville', 'SC', 'presencial', 'Disponível agora'
       )
       ON CONFLICT (user_id) DO UPDATE SET
         bio = EXCLUDED.bio, skills = EXCLUDED.skills,
         hourly_rate = EXCLUDED.hourly_rate, pricing_type = EXCLUDED.pricing_type,
         project_rate = EXCLUDED.project_rate, experience = EXCLUDED.experience,
         city = EXCLUDED.city, state = EXCLUDED.state,
         service_mode = EXCLUDED.service_mode, availability = EXCLUDED.availability`,
      [professionalId]
    );
    await client.query(
      `INSERT INTO professional_profiles (
         user_id, bio, skills, hourly_rate, pricing_type, project_rate,
         experience, city, state, service_mode, availability
       ) VALUES (
         $1,
         'Especialista em reformas rápidas, pintura e pequenos reparos com preço fechado e escopo combinado antes do início.',
         ARRAY['Pintura', 'Construção e reparos'], NULL, 'empreitada', 850,
         'Dez anos executando reformas residenciais com planejamento, prazo e registro fotográfico.',
         'Joinville', 'SC', 'presencial', 'Agenda nesta semana'
       )
       ON CONFLICT (user_id) DO UPDATE SET
         bio = EXCLUDED.bio, skills = EXCLUDED.skills,
         hourly_rate = EXCLUDED.hourly_rate, pricing_type = EXCLUDED.pricing_type,
         project_rate = EXCLUDED.project_rate, experience = EXCLUDED.experience,
         city = EXCLUDED.city, state = EXCLUDED.state,
         service_mode = EXCLUDED.service_mode, availability = EXCLUDED.availability`,
      [projectProfessionalId]
    );
    await client.query(
      `INSERT INTO client_preferences (user_id, require_work_confirmation)
       VALUES ($1, TRUE)
       ON CONFLICT (user_id) DO UPDATE SET require_work_confirmation = TRUE`,
      [clientId]
    );

    await client.query(`DELETE FROM services WHERE client_id = $1 AND title LIKE '[DEMO]%'`, [clientId]);

    const runningService = await createService(client, clientId, professionalId, {
      title: '[DEMO] Manutenção do jardim',
      description: 'Cortar a grama, aparar os arbustos e recolher os resíduos do quintal.',
      budget: 240,
      status: 'em_andamento',
      date: new Date(),
      createdAt: new Date(Date.now() - 4 * 60 * 60 * 1000),
    });
    await client.query(
      `INSERT INTO work_sessions (
         service_id, professional_id, client_id, started_at,
         hourly_rate_snapshot, fixed_amount_snapshot, amount_basis, status
       ) VALUES ($1, $2, $3, now() - interval '32 minutes', 60, 240, 'por_hora', 'em_andamento')`,
      [runningService, professionalId, clientId]
    );

    const pendingService = await createService(client, clientId, professionalId, {
      title: '[DEMO] Poda das árvores da entrada',
      description: 'Poda de acabamento em três árvores de pequeno porte na entrada da residência.',
      budget: 180,
      status: 'em_andamento',
      date: new Date(),
      createdAt: new Date(Date.now() - 24 * 60 * 60 * 1000),
    });
    const pendingSession = await client.query(
      `INSERT INTO work_sessions (
         service_id, professional_id, client_id, started_at, ended_at,
         duration_minutes, hourly_rate_snapshot, fixed_amount_snapshot,
         amount_basis, amount, provider_note, status, updated_at
       ) VALUES (
         $1, $2, $3, now() - interval '2 hours', now() - interval '25 minutes',
         95, 60, 180, 'por_hora', 95,
         'Poda concluída. Um galho seco já estava apoiado sobre o muro e foi removido com segurança.',
         'aguardando_confirmacao', now()
       ) RETURNING id`,
      [pendingService, professionalId, clientId]
    );
    await client.query(
      `INSERT INTO notifications (user_id, type, title, message, data)
       VALUES ($1, 'confirmacao_pendente', 'Confirmação de jornada pendente',
               'João finalizou a poda das árvores. Confira os dados e confirme.', $2::jsonb)`,
      [clientId, JSON.stringify({ service_id: pendingService, work_session_id: pendingSession.rows[0].id })]
    );

    for (const item of [
      { days: 2, title: '[DEMO] Limpeza do canteiro', minutes: 150, amount: 150 },
      { days: 6, title: '[DEMO] Plantio de mudas', minutes: 210, amount: 210 },
      { days: 11, title: '[DEMO] Preparação do solo', minutes: 120, amount: 120 },
    ]) {
      const serviceId = await createService(client, clientId, professionalId, {
        title: item.title,
        description: 'Serviço concluído usado para demonstrar o histórico e os indicadores do mês.',
        budget: item.amount,
        status: 'concluido',
        date: new Date(Date.now() - item.days * 24 * 60 * 60 * 1000),
        createdAt: new Date(Date.now() - (item.days + 1) * 24 * 60 * 60 * 1000),
      });
      await client.query(
        `INSERT INTO work_sessions (
           service_id, professional_id, client_id, started_at, ended_at,
           duration_minutes, hourly_rate_snapshot, fixed_amount_snapshot,
           amount_basis, amount, provider_note, status, confirmed_at, updated_at
         ) VALUES (
           $1, $2, $3,
           now() - ($4::int * interval '1 day') - ($5::int * interval '1 minute'),
           now() - ($4::int * interval '1 day'),
           $5, 60, $6, 'por_hora', $6, 'Serviço concluído sem ocorrências.',
           'confirmado', now() - ($4::int * interval '1 day'), now()
         )`,
        [serviceId, professionalId, clientId, item.days, item.minutes, item.amount]
      );
    }

    await createService(client, clientId, professionalId, {
      title: '[DEMO] Roçar terreno lateral',
      description: 'Roçar uma área de aproximadamente 300 m² e separar os resíduos em sacos.',
      budget: 280,
      status: 'aberto',
      date: new Date(),
      createdAt: new Date(Date.now() - 45 * 60 * 1000),
    });

    await client.query('COMMIT');
    console.log('Dados de demonstração preparados.');
    console.log('Contratante: cliente.demo@contrata.local / demo123');
    console.log('Profissional: profissional.demo@contrata.local / demo123');
    console.log('Empreitada: empreitada.demo@contrata.local / demo123');
    console.log('Administrador: admin@contrata.local / demo123');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

run()
  .catch((error) => {
    console.error('Falha ao preparar demonstração:', error.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
