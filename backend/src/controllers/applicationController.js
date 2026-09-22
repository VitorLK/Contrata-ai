const pool = require('../config/db');

async function listMyApplications(req, res) {
  try {
    const result = await pool.query(
      `SELECT sa.*,
              s.title AS service_title,
              s.status AS service_status,
              s.category AS service_category,
              s.budget AS service_budget,
              s.scheduled_date AS service_scheduled_date,
              s.city AS service_city,
              s.state AS service_state,
              s.service_mode,
              u.name AS client_name
       FROM service_applications sa
       JOIN services s ON s.id = sa.service_id
       JOIN users u ON u.id = s.client_id
       WHERE sa.professional_id = $1
       ORDER BY sa.created_at DESC`,
      [req.user.id]
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('Erro ao listar minhas candidaturas:', err);
    return res.status(500).json({ error: 'Não foi possível carregar suas candidaturas.' });
  }
}

async function withdrawApplication(req, res) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    const result = await client.query(
      `SELECT sa.id, sa.status, s.status AS service_status
       FROM service_applications sa
       JOIN services s ON s.id = sa.service_id
       WHERE sa.id = $1 AND sa.professional_id = $2
       FOR UPDATE`,
      [req.params.id, req.user.id]
    );
    const application = result.rows[0];

    if (!application) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Candidatura não encontrada.' });
    }
    if (application.status !== 'pendente') {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: 'Somente candidaturas pendentes podem ser retiradas.',
      });
    }
    if (application.service_status !== 'aberto') {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: 'Este serviço não está mais aberto para alterações na candidatura.',
      });
    }

    await client.query(
      'DELETE FROM service_applications WHERE id = $1 AND professional_id = $2',
      [req.params.id, req.user.id]
    );
    await client.query('COMMIT');
    return res.status(204).send();
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Erro ao retirar candidatura:', err);
    return res.status(500).json({ error: 'Não foi possível retirar a candidatura.' });
  } finally {
    client.release();
  }
}

module.exports = { listMyApplications, withdrawApplication };
