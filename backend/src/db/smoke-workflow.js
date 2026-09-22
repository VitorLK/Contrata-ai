require('dotenv').config();

const crypto = require('crypto');
const pool = require('../config/db');

const baseUrl = `http://localhost:${process.env.PORT || 3000}`;
const cleanupIds = [];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function request(path, { method = 'GET', token, body } = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await response.json().catch(() => null);
  if (!response.ok) {
    throw new Error(`${method} ${path}: ${response.status} ${data?.error || 'sem mensagem'}`);
  }
  return data;
}

async function register(role, suffix) {
  const data = await request('/auth/register', {
    method: 'POST',
    body: {
      name: role === 'cliente' ? 'Cliente Teste Jornada' : 'Profissional Teste Jornada',
      email: `smoke-${suffix}-${role}@example.test`,
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
      bio: 'Profissional temporário criado para validar o fluxo completo de jornada do aplicativo.',
      skills: ['Jardinagem'],
      hourly_rate: 60,
      city: 'Joinville',
      state: 'SC',
      service_mode: 'presencial',
      availability: 'Disponível agora',
    },
  });

  const today = new Date().toISOString().slice(0, 10);
  const service = await request('/services', {
    method: 'POST',
    token: client.token,
    body: {
      title: 'Roçar gramado do teste',
      description: 'Serviço temporário para validar candidatura, jornada, confirmação e desempenho.',
      category: 'Jardinagem',
      budget: 250,
      scheduled_date: today,
      city: 'Joinville',
      state: 'SC',
      service_mode: 'presencial',
      address: 'Centro',
      latitude: -26.3045,
      longitude: -48.8487,
    },
  });

  const discovered = await request('/services?status=aberto&date_scope=hoje&category=Jardinagem&state=SC');
  assert(discovered.some((item) => item.id === service.id), 'Serviço não apareceu na descoberta filtrada.');

  await request(`/services/${service.id}/apply`, {
    method: 'POST',
    token: professional.token,
    body: { message: 'Tenho disponibilidade para executar hoje.' },
  });
  const applications = await request(`/services/${service.id}/applications`, { token: client.token });
  assert(applications.length === 1, 'Candidatura não foi registrada.');

  await request(`/services/${service.id}/applications/${applications[0].id}/accept`, {
    method: 'POST',
    token: client.token,
    body: {},
  });

  let todayWork = await request('/work/today', { token: professional.token });
  assert(todayWork.length === 1 && todayWork[0].session === null, 'Ordem aceita não apareceu no trabalho do dia.');

  const started = await request(`/work/services/${service.id}/start`, {
    method: 'POST',
    token: professional.token,
    body: {},
  });
  assert(started.status === 'em_andamento', 'Jornada não iniciou.');

  const finished = await request(`/work/${started.id}/finish`, {
    method: 'POST',
    token: professional.token,
    body: { note: 'Serviço concluído sem ocorrências.' },
  });
  assert(finished.status === 'aguardando_confirmacao', 'Jornada não aguardou confirmação.');
  assert(Number(finished.amount) > 0, 'Valor da jornada não foi calculado.');

  const pending = await request('/work/pending-confirmations', { token: client.token });
  assert(pending.some((item) => item.id === started.id), 'Confirmação não apareceu para o cliente.');

  const confirmed = await request(`/work/${started.id}/confirm`, {
    method: 'POST',
    token: client.token,
    body: {},
  });
  assert(confirmed.status === 'confirmado', 'Jornada não foi confirmada.');

  const performance = await request(`/work/performance?month=${today.slice(0, 7)}`, {
    token: professional.token,
  });
  assert(performance.week.service_count === 1, 'Resumo semanal não contabilizou a jornada.');
  assert(performance.history.some((item) => item.id === started.id), 'Histórico não recebeu a jornada.');

  const receipt = await request(`/work/${started.id}/receipt`, { token: professional.token });
  assert(receipt.receipt_number && receipt.document_type === 'comprovante_nao_fiscal', 'Comprovante inválido.');

  console.log('Fluxo validado: descoberta -> candidatura -> aceite -> jornada -> confirmação -> desempenho -> comprovante.');
}

run()
  .catch((error) => {
    console.error('Smoke test falhou:', error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (cleanupIds.length > 0) {
      await pool.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [cleanupIds]);
    }
    await pool.end();
  });
