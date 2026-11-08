// Runs a fixed corpus of inputs through every API schema and prints a JSON snapshot.
// Usage: node validation_snapshot.js <path-to-backend/src/validators/schemas.js>  > snapshot.json
const schemas = require(process.argv[2]);
const clientId = '3f2b8c1e-9d4a-4e6b-8f10-2a7c5d9e1b34';
const cid = '7a1d9e52-0c3b-4f68-b2a4-91e5d3c8f001';
const base = {
  registerSchema: { name: 'Test User', email: 'a@b.co', password: 'Passw0rd1', studentId: 'E186364', program: 'BSc' },
  loginSchema: { email: 'a@b.co', password: 'x' },
  profileSchema: { name: 'Test User', studentId: 'E1', program: 'BSc' },
  'course.create': { clientId, name: 'MAD', code: 'CI6330', lecturer: 'Dr X', description: '', startDate: '2026-01-01T00:00:00.000Z', endDate: '2026-06-01T00:00:00.000Z' },
  'assignment.create': { clientId, courseClientId: cid, title: 'CW2', description: '', dueDate: '2026-12-01T04:30:00.000Z', priority: 'high', status: 'in_progress' },
  'studySession.create': { clientId, courseClientId: cid, topic: 'Provider', date: '2026-11-09', startTime: '09:00', endTime: '10:30', description: '', completed: false },
  'note.create': { clientId, courseClientId: cid, title: 'L1', content: 'text' },
  'event.create': { clientId, title: 'Exam', type: 'exam', date: '2026-12-15', startTime: '09:00', endTime: '', location: 'Hall', description: '' },
};
// update variants share the same bodies without clientId + extras
for (const k of ['course', 'assignment', 'studySession', 'note', 'event']) {
  const b = { ...base[`${k}.create`] }; delete b.clientId;
  base[`${k}.update`] = { ...b, baseUpdatedAt: '2026-11-07T10:15:30.123Z', force: false };
}
const get = (name) => (name.includes('.') ? name.split('.').reduce((o, p) => o[p], schemas) : schemas[name]);

const weird = [undefined, null, 0, 1, -1, 1.5, true, false, '', ' ', '   x   ', 'x'.repeat(10001), [], [1], {}, { a: 1 }, 'NaN', '2026-13-45', '9999-99-99', '24:00', '9:00', '09:60'];
const emails = ['a@b.co', ' A@B.CO ', 'user+tag@example.com', 'a@b', 'a b@c.co', 'user@localhost', 'a@b..co', '.a@b.co', 'a.@b.co', 'a@-b.co', 'üser@example.com', 'a@example.c', 'a@' + 'x'.repeat(60) + '.com', 'x'.repeat(115) + '@a.co', '', 'plainaddress', '@b.co', 'a@b.co.', 'a@[127.0.0.1]', "o'brien@example.com"];
const passwords = ['', 'short1', 'Passw0r', 'Passw0rd', 'passwordonly', '12345678', 'Abcdefg1', 'A'.repeat(71) + '1', 'A'.repeat(72) + '1', 'пароль123a', ' Passw0rd1 ', 'Passw0rd1\n'];

const out = {};
const run = (label, schema, input) => {
  const r = schema.safeParse(input);
  out[label] = r.success
    ? { ok: true, data: r.data }
    : { ok: false, errors: r.error.issues.map((i) => ({ field: i.path.join('.') || 'body', message: i.message })) };
};
for (const name of Object.keys(base)) {
  const schema = get(name); const b = base[name];
  run(`${name} | valid base`, schema, b);
  run(`${name} | not an object (string)`, schema, 'x');
  run(`${name} | not an object (null)`, schema, null);
  run(`${name} | empty object`, schema, {});
  run(`${name} | extra unknown key`, schema, { ...b, hacker: 1 });
  run(`${name} | extra key __proto__`, schema, JSON.parse(JSON.stringify(b).replace(/^\{/, '{"__proto__":{"x":1},')));
  for (const f of Object.keys(b)) {
    run(`${name} | missing ${f}`, schema, Object.fromEntries(Object.entries(b).filter(([k]) => k !== f)));
    weird.forEach((w, i) => run(`${name} | ${f} = weird#${i} ${JSON.stringify(w)?.slice(0, 20)}`, schema, { ...b, [f]: w }));
  }
}
emails.forEach((e) => { run(`registerSchema | email ${JSON.stringify(e).slice(0, 40)}`, schemas.registerSchema, { ...base.registerSchema, email: e }); run(`loginSchema | email ${JSON.stringify(e).slice(0, 40)}`, schemas.loginSchema, { ...base.loginSchema, email: e }); });
passwords.forEach((p) => run(`registerSchema | password ${JSON.stringify(p).slice(0, 30)}`, schemas.registerSchema, { ...base.registerSchema, password: p }));
// cross-field rules and enums
run('course | end before start', schemas.course.create, { ...base['course.create'], endDate: '2025-01-01T00:00:00.000Z' });
run('course | end equals start', schemas.course.create, { ...base['course.create'], endDate: base['course.create'].startDate });
run('study | end equals start', schemas['studySession'].create, { ...base['studySession.create'], endTime: '09:00' });
run('study | end before start', schemas['studySession'].create, { ...base['studySession.create'], endTime: '08:00' });
run('event | endTime before start', schemas.event.create, { ...base['event.create'], endTime: '08:00' });
run('event | endTime after start', schemas.event.create, { ...base['event.create'], endTime: '10:00' });
for (const v of ['low', 'medium', 'high', 'urgent', 'HIGH', 'overdue']) run(`assignment | priority ${v}`, schemas.assignment.create, { ...base['assignment.create'], priority: v });
for (const v of ['not_started', 'in_progress', 'completed', 'overdue', 'done', 'Completed']) run(`assignment | status ${v}`, schemas.assignment.create, { ...base['assignment.create'], status: v });
for (const v of ['exam', 'class', 'event', 'lecture', 'EXAM']) run(`event | type ${v}`, schemas.event.create, { ...base['event.create'], type: v });
// defaults
run('course | defaults applied', schemas.course.create, { clientId, name: 'A', code: 'B', startDate: '2026-01-01', endDate: '2026-02-01' });
run('assignment | defaults applied', schemas.assignment.create, { clientId, courseClientId: cid, title: 'T', dueDate: '2026-12-01' });
run('note | null course default', schemas.note.create, { clientId, title: 'T', content: 'C' });
run('note | explicit null course', schemas.note.create, { clientId, title: 'T', content: 'C', courseClientId: null });
run('event | defaults applied', schemas.event.create, { clientId, title: 'T', date: '2026-12-01', startTime: '09:00' });
run('study | completed default', schemas.studySession.create, { clientId, courseClientId: cid, topic: 'T', date: '2026-12-01', startTime: '09:00', endTime: '10:00' });
// trimming / whitespace-only required text
run('course | name whitespace only', schemas.course.create, { ...base['course.create'], name: '    ' });
run('note | content whitespace only', schemas.note.create, { ...base['note.create'], content: '   \n  ' });
// force / baseUpdatedAt types
for (const v of [true, false, 'true', 1, null]) run(`course.update | force ${JSON.stringify(v)}`, schemas.course.update, { ...base['course.update'], force: v });
for (const v of ['2026-11-07T10:15:30.123Z', '2026-11-07', 'garbage', '', 123]) run(`course.update | baseUpdatedAt ${JSON.stringify(v)}`, schemas.course.update, { ...base['course.update'], baseUpdatedAt: v });
process.stdout.write(JSON.stringify(out, null, 1));
