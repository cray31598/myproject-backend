/**
 * Backend configuration.
 * Override with environment variables (e.g. .env or shell).
 */
const config = {
  port: Number(process.env.PORT) || 3000,

  database: {
    /** On Vercel, use /tmp (only writable dir). Data is ephemeral. For persistence use DATABASE_PATH with external storage. */
    path: (() => {
      const v = process.env.DATABASE_PATH;
      if (v && v.startsWith('/')) return v;
      if (process.env.VERCEL || process.env.VERCEL_ENV) return '/tmp/app.db';
      return v || './data/app.db';
    })(),
    /** Enable WAL mode for better concurrent read performance */
    wal: process.env.DATABASE_WAL !== 'false',
  },
};

export default config;
