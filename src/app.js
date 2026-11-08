const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const mongoose = require('mongoose');
const { env } = require('./config/env');
const resources = require('./resources');
const resourceRoutes = require('./routes/resource.routes');
const { notFound, errorHandler } = require('./middleware/error');

/** requireDb: answer 503 while MongoDB is not connected (used by server.js; off in unit tests). */
function createApp({ requireDb = false } = {}) {
  const app = express();
  // Behind a reverse proxy (Enzonic) the real client IP comes from X-Forwarded-For; needed for rate limiting.
  app.set('trust proxy', env.trustProxy);
  app.use(helmet());
  app.use(cors({ origin: env.corsOrigin }));
  app.use(express.json({ limit: '1mb' }));
  if (!env.isTest) app.use(morgan('dev'));

  // Lightweight reachability probe used by the Flutter app (internet != server reachable).
  app.get('/api/health', (_req, res) => {
    const db = mongoose.connection.readyState === 1 ? 'connected' : 'disconnected';
    // 200 = API process is up; the app uses "db" to know whether data requests can succeed.
    res.json({ success: true, status: 'ok', db, time: new Date().toISOString() });
  });

  if (requireDb) {
    app.use('/api', (_req, res, next) => {
      if (mongoose.connection.readyState === 1) return next();
      return res.status(503).json({ success: false, message: 'Service temporarily unavailable. Please try again shortly.' });
    });
  }

  app.use('/api/auth', require('./routes/auth.routes'));
  app.use('/api/users', require('./routes/user.routes'));
  resources.forEach((r) => app.use(`/api/${r.path}`, resourceRoutes(r)));

  app.use(notFound);
  app.use(errorHandler);
  return app;
}

module.exports = { createApp };
