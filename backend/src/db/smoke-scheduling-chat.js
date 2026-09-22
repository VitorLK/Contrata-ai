require('dotenv').config();

const crypto = require('crypto');
const pool = require('../config/db');

const baseUrl = `http://localhost:${process.env.PORT || 3000}`;
const cleanupIds = [];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function request(path, { method = 'GET', token, body, expectedStatus } = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await response.json().catch(() => null);
  if (expectedStatus !== undefined) {
    assert(
      response.status === expectedStatus,
      `${method} ${path}: esperado ${expectedStatus}, recebido ${response.status}`
    );
    return data;
  }
  if (!response.ok) {
    throw new Error(`${method} ${path}: ${response.status} ${data?.error || 'sem mensagem'}`);
  }
  return data;
}

async function register(role, suffix) {
  const data = await request('/auth/register', {
    method: 'POST',
    body: {
      name: role === 'cliente' ? 'Cliente Agenda Teste' : 'Profissional Agenda Teste',
      email: `agenda-${suffix}-${role}@example.test`,
      password: 'teste123',
      role,
    },
  });
  cleanupIds.push(data.user.id);
  return data;
}

async function run() {
  const suffix = `${Date.now()}-${crypto.randomUUID().slice(0, 6)}`;
  const client = await register('cliente', suffix);
  const professional = await register('profissional', suffix);

  await request('/professionals/me', {
    method: 'PUT',
    token: professional.token,
    body: {
      bio: 'Profissional temporário para validar agenda, chat e bloqueio de horários sobrepostos.',
      skills: ['Serviços gerais'],
      pricing_type: 'por_hora',
      hourly_rate: 75,
      city: 'Joinville',
      state: 'SC',
      service_mode: 'presencial',
      availability: 'Agenda nesta semana',
    },
  });

  const availability = await request('/professionals/me/availability', {
    method: 'PUT',
    token: professional.token,
    body: {
      buffer_minutes: 30,
      variable_hours: false,
      slots: [
        {
          weekday: 1,
          start_time: '08:00',
          end_time: '12:00',
          ends_next_day: false,
        },
        {
          weekday: 5,
          start_time: '18:00',
          end_time: '02:00',
          ends_next_day: true,
        },
      ],
    },
  });
  assert(availability.slots.length === 2, 'Disponibilidade semanal não foi salva.');
  assert(availability.buffer_minutes === 30, 'Intervalo entre trabalhos não foi salvo.');

  const conversation = await request('/chat/conversations', {
    method: 'POST',
    token: client.token,
    body: { professional_id: professional.user.id },
  });
  await request(`/chat/conversations/${conversation.id}/messages`, {
    method: 'POST',
    token: client.token,
    body: { body: 'Olá! Gostaria de combinar um trabalho para amanhã.' },
  });
  const unread = await request('/chat/unread-count', { token: professional.token });
  assert(unread.unread_count === 1, 'Mensagem nova não apareceu como não lida.');

  const start = new Date();
  start.setDate(start.getDate() + 1);
  start.setHours(10, 0, 0, 0);
  const end = new Date(start.getTime() + 2 * 60 * 60 * 1000);
  const dateText = start.toISOString().slice(0, 10);
  const proposalBody = {
    title: 'Limpeza agendada pelo chat',
    description: 'Limpeza completa de um imóvel com materiais disponíveis no local.',
    category: 'Serviços gerais',
    service_mode: 'remoto',
    pricing_type: 'por_hora',
    amount: 75,
    scheduled_date: dateText,
    scheduled_start: start.toISOString(),
    scheduled_end: end.toISOString(),
    is_all_day: false,
  };

  const firstProposal = await request(
    `/chat/conversations/${conversation.id}/proposals`,
    { method: 'POST', token: client.token, body: proposalBody }
  );
  const accepted = await request(`/chat/proposals/${firstProposal.id}/respond`, {
    method: 'POST',
    token: professional.token,
    body: { action: 'aceitar' },
  });
  assert(accepted.service.status === 'agendado', 'Proposta aceita não criou serviço agendado.');

  const overlappingProposal = await request(
    `/chat/conversations/${conversation.id}/proposals`,
    {
      method: 'POST',
      token: client.token,
      body: {
        ...proposalBody,
        title: 'Segundo trabalho no mesmo horário',
        scheduled_start: new Date(start.getTime() + 30 * 60 * 1000).toISOString(),
        scheduled_end: new Date(end.getTime() + 30 * 60 * 1000).toISOString(),
      },
    }
  );
  const conflict = await request(`/chat/proposals/${overlappingProposal.id}/respond`, {
    method: 'POST',
    token: professional.token,
    body: { action: 'aceitar' },
    expectedStatus: 409,
  });
  assert(
    String(conflict.error || '').includes('Conflito'),
    'Sobreposição não retornou uma explicação de conflito.'
  );

  console.log('Fluxo validado: disponibilidade -> chat -> proposta -> reserva -> bloqueio de conflito.');
}

run()
  .catch((error) => {
    console.error('Smoke test de agenda/chat falhou:', error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (cleanupIds.length > 0) {
      await pool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [cleanupIds]);
    }
    await pool.end();
  });
