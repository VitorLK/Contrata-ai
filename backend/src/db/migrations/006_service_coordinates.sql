-- Coordenadas escolhidas no mapa para localizar o serviço.
ALTER TABLE services
  ADD COLUMN IF NOT EXISTS latitude NUMERIC(9, 6),
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(9, 6);

DO $$ BEGIN
  ALTER TABLE services
    ADD CONSTRAINT services_latitude_check
    CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE services
    ADD CONSTRAINT services_longitude_check
    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
