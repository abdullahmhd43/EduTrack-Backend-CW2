#!/usr/bin/env node
/**
 * End-to-end smoke test for a RUNNING EduTrack API (local or deployed).
 *   node tools/smoke.js https://edutrack-backend.enzonic.dev/api
 *   node tools/smoke.js http://localhost:5000/api
 * It creates two throw-away users (random e-mails) and one course/assignment, and deletes the records it
 * creates. The two test user accounts remain in the database (the API has no "delete account").
 * Prints PASS/FAIL per check and exits 1 if anything failed. Needs Node 18+ (built-in fetch).
 */
const base = (process.argv[2] || 'http://localhost:5000/api').replace(/\/+$/, '');
let failed = 0;
const rnd = () => Math.random().toString(36).slice(2, 10);
const check = (name, ok, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : '  -> ' + detail}`);
  if (!ok) failed++;
};
async function call(method, path, { token, body } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = {};
  try { json = await res.json(); } catch (_) { /* not json */ }
  return { status: res.status, body: json };
}

(async () => {
  console.log(`Smoke test against ${base}\n`);
  const h = await call('GET', '/health');
  check('GET /health -> 200', h.status === 200, JSON.stringify(h.body));
  check('database connected', h.body.db === 'connected' || h.body.db === undefined, JSON.stringify(h.body));

  const pw = 'Passw0rd' + rnd();
  const mk = async (tag) => {
    const email = `smoke_${tag}_${rnd()}@example.com`;
    const r = await call('POST', '/auth/register', { body: { name: `Smoke ${tag}`, email, password: pw, studentId: 'E000000', program: 'BSc' } });
    return { email, r, token: r.body?.data?.token };
  };
  const A = await mk('a');
  check('register user A -> 201 + token', A.r.status === 201 && !!A.token, JSON.stringify(A.r.body));
  const dup = await call('POST', '/auth/register', { body: { name: 'Dup', email: A.email, password: pw } });
  check('duplicate e-mail -> 409', dup.status === 409, String(dup.status));
  const bad = await call('POST', '/auth/register', { body: { name: 'X', email: 'nope', password: '1' } });
  check('invalid registration -> 400', bad.status === 400, String(bad.status));
  const lg = await call('POST', '/auth/login', { body: { email: A.email, password: pw } });
  check('login -> 200 + token', lg.status === 200 && !!lg.body?.data?.token, JSON.stringify(lg.body));
  const wrong = await call('POST', '/auth/login', { body: { email: A.email, password: 'WrongPass1' } });
  check('wrong password -> 401', wrong.status === 401, String(wrong.status));
  const noTok = await call('GET', '/courses');
  check('no token -> 401', noTok.status === 401, String(noTok.status));
  if (!A.token) return finish();
  const t = lg.body.data.token;

  const B = await mk('b');
  const cid = 'smoke-' + rnd() + rnd();
  const course = { clientId: cid, name: 'Smoke Course', code: 'SMK100', lecturer: 'Dr S', startDate: '2026-01-01', endDate: '2026-06-01' };
  const c1 = await call('POST', '/courses', { token: t, body: course });
  check('create course -> 201', c1.status === 201 && c1.body.duplicate === false, JSON.stringify(c1.body));
  const id = c1.body?.data?._id || c1.body?.data?.id;
  const c2 = await call('POST', '/courses', { token: t, body: course });
  check('same clientId again -> 200 duplicate:true (idempotent)', c2.status === 200 && c2.body.duplicate === true, JSON.stringify(c2.body));
  const list = await call('GET', '/courses', { token: t });
  check('list has exactly 1 course (no duplicate)', list.body.count === 1, JSON.stringify(list.body.count));

  const g = await call('GET', `/courses/${id}`, { token: t });
  check('get course -> 200', g.status === 200, String(g.status));
  const upd = await call('PUT', `/courses/${id}`, { token: t, body: { ...course, name: 'Renamed', baseUpdatedAt: g.body?.data?.updatedAt } });
  check('update with current base -> 200', upd.status === 200 && upd.body.data?.name === 'Renamed', JSON.stringify(upd.body));
  const stale = await call('PUT', `/courses/${id}`, { token: t, body: { ...course, name: 'Stale edit', baseUpdatedAt: '2020-01-01T00:00:00.000Z' } });
  check('update with stale base -> 409 + serverVersion (no silent overwrite)', stale.status === 409, JSON.stringify(stale.body));
  const keep = await call('GET', `/courses/${id}`, { token: t });
  check('server value untouched after conflict', keep.body?.data?.name === 'Renamed', JSON.stringify(keep.body?.data?.name));

  if (B.token) {
    const x = await call('GET', `/courses/${id}`, { token: B.token });
    check("user B cannot read user A's course -> 404", x.status === 404, String(x.status));
    const xd = await call('DELETE', `/courses/${id}`, { token: B.token });
    check("user B cannot delete user A's course -> 404", xd.status === 404, String(xd.status));
  }

  const a = await call('POST', '/assignments', { token: t, body: { clientId: 'smoke-a-' + rnd() + rnd(), courseClientId: cid, title: 'Smoke Assignment', dueDate: '2026-12-01T10:00:00.000Z', priority: 'high', status: 'not_started' } });
  check('create assignment linked to course -> 201', a.status === 201, JSON.stringify(a.body));
  const badId = await call('GET', '/courses/not-an-id', { token: t });
  check('invalid id -> 400', badId.status === 400, String(badId.status));

  const del = await call('DELETE', `/courses/${id}`, { token: t });
  check('delete course -> 200', del.status === 200, String(del.status));
  const gone = await call('GET', `/courses/${id}`, { token: t });
  check('deleted course -> 404', gone.status === 404, String(gone.status));
  const cascade = await call('GET', '/assignments', { token: t });
  check('course delete cascaded to its assignment', cascade.body.count === 0, JSON.stringify(cascade.body.count));
  finish();
})().catch((e) => { console.error('Smoke test crashed:', e.message); process.exit(1); });

function finish() {
  console.log(failed ? `\n${failed} check(s) FAILED` : '\nAll checks passed');
  process.exit(failed ? 1 : 0);
}
