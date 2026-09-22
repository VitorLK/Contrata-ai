-- Migração 3: tabela de avaliações. Um cliente avalia um profissional
-- depois que um serviço é concluído — regra de negócio aplicada no
-- controller (Etapa 21), não aqui.
--
-- UNIQUE (service_id, client_id) garante "1 avaliação por serviço por
-- contratante" diretamente no banco (mesmo padrão já usado em
-- service_applications para impedir candidatura duplicada).
--
-- Rodar com:
--   psql -U postgres -d tcc_freelancers -f src/db/migrations/003_create_reviews.sql

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

CREATE INDEX IF NOT EXISTS idx_reviews_professional_id ON reviews (professional_id);
