# Growza — Cloudflare Worker setup

Updated: 15 November 2026. Project: `D:/Growza/server`.

## Current boundary

The Flutter app keeps email/password fingerprints and study data in SQLite on the device. Cloudflare does not receive account credentials and does not synchronize study data. Supabase is not required. The Worker exposes only `/health`, `/installations`, and `/ai/topics`.

AI is now active at https://growza-api.growza-worker.workers.dev with `AI_ENABLED = "true"`. The owner confirmed Workers Free; no paid upgrade or credits were enabled. Live health is `ok=true`, `ready=true`, `ai=true`. Remote D1, IP_HASH_SECRET and the existing Android endpoint are configured. No APK update is needed for this server-only activation. Latest deployment: `543ea78b-c31a-4b1b-9a39-1f9353b4ba59`.

Validation: clean Flutter Analyze, 181 Flutter tests, 28 Worker tests and a successful deployment dry-run. A real production enrollment/topic request returned two correct page-linked topics in 959 ms. The following setup commands document initial reproduction; those resources already exist and must not be recreated.

## What the owner does

1. Sign in to Cloudflare in your browser, or create your own account. Keep Workers Free if spending is not authorized. Do not add paid AI Gateway credits or upgrade the plan as part of this setup.
2. The developer starts `npm run login`, then you open the displayed official Cloudflare URL and approve Wrangler. Credentials stay in your browser. If browser callbacks fail, use the device flow below; enter the displayed short code yourself within its validity period.
3. Say that approval is complete. Do not paste passwords, API tokens, callback URLs or OAuth authorization codes into chat.

```powershell
Set-Location 'D:/Growza/server'
$env:WRANGLER_SEND_METRICS = 'false'
npm.cmd run login
# Alternative: avoids the localhost browser callback.
& ./node_modules/.bin/wrangler.cmd login --device --browser=false --scopes account:read user:read workers:write workers_scripts:write d1:write ai:write --use-keyring
```

Wrangler stores its OAuth credential encrypted with the OS keyring. Requested scopes cover account/user reads, Workers deployment, D1 and Workers AI; refresh access is added by Wrangler. Authentication is not a cloud account system for Growza users.

## First-time deployment instructions (already completed here)

These instructions are for future reproduction; the current account already has the database and Worker. Do not recreate them or rotate the secret unnecessarily. Run from `D:/Growza/server`; use the project's pinned Wrangler 4.162.0. All commands below are for the selected owner's account. With multiple accounts, choose the intended account before creating resources. No Git integration is used.

```powershell
& ./node_modules/.bin/wrangler.cmd whoami
& ./node_modules/.bin/wrangler.cmd d1 create growza-api-limits
```

Copy the resulting database UUID into `database_id` in `wrangler.toml`, replacing the placeholder. It is an identifier, not an API secret. Apply only this project's remote migrations, then deploy with AI disabled:

```powershell
& ./node_modules/.bin/wrangler.cmd d1 migrations apply growza-api-limits --remote
& ./node_modules/.bin/wrangler.cmd deploy
node scripts/set-ip-secret.mjs
```

The secret helper generates 32 random bytes and sends them directly to `wrangler secret put IP_HASH_SECRET`; it does not print or save the value. Run it once at initial setup. Rotating it later changes the IP quota buckets. Do not put it into Flutter or a backup.

Visit the exact HTTPS URL returned by deployment, adding `/health`. Expected state: `ok: true`, `ready: true`, `ai: false`. First deployment can require choosing a workers.dev subdomain in the dashboard. Do not invent or reuse another project's URL.

Build Flutter with that public endpoint:

```text
--dart-define-from-file=config/services.json
```

This define is the public service address, not a secret. The ordinary account flow remains local. No network call or installation enrollment occurs at app startup or sign-in. Only a signed-in user's explicit suggestion request, after the existing text preview and consent, contacts the Worker. Production endpoint must use HTTPS; redirect following is disabled.

## AI activation — completed

The owner authorized live evaluation and confirmed Workers Free. Model: `@cf/google/gemma-4-26b-a4b-it`. The Worker disables thinking with `chat_template_kwargs: {enable_thinking: false}` for this bounded extraction task; JSON mode, `store=false`, `stream=false`, temperature 0 and existing token limits remain. A small live comparison improved from 40.731 seconds / 17.836 Neurons to 1.517 seconds / 1.491 Neurons. These are individual measurements, not latency guarantees.

Two real synthetic 40-page PDFs, each with 40 outline headings, were generated and extracted with pypdf. The same Worker handler used an in-memory quota database and real Cloudflare REST inference: Arabic Calculus took 12.516 s / 28.818 Neurons; English Biology took 7.442 s / 24.318 Neurons. Each used two batches and returned 40 exact source headings with correct original page numbers. Combined measured usage: 53.136 Neurons, reported by the provider. No student PDFs or account credentials were sent. This host-side test does not establish native PDF-to-AI end-to-end behaviour, OCR support or quality on arbitrary course files.

Then the deployed Worker AI binding passed a separate small production test. Its installation is separate from the phone's. One production model-call reservation remains counted; no quota was deleted or waived. The synthetic two-file benchmark did not consume phone/production installation attempts.

