-- Migração 4: agenda do serviço, renovação de anúncios, jornada de trabalho,
-- preferências de confirmação e notificações internas.
--
-- Rodar com:
--   psql -U postgres -d tcc_freelancers -f src/db/migrations/004_workflow_and_time_tracking.sql

ALTER TABLE services
  ADD COLUMN IF NOT EXISTS scheduled_date DATE,
  ADD COLUMN IF NOT EXISTS city VARCHAR(100),
  ADD COLUMN IF NOT EXISTS state VARCHAR(2),
  ADD COLUMN IF NOT EXISTS service_mode VARCHAR(20),
  ADD COLUMN IF NOT EXISTS open_confirmed_at TIMESTAMPTZ;

UPDATE services
SET scheduled_date = created_at::date
WHERE scheduled_date IS NULL;

UPDATE services
SET open_confirmed_at = created_at
WHERE open_confirmed_at IS NULL;

ALTER TABLE services
  ALTER COLUMN scheduled_date SET DEFAULT CURRENT_DATE,
  ALTER COLUMN scheduled_date SET NOT NULL,
  ALTER COLUMN open_confirmed_at SET DEFAULT now(),
  ALTER COLUMN open_confirmed_at SET NOT NULL;

DO $$ BEGIN
  ALTER TABLE services
    ADD CONSTRAINT services_service_mode_check
    CHECK (service_mode IS NULL OR service_mode IN ('presencial', 'remoto', 'hibrido'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE work_session_status AS ENUM (
    'em_andamento',
    'aguardando_confirmacao',
    'confirmado',
    'contestado'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS client_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  require_work_confirmation BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS work_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID NOT NULL UNIQUE REFERENCES services(id) ON DELETE CASCADE,
  professional_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ,
  duration_minutes INTEGER CHECK (duration_minutes IS NULL OR duration_minutes > 0),
  hourly_rate_snapshot NUMERIC(10, 2),
  fixed_amount_snapshot NUMERIC(10, 2),
  amount_basis VARCHAR(20) NOT NULL CHECK (amount_basis IN ('por_hora', 'valor_fixo')),
  amount NUMERIC(10, 2),
  provider_note TEXT,
  evidence_photo_url TEXT,
  status work_session_status NOT NULL DEFAULT 'em_andamento',
  confirmed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL,
  title VARCHAR(150) NOT NULL,
  message TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_services_discovery
  ON services (status, scheduled_date, open_confirmed_at);
CREATE INDEX IF NOT EXISTS idx_services_category ON services (category);
CREATE INDEX IF NOT EXISTS idx_work_sessions_professional
  ON work_sessions (professional_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_work_sessions_client_status
  ON work_sessions (client_id, status, started_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_work_sessions_professional_running
  ON work_sessions (professional_id)
  WHERE status = 'em_andamento';
CREATE INDEX IF NOT EXISTS idx_notifications_user
  ON notifications (user_id, created_at DESC);
