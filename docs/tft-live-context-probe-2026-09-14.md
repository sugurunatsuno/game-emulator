# Passive TFT live-context probe

September 14, 2026, during the owner's running ranked match. This follows the
[1.2.3 field review](performance-telemetry-review-2026-09-14.md) and tests whether
game context can come directly from the Android client instead of screenshots.

## Scope

The owner explicitly authorized experiments without stopping or disturbing the
game. Reads used the already-running ADB service and existing root shell. No
restart, game input, settings/profile change, debugger attach, memory scan,
code injection, logging-verbosity change or network interception was performed.
No new executable was installed in Android. Two screenshots were taken for
visual context; neither was uploaded or committed. The game process retained
PID 3553 during the checks.

Observed Android build: global TFT `18.2-5450971`, version code `8450971`.
The UI was Russian. The launcher remained installed as 1.2.3. Results apply to
this observed game build and session; they are not a cross-version guarantee.

## What the game exposes

The current text log is:

```
/sdcard/Android/data/com.riotgames.league.teamfighttactics/files/UnrealGame/TFT/TFT/Saved/Logs/TFT.log
```

### Match lifecycle: directly observable

Existing Riot messaging records contain structured fields. Only these bounded
semantic values were retained, excluding account, player, match and session IDs:

| Log time, UTC | Field | Value |
| --- | --- | --- |
| 11:22:58.640 | `gameflowPhase` | `LOBBY` |
| 11:23:06.441 | `phaseName` | `MATCHMAKING` |
| 11:25:59.666 | `phaseName` | `AFK_CHECK` |
| 11:26:05.597 | `phaseName` | `CHAMPION_SELECT` |
| 11:26:05.997 | `gameState` | `IN_PROGRESS` |

The last record also supplies `gameMode=TFT`, `queueId=1100` and
`queueType=RANKED_TFT`. These are game-emitted labels, not OCR results. Do not
interpret `CHAMPION_SELECT` as a literal TFT champion-picking screen: it is the
upstream lifecycle enum. `IN_PROGRESS` establishes match association; by itself
it does not prove a rendered battle, foreground visibility, or completed loading.

### Some internal phase transitions: directly observable, incomplete

The game emits this kind of record without enabling additional logging:

```
TFTRuntimePerformanceSubsystem: Scheduled phase garbage collection ... / Phase[ETFTPhaseType::PlanningDeparture]
```

Observed sequence through 11:33:35 UTC:

| Log time, UTC | Internal phase at scheduled GC |
| --- | --- |
| 11:27:57.513 | `DraftDeparture` |
| 11:28:24.516 | `CombatDeparture` |
| 11:29:01.692 | `CombatDeparture` |
| 11:29:36.954 | `CombatDeparture` |
| 11:30:28.956 | `PlanningDeparture` |
| 11:31:06.947 | `CombatDeparture` |
| 11:31:39.015 | `PlanningDeparture` |
| 11:32:17.618 | `CombatDeparture` |
| 11:32:49.677 | `PlanningDeparture` |
| 11:33:25.641 | `CombatDeparture` |

These records prove that some phase information can be extracted directly from
the running game, independently of display language. However, they are emitted
when garbage collection is scheduled, not as a demonstrated complete stream of
phase changes. Repeated `CombatDeparture` records omit intervening phases. A
departure is a transition event, not a durable assertion that the following
entire time interval is combat or planning. Do not count these events to infer
the round or keep the last phase indefinitely as current state.

### Exact stage/round: no live source verified yet

The log registers `TFTRoundSubsystem` as provider for
`TFTStagesRoundsTooltipViewModel`. This identifies an internal component worth
investigating, but it does not expose its current properties to the launcher.
The displayed stage `1-3` was verified on a passive screenshot during the match.
No corresponding numeric round/stage stream was found in the inspected log
records or recent game-process logcat output.

`TFTEoGStats.json` exists beside the log. Its schema includes queue/mode, game
length and final player data, but its modification time predates this match.
It is an end-of-game artifact, not a verified source of current stage or phase.
Its player data was not retained in the findings.

## Other interfaces checked

- The game process had no listening TCP/TCP6 sockets in either the matchmaking
  or in-match check, and no named Unix socket among its open socket descriptors.
  This rules out an already-serving local HTTP API in that process at those
  moments, not every possible interface in future builds or other processes.
- Read only 14,119 bytes of the current `libUnreal.so` ELF metadata/string table,
  in about 0.15 seconds. No exported `TFTRound`, `TFTStage`, `CurrentPhase`,
  `CurrentRound`, `CurrentStage`, `GameState`, `GWorld`, `GUObjectArray` or
  `NamePool` names were present; no full symbol table was present. This is not
  proof that the underlying state does not exist. It means a ready named
  symbol-based reader was not available from that check.
- Riot documents a local [Live Client Data API for League of Legends](https://developer.riotgames.com/docs/lol#game-client-api).
  That documentation is not evidence that the Android TFT client offers the
  same service. The [TFT documentation](https://developer.riotgames.com/docs/tft)
  describes match history, including `last_round`; that historical field cannot
  label the current frame-measurement window.

## Change to the investigation order

Direct client signals should be evaluated before expanding a large OCR rule
set. The previous assumption that game context must be entirely external was
too strong: the passive log experiment found real internal lifecycle and phase
signals without instrumenting the engine.

1. Prototype a local, allowlisted log reader and validate lifecycle/transition
   signals against owned screenshots across complete matches. Handle rotation,
   truncation, stale events, reconnection and app termination. Preserve raw event
   meaning and freshness rather than guessing a phase from a previous event.
2. Investigate whether `TFTRoundSubsystem`/its view model has an accessible,
   stable read-only source for current round and phase. A version-specific memory
   reader would require additional binary analysis; it was not attempted during
   this game. Access to a root shell alone does not identify those values.
3. If exact live state remains unavailable, use validated direct lifecycle
   signals alongside a smaller visual classifier. Stage digits may be readable
   with focused OCR even when localized HUD words are not. A hybrid still needs
   independent accuracy, transition rejection and collection-cost validation.

The host-side passive observer was stopped after the bounded checks. The game
was still running under the same PID. No production classifier, telemetry
contract or release was changed by this probe. The observed enum events are
evidence for a prototype, not a shipped replacement for screenshot classification.
