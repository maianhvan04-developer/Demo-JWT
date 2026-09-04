import express from 'express';
import { createRemoteJWKSet, jwtVerify } from 'jose';

const app = express();
app.disable('x-powered-by');
app.use(express.json());

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

const PORT = Number(process.env.PORT || 3000);
const ISSUER = requiredEnv('ISSUER');
const AUDIENCE = requiredEnv('AUDIENCE');
const FINANCE_API_URL = requiredEnv('FINANCE_API_URL');
const JWKS = createRemoteJWKSet(new URL(requiredEnv('JWKS_URL')));

function bearer(req) {
  const value = req.headers.authorization;
  return value?.startsWith('Bearer ') ? value.slice(7) : null;
}

async function authenticate(req, res, next) {
  const token = bearer(req);
  if (!token) {
    return res.status(401).json({ error: 'missing_token', layer: 'api-gateway' });
  }

  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: ISSUER,
      audience: AUDIENCE,
      algorithms: ['RS256'],
      clockTolerance: 5
    });

    if (payload.typ && payload.typ !== 'Bearer') {
      return res.status(401).json({ error: 'invalid_token_type', type: payload.typ, layer: 'api-gateway' });
    }

    req.auth = payload;
    next();
  } catch (err) {
    return res.status(401).json({
      error: 'invalid_token',
      code: err.code || 'JWT_VERIFY_FAILED',
      message: err.message,
      layer: 'api-gateway'
    });
  }
}

app.get('/health', async (_req, res) => {
  try {
    const upstream = await fetch(`${FINANCE_API_URL}/health`, {
      signal: AbortSignal.timeout(3000)
    });
    const finance = await upstream.json();
    const ok = upstream.ok && finance.ok === true;
    res.status(ok ? 200 : 503).json({
      ok,
      service: 'api-gateway',
      dependencies: { financeApi: ok ? 'ok' : 'down' }
    });
  } catch (_err) {
    res.status(503).json({
      ok: false,
      service: 'api-gateway',
      dependencies: { financeApi: 'down' }
    });
  }
});

app.get('/api/profile', authenticate, (req, res) => {
  res.json({
    username: req.auth.preferred_username,
    sub: req.auth.sub,
    issuer: req.auth.iss,
    audience: req.auth.aud,
    roles: req.auth.realm_access?.roles || []
  });
});

app.all('/api/finance/*splat', authenticate, async (req, res) => {
  try {
    const upstreamPath = req.originalUrl.replace('/api/finance', '');
    const upstream = await fetch(`${FINANCE_API_URL}${upstreamPath}`, {
      method: req.method,
      signal: AbortSignal.timeout(5000),
      headers: {
        'authorization': req.headers.authorization,
        'content-type': 'application/json'
      },
      body: ['GET', 'HEAD'].includes(req.method) ? undefined : JSON.stringify(req.body)
    });

    const text = await upstream.text();
    res.status(upstream.status);
    const ct = upstream.headers.get('content-type') || '';
    if (ct.includes('application/json')) return res.json(JSON.parse(text));
    return res.send(text);
  } catch (err) {
    return res.status(502).json({ error: 'bad_gateway', message: err.message });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`API Gateway listening on :${PORT}`);
});
