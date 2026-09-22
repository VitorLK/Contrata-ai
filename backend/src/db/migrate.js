require('dotenv').config();

const fs = require('fs');
const path = require('path');
const pool = require('../config/db');

async function run() {
  const migrationsDirectory = path.join(__dirname, 'migrations');
  const files = fs
    .readdirSync(migrationsDirectory)
    .filter((file) => file.endsWith('.sql'))
    .sort();

  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  for (const filename of files) {
    const existing = await pool.query(
      'SELECT 1 FROM schema_migrations WHERE filename = $1',
      [filename]
    );
    if (existing.rowCount > 0) {
      console.log(`Ignorando ${filename} (já aplicada).`);
      continue;
    }

    const sql = fs.readFileSync(path.join(migrationsDirectory, filename), 'utf8');
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [filename]);
      await client.query('COMMIT');
      console.log(`Aplicada: ${filename}`);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}

run()
  .then(() => console.log('Banco de dados atualizado.'))
  .catch((error) => {
    console.error('Falha ao aplicar migrações:', error.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
