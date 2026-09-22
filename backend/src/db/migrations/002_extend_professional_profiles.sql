-- Migração 2: estende o perfil profissional (foto, experiência, região,
-- forma de atendimento, disponibilidade) e cria a tabela de portfólio.
--
-- Aditiva: colunas NULLable, tabela nova isolada. Não afeta o registro de
-- usuário (professional_profiles continua criada com só user_id) nem
-- nenhuma leitura existente.
--
-- Rodar com:
--   psql -U postgres -d tcc_freelancers -f src/db/migrations/002_extend_professional_profiles.sql

ALTER TABLE professional_profiles
  ADD COLUMN IF NOT EXISTS photo_url TEXT,
  ADD COLUMN IF NOT EXISTS experience TEXT,
  ADD COLUMN IF NOT EXISTS city VARCHAR(100),
  ADD COLUMN IF NOT EXISTS state VARCHAR(2),
  ADD COLUMN IF NOT EXISTS service_mode VARCHAR(20) CHECK (service_mode IN ('presencial', 'remoto', 'hibrido')),
  ADD COLUMN IF NOT EXISTS availability TEXT;

-- skills (já existente, TEXT[]) é reaproveitada como "categorias/
-- habilidades" de atuação — sem coluna nova para isso.

CREATE TABLE IF NOT EXISTS portfolio_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professional_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_portfolio_items_professional_id ON portfolio_items (professional_id);
