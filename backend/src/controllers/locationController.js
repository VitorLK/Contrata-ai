const GEOCODING_URL = process.env.GEOCODING_URL || 'https://nominatim.openstreetmap.org/search';
const MAP_USER_AGENT = process.env.MAP_USER_AGENT || 'ContrataAi-TCC/1.0 (academic service marketplace)';
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const MIN_REQUEST_INTERVAL_MS = 1100;
const cache = new Map();

let lastRequestAt = 0;
let requestQueue = Promise.resolve();

function normalize(value) {
  return String(value ?? '').trim();
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function runRateLimited(task) {
  const queued = requestQueue.then(async () => {
    const remaining = MIN_REQUEST_INTERVAL_MS - (Date.now() - lastRequestAt);
    if (remaining > 0) await wait(remaining);
    lastRequestAt = Date.now();
    return task();
  });
  requestQueue = queued.catch(() => {});
  return queued;
}

async function fetchFromNominatim(query) {
  const url = new URL(GEOCODING_URL);
  url.searchParams.set('q', query);
  url.searchParams.set('format', 'jsonv2');
  url.searchParams.set('limit', '1');
  url.searchParams.set('countrycodes', 'br');

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': MAP_USER_AGENT,
        'Accept-Language': 'pt-BR,pt;q=0.9',
      },
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`Nominatim respondeu ${response.status}`);
    return response.json();
  } finally {
    clearTimeout(timeout);
  }
}

async function geocodeAddress(req, res) {
  const address = normalize(req.query.address);
  const city = normalize(req.query.city);
  const state = normalize(req.query.state).toUpperCase();

  if (address.length < 4 || !city || !/^[A-Z]{2}$/.test(state)) {
    return res.status(400).json({
      error: 'Informe bairro ou referência, cidade e estado antes de localizar.',
    });
  }

  const query = `${address}, ${city}, ${state}, Brasil`;
  const cacheKey = query.toLocaleLowerCase('pt-BR');
  const cached = cache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) return res.json(cached.value);

  try {
    const results = await runRateLimited(() => fetchFromNominatim(query));
    const first = Array.isArray(results) ? results[0] : null;
    if (!first) {
      return res.status(404).json({
        error: 'Local não encontrado. Tente informar o bairro e um ponto de referência conhecido.',
      });
    }

    const value = {
      latitude: Number(first.lat),
      longitude: Number(first.lon),
      display_name: first.display_name,
    };
    if (!Number.isFinite(value.latitude) || !Number.isFinite(value.longitude)) {
      throw new Error('Coordenadas inválidas recebidas do geocodificador.');
    }

    cache.set(cacheKey, { value, expiresAt: Date.now() + CACHE_TTL_MS });
    return res.json(value);
  } catch (error) {
    console.error('Erro ao localizar endereço:', error.message);
    return res.status(502).json({
      error: 'O serviço de mapas está indisponível agora. Tente novamente em alguns instantes.',
    });
  }
}

module.exports = { geocodeAddress };
