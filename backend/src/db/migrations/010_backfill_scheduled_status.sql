-- Serviços que já tinham profissional aceito, mas ainda não possuíam uma
-- jornada iniciada, passam a representar corretamente um compromisso futuro.
UPDATE services s
SET status = 'agendado'::service_status
WHERE s.status = 'em_andamento'
  AND s.accepted_professional_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM work_sessions ws WHERE ws.service_id = s.id
  );
