const mongoose = require('mongoose');
const { env, assertEnv } = require('./config/env');
const { connectDb } = require('./config/db');
const { createApp } = require('./app');

// Missing secrets are a configuration error: fail loudly instead of running half-broken.
try {
  assertEnv();
} catch (err) {
  console.error('Failed to start server:', err.message);
  process.exit(1);
}

// Listen first so the hosting platform sees the port open; data routes answer 503 until MongoDB is ready.
const app = createApp({ requireDb: true });
const server = app.listen(env.port, '0.0.0.0', () => {
  console.log(`EduTrack API listening on port ${env.port}`);
});

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Keep trying until Atlas is reachable (mongoose reconnects by itself after the first success). */
async function connectWithRetry() {
  for (;;) {
    try {
      await connectDb();
      console.log('MongoDB connected');
      return;
    } catch (err) {
      console.error('MongoDB connection failed, retrying in 5s:', err.message);
      await sleep(5000);
    }
  }
}
connectWithRetry();

function shutdown() {
  server.close(async () => {
    await mongoose.disconnect().catch(() => {});
    process.exit(0);
  });
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
