# Onboarding v2 — Voice-first, resilient (DRAFT)

> Status: proposal for review. Nothing here is built yet.
> Author: Jo (code-puppy) with Abhinav, 2026-07-14.

## Why we're redoing it
The current flow (18 files: polling mixins, phase widgets, 17KB `onboarding_complete`)
is sprawling AND fragile. In practice it *hangs*, but the root cause observed in
device logs is **infrastructure, not the funnel**:

- `App Check: Too many attempts` → token exchange throttled
- → `userStream timed out after 8s`, `dailyInsightStream timed out, emitting null`
- → the chart/insight the UI is waiting on never arrives
- Secondary jank: `CursorWindow: NO_MEMORY` (546 days of sky data in SQLite) + dropped frames.

**Design principle #1: the funnel must degrade gracefully when the backend is slow
or starved.** No infinite spinners. Ever.

## North star
Baba (Aurobhatt) *leads* onboarding by voice. Tapping is always available as a
fallback and is fully in sync with what Baba is doing. A guest can complete the
whole thing and get value; login is nudged after the reveal (see prior decision).

## The flow (voice-first)
1. **Warm open (0 friction).** Baba greets, introduces himself, asks the user's name.
   Screen: a calm starfield + a single live caption of what Baba says + a mic orb.
   Tap fallback: a name field.
2. **Micro-value before the ask.** Baba gives a tiny genuine observation about *today*
   (needs no birth data) so the user feels value before being asked for anything.
3. **Collect birth details conversationally.** Baba drives: date → time → place, one at
   a time, reading each back. The birth-details screen is visibly filling in as he
   captures each value (the set* tools already do this). Tap fallback: the same form,
   editable at any moment; voice and form share one state.
4. **Submit + reveal.** On submit, show an *engaging* reveal sequence (sign, chart
   highlights) that is **driven by streamed partial data**, not a single all-or-nothing
   await. Baba narrates the reveal as pieces arrive.
5. **Post-reveal.** Baba proactively offers the next step (daily insight / explain a
   placement) and — if guest — warmly nudges login (already implemented in guidelines).

## Resilience contract (the important part)
- Every backend wait has: a **skeleton/animation**, a **soft timeout** that shows a
  "still calculating…" state (not a dead spinner), and a **retry** affordance.
- The reveal renders **incrementally** from whatever data has arrived; missing pieces
  show as "coming in…" and fill live.
- If astro calc is genuinely slow (App Check/backend), the user still lands on a usable
  screen with their sign + a "your full chart is being prepared" banner, and Baba says so
  honestly (never claims done when it isn't — per the ok:false convention).
- Sky-data load must not OOM: page/window the 546-day dataset or load lazily.

## Voice ⇄ UI sync (single source of truth)
- One onboarding state object (name, date, time, place, gender, submitStatus,
  revealData). Both Baba's tools and the tap form read/write it. No divergence.
- Baba's `whereAmI` already exposes on-screen state; the reveal screen must register a
  snapshot provider so Baba narrates exactly what's rendered.

## Proposed structure (replacing the 18-file sprawl)
```
lib/features/onboarding/
  domain/
    onboarding_controller.dart   # single state + transitions (ChangeNotifier)
    onboarding_tools.dart        # Baba tool handlers, thin, delegate to controller
  presentation/
    onboarding_flow.dart         # the one host that switches phases off controller
    phases/
      welcome_phase.dart         # greet + name (voice + field)
      collect_phase.dart         # birth details (voice + form, shared state)
      reveal_phase.dart          # incremental, streamed reveal
    widgets/                     # reused: starfield, zodiac wheel, cards, caption
```
Keep the good painters (`star_field_painter`, `zodiac_wheel_painter`) and cards.
Collapse the polling mixins + phase widgets into the controller + phases above.

## Open questions for Abhinav
- Keep the existing "path choice" (talk to Baba vs do it myself) as an explicit first
  screen, or go straight into voice with a visible "type instead" escape hatch?
- How elaborate should the reveal be (quick sign card vs full animated chart)?
- Any brand/motion guidelines to honor for the reveal?
```
