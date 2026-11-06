# MoMo Sandbox for WashCare

## Setup

1. Obtain the Sandbox integration information from MoMo Business.
   Follow https://developers.momo.vn/v3/vi/docs/payment/onboarding/integration-process/
2. Run the full contents of migrations/202611050003_momo_sandbox.sql in the
   Supabase SQL Editor after migrations 001 and 002.
3. Open Supabase Dashboard, Edge Functions, Secrets. Add the Sandbox values
   MOMO_PARTNER_CODE, MOMO_ACCESS_KEY and MOMO_SECRET_KEY.
   Keep these values in Edge Function Secrets. The Flutter application uses
   the signed-in user's session when calling the backend.
4. Deploy the functions from the project directory using the Supabase CLI.

    npx supabase@latest login
    npx supabase@latest functions deploy momo-payment --project-ref fbkmdphtriekjfcqdbqy
    npx supabase@latest functions deploy momo-callback --project-ref fbkmdphtriekjfcqdbqy

The CLI reads config.toml. Both functions have verify_jwt=false.
momo-payment validates the bearer token with Supabase Auth before any database
operation. momo-callback authenticates POST notifications using MoMo HMAC-SHA256.

SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are supplied by
Supabase to Edge Functions. These server credentials are read only by backend code.

## URLs

The create request supplies both URLs automatically.

- IPN and browser return URL
  https://fbkmdphtriekjfcqdbqy.supabase.co/functions/v1/momo-callback
- Payment gateway
  https://test-payment.momo.vn/v2/gateway/api/create

Use the Sandbox credentials from the matching MoMo Business environment.
The gateway host is fixed to the Sandbox environment in the source code.

## Device test

1. Sign in as a customer and create a test order using MoMo Sandbox.
2. Select Open MoMo Sandbox and complete checkout using the test tools/accounts
   supplied by MoMo.
3. Return to WashCare. The dialog refreshes on resume and also offers Check Status.
4. Confirm the saved status is paid only after a valid IPN or server-side query.
5. Test a rejected/cancelled gateway transaction and retry.
6. Confirm users can read only their own transactions and cannot call service RPCs.

Orders with an outstanding or successful Sandbox transaction are protected from
cancellation. Pending requests reuse their stored provider reference and URL.
If a network error loses a create response, opening payment again reuses the
original request ID. An unresolved provider request stays pending until a result
is confirmed. Duplicate successful callbacks are idempotent. Late conflicting
successes are recorded as review_required for manual review.

A created payment URL is treated as pending. Browser return parameters are used
only for navigation. Existing momo_demo orders are displayed as historical demo
records and keep their separate demo_payment_status.

## Local verification

    node --test supabase/functions/_shared/momo_test.ts

For isolated PostgreSQL tests using a fixture reconstructed from the supplied
database audit, install the test runtime in the ignored build directory.

    npm install --prefix .dart_tool/momo-sql-check --no-save --ignore-scripts @electric-sql/pglite
    node --test supabase/tests/momo_sandbox_test.mjs

These tests use an in-memory database. They verify schema migration, SQL
permissions, amount matching, repeated intents, cancellation guards and duplicate
results. Provider HTTP calls in the backend tests use fixtures.

## Provider references

- https://developers.momo.vn/v3/vi/docs/payment/api/wallet/onetime/
- https://developers.momo.vn/v3/docs/payment/api/payment-api/query/
- https://developers.momo.vn/v3/docs/payment/api/result-handling/notification/
