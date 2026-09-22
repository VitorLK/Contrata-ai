-- Schema do banco "tcc_freelancers".
-- Rode este script uma vez, depois de criar o banco:
--   psql -U postgres -d tcc_freelancers -f src/db/schema.sql

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('cliente', 'profissional', 'administrador');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE service_status AS ENUM ('aberto', 'agendado', 'em_andamento', 'concluido', 'cancelado');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE application_status AS ENUM ('pendente', 'aceito', 'recusado');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role user_role NOT NULL,
    phone VARCHAR(20),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID UNIQUE REFERENCES users(id) ON DELETE SET NULL,
    legal_name VARCHAR(180) NOT NULL,
    trade_name VARCHAR(150),
    document VARCHAR(14) UNIQUE NOT NULL,
    email VARCHAR(150),
    phone VARCHAR(20),
    city VARCHAR(100),
    state VARCHAR(2),
    status VARCHAR(20) NOT NULL DEFAULT 'ativa'
      CHECK (status IN ('ativa', 'suspensa')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(40) NOT NULL,
    entity_id UUID,
    summary VARCHAR(240) NOT NULL,
    before_data JSONB,
    after_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Perfil estendido, exclusivo de usuários com role = 'profissional'.
-- skills é reaproveitada como "categorias/habilidades" de atuação.
CREATE TABLE IF NOT EXISTS professional_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    bio TEXT,
    skills TEXT[] NOT NULL DEFAULT '{}',
    hourly_rate NUMERIC(10, 2),
    pricing_type VARCHAR(20) NOT NULL DEFAULT 'por_hora'
      CHECK (pricing_type IN ('por_hora', 'empreitada')),
    project_rate NUMERIC(10, 2),
    photo_url TEXT,
    experience TEXT,
    city VARCHAR(100),
    state VARCHAR(2),
    service_mode VARCHAR(20) CHECK (service_mode IN ('presencial', 'remoto', 'hibrido')),
    availability TEXT,
    buffer_minutes INTEGER NOT NULL DEFAULT 0 CHECK (buffer_minutes BETWEEN 0 AND 240),
    variable_hours BOOLEAN NOT NULL DEFAULT FALSE
);

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

-- Imagens de portfólio do profissional (upload real — ver Etapa 16).
CREATE TABLE IF NOT EXISTS portfolio_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professional_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(100),
    budget NUMERIC(10, 2),
    status service_status NOT NULL DEFAULT 'aberto',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    scheduled_date DATE NOT NULL DEFAULT CURRENT_DATE,
    city VARCHAR(100),
    state VARCHAR(2),
    service_mode VARCHAR(20) CHECK (service_mode IS NULL OR service_mode IN ('presencial', 'remoto', 'hibrido')),
    address VARCHAR(220),
    image_url TEXT,
    latitude NUMERIC(9, 6) CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    longitude NUMERIC(9, 6) CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    open_confirmed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Preenchida quando o cliente aceita uma candidatura (ver Etapa 8 do
    -- plano) — registra qual profissional foi efetivamente contratado.
    accepted_professional_id UUID REFERENCES users(id) ON DELETE SET NULL,
    scheduled_start TIMESTAMPTZ NOT NULL DEFAULT now(),
    scheduled_end TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '1 day'),
    is_all_day BOOLEAN NOT NULL DEFAULT FALSE,
    agreed_pricing_type VARCHAR(20)
      CHECK (agreed_pricing_type IS NULL OR agreed_pricing_type IN ('por_hora', 'empreitada')),
    agreed_amount NUMERIC(10, 2),
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    cancelled_at TIMESTAMPTZ,
    CHECK (scheduled_end > scheduled_start)
);

DO $$ BEGIN
    CREATE TYPE work_session_status AS ENUM ('em_andamento', 'aguardando_confirmacao', 'confirmado', 'contestado');
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

CREATE TABLE IF NOT EXISTS service_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    professional_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT,
    status application_status NOT NULL DEFAULT 'pendente',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (service_id, professional_id)
);

-- Uma avaliação por serviço por cliente (UNIQUE abaixo); regra de negócio
-- de quando é permitido avaliar fica no controller (ver Etapa 21).
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    professional_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (service_id, client_id)
);

CREATE INDEX IF NOT EXISTS idx_services_status ON services (status);
CREATE INDEX IF NOT EXISTS idx_services_client ON services (client_id);
CREATE INDEX IF NOT EXISTS idx_services_accepted_professional_id ON services (accepted_professional_id);
CREATE INDEX IF NOT EXISTS idx_applications_service ON service_applications (service_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_items_professional_id ON portfolio_items (professional_id);
CREATE INDEX IF NOT EXISTS idx_reviews_professional_id ON reviews (professional_id);
CREATE INDEX IF NOT EXISTS idx_services_discovery ON services (status, scheduled_date, open_confirmed_at);
CREATE INDEX IF NOT EXISTS idx_services_category ON services (category);
CREATE INDEX IF NOT EXISTS idx_work_sessions_professional ON work_sessions (professional_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_work_sessions_client_status ON work_sessions (client_id, status, started_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_work_sessions_professional_running
  ON work_sessions (professional_id) WHERE status = 'em_andamento';
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications (user_id, created_at DESC);
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
CREATE INDEX IF NOT EXISTS idx_users_role_active ON users (role, is_active);
CREATE INDEX IF NOT EXISTS idx_companies_status ON companies (status);
CREATE INDEX IF NOT EXISTS idx_admin_audit_created ON admin_audit_logs (created_at DESC);
