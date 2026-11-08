/**
 * Security / robustness tests that need NO database.
 * (JWT edge cases, password hashing, sensitive-field exposure, CORS, body-size limit, 429 rate limit.)
 */
process.env.NODE_ENV = 'test';
jest.mock('../../src/models/User');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const User = require('../../src/models/User');
const { createApp } = require('../../src/app');
const { signToken } = require('../../src/utils/token');
const { env } = require('../../src/config/env');

const app = createApp();
const uid = '64b000000000000000000001';
beforeEach(() => { User.findById.mockResolvedValue({ _id: uid, name: 'T' }); User.exists.mockResolvedValue(null); });

describe('JWT handling', () => {
  const get = (token) => request(app).get('/api/courses').set('Authorization', `Bearer ${token}`);
  test('expired token -> 401', async () => {
    const t = jwt.sign({ sub: uid }, env.jwtSecret, { expiresIn: -10 });
    const r = await get(t); expect(r.status).toBe(401); expect(r.body.success).toBe(false);
  });
  test('token signed with another secret -> 401', async () => {
    expect((await get(jwt.sign({ sub: uid }, 'some-other-secret-value-123456'))).status).toBe(401);
  });
  test('unsigned "alg: none" token -> 401', async () => {
    const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
    expect((await get(`${b64({ alg: 'none', typ: 'JWT' })}.${b64({ sub: uid })}.`)).status).toBe(401);
  });
  test('HS512 token with the right secret but wrong algorithm is rejected (algorithm pinned to HS256)', async () => {
    expect((await get(jwt.sign({ sub: uid }, env.jwtSecret, { algorithm: 'HS512' }))).status).toBe(401);
  });
  test('wrong scheme (Basic) -> 401', async () => {
    expect((await request(app).get('/api/courses').set('Authorization', 'Basic abc')).status).toBe(401);
  });
  test('valid token is accepted past the auth middleware (reaches the 503/DB layer, not 401)', async () => {
    const r = await request(createApp({ requireDb: true })).get('/api/courses').set('Authorization', `Bearer ${signToken(uid)}`);
    expect(r.status).toBe(503); // authenticated, but DB is down in unit tests
  });
});

describe('password handling', () => {
  test('register stores a bcrypt hash, never the plain password, and never returns it', async () => {
    let saved;
    User.create.mockImplementation(async (doc) => { saved = doc; return new (jest.requireActual('../../src/models/User'))({ ...doc }); });
    const plain = 'Passw0rdTest1';
    const r = await request(app).post('/api/auth/register').send({ name: 'Test User', email: 'a@b.co', password: plain });
    expect(r.status).toBe(201);
    expect(saved.passwordHash).toMatch(/^\$2[aby]\$\d{2}\$/);   // bcrypt format
    expect(saved.passwordHash).not.toContain(plain);
    expect(await bcrypt.compare(plain, saved.passwordHash)).toBe(true);
    expect(saved.password).toBeUndefined();                       // plain text never passed to the model
    expect(JSON.stringify(r.body)).not.toMatch(/passwordHash|Passw0rdTest1/);
  });
  test('duplicate e-mail -> 409', async () => {
    User.exists.mockResolvedValue({ _id: 'x' });
    const r = await request(app).post('/api/auth/register').send({ name: 'Test User', email: 'a@b.co', password: 'Passw0rdTest1' });
    expect(r.status).toBe(409);
  });
  test('login with unknown e-mail and with wrong password give the same 401 message', async () => {
    User.findOne.mockReturnValue({ select: async () => null });
    const a = await request(app).post('/api/auth/login').send({ email: 'no@one.co', password: 'Whatever1' });
    const hash = await bcrypt.hash('Right1234', 4);
    User.findOne.mockReturnValue({ select: async () => ({ _id: uid, passwordHash: hash }) });
    const b = await request(app).post('/api/auth/login').send({ email: 'a@b.co', password: 'Wrong12345' });
    expect(a.status).toBe(401); expect(b.status).toBe(401);
    expect(a.body.message).toBe(b.body.message);
  });
  test('login ok returns a token and the user JSON has no passwordHash', async () => {
    const Real = jest.requireActual('../../src/models/User');
    const hash = await bcrypt.hash('Right1234', 4);
    const doc = new Real({ name: 'T', email: 'a@b.co', passwordHash: hash });
    User.findOne.mockReturnValue({ select: async () => doc });
    const r = await request(app).post('/api/auth/login').send({ email: 'a@b.co', password: 'Right1234' });
    expect(r.status).toBe(200); expect(r.body.data.token).toBeTruthy();
    expect(JSON.stringify(r.body)).not.toContain(hash);
  });
  test('NoSQL-injection style login body (object instead of string) -> 400', async () => {
    const r = await request(app).post('/api/auth/login').send({ email: { $gt: '' }, password: { $gt: '' } });
    expect(r.status).toBe(400);
  });
});

describe('HTTP hardening', () => {
  test('helmet security headers present', async () => {
    const r = await request(app).get('/api/health');
    expect(r.headers['x-content-type-options']).toBe('nosniff');
    expect(r.headers['x-powered-by']).toBeUndefined();
  });
  test('CORS: default allows cross-origin reads', async () => {
    const r = await request(app).get('/api/health').set('Origin', 'http://example.com');
    expect(r.headers['access-control-allow-origin']).toBe('*');
  });
  test('request body over 1 MB -> 413 JSON error', async () => {
    const big = { name: 'x'.repeat(1.2 * 1024 * 1024), email: 'a@b.co', password: 'Passw0rd1' };
    const r = await request(app).post('/api/auth/register').send(big);
    expect(r.status).toBe(413); expect(r.body.success).toBe(false);
  });
  test('?updatedSince as an object (injection attempt) is ignored, not executed', async () => {
    const r = await request(createApp({ requireDb: true })).get('/api/courses?updatedSince[$gt]=x').set('Authorization', `Bearer ${signToken(uid)}`);
    expect([200, 400, 503]).toContain(r.status); // never a 500
  });
});

describe('zod advisory GHSA-mrhx-c7xc-m3w5 (unbounded array validation) - exposure check', () => {
  test('no validation schema uses z.array (the only affected schema type); re-check if one is ever added', () => {
    const fs = require('fs'); const path = require('path');
    const src = fs.readFileSync(path.join(__dirname, '../../src/validators/schemas.js'), 'utf8');
    expect(src).not.toMatch(/z\.array\(|z\.set\(|z\.tuple\(/);
  });
  test('a ~0.9 MB array sent where a string is expected is rejected fast with 400', async () => {
    const huge = { name: Array.from({ length: 150000 }, (_, i) => i), email: 'a@b.co', password: 'Passw0rd1' };
    const t0 = Date.now();
    const r = await request(app).post('/api/auth/register').send(huge);
    expect(r.status).toBe(400);
    expect(Date.now() - t0).toBeLessThan(2000);
  });
});

describe('rate limiting (auth routes) - enabled outside the test environment', () => {
  test('101st login attempt within the window -> 429', async () => {
    jest.resetModules();
    process.env.NODE_ENV = 'development';
    process.env.JWT_SECRET = 'a-long-enough-test-secret-value-1234';
    jest.doMock('../../src/models/User');
    const { createApp: make } = require('../../src/app');
    const silent = jest.spyOn(console, 'log').mockImplementation(() => {});
    const a = make();
    let last;
    for (let i = 0; i < 101; i++) last = await request(a).post('/api/auth/login').send({});
    silent.mockRestore();
    process.env.NODE_ENV = 'test';
    expect(last.status).toBe(429);
    expect(last.body.success).toBe(false);
  }, 60000);
});
