ALTER TABLE professional_profiles
  ADD COLUMN IF NOT EXISTS pricing_type VARCHAR(20) NOT NULL DEFAULT 'por_hora',
  ADD COLUMN IF NOT EXISTS project_rate NUMERIC(10, 2);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'professional_profiles_pricing_type_check'
  ) THEN
    ALTER TABLE professional_profiles
      ADD CONSTRAINT professional_profiles_pricing_type_check
      CHECK (pricing_type IN ('por_hora', 'empreitada'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_professional_profiles_pricing_type
  ON professional_profiles (pricing_type);
