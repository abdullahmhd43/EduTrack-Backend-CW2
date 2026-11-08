
const mongoose = require('mongoose');
const Course = require('../models/Course');
const ApiError = require('../utils/ApiError');

const sameValue = (a, b) => {
  if (a instanceof Date || b instanceof Date) {
    const dateA = a == null ? null : new Date(a).getTime();
    const dateB = b == null ? null : new Date(b).getTime();

    return dateA === dateB;
  }

  return (a ?? null) === (b ?? null);
};

/**
 * Checks whether the supplied fields are identical to the stored values.
 * Mongoose setters are applied before comparison so values such as
 * lowercase course codes and whitespace are normalized consistently.
 */
const isNoOp = (doc, data, fields) =>
  fields
    .filter((field) => data[field] !== undefined)
    .every((field) => {
      const schemaPath = doc.schema.path(field);

      const incomingValue = schemaPath
        ? schemaPath.applySetters(data[field], doc)
        : data[field];

      return sameValue(doc.get(field), incomingValue);
    });

function assertObjectId(id) {
  if (!mongoose.isValidObjectId(id)) {
    throw ApiError.badRequest('Invalid id');
  }
}

async function assertCourseExists(userId, courseClientId) {
  const exists = await Course.exists({
    userId,
    clientId: courseClientId,
  });

  if (!exists) {
    throw ApiError.badRequest('Validation failed', {
      errors: [
        {
          field: 'courseClientId',
          message: 'Course does not exist',
        },
      ],
    });
  }
}

async function checkRefs(res, userId, data) {
  if (
    res.requiresCourse ||
    (res.optionalCourse && data.courseClientId)
  ) {
    await assertCourseExists(userId, data.courseClientId);
  }
}

const pick = (obj, fields) =>
  Object.fromEntries(
    fields
      .filter((field) => obj[field] !== undefined)
      .map((field) => [field, obj[field]])
  );

async function list(res, userId, { updatedSince } = {}) {
  const filter = { userId };

  if (updatedSince && !Number.isNaN(Date.parse(updatedSince))) {
    filter.updatedAt = {
      $gt: new Date(updatedSince),
    };
  }

  return res.Model.find(filter).sort({ updatedAt: -1 });
}

async function getOne(res, userId, id) {
  assertObjectId(id);

  const doc = await res.Model.findOne({
    _id: id,
    userId,
  });

  if (!doc) {
    throw ApiError.notFound(`${res.path} record not found`);
  }

  return doc;
}

/**
 * Idempotent create:
 * Same userId + clientId returns the existing record.
 */
async function create(res, userId, body) {
  const existing = await res.Model.findOne({
    userId,
    clientId: body.clientId,
  });

  if (existing) {
    return {
      doc: existing,
      created: false,
    };
  }

  await checkRefs(res, userId, body);

  try {
    const doc = await res.Model.create({
      userId,
      clientId: body.clientId,
      ...pick(body, res.fields),
    });

    return {
      doc,
      created: true,
    };
  } catch (error) {
    if (error.code === 11000) {
      const doc = await res.Model.findOne({
        userId,
        clientId: body.clientId,
      });

      if (doc) {
        return {
          doc,
          created: false,
        };
      }
    }

    throw error;
  }
}

/**
 * Update with optimistic concurrency.
 *
 * - A stale baseUpdatedAt returns 409.
 * - force:true allows the user to keep their version.
 * - An identical retry is a no-op.
 */
async function update(res, userId, id, body) {
  const doc = await getOne(res, userId, id);

  const {
    baseUpdatedAt,
    force,
    ...data
  } = body;

  // Check idempotency before stale-version conflict.
  if (isNoOp(doc, data, res.fields)) {
    return doc;
  }

  if (
    !force &&
    baseUpdatedAt &&
    doc.updatedAt.getTime() > new Date(baseUpdatedAt).getTime()
  ) {
    throw ApiError.conflict(
      'Record was modified on the server after your last sync',
      {
        serverVersion: doc.toJSON(),
      }
    );
  }

  await checkRefs(res, userId, data);

  Object.assign(doc, pick(data, res.fields));

  await doc.save();

  return doc;
}

async function remove(res, userId, id) {
  const doc = await getOne(res, userId, id);

  if (res.cascade) {
    await Promise.all(
      res.cascade.map((Model) =>
        Model.deleteMany({
          userId,
          courseClientId: doc.clientId,
        })
      )
    );
  }

  await doc.deleteOne();
}

module.exports = {
  list,
  getOne,
  create,
  update,
  remove,
  isNoOp,
};
