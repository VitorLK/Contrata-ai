require('dotenv').config();

const fs = require('fs');
const path = require('path');
const express = require('express');
const apiApp = require('./app');

const port = Number(process.env.DEMO_PORT || 8090);
const flutterWebDir = path.resolve(
  process.env.FLUTTER_WEB_DIR ||
    path.join(__dirname, '..', '..', 'contrata_ai_app', 'build', 'web'),
);
const indexFile = path.join(flutterWebDir, 'index.html');

if (!fs.existsSync(indexFile)) {
  console.error(
    `Build Web não encontrada em ${flutterWebDir}. Execute "flutter build web --release" primeiro.`,
  );
  process.exit(1);
}

const demoApp = express();

// A versão Web e a API compartilham a mesma origem. Isso evita CORS, HTTP
// inseguro e a necessidade de criar dois túneis públicos diferentes.
demoApp.use(express.static(flutterWebDir));

const backendPaths = [
  '/health',
  '/uploads',
  '/auth',
  '/services',
  '/applications',
  '/professionals',
  '/work',
  '/locations',
  '/admin',
  '/chat',
];

// Mantém compatibilidade caso o app passe a usar URLs sem # no futuro.
demoApp.use((req, res, next) => {
  const isBackendRequest = backendPaths.some(
    (prefix) => req.path === prefix || req.path.startsWith(`${prefix}/`),
  );
  const isPageNavigation =
    req.method === 'GET' &&
    !path.extname(req.path) &&
    Boolean(req.accepts('html'));

  if (!isBackendRequest && isPageNavigation) {
    return res.sendFile(indexFile);
  }

  return next();
});

demoApp.use(apiApp);

const server = demoApp.listen(port, '127.0.0.1', () => {
  console.log(`Demonstração local em http://127.0.0.1:${port}`);
});

function shutdown() {
  server.close(() => process.exit(0));
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
