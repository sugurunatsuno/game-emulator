# Passive game-log experiment — 1.2.4

## Purpose and release boundary

Assess whether existing game logs can supply useful context cheaply across
clients and languages. The release runs a shadow probe; it does not replace
OCR, change frame eligibility or claim that unknown coverage is fixed.
See [the v2 diagnostic contract](telemetry-contract/performance-diagnostics.md)
and [the live probe findings](tft-live-context-probe-2026-09-14.md).

## Local verification, September 14, 2026

- On the owner's Mac, started the installed 1.2.3 launcher and current Global TFT
  18.2 normally. The probe reported read failure while the guest was unavailable,
  then game_not_running, then observed with no known event during startup.
- In the Russian 3840×2160 lobby, the exact release parser read gameflow_lobby.
  A local screenshot was independently inspected and the installed screenshot
  classifier also returned lobby. No match or game interaction was initiated.
- Six consecutive lobby reads succeeded. ADB reads took 92.6–112.9 ms;
  decode plus standalone helper-process startup took 36.0–38.8 ms. Combined
  observed cost was 128.6–149.9 ms. These wall times do not measure FPS impact
  or guarantee the same cost on other Macs; production records its own timings.
- Replayed ten previously sanitized phase events from the owner's earlier
  ranked match through the same parser: 10/10 preserved departure type and age.
  These are reconstructions of observed records, not a new live combat test.
- Parser tests reject rotation, truncation, process replacement/PID reuse,
  pre-process and future events, partial trailing records, oversized input and
  unapproved package strings. Missing reads cannot retain a phase.
- Swift round-trips legacy, v1 and v2 canonical wire fixtures. API tests cover
  v1/v2 compatibility, raw-field rejection, counter conservation/monotonicity,
  separate report denominators and suppression below five probe-enabled attempts.
  The conservative payload envelope is 25,107 bytes plus a 1 KiB reserve,
  below the existing 32 KiB limit.

The signed/notarized 1.2.4 build 53 was then installed over 1.2.3 on the same
Mac. TFT reached the lobby with the existing settings and game content. A real
foreground measurement produced one accepted lobby histogram, two lobby OCR
endpoints and one gameflow_lobby log observation. The integrated log read/parse
was in the 100–500 ms timing bucket. The production API retained revision 12
with these counters; the client pending queue was empty. Initial background
checks were skipped while the game was on another desktop. This verifies the
release collector and delivery path in a lobby, not combat accuracy or FPS impact.

Screenshots and raw logs are not committed. The reusable local probe is:

```sh
python3 scripts/probe-tft-game-log.py --samples 6 --interval 5
```

## Field evaluation

Check read availability, none/stale fractions, timings/backoff and screen-context
outcomes near recent GC events, separated by diagnostic implementation and
existing language/edition/configuration groups. Counts are observations, not
unique phase events. A recent departure does not prove phase agreement with
an earlier screenshot or the whole frame window.

Before using direct signals to label gameplay, validate current phase/round
against a complete ordinary match, including transitions, reconnect and end of
match. This release has no verified numeric round source and no complete phase
stream. Keep such samples unknown until that validation supports a change.
