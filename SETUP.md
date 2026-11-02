# Environment setup and validation

Prepared in `/workspace/worldleaders` on 2 November 2026. The selected repository was empty/unborn; all application files were created for the user's WorldVote request. No existing application files were overwritten.

## Verified locally

- Node 24.19.0 / npm 11.9.0; lockfile-based dependency installation.
- Optimized Next.js 16.4.4 production build and TypeScript validation.
- Four input-validation tests: valid votes, quantity bounds, substantive reasons, price/type tampering.
- Embedded PostgreSQL schema + transaction suite: signup cannot grant admin, wrong payment amounts rejected, duplicate webhooks create one vote/comment, negative net score, idempotent full refunds, public refunded comments excluded, rate limiting, anonymous function denial, RLS vote-insert denial and role-edit denial.
- Five Chromium browser tests: feed filters and voting/login flow; leader profile/chart/rankings/dark mode; 390px mobile layout/modal/navigation, landing/signup routes; unavailable checkout/webhook and administrator access gates.
- Desktop/mobile screenshot inspection: no broken local images, no horizontal overflow, no browser page errors.
- Production dependency audit: zero reported vulnerabilities after the user-approved upgrade from Next.js 14.
- Read-only GitHub access succeeded using existing platform authentication; origin has no commits.

## Reproduce

From the existing checkout, `npm ci --no-audit --no-fund`, `npm run build`, then `npm test`. Start with `npm start` for the production workflow or `npm run dev` for editing. Run `npm run test:e2e` against the running server. Inter fonts and image assets are local.

In this session, network access and browser/server process startup required the supported command sandbox escalation. Keep the configured proxy and TLS verification. Initial sandbox-local proxy connection errors did not indicate missing GitHub credentials. No token was requested or extracted.

## Saved configuration

The environment draft contains complete `install_script` and `start_skill` instructions, variable requirement names from `.env.example`, and additive network destinations: `api.stripe.com`, `checkout.stripe.com`, `challenges.cloudflare.com`, and `*.supabase.co` (plus `images.unsplash.com` for optional remote images). Package-manager presets were retained. Saving a draft does not apply it or publish a snapshot.

Review and save the draft in environment settings, enter service values securely if live integration is wanted, and publish the environment. Processes do not survive publication/restoration; use the saved startup instructions. A fresh restored task has not been independently tested.

## Scope limits

The default demo development workflow runs without credentials. Production integration readiness remains blocked on project-specific Supabase, Stripe, Google OAuth, CAPTCHA and email configuration. Live payments, receipt delivery, external auth, Realtime and hosted storage are unverified. See README.md for launch gaps and integration steps; do not accept live payments before staging validation.
