import * as Sentry from '@sentry/node';

// Mirrors exono/lib/config/sentry_config.dart's pattern: when SENTRY_DSN is
// unset (e.g. local dev), Sentry init is skipped entirely so the app runs
// normally without reporting. enableLogs turns on Sentry.logger.* (structured
// logs) used for cost-instrumentation metrics — see INFRASTRUCTURE_ANALYSIS.md.
export const SENTRY_ENABLED = Boolean(process.env.SENTRY_DSN);

export function initSentry(): void {
  if (!SENTRY_ENABLED) return;
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.SENTRY_ENV || process.env.NODE_ENV || 'development',
    tracesSampleRate: 0,
    enableLogs: true,
  });
}
