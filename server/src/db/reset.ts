import { closeDb, db, initDb } from './index.js';

/**
 * Development-only destructive reset. Requires CONFIRM_DB_RESET=yes and refuses
 * to run in production.
 */
async function reset() {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Refusing to reset a production database.');
  }
  if (process.env.CONFIRM_DB_RESET !== 'yes') {
    throw new Error('Set CONFIRM_DB_RESET=yes to drop and recreate the development schema.');
  }
  await initDb();
  await db().exec('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
  // eslint-disable-next-line no-console
  console.log('[reset] development schema recreated. Run db:migrate and db:seed next.');
  await closeDb();
}

const isEntrypoint = process.argv[1] && /reset\.(ts|js)$/.test(process.argv[1]);
if (isEntrypoint) {
  reset().catch(async (error) => {
    // eslint-disable-next-line no-console
    console.error('[reset] failed:', error);
    await closeDb().catch(() => undefined);
    process.exit(1);
  });
}
