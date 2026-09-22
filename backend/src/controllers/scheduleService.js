const DEFAULT_TIME_ZONE = 'America/Sao_Paulo';

function asBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === '') return fallback;
  if (typeof value === 'boolean') return value;
  return String(value).toLowerCase() === 'true';
}

function dateOnlyInSaoPaulo(date) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: DEFAULT_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

function parseSchedulePayload(body, { allowPast = false } = {}) {
  const scheduledDate = String(body.scheduled_date || '').trim();
  const isAllDay = asBoolean(
    body.is_all_day,
    !body.scheduled_start && !body.scheduled_end
  );
  let start;
  let end;

  if (body.scheduled_start && body.scheduled_end) {
    start = new Date(body.scheduled_start);
    end = new Date(body.scheduled_end);
  } else if (/^\d{4}-\d{2}-\d{2}$/.test(scheduledDate)) {
    start = new Date(`${scheduledDate}T00:00:00-03:00`);
    end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  } else {
    return { error: 'Informe a data e o período do serviço.' };
  }

  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    return { error: 'O período informado é inválido.' };
  }
  if (end <= start) {
    return { error: 'O horário final deve ser posterior ao horário inicial.' };
  }
  if (end.getTime() - start.getTime() > 72 * 60 * 60 * 1000) {
    return { error: 'Um agendamento pode ocupar no máximo 72 horas.' };
  }
  if (!allowPast && end < new Date()) {
    return { error: 'O período do serviço não pode estar no passado.' };
  }

  return {
    scheduledDate: scheduledDate || dateOnlyInSaoPaulo(start),
    scheduledStart: start.toISOString(),
    scheduledEnd: end.toISOString(),
    isAllDay,
  };
}

async function assertNoScheduleConflict(
  client,
  { professionalId, scheduledStart, scheduledEnd, excludeServiceId = null }
) {
  await client.query(
    'SELECT pg_advisory_xact_lock(hashtext($1::text)::bigint)',
    [professionalId]
  );

  const preferenceResult = await client.query(
    `SELECT COALESCE(buffer_minutes, 0)::int AS buffer_minutes
     FROM professional_profiles WHERE user_id = $1`,
    [professionalId]
  );
  const bufferMinutes = preferenceResult.rows[0]?.buffer_minutes ?? 0;

  const runningResult = await client.query(
    `SELECT s.id, s.title, ws.started_at
     FROM work_sessions ws
     JOIN services s ON s.id = ws.service_id
     WHERE ws.professional_id = $1 AND ws.status = 'em_andamento'
       AND $2::timestamptz <= now()
     LIMIT 1
     FOR UPDATE OF ws`,
    [professionalId, scheduledStart]
  );
  if (runningResult.rowCount > 0) {
    const conflict = runningResult.rows[0];
    const error = new Error(
      `Você está trabalhando agora em “${conflict.title}”. Escolha um horário futuro.`
    );
    error.code = 'SCHEDULE_CONFLICT';
    error.conflict = conflict;
    throw error;
  }

  const result = await client.query(
    `SELECT id, title, scheduled_start, scheduled_end
     FROM services
     WHERE accepted_professional_id = $1
       AND status IN ('agendado', 'em_andamento')
       AND scheduled_start < $3::timestamptz + make_interval(mins => $5)
       AND scheduled_end > $2::timestamptz - make_interval(mins => $5)
       AND ($4::uuid IS NULL OR id <> $4::uuid)
     ORDER BY scheduled_start
     LIMIT 1
     FOR UPDATE`,
    [professionalId, scheduledStart, scheduledEnd, excludeServiceId, bufferMinutes]
  );

  if (result.rowCount > 0) {
    const conflict = result.rows[0];
    const error = new Error(
      `Conflito com “${conflict.title}”, já agendado nesse período.`
    );
    error.code = 'SCHEDULE_CONFLICT';
    error.conflict = conflict;
    throw error;
  }
}

module.exports = {
  DEFAULT_TIME_ZONE,
  parseSchedulePayload,
  assertNoScheduleConflict,
};
