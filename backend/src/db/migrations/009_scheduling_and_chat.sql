-- Migração 9: agenda com intervalos reais, disponibilidade semanal e
-- conversas/propostas de contratação direta.

-- A migração 010 usa o novo valor somente depois do COMMIT desta migração.
ALTER TYPE service_status ADD VALUE IF NOT EXISTS 'agendado' BEFORE 'em_andamento';

ALTER TABLE services
  ADD COLUMN IF NOT EXISTS scheduled_start TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS scheduled_end TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_all_day BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS agreed_pricing_type VARCHAR(20),
  ADD COLUMN IF NOT EXISTS agreed_amount NUMERIC(10, 2),
  ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
  ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

UPDATE services
SET scheduled_start = scheduled_date::timestamp AT TIME ZONE 'America/Sao_Paulo',
    scheduled_end = (scheduled_date + 1)::timestamp AT TIME ZONE 'America/Sao_Paulo'
WHERE scheduled_start IS NULL OR scheduled_end IS NULL;

ALTER TABLE services
  ALTER COLUMN scheduled_start SET NOT NULL,
  ALTER COLUMN scheduled_start SET DEFAULT now(),
  ALTER COLUMN scheduled_end SET NOT NULL,
  ALTER COLUMN scheduled_end SET DEFAULT (now() + interval '1 day');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'services_schedule_interval_check'
  ) THEN
    ALTER TABLE services
      ADD CONSTRAINT services_schedule_interval_check
      CHECK (scheduled_end > scheduled_start);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'services_agreed_pricing_type_check'
  ) THEN
    ALTER TABLE services
      ADD CONSTRAINT services_agreed_pricing_type_check
      CHECK (agreed_pricing_type IS NULL OR agreed_pricing_type IN ('por_hora', 'empreitada'));
  END IF;
END $$;

ALTER TABLE professional_profiles
  ADD COLUMN IF NOT EXISTS buffer_minutes INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS variable_hours BOOLEAN NOT NULL DEFAULT FALSE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'professional_profiles_buffer_minutes_check'
  ) THEN
    ALTER TABLE professional_profiles
      ADD CONSTRAINT professional_profiles_buffer_minutes_check
      CHECK (buffer_minutes BETWEEN 0 AND 240);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS professional_availability_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  professional_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  weekday SMALLINT NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  ends_next_day BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (professional_id, weekday, start_time, end_time, ends_next_day)
);

CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  professional_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (client_id, professional_id),
  CHECK (client_id <> professional_id)
);

CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body TEXT NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS job_proposals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  proposed_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  professional_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(150) NOT NULL,
  description TEXT NOT NULL,
  category VARCHAR(100),
  service_mode VARCHAR(20) NOT NULL
    CHECK (service_mode IN ('presencial', 'remoto', 'hibrido')),
  city VARCHAR(100),
  state VARCHAR(2),
  address VARCHAR(220),
  pricing_type VARCHAR(20) NOT NULL
    CHECK (pricing_type IN ('por_hora', 'empreitada')),
  amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
  scheduled_start TIMESTAMPTZ NOT NULL,
  scheduled_end TIMESTAMPTZ NOT NULL,
  is_all_day BOOLEAN NOT NULL DEFAULT FALSE,
  status VARCHAR(20) NOT NULL DEFAULT 'pendente'
    CHECK (status IN ('pendente', 'aceita', 'recusada', 'cancelada')),
  service_id UUID REFERENCES services(id) ON DELETE SET NULL,
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (scheduled_end > scheduled_start)
);

CREATE INDEX IF NOT EXISTS idx_services_professional_schedule
  ON services (accepted_professional_id, scheduled_start, scheduled_end);
CREATE INDEX IF NOT EXISTS idx_availability_professional_weekday
  ON professional_availability_slots (professional_id, weekday, start_time);
CREATE INDEX IF NOT EXISTS idx_conversations_client_updated
  ON conversations (client_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_professional_updated
  ON conversations (professional_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_created
  ON chat_messages (conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_chat_messages_unread
  ON chat_messages (conversation_id, read_at) WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_job_proposals_conversation_created
  ON job_proposals (conversation_id, created_at);
