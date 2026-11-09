import { createServer } from 'node:http';
import { config } from './config.js';
import { closeDb, databaseBackend, db, initDb } from './db/index.js';
import { migrate } from './db/migrate.js';
import { createApp } from './http/app.js';
import { initCache, closeCache } from './lib/cache.js';
import { logger } from './lib/logger.js';
import { hub } from './realtime.js';

async function main() {
  await initDb();
  await initCache();
  if (config.AUTO_MIGRATE) {
    const applied = await migrate();
    logger.info({ applied }, 'database migrations checked');
  }

  const app = createApp();
  const server = createServer(app);
  hub.attach(server);

  // Blueprint reliability rule: never wait forever on an incoming request.
  server.headersTimeout = 10_000;
  server.requestTimeout = 30_000;
  server.keepAliveTimeout = 5_000;

  // Hourly purge: idempotency answers live 24 h, expired sessions linger 7
  // days so refresh-reuse detection can still see recently revoked tokens.
  const cleanup = setInterval(() => {
    void (async () => {
      try {
        await db().query(
          `DELETE FROM idempotency_keys WHERE created_at < now() - interval '24 hours'`,
        );
        await db().query(
          `DELETE FROM sessions WHERE expires_at < now() - interval '7 days'`,
        );
      } catch (error) {
        logger.warn({ err: error }, 'periodic cleanup failed');
      }
    })();
  }, 60 * 60 * 1000);
  cleanup.unref();

  server.listen(config.PORT, () => {
    logger.info(
      {
        port: config.PORT,
        env: config.NODE_ENV,
        database: databaseBackend().toLowerCase(),
      },
      'Kalla-Lai API listening',
    );
  });

  const shutdown = async (signal: string) => {
    logger.info({ signal }, 'shutting down');
    clearInterval(cleanup);
    hub.close();
    server.close(async () => {
      await closeCache().catch(() => undefined);
      await closeDb().catch((error) => logger.error({ err: error }, 'database close failed'));
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
  process.on('unhandledRejection', (reason) => logger.error({ err: reason }, 'unhandled rejection'));
  process.on('uncaughtException', (error) => {
    logger.fatal({ err: error }, 'uncaught exception');
    process.exit(1);
  });
}

main().catch((error) => {
  logger.fatal({ err: error }, 'failed to start API');
  process.exit(1);
});
