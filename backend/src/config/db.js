const { Pool } = require('pg');

// O Pool só abre conexões de fato quando a primeira query é executada,
// então o servidor consegue subir mesmo que o Postgres ainda não esteja
// configurado — o erro só aparece quando uma rota tentar acessar o banco.
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

module.exports = pool;
