// Sentry initialization — MUST run before any other import so the SDK can
// instrument http/express/etc. at require-time (per Sentry's setup guide).
// This file is imported as the very first line of server.ts; keep it that way.
// dotenv is loaded here (not in server.ts) so SENTRY_DSN / SENTRY_ENV are
// available before initSentry() reads them.
import dns from 'dns';
import dotenv from 'dotenv';
import { initSentry } from './config/sentry';

// Prefer IPv4 when resolving hostnames. On hosts whose DNS returns an
// unroutable IPv6 address for the Sentry ingest endpoint (ENETUNREACH), Node
// would try IPv6 first and the Sentry transport would ETIMEDOUT — so events
// were captured but silently never delivered. Forcing IPv4-first makes the
// transport connect on the working address. Must run before Sentry.init.
dns.setDefaultResultOrder('ipv4first');

dotenv.config();
initSentry();
