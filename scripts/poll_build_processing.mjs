#!/usr/bin/env node
/**
 * Poll App Store Connect for build processing state with fresh JWT per request.
 *
 * Replaces the broken wait-for-processing inside upload-testflight-build@v5
 * which reuses a single 600s JWT across a >10min polling loop.
 *
 * Required env:
 *   APPSTORE_ISSUER_ID
 *   APPSTORE_API_KEY_ID
 *   APPSTORE_API_PRIVATE_KEY  (raw .p8 PEM contents, never logged)
 *   APP_BUNDLE_ID
 *   BUILD_NUMBER  (CFBundleVersion, must match github.run_number used for archive)
 *
 * Logs: bundleId, buildNumber, attempt, elapsed, processingState, HTTP status.
 * Never logs JWT or private key.
 */

import { createSign } from 'node:crypto';

const API_BASE = 'https://api.appstoreconnect.apple.com';

// 30 minutes maximum, matching Apple processing expectations (>10 min normal)
const MAX_WAIT_MS = 30 * 60 * 1000;
const INITIAL_INTERVAL_MS = 30_000;
const MAX_INTERVAL_MS = 60_000;

function requireEnv(name) {
  const v = process.env[name];
  if (!v || v.trim() === '') {
    console.error(`Missing required env ${name}`);
    process.exit(1);
  }
  return v;
}

function generateJwt(issuerId, apiKeyId, privateKey) {
  const header = { alg: 'ES256', kid: apiKeyId, typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: issuerId,
    aud: 'appstoreconnect-v1',
    iat: now - 60,
    exp: now + 600,
  };
  const encodedHeader = Buffer.from(JSON.stringify(header)).toString('base64url');
  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signer = createSign('SHA256');
  signer.update(signingInput);
  signer.end();
  // Node needs to convert DER to IEEE-P1363 for ES256 JWT; use dsaEncoding
  const signature = signer.sign({ key: privateKey, dsaEncoding: 'ieee-p1363' });
  const encodedSignature = Buffer.from(signature).toString('base64url');
  return `${signingInput}.${encodedSignature}`;
}

async function fetchWithFreshJwt(path, issuerId, apiKeyId, privateKey, { method = 'GET', body = undefined, attempt = 1 } = {}) {
  // Generate fresh JWT for EVERY request per requirements
  const token = generateJwt(issuerId, apiKeyId, privateKey);
  const url = `${API_BASE}${path}`;
  const headers = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
  const res = await fetch(url, { method, headers, body: body ? JSON.stringify(body) : undefined });
  return res;
}

