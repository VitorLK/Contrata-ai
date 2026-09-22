-- Migração 1: adiciona a coluna que registra qual profissional foi
-- efetivamente contratado para o serviço (preenchida quando o cliente
-- aceita uma candidatura — ver Etapa 8 do plano).
--
-- Aditiva: coluna NULLable, não afeta nenhuma linha existente nem
-- nenhuma query atual (SELECT s.* passa a trazer mais uma coluna, que o
-- Flutter ainda ignora até a Etapa 6).
--
-- Rodar com:
--   psql -U postgres -d tcc_freelancers -f src/db/migrations/001_add_accepted_professional_id.sql

ALTER TABLE services
  ADD COLUMN IF NOT EXISTS accepted_professional_id UUID REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_services_accepted_professional_id ON services (accepted_professional_id);
