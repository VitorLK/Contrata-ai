-- Dados de apresentação e referência geográfica usados no cadastro e no
-- detalhe responsivo do serviço.
ALTER TABLE services
  ADD COLUMN IF NOT EXISTS address VARCHAR(220),
  ADD COLUMN IF NOT EXISTS image_url TEXT;
