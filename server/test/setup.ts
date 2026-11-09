process.env.NODE_ENV = 'test';
process.env.PGLITE_PATH = 'memory://';
process.env.AUTO_MIGRATE = 'false';
delete process.env.FIREBASE_PROJECT_ID;
process.env.JWT_ACCESS_SECRET = 'test-access-secret-at-least-16-chars';
process.env.JWT_ACCESS_TTL_SECONDS = '900';
process.env.PAYMENT_WEBHOOK_SECRET = 'test-webhook-secret';
process.env.LOG_LEVEL = 'error';
process.env.CORS_ORIGINS = 'http://127.0.0.1:7357';
process.env.MIN_APP_VERSION = '1.0.0';

// The suite seeds demo data. Never let it connect to a developer's real
// Supabase project just because server/.env points there.
process.env.SUPABASE_DB_URL = '';
process.env.SUPABASE_DB_PASSWORD = '';
process.env.SUPABASE_DB_HOST = '';
process.env.SUPABASE_PROJECT_REF = '';
process.env.SUPABASE_URL = '';
process.env.SUPABASE_PUBLISHABLE_KEY = '';
process.env.SUPABASE_SECRET_KEY = '';
