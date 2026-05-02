# Incident: `onHealthSnapshotWrite` infinite loop

**Date:** 2026-04-21 → 2026-05-02 (11 days)
**Severity:** P1 — runaway cost / infrastructure
**Project:** `ty-dev-516d7`
**Resolved:** 2026-05-02 ~03:00 UTC by deleting the deployed function.

---

## TL;DR

A Firestore `onDocumentWritten` trigger wrote back to its own trigger document
on every invocation, causing an unbounded self-trigger loop. Once a single user
wrote a `healthSnapshots/{dayKey}` document, the function ran forever against
that document, pumping Firestore writes at ~75/sec for 11 days.

- **~33 million** function invocations
- **~71 million** Firestore writes
- Estimated GCP cost impact: **~$190–$250 USD** for the period
- Detected via Cloud Monitoring `function/execution_count` metric query
- Stopped by deleting the function deployment

## Root cause

`backend/functions/ayurveda.js :: onHealthSnapshotWrite` was triggered by
`onDocumentWritten("users/{userId}/healthSnapshots/{dayKey}", …)`.
Inside the handler, after computing the dosha analysis, it ran:

```js
await event.data.after.ref.update({
    "analysis.signalDosha": dominant,
    // … other analysis fields …
    "analysis.analyzedAt": FieldValue.serverTimestamp(),
});
```

That update fired the same trigger again (`onDocumentWritten` matches updates
too), which produced the same analysis output, which fired another update, etc.

The `withIdempotency` wrapper on this function did **not** prevent the loop,
because at-least-once dedup is keyed by **event ID** — every loop iteration is
a brand-new event with a brand-new ID, so it always passes the dedup gate.

## Why it took 11 days to find

1. No GCP billing budget alert was configured. The pre-existing budget had
   currency `INR` with no `units` field set (effectively zero) and an empty
   `notificationsRule`.
2. No Cloud Monitoring alert on function invocation rate.
3. No BigQuery billing export, so historical cost analysis required manual
   month-by-month polling of the Cloud Billing API.
4. Cost rose linearly inside Firebase's free tier headroom for the first ~3
   days before crossing into paid usage.

## Fix

### 1. Stop the bleeding
- Deleted the runaway function deployment via
  `gcloud functions delete onHealthSnapshotWrite --gen2 --region=asia-southeast2`.
- Confirmed Firestore write rate dropped from **~250,000/hour → 2/hour**
  within the next hour.

### 2. Code-level safeguard
Added `backend/lib/idempotency.js :: withLoopGuard`, a content-hash-based
loop guard. It works by:

1. Hashing the **input fields the handler actually reads** (caller passes a
   selector function).
2. Storing that hash on the document at `_meta.<functionName>.inputHash`
   inside the same `update()` call that writes the analysis result.
3. On the next invocation, comparing the stored hash to the freshly computed
   hash — if equal, **skip**. The handler's own write-back can never trigger
   it again, because the input fields haven't changed.

`onHealthSnapshotWrite` was rewritten to use `withLoopGuard` and capped at
`maxInstances: 5` so even a future bug cannot scale to 33M invocations.

### 3. Monitoring + guardrails
- **Billing budget** patched: USD $20/month, project-scoped, alerts at
  25% / 50% / 90% / 100% of current spend and 50% / 100% of forecasted spend,
  emails go to billing-account admins.
- **Cloud Monitoring alert** "Runaway Cloud Function invocations": fires when
  any function exceeds **10 executions/sec** sustained for 5 min. Notifies
  `canay.info@gmail.com`. Covers both gen1 (`cloud_function`) and gen2
  (`cloud_run_revision`) resource types.
- **Cloud Monitoring alert** "Runaway Firestore write rate": fires when the
  Firestore document write rate exceeds **5/sec** sustained for 10 min
  (healthy baseline is ~0.02/sec).

## Patterns to avoid

### NEVER do this in a Firestore trigger handler

```js
// onDocumentWritten / onDocumentUpdated handler
export const onSomething = onDocumentWritten("things/{id}", async (event) => {
    const data = event.data.after.data();
    const result = compute(data);
    await event.data.after.ref.update({ result });   // ← INFINITE LOOP
});
```

### Do one of these instead

**Option A — write to a different document.** Most denormalizations belong
on a sibling/parent doc, not on the trigger doc itself.

**Option B — use `withLoopGuard`** if you genuinely must write back to the
trigger doc (e.g. caching computed analysis on the source). Pass a selector
that returns ONLY the input fields the handler reads:

```js
import { withLoopGuard } from "../lib/idempotency.js";

export const onSomething = onDocumentWritten(
    { document: "things/{id}", maxInstances: 5 },
    withLoopGuard("onSomething",
        (d) => ({ a: d.a, b: d.b }),     // input selector — read fields only
        async (event, ctx) => {
            const data = ctx.after;
            const result = compute(data);
            await event.data.after.ref.update({
                result,
                ...ctx.metaPatch,         // ← MUST spread in the SAME update
            });
        }
    )
);
```

**Option C — use `onDocumentCreated`** instead of `onDocumentWritten`/
`onDocumentUpdated` whenever you only care about the initial creation. The
Created trigger does not refire on updates, so write-back is safe.

### Always set `maxInstances` on Firestore triggers

Firebase Functions v2 default is unbounded auto-scaling. A capped function
can still be runaway, but it cannot reach 33M invocations in 11 days.

```js
export const onFoo = onDocumentWritten(
    { document: "...", maxInstances: 5 },   // ← blast radius cap
    handler
);
```

## Detection runbook

If a future cost spike is suspected, the fastest path is the Cloud Monitoring
`function/execution_count` time-series query — not the billing console. Cost
data lags by 24–48 h; monitoring metrics are near real-time.

```bash
TOKEN=$(gcloud auth print-access-token)
PROJECT=ty-dev-516d7
START=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

curl -sG \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'filter=resource.type="cloud_function" AND metric.type="cloudfunctions.googleapis.com/function/execution_count"' \
  --data-urlencode "interval.startTime=$START" \
  --data-urlencode "interval.endTime=$END" \
  --data-urlencode "aggregation.alignmentPeriod=86400s" \
  --data-urlencode "aggregation.perSeriesAligner=ALIGN_SUM" \
  --data-urlencode "aggregation.crossSeriesReducer=REDUCE_SUM" \
  --data-urlencode "aggregation.groupByFields=resource.label.function_name" \
  "https://monitoring.googleapis.com/v3/projects/$PROJECT/timeSeries"
```

Group by `resource.label.function_name` to spot the offender. A healthy
function fires < 10k/day; a runaway one fires millions/day.

## Open follow-ups (not blocking)

- Enable BigQuery billing export so future cost analysis is queryable rather
  than requiring API polling.
- Audit the dependents of `onHealthSnapshotWrite` (Aura point handlers etc.)
  to make sure they tolerated 11 days of duplicate firings without their own
  side-effect explosions.
- Add a CI lint rule that flags `event.data.after.ref.update(` /
  `event.data.after.ref.set(` calls inside `onDocumentWritten` /
  `onDocumentUpdated` handlers, requiring an explicit `withLoopGuard` wrap.
