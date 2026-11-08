/**
 * Contract test: request bodies built exactly like the Flutter app builds them
 * (frontend/lib/services/database/entity_spec.dart toApiBody + models' fields()) must be
 * accepted by the backend's real zod schemas, for both create (POST) and update (PUT).
 * This does not replace a live run of the two together, but it catches field-name/format mismatches.
 */
process.env.NODE_ENV = 'test';
const schemas = require('../../src/validators/schemas');

const clientId = '3f2b8c1e-9d4a-4e6b-8f10-2a7c5d9e1b34'; // UUID v4 like the app's localId
const base = '2026-11-07T10:15:30.123Z'; // server updatedAt the app sends back as baseUpdatedAt
const courseId = '7a1d9e52-0c3b-4f68-b2a4-91e5d3c8f001';

const bodies = {
  course: {
    name: 'Mobile Application Development', code: 'CI6330', lecturer: 'Ms. Deshani', description: '',
    startDate: '2025-12-31T18:30:00.000Z', endDate: '2026-05-31T18:30:00.000Z', // DateTime.toUtc().toIso8601String()
  },
  assignment: [
    { courseClientId: courseId, title: 'Coursework 2', description: '', dueDate: '2026-12-01T04:30:00.000Z', priority: 'high', status: 'not_started' },
    { courseClientId: courseId, title: 'Quiz', description: 'x', dueDate: '2026-12-01T04:30:00.000Z', priority: 'low', status: 'in_progress' },
    { courseClientId: courseId, title: 'Done', description: '', dueDate: '2026-12-01T04:30:00.000Z', priority: 'medium', status: 'completed' },
  ],
  studySession: { courseClientId: courseId, topic: 'Provider', date: '2026-11-09', startTime: '09:00', endTime: '10:30', description: '', completed: false },
  note: [
    { courseClientId: courseId, title: 'Lecture 1', content: 'Widgets are immutable' },
    { courseClientId: null, title: 'No course', content: 'General note' }, // note without a course
  ],
  event: [
    { title: 'Final exam', type: 'exam', date: '2026-12-15', startTime: '09:00', endTime: '', location: '', description: '' }, // endTime empty
    { title: 'Lecture', type: 'class', date: '2026-11-10', startTime: '08:30', endTime: '10:00', location: 'Room 4', description: '' },
    { title: 'Open day', type: 'event', date: '2026-11-11', startTime: '10:00', endTime: '', location: 'Hall', description: 'x' },
  ],
};
const asList = (v) => (Array.isArray(v) ? v : [v]);

describe.each(Object.keys(bodies))('app request body for %s matches the API schema', (name) => {
  test.each(asList(bodies[name]).map((b, i) => [i, b]))('sample %i: POST create (with clientId) is accepted', (_i, body) => {
    const r = schemas[name].create.safeParse({ ...body, clientId });
    expect(r.success).toBe(true);
    if (!r.success) console.log(JSON.stringify(r.error.issues));
  });
  test.each(asList(bodies[name]).map((b, i) => [i, b]))('sample %i: PUT update (with baseUpdatedAt) is accepted', (_i, body) => {
    const r = schemas[name].update.safeParse({ ...body, baseUpdatedAt: base });
    expect(r.success).toBe(true);
    if (!r.success) console.log(JSON.stringify(r.error.issues));
  });
});

test('the app never sends the derived "overdue" status (it maps to not_started)', () => {
  const bad = schemas.assignment.create.safeParse({ ...bodies.assignment[0], status: 'overdue', clientId });
  expect(bad.success).toBe(false); // so the app must (and does) map overdue -> not_started
});
