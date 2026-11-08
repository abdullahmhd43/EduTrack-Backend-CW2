require('dotenv').config();

const isTest = process.env.NODE_ENV === 'test';

/** Number of reverse proxies in front of the app (Enzonic's proxy = 1). 'false'/'0' disables it. */
function parseTrustProxy(v) {
  if (v === undefined || v === '') return 1;
  if (v === 'false' || v === '0') return false;
  if (v === 'true') return 1;
  return /^\d+$/.test(v) ? Number(v) : v;
}

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  isTest,
  isProd: process.env.NODE_ENV === 'production',
  port: Number(process.env.PORT) || 5000,
  mongoUri: process.env.MONGODB_URI,
  jwtSecret: process.env.JWT_SECRET || (isTest ? 'test-secret-test-secret-test-secret' : undefined),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  bcryptRounds: Number(process.env.BCRYPT_ROUNDS) || (isTest ? 4 : 12),
  corsOrigin: process.env.CORS_ORIGIN || '*',
  trustProxy: parseTrustProxy(process.env.TRUST_PROXY),
};

/** Fail fast when required secrets are missing (no hard-coded fallbacks outside tests). */
function assertEnv() {
  const missing = [];
  if (!env.jwtSecret || env.jwtSecret.length < 16) missing.push('JWT_SECRET (min 16 chars)');
  if (!env.mongoUri) missing.push('MONGODB_URI');
  if (missing.length) {
    throw new Error(`Missing/invalid environment variables: ${missing.join(', ')}. See .env.example`);
  }
}

module.exports = { env, assertEnv };