- Text only: at most 12,000 UTF-16 characters and 2,000 document pages; request body at most 64,000 bytes. No PDF bytes, local account ID, email or password are submitted.
- Installation credentials: cryptographically random 256-bit bearer tokens, 30-day lifetime, only SHA-256 hashes in D1. The app stores the token in secure storage scoped to the exact Worker endpoint. An expired/revoked token gets one re-enrollment/retry, without email codes.
- Quotas reset at UTC midnight: 3 file-analysis attempts per installation/day, 30 model calls globally by default (configuration range 1-100), and 10 model calls per IP/network/day. Each file is split into at most 3 batches and uses one installation attempt. One atomic reservation counts every planned model call before processing; failed calls keep their reservations. Enrollment remains 5/IP/day and 100 globally/day.
- Quotas identify installations, not verified people. Reinstallation/clearing storage creates another identity; network limits reduce simple abuse but can also group students on a shared campus/Wi-Fi. This does not provide device attestation or full abuse protection. The global cap limits provider calls, not total traffic/D1 costs on a paid plan.
- Cloudflare supplies `CF-Connecting-IP`; the Worker stores HMAC-SHA256 IP hashes with a server secret, never raw IPs. Quota metadata is cleaned after two days; expired installation rows are cleaned daily. Logs/observability are disabled in configuration. Cloudflare still processes the incoming connection and, after consent, document text.
- Output is strictly parsed and filtered for title length, duplicates, markup/links and page ranges. Document content is untrusted input. Students review suggestions before saving. No automatic subject changes or growth-rule changes occur.
- Workers AI Free currently provides 10,000 Neurons/day, resetting at 00:00 UTC. Free requests fail at the provider limit; no paid overages were enabled. Request counts and these small fixtures do not guarantee free capacity or latency for every document. The account may share its AI allocation with other applications.

## Local checks

```powershell
npm.cmd ci --ignore-scripts --no-audit --no-fund
npm.cmd test
npm.cmd run check
& ./node_modules/.bin/wrangler.cmd d1 migrations apply growza-api-limits --local
```

Tests cover real SQLite quota SQL, expiry/authentication, privacy boundaries, concurrent calls, invalid documents/provider output, CORS, errors and scheduled cleanup. A separate Miniflare/workerd test runs the actual entrypoint and D1 migrations with AI disabled. Mock AI tests do not establish real inference quality or deployment success.

The local D1 state is under `server/.wrangler/`; it is separate from Android SQLite and the future remote database. Never include `.wrangler`, `node_modules`, `.dev.vars` or account credentials in a student-data backup.

## References

- [Wrangler commands](https://developers.cloudflare.com/workers/wrangler/commands/)
- [D1 migrations](https://developers.cloudflare.com/d1/reference/migrations/)
- [Workers AI pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/)
- [Configured candidate model](https://developers.cloudflare.com/workers-ai/models/gemma-4-26b-a4b-it/)
- [Retirement notice for the earlier model](https://developers.cloudflare.com/changelog/post/2026-11-05-planned-model-deprecations/)

Flutter build command from `D:/Growza`: `flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=config/services.json`. The delivered APK contains this endpoint; future builds/runs must also pass this define file. No account credentials are in it.

## Bounded topic batches — deployed and active

The existing previewed headings text (maximum 12,000 characters) is split into at most three batches, balancing line count and length. Chunks prefer whole lines and preserve surrogate pairs. Each is capped at 6,000 characters; generation requests at most 20 topics and 2,048 completion tokens. Original document page numbers are retained. Validated results are sorted and duplicate/overlapping boundary topics merged before the existing student review. This does not upload a PDF, perform OCR or process all full-page content. Existing local extraction/truncation limits remain visible in the preview.

`src/topic_chunks.js` centralizes the batch limits. `0003_model_call_budget.sql` adds `model_calls` with default 1 for old rows, preserving IDs. File attempts and actual planned model calls have separate quota semantics. If any batch fails or is truncated, the whole analysis returns a controlled error; no partial success or automatic paid retry is reported. The UI retains its preview/manual alternative. Splitting can increase prompt/output overhead and does not guarantee lower Neuron consumption.

Gemma 4's documented `choices[0].message.content` output and `max_completion_tokens` are supported; the legacy response shape remains accepted for compatibility. `store=false`, `stream=false` and JSON output are requested. The live evaluation and actual usage are recorded above. No paid plan or AI Gateway credits were enabled.

Verification: 28 local Worker tests, including mock analyses for two 40-page heading fixtures; weighted global/network/concurrent budgets; preserved page markers/Unicode; legacy migration; and real workerd/D1 SQL. Flutter Analyze is clean and all 181 Flutter tests pass. Migration 0003 and the Worker are deployed. Following activation, live health is ready=true and ai=true. Production validation created one verification installation and one one-call analysis reservation; student data is not in D1. No Android rebuild is needed for this server-only revision.

## Try the installed application

Sign in with the existing Growza account, open a subject, choose **Suggest topics from PDF** (`اقترح المواضيع من الملف`), select the PDF and inspect the extracted headings. Consent sends only the displayed text. Review/edit suggestions before confirming them. Selecting a reference filename alone does not invoke AI. A scan without extractable text needs manual topics; no OCR was added. No new installation is required for this activation.