async function fetchJsonWithRetry(path, issuerId, apiKeyId, privateKey, errorContext, { method = 'GET', body = undefined } = {}) {
  const max401Retries = 2;
  const maxTransientRetries = 3;
  let attempt401 = 0;
  let attemptTransient = 0;

  while (true) {
    const res = await fetchWithFreshJwt(path, issuerId, apiKeyId, privateKey, { method, body });
    const status = res.status;

    // Success
    if (res.ok) {
      const text = await res.text();
      if (!text) return {};
      try {
        return JSON.parse(text);
      } catch {
        return {};
      }
    }

    // 401 → generate fresh JWT and retry bounded
    if (status === 401) {
      attempt401++;
      if (attempt401 > max401Retries) {
        const bodyText = await res.text().catch(() => '');
        console.error(`[${errorContext}] 401 NOT_AUTHORIZED after ${attempt401} retries with fresh JWT.`);
        console.error(`[${errorContext}] Response: ${bodyText.slice(0, 500)}`);
        console.error(`[${errorContext}] Check: vars.APPSTORE_ISSUER_ID, vars.APPSTORE_API_KEY_ID, secrets.APPSTORE_API_PRIVATE_KEY pairing and that the key is Active + App Manager in App Store Connect.`);
        const err = new Error(`${errorContext} 401 after retries`);
        err.code = 'AUTH_401';
        throw err;
      }
      console.warn(`[${errorContext}] 401, generating fresh JWT and retrying (${attempt401}/${max401Retries})...`);
      await sleep(2000);
      continue;
    }

    // Transient
    if ([429, 500, 502, 503, 504].includes(status)) {
      attemptTransient++;
      if (attemptTransient > maxTransientRetries) {
        const bodyText = await res.text().catch(() => '');
        throw new Error(`${errorContext} transient ${status} after ${attemptTransient} retries: ${bodyText.slice(0,500)}`);
      }
      const backoff = Math.min(5000 * attemptTransient, 15000);
      console.warn(`[${errorContext}] transient ${status}, retry ${attemptTransient}/${maxTransientRetries} in ${backoff}ms`);
      await sleep(backoff);
      continue;
    }

    const bodyText = await res.text().catch(() => '');
    throw new Error(`${errorContext} failed ${status}: ${bodyText.slice(0,1000)}`);
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function lookupAppId(bundleId, issuerId, apiKeyId, privateKey) {
  const path = `/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`;
  console.log(`Resolving app ID for bundleId=${bundleId}...`);
  const res = await fetchJsonWithRetry(path, issuerId, apiKeyId, privateKey, 'lookupAppId');
  const id = res.data?.[0]?.id;
  if (!id) {
    throw new Error(`App not found for bundleId=${bundleId}. Ensure app record exists in App Store Connect.`);
  }
  console.log(`Resolved appId=${id} for bundleId=${bundleId}`);
  return id;
}

async function lookupBuild(appId, buildNumber, issuerId, apiKeyId, privateKey) {
  const query = new URLSearchParams();
  query.set('filter[app]', appId);
  query.set('filter[version]', String(buildNumber));
  query.set('filter[preReleaseVersion.platform]', 'IOS');
  const path = `/v1/builds?${query.toString()}`;
  const res = await fetchJsonWithRetry(path, issuerId, apiKeyId, privateKey, 'lookupBuild');
  const build = res.data?.[0];
  if (!build) return null;
  return build;
}

async function fetchBuildDetail(buildId, issuerId, apiKeyId, privateKey) {
  try {
    const res = await fetchJsonWithRetry(`/v1/builds/${buildId}`, issuerId, apiKeyId, privateKey, 'fetchBuildDetail');
    return res.data;
  } catch (e) {
    console.warn(`Failed to fetch build detail for ${buildId}: ${e.message}`);
    return null;
  }
}

async function main() {
  const issuerId = requireEnv('APPSTORE_ISSUER_ID');
  const apiKeyId = requireEnv('APPSTORE_API_KEY_ID');
  const privateKey = requireEnv('APPSTORE_API_PRIVATE_KEY');
  const bundleId = requireEnv('APP_BUNDLE_ID');
  const buildNumber = requireEnv('BUILD_NUMBER');

  // Validate JWT generation without logging secrets
  try {
    const testJwt = generateJwt(issuerId, apiKeyId, privateKey);
    const parts = testJwt.split('.');
    if (parts.length !== 3) throw new Error('JWT does not have 3 parts');
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    const ttl = payload.exp - payload.iat;
    if (ttl !== 660) {
      console.warn(`JWT ttl is ${ttl} (expected 660 = 600+60 skew) — still within Apple's 1200 cap`);
    }
    // Verify kid
    const header = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
    if (header.kid !== apiKeyId || header.alg !== 'ES256') {
      console.error('JWT header mismatch');
      process.exit(1);
    }
    console.log(`JWT generation validated (kid=${apiKeyId}, iss=${issuerId.slice(0,8)}..., ttl=${ttl}s, aud=${payload.aud}) — fresh token per request enabled`);
  } catch (e) {
    console.error(`JWT generation failed: ${e.message}`);
    console.error('Check that APPSTORE_API_PRIVATE_KEY is a raw .p8 PEM file and not base64-wrapped.');
    process.exit(1);
  }

  console.log(`Polling for build processing: bundleId=${bundleId} buildNumber=${buildNumber} platform=IOS`);
  console.log(`Max wait: ${Math.round(MAX_WAIT_MS/60000)} min, interval ${INITIAL_INTERVAL_MS/1000}-${MAX_INTERVAL_MS/1000}s, fresh JWT per request`);

  const start = Date.now();
  let appId;
  try {
    appId = await lookupAppId(bundleId, issuerId, apiKeyId, privateKey);
  } catch (e) {
    console.error(`Failed to resolve app ID: ${e.message}`);
    process.exit(1);
  }

  let attempt = 0;
  let interval = INITIAL_INTERVAL_MS;

  // Initial grace period: Apple needs ~60s after upload before build is visible
  console.log('Waiting 60s initial grace before first poll...');
  await sleep(60_000);

  while (Date.now() - start < MAX_WAIT_MS) {
    attempt++;
    const elapsedSec = Math.round((Date.now() - start) / 1000);
    console.log(`\n[Attempt ${attempt}] elapsed=${elapsedSec}s bundleId=${bundleId} version=${buildNumber}`);

    let build;
    try {
      build = await lookupBuild(appId, buildNumber, issuerId, apiKeyId, privateKey);
    } catch (e) {
      if (e.code === 'AUTH_401') {
        console.error('❌ Persistent App Store Connect 401 authentication failure — failing fast.');
        console.error(`lookupBuild failed: ${e.message}`);
        process.exit(1);
      }
      console.error(`lookupBuild failed: ${e.message}`);
      console.warn('Continuing to poll despite lookup error...');
      await sleep(interval);
      interval = Math.min(interval + 5000, MAX_INTERVAL_MS);
      continue;
    }

    if (!build) {
      console.log(`Build not yet visible (no data) — continuing (attempt ${attempt})`);
      await sleep(interval);
      interval = Math.min(interval + 5000, MAX_INTERVAL_MS);
      continue;
    }

    const state = build.attributes?.processingState;
    const buildId = build.id;
    console.log(`Build id=${buildId} processingState=${state} version=${build.attributes?.version} uploadedDate=${build.attributes?.uploadedDate || 'n/a'}`);

    if (state === 'VALID') {
      console.log('\n✅ TestFlight processing VALID — build is ready for TestFlight');
      console.log(`App ${bundleId} build ${buildNumber} is VALID after ${elapsedSec}s`);
      process.exit(0);
    }

    if (state === 'FAILED' || state === 'INVALID') {
      console.error(`\n❌ TestFlight processing ${state} — build failed Apple processing`);
      const detail = await fetchBuildDetail(buildId, issuerId, apiKeyId, privateKey);
      if (detail) {
        console.error(`Build detail: id=${detail.id} state=${detail.attributes?.processingState}`);
        // Try to surface any additional error info if present
        if (detail.attributes) {
          console.error(`Attributes: ${JSON.stringify(detail.attributes, null, 2).slice(0, 2000)}`);
        }
      }
      // Try to fetch beta build localizations or build errors if available
      console.error(`Check App Store Connect → TestFlight → Builds → ${bundleId} version ${buildNumber} for Apple diagnostic details.`);
      process.exit(1);
    }

    if (state === 'PROCESSING' || !state) {
      console.log(`State ${state || 'unknown'} — still processing, retrying in ${Math.round(interval/1000)}s with fresh JWT next request...`);
      await sleep(interval);
      interval = Math.min(interval + 5000, MAX_INTERVAL_MS);
      continue;
    }

    // Unknown state — log and continue
    console.warn(`Unknown processingState=${state} — continuing to poll`);
    await sleep(interval);
    interval = Math.min(interval + 5000, MAX_INTERVAL_MS);
  }

  console.error(`\n⌛ Timeout after ${Math.round(MAX_WAIT_MS/60000)} min — build ${buildNumber} did not reach VALID`);
  console.error(`Last attempt ${attempt}. Check App Store Connect → TestFlight for build ${buildNumber} status.`);
  process.exit(1);
}

main().catch((e) => {
  console.error(`Polling failed: ${e.stack || e.message}`);
  process.exit(1);
});
