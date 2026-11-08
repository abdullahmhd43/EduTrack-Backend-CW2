/**
 * Server start-up behaviour (spawns the real server process; no database needed).
 */
const { spawn } = require('child_process');
const path = require('path');
const http = require('http');

const server = path.join(__dirname, '../../src/server.js');
const run = (env, port) => spawn(process.execPath, [server], {
  cwd: path.join(__dirname, '../..'),
  env: { PATH: process.env.PATH, NODE_ENV: 'development', PORT: String(port), ...env },
});
const waitExit = (p) => new Promise((res) => { let out = ''; p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (out += d)); p.on('exit', (code) => res({ code, out })); });
const getJson = (port, p) => new Promise((resolve, reject) => {
  http.get({ host: '127.0.0.1', port, path: p }, (r) => { let b = ''; r.on('data', (d) => (b += d)); r.on('end', () => resolve({ status: r.statusCode, body: JSON.parse(b || '{}') })); }).on('error', reject);
});
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

describe('start-up', () => {
  test('missing MONGODB_URI and JWT_SECRET -> exits with code 1 and names the variables (no secrets printed)', async () => {
    const r = await waitExit(run({ MONGODB_URI: '', JWT_SECRET: '' }, 5611));
    expect(r.code).toBe(1);
    expect(r.out).toMatch(/JWT_SECRET/); expect(r.out).toMatch(/MONGODB_URI/);
  }, 20000);

  test('JWT_SECRET shorter than 16 characters is rejected', async () => {
    const r = await waitExit(run({ JWT_SECRET: 'short', MONGODB_URI: 'mongodb://127.0.0.1:1/x' }, 5612));
    expect(r.code).toBe(1); expect(r.out).toMatch(/JWT_SECRET/);
  }, 20000);

  test('database unreachable: process stays up, /health says db disconnected, data routes answer 503; no secret in logs', async () => {
    const secret = 'unit-test-secret-not-real-1234567890';
    const p = run({ JWT_SECRET: secret, MONGODB_URI: 'mongodb://127.0.0.1:1/x?serverSelectionTimeoutMS=300' }, 5613);
    let out = ''; p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (out += d));
    try {
      await sleep(2500);
      const h = await getJson(5613, '/api/health');
      expect(h.status).toBe(200); expect(h.body.db).toBe('disconnected');
      const c = await getJson(5613, '/api/courses');
      expect(c.status).toBe(503);
      expect(out).not.toContain(secret);
    } finally { p.kill('SIGTERM'); await sleep(200); }
  }, 30000);
});

