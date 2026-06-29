# Cosmic Timeline & Date Card Redesign

## The Problem
The current layout stacks too many discrete elements vertically. We have:
1. Date elements spread across 2-3 lines.
2. The live Vedic time on its own line.
3. A gap, then the Timeline header.
4. "Inauspicious" event lanes (up to 2-3 lines of text + connector sticks).
5. The track area.
6. "Auspicious" event lanes (another 2-3 lines + sticks).
7. Hour markers.

All of this creates an airy, disjointed, and vertically expensive card.

## The Vision: "Swiss Watch Minimal"
We need to aggressively collapse the vertical stack by combining related data horizontally and embedding labels *into* the UI elements rather than hanging them outside.

### 1. The Header: The Single-Line Dashboard
Instead of centering everything and stacking it 4 lines deep, we use a classic left/right split to maximize horizontal space:

* **Top Line**: `JYESHTHA • SHUKLA • PURNIMA` (Left) | `14G 20P • USHA` (Right)
* **Bottom Line**: `ROHINI NAKSHATRA • 2083` (Left) | `LIVE` or `TOMORROW` (Right)

This turns 4-5 lines of text into exactly 2 lines.

### 2. The Timeline: The "Solid Ribbon"
Instead of a 1px wire track with floating text labels on sticks, the track becomes a solid, elegant ribbon (e.g., 20px - 24px tall).

* **Embedded Text**: We place the event names (`AMRIT KAAL`, `VARJYAM`) **inside** the colored event blocks on the ribbon. With a sleek 8px or 9px bold, wide-tracked font, this looks incredibly high-end.
* **Overlaps**: Since events can overlap, the ribbon can be split horizontally into two tracks internally—the top half (12px) for auspicious events (Green) and the bottom half (12px) for inauspicious events (Red). 
* **The "Now" Indicator**: Instead of a dot floating above the line, the current time is a stark white vertical needle that slices cleanly through the entire ribbon, perhaps with a subtle glow.
* **Hour Ticks**: Simple, tiny numbers (`5 AM`, `6 AM`) placed immediately below the ribbon.

### 3. Eliminated Elements
* We drop the "Time Guidance" title entirely. The UI speaks for itself.
* We drop all connector sticks and vertical lanes (`laneHeight`, `reservedLanes`). 
* We drop all empty vertical padding that was previously needed to make the sticks readable.

## Vertical Space Savings
* Old Card Height: ~180px - 220px (depending on events).
* New Card Height: ~70px - 90px total.

Let me know what you think of this direction, especially the "Solid Ribbon" idea where event labels sit directly inside the timeline bar!