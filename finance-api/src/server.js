import express from 'express';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import pg from 'pg';

const { Pool } = pg;
const app = express();
app.disable('x-powered-by');
app.use(express.json());

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

const PORT = Number(process.env.PORT || 4000);
const ISSUER = requiredEnv('ISSUER');
const AUDIENCE = requiredEnv('AUDIENCE');
const JWKS = createRemoteJWKSet(new URL(requiredEnv('JWKS_URL')));
const pool = new Pool({
  connectionTimeoutMillis: 5000,
  idleTimeoutMillis: 30000,
  max: 10
});

function bearer(req) {
  const value = req.headers.authorization;
  return value?.startsWith('Bearer ') ? value.slice(7) : null;
}

async function authenticate(req, res, next) {
  const token = bearer(req);
  if (!token) return res.status(401).json({ error: 'missing_token', layer: 'finance-api' });

  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: ISSUER,
      audience: AUDIENCE,
      algorithms: ['RS256'],
      clockTolerance: 5
    });

    if (payload.typ && payload.typ !== 'Bearer') {
      return res.status(401).json({ error: 'invalid_token_type', type: payload.typ, layer: 'finance-api' });
    }

    req.auth = payload;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'invalid_token', code: err.code || 'JWT_VERIFY_FAILED', message: err.message, layer: 'finance-api' });
  }
}

function requireRole(role) {
  return (req, res, next) => {
    const roles = req.auth?.realm_access?.roles || [];
    if (!roles.includes(role)) {
      return res.status(403).json({ error: 'forbidden', required_role: role, roles, layer: 'finance-api' });
    }
    next();
  };
}

app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true, service: 'finance-api', database: 'postgresql', db: 'ok' });
  } catch (_err) {
    res.status(503).json({ ok: false, service: 'finance-api', database: 'postgresql', db: 'down' });
  }
});

app.get('/accounts', authenticate, requireRole('finance.read'), async (req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT id, owner, account_no AS "accountNo", balance::float8 AS balance
      FROM accounts
      ORDER BY account_no
    `);

    res.json({
      requestedBy: req.auth.preferred_username,
      database: 'postgresql',
      accounts: rows
    });
  } catch (err) {
    console.error('Account query failed:', err);
    res.status(500).json({ error: 'database_error', layer: 'finance-api' });
  }
});

app.get('/session', authenticate, (req, res) => {
  res.json({
    active: true,
    username: req.auth.preferred_username,
    exp: req.auth.exp,
    iss: req.auth.iss,
    aud: req.auth.aud,
    roles: req.auth.realm_access?.roles || []
  });
});

let server;

async function start() {
  const { rows } = await pool.query("SELECT to_regclass('public.accounts') AS table_name");
  if (!rows[0].table_name) {
    throw new Error('Required table public.accounts was not initialized');
  }

  server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`Finance API listening on :${PORT}`);
    console.log('PostgreSQL schema is ready');
  });
}

async function shutdown(signal) {
  console.log(`${signal} received, shutting down Finance API`);
  server?.close();
  await pool.end();
  process.exit(0);
}

process.on('SIGTERM', () => void shutdown('SIGTERM'));
process.on('SIGINT', () => void shutdown('SIGINT'));

start().catch((err) => {
  console.error('Finance API startup failed:', err);
  process.exit(1);
});
