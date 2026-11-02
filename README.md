# WorldVote

A responsive civic participation platform built with **Next.js 16.4.4**, React, TypeScript, Tailwind CSS, Radix/shadcn-style UI primitives, Supabase, Stripe, Framer Motion, and Recharts. Next.js 16 replaces the originally requested version 14 with the user's approval after a security audit.

## Start developing

Node 22 or 24 and npm 10+. Use the existing isolated checkout at `/workspace/worldleaders`; do not create a worktree unless explicitly requested.

```sh
npm ci
npm run dev
```

The default app is a self-contained demo with ten **fictional** leaders, ten work posts, local image assets, and explicitly labeled sample rankings/reasons. No credentials are needed to explore the interface. The feed is at `/`, a dedicated landing page at `/welcome`, and supporting pages include `/leaders`, `/leaders/elena-martinez`, `/leaderboard`, `/my-votes`, `/profile`, `/login`, `/signup`, `/leader-dashboard`, `/admin`, `/payment/success`, `/payment/failure`, `/terms`, `/privacy-policy`, `/refund-policy`, and `/faq`.

```sh
npm run build       # optimized production build and type validation
npm start           # serve the production build on port 3000
npm test            # input validation + embedded PostgreSQL transaction/access tests
npm run test:e2e    # run with the server running; expects /usr/bin/chromium
```

Set `CHROMIUM_PATH` when Chromium is installed elsewhere. The five browser tests cover desktop/mobile feed filtering, vote reason/quantity validation, login gating, leader profiles, charts, rankings, dark mode, and unavailable-service/privileged access boundaries.

## Connect live services

Copy `.env.example` to `.env.local` and securely populate it. Never commit credentials. Restart after changing configuration.

1. Create a Supabase project. Run `supabase/schema.sql` **once in a fresh project**, then `supabase/seed.sql`. The seed contains fictional leader profiles and work posts, not fake payments or paid votes. Live rankings start at zero.
2. Set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and server-only `SUPABASE_SERVICE_ROLE_KEY`.
3. Enable email confirmation and Google OAuth in Supabase. Configure OAuth/email redirect URLs and SMTP. Enable Supabase Turnstile CAPTCHA and set `NEXT_PUBLIC_TURNSTILE_SITE_KEY`; the CAPTCHA secret belongs in Supabase settings. Email signup is disabled in the UI until CAPTCHA is configured.
4. Configure Stripe in **test mode**, set `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET`, and register `/api/webhooks/stripe` for `checkout.session.completed`, `checkout.session.async_payment_succeeded`, and `charge.refunded`.
5. Set `APP_URL` to the exact application origin. Configure Stripe successful-payment receipt emails. Receipt delivery is provider-managed and must be tested separately.
6. Provision the initial administrator through the trusted Supabase SQL editor: assign the `admin` role to an existing verified user's row. Never let clients choose roles. Admins can then create verified leaders from registered accounts or manage existing verification.
7. Permit the project-specific Supabase hostname, Stripe API/Checkout, and Cloudflare challenge destinations in the environment's network settings. A configuration draft is saved; it does not automatically change the running instance.

When configured, the feed, post stats, rankings, reasons, notifications, and vote history query the database. Realtime subscriptions observe public leader/post changes; an atomic vote trigger updates the public leader row to prompt a rankings refresh. Supabase authenticated storage allows verified leaders to upload up to five JPEG/PNG/WebP images, each under 5 MB.

## Payment integrity and access control

The server verifies the bearer session, confirmed email, voter role, origin, quantity and reason. Prices are server-calculated at 100 cents per vote. A database-backed limiter permits five checkout attempts per minute per voter. Client-generated request IDs and Stripe idempotency keys avoid duplicate checkout sessions on retries.

Webhooks verify Stripe signatures against the raw body. A transaction locks the stored payment, validates amount/currency/session/post/leader, and atomically creates the vote, public reason, and notification. Unique payment IDs make webhook retries idempotent. Success redirects never record votes. Full-refund events atomically reverse votes; partial refunds are not exposed in the admin UI. Negative votes subtract from the score.

RLS denies client insertion of payments/votes and profile role changes. Public views expose only intended comment/display and aggregate data. Leader APIs check verified ownership; admin APIs check the server-side role. Reports and replies require an authenticated verified account. Comments render as escaped text.

## Product behavior

- Responsive three-column feed with mobile navigation/search, country/category/region filters and sorting.
- Verified leader profiles, work update galleries, support/disapprove reasons, live period rankings and animated crown.
- Vote quantity 1–100, $1 pricing, mandatory 20–1000 character reason, secure sign-in/checkout gates.
- Email/Google sign-in, CAPTCHA-enabled signup, confirmed vote history, notifications and provider-managed receipts.
- Verified leader workspace: publishing, image storage, received-vote totals and trends; leaders can reply to their own updates.
- Administrator workspace: leader creation/verification, report moderation, full refunds and recent revenue totals.
- Local dark-mode and saved-update preferences, sharing links, payment result pages and draft policy/FAQ pages.
- Privacy preferences for public display names, authenticated JSON data export, and deletion-review requests. Financial retention decisions require operator review.

## Before public launch

Live Supabase/Google/Turnstile/Stripe/SMTP integrations have **not** been exercised here because service credentials were not supplied. Embedded PostgreSQL tests verify schema and transaction logic with platform auth/storage stubs; they do not replace Supabase integration tests. End-to-end test signed webhooks, actual checkout, refunds, email, uploads, role workflows, and Realtime in a staging project before accepting money.

Legal documents are drafts. Automatic GDPR deletion execution, operational audit logging, advanced fraud detection, broader API rate limiting, accessibility review and monitoring still need implementation/review. Revenue displays the latest 500 payments, not full accounting. Notification data is real when connected, but inbox polling occurs on opening it. Saves are browser-local. Demo period totals/charts are illustrative. PayPal is not implemented. Paid vote rankings measure purchased participation, **not representative public opinion or election results**.

Local sample portraits are from Creative Tim's MIT-licensed Soft UI Dashboard; the license is in `public/images/PORTRAIT-LICENSE.txt`. Landscape/healthcare/education artwork is bundled SVG. No remote image host is required for the default demo.

See `SETUP.md` for validation evidence and environment publication instructions.
