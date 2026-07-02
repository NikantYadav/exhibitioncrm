import * as Sentry from '@sentry/node';

// Mirrors exono/lib/config/sentry_config.dart's pattern: when SENTRY_DSN is
// unset (e.g. local dev), Sentry init is skipped entirely so the app runs
// normally without reporting. enableLogs turns on Sentry.logger.* (structured
// logs) used for cost-instrumentation metrics — see INFRASTRUCTURE_ANALYSIS.md.
//
// Evaluated as a function (NOT a module-load-time const): ES import hoisting can
// evaluate this module before instrument.ts calls dotenv.config(), so a const
// would freeze to `false` before SENTRY_DSN is loaded and silently disable
// Sentry. Reading process.env at call time avoids that ordering trap.
export function isSentryEnabled(): boolean {
  return Boolean(process.env.SENTRY_DSN);
}

export function initSentry(): void {
  if (!isSentryEnabled()) return;
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.SENTRY_ENV || process.env.NODE_ENV || 'development',
    tracesSampleRate: 0,
    enableLogs: true,
  });
}

// Emit a Sentry structured log (Sentry.logger.info). Structured logs are BATCHED
// by the SDK (sent when the buffer hits 100 entries or on an idle timer) — this
// is the efficient default, so we do NOT force a per-log flush here.
//
// When Sentry is disabled (no DSN, e.g. local dev) we skip Sentry entirely and
// print the payload so the instrumentation stays observable with no DSN.
export function sentryLog(
  name: string,
  attributes: Record<string, unknown>,
): void {
  if (!isSentryEnabled()) {
    console.log(`[sentry] DISABLED (no DSN) — would log "${name}":`, attributes);
    return;
  }
  Sentry.logger.info(name, attributes);
}
