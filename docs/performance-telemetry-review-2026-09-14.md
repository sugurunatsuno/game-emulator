# Performance telemetry: first 1.2.3 field review

Reviewed September 14, 2026. Snapshot: September 13, 23:08:32 UTC
(September 14, 01:08:32 Europe/Paris). Launcher source: `52d7cd0`, build 52.
This is the first field review in the [recovery plan](performance-telemetry-recovery-plan.md).

There is enough evidence to prioritize classifier and collection-cost work.
There is still insufficient matched gameplay data to compare release performance.
The diagnostic release explains the existing losses; it did not change the classifier.

## Scope and checks

Read the latest cumulative checkpoint for each attempt directly from production,
without modifying server files. The snapshot contains 2,115 attempts across
1.2.0–1.2.3. Event IDs, transport addresses and other event types were excluded
from the local analysis copy. No screenshots or OCR text exist in these payloads.

The main cohort is all 704 attempts on 1.2.3; all 704 include diagnostics v1.
Their start times span September 11, 12:42:37 UTC to September 13, 22:59:12 UTC.
Two attempts precede the original public release time, 13:02 UTC on September 11.
For the separate adoption and reliability comparison, use starts after that time:
702 of 898 attempts (78.2%) use 1.2.3. Attempts are not unique players or matches.
The September 13 UTC day is incomplete at snapshot time.

Verified per-attempt conservation of measurement outcomes, sampled segments,
context outcomes, gameplay windows and dimension observations on all 704 records.
Only one latest revision is counted per stored attempt; checkpoints are not summed.
Diagnostic counters are not mixed with legacy clients' missing diagnostics.

The private, ignored analysis snapshot is in
`launcher/.build/telemetry-review-20260914/snapshot.json` in the original checkout.
SHA-256: `90b1978edad37c6d1226853bbe6e0a026dbcebafaf74b1bdeb0481bf06e97240`.
Only aggregate findings are committed here.

## Coverage

| Measure | 1.2.3 result |
| --- | ---: |
| Launch attempts / ready | 704 / 645 |
| Attempts with any measured frames | 496 |
| Attempts with recognized gameplay | 203 |
| Attempts with only unknown samples | 283 |
| Foreground measurement attempts | 3,513 |
| Successful windows | 3,077 (87.6%) |
| Missing windows | 436 (12.4%) |
| Gameplay windows | 512 (16.6% of successful windows) |
| Combat / planning / lobby / unknown windows | 438 / 74 / 31 / 2,534 |
| Unknown after 20 minutes of session age | 1,715 / 2,110 (81.3%) |
| Median successful windows per sampled attempt | 4 |
| Median gameplay windows per attempt with gameplay | 2 |

Unknown remains 82.4%, versus 81.9% in the September 8–11 baseline. Different
cohorts and observation periods prevent treating that difference as a regression.
Waiting longer has not resolved the classification gap.

There are 258 exact hardware/runtime/settings configurations in 1.2.3. Six
gameplay context groups reach the existing five-attempt display floor; each has
only one reportable variant. Only six terminal attempts meet the slow-session
eligibility rule in any context. No context has five eligible attempts.
Total recognized gameplay measurement time is 27.3 minutes across 203 attempts,
not 27.3 minutes of continuous play. Performance tables remain descriptive.

## 1. Language-dependent recognition is the clearest systematic gap

The 231 attempts requesting languages other than English or Russian contribute
1,010 measured windows: 1,008 unknown and only two recognized gameplay windows.
That is 99.8% unknown, compared with 73.8% for English/Russian. This group accounts
for 39.8% of all unknown windows, an association rather than a recoverable-share
estimate: its unknowns also include non-gameplay screens and transitions.

| Requested language | Attempts | Measured windows | Unknown windows |
| --- | ---: | ---: | ---: |
| English | 450 | 1,977 | 1,461 (73.9%) |
| Russian | 23 | 90 | 65 (72.2%) |
| Vietnamese | 62 | 189 | 189 (100%) |
| French | 58 | 155 | 153 (98.7%) |
| Korean | 33 | 89 | 89 (100%) |
| Traditional Chinese | 22 | 168 | 168 (100%) |
| Brazilian Portuguese | 13 | 215 | 215 (100%) |
| Mexican Spanish | 19 | 47 | 47 (100%) |

Requested language is the launcher setting, not a verified UI language.
French and Vietnamese are the strongest initial targets by affected attempts.
Portuguese and Traditional Chinese have many windows but greater concentration:
their top three attempts supply 53.5% and 45.8% of sampled windows respectively,
versus 21.9% for French and 21.2% for Vietnamese. Smaller language cohorts are
not individually reported here.

The code explicitly configures Vision for `en-US`/`ru-RU` and recognizes gameplay
HUD words in those languages only. In the other-language group, stage digits
were still read at 1,432 of 2,188 endpoints, while 2,151 endpoints failed the
semantic evidence gate. This points to HUD/language support, not just unreadable
stage numbers. Both OCR language configuration and semantic rules need validation.

## 2. English/Russian phase and context coverage also need work

Across all languages, 3,334 of 6,712 endpoint attempts have insufficient evidence
(49.7%, affecting 478 launch attempts). Another 683 endpoints recognize the battle
state but cannot yield a usable planning/combat phase (10.2% of endpoints, 26.2%
of battle-state endpoints; 194 affected attempts). Of those 683, 677 occur in
English/Russian. Stage-unreadable endpoints are much less common: 154 (2.3%).

The classifier uses English/Russian phase words and a timer region calibrated
for Tocker's Trials. The missing phase counter can also include deliberately
excluded `post_combat` states. Telemetry does not identify game mode, retain
screenshots, or separate every missing cue. Therefore regular-match cue gaps
are a priority hypothesis, not a measured attribution of all 683 endpoints.

Unknown accepted windows break down as follows; these reasons are exclusive:

| Context reason | Windows | Affected attempts |
| --- | ---: | ---: |
| Both endpoints unknown | 1,485 | 356 |
| Decoded screen state changed | 402 | 232 |
| One endpoint unknown | 284 | 150 |
| Observed round changed | 134 | 100 |
| Observed phase changed | 115 | 89 |
| Stable recognized non-gameplay | 110 | 83 |
| Endpoint technical failure | 4 | 4 |

Affected-attempt columns overlap. Endpoint and window denominators differ.
State changes can reflect real transitions or unstable recognition. The 110
known non-gameplay windows and legitimate transitions must remain excluded;
relabeling them as gameplay would inflate coverage without improving accuracy.

## 3. Collection cost makes useful windows sparse

Backoff extended the nominal 45–75-second delay on 3,512 of 3,513 foreground
checks (99.97%). Of 2,965 observed intervals between foreground checks, 1,898
(64.0%) were over three and at most ten minutes, and 999 (33.7%) exceeded ten
minutes. Those intervals can include background time; they are not a pure
foreground scheduling measurement.

The code intentionally targets approximately 1% collection wall-time duty:
`max(random(45...75), collectorMS / 10)` seconds. For example, 5,000 ms of
collection work extends the next delay to 500 seconds. This is the documented
budget policy, not an established unit-conversion bug. Measured collector wall
time is 0.73% of total attempt elapsed time; that is not CPU usage or proof of
negligible impact during gameplay.

Capture and classifier wall-time medians each fall in (0.5, 1] seconds; their
p95 values each fall in (1, 2.5] seconds. Before-frame screenshot-to-baseline
gaps have median (1, 2.5] seconds and p95 (2.5, 5] seconds. 36.7% exceed 2.5
seconds. Buckets cannot provide exact percentiles. These gaps support checking
stale context, but do not establish how many transitions it causes.

Reduce collection cost before changing cadence. The telemetry path currently
runs full-frame, stage and board-occupancy OCR on both screenshots. Investigate
whether the occupancy pass is needed for telemetry, and narrower recognition
regions while preserving dialog/overlay rejection. Evaluate capturing closer
to the frame baseline and deferring interpretation until after measurement.
Measure the result in controlled gameplay before relaxing any duty constraint.

## Lower-priority hypotheses and launch reliability

Only seven endpoint attempts failed technically: five helper timeouts and two
capture failures (0.1%). There were no reported missing helpers, invalid protocol
responses, unsupported dimensions, or OCR-failed responses. All 6,705 observed
dimensions match the requested profile. Poor recognition is still possible at
matching dimensions, so this does not prove every resolution/UI scale is correct.

The 436 missing frame measurements comprise 230 missing layers, 190 focus losses,
nine TimeStats failures and seven zero-frame deltas. Missing frames are separate
from the 2,534 unknown measured windows. Layer acquisition deserves a secondary
check after the larger classification gaps.

For attempts started after original public release, 1.2.3 has 38 launch failures
out of 702 (5.4%), versus 10/185 (5.4%) on 1.2.2 during the same period. No
`runtime_error` is recorded for 1.2.3. These are observational, unmatched cohorts;
they do not prove equal reliability or absence of crashes. The 406 `game_exit`
statuses in the full 1.2.3 cohort cannot distinguish crashes from ordinary exits.
There is no new aggregate signal of a mass startup regression in this snapshot.

## Local reproduction and next change

Ran a temporary Swift probe using the exact released classifier functions,
supplying ideal OCR lines without changing production code. English `4-6` +
`BUY XP` + `REROLL` and the existing Russian equivalents yield battle/planning.
Illustrative French `4-6` + `ACHETER XP` + `RELANCER`, even with a positive cyan
combat-bar signal, yields unknown with readable stage and no phase. English
stage + `BUY XP` without phase cues yields battle with no phase.

This reproduces the semantic-gate limitations independently of OCR quality. The
French tokens are synthetic examples, not captured or verified TFT UI labels.
It does not replace owned, labelled screenshots from regular matches or prove
which screen caused an individual field failure.

Next implementation sequence:

1. Collect a small owned, labelled set: regular planning/combat/carousel, Trials,
   loading/lobby/dialogs, French and Vietnamese first, then Portuguese/Traditional
   Chinese. Fix HUD and phase recognition against those examples; retain a held-out
   set and report stage/phase accuracy separately from gameplay coverage. Require
   no additional false gameplay on held-out non-gameplay examples. Version the
   classifier; keep runtime performance experiments separate.
2. Benchmark and remove unnecessary capture/OCR work, preserve transition and
   overlay rejection, and bring capture timestamps closer to the measured window.
   Verify controlled gameplay overhead before considering a cadence change.
3. Recheck field coverage and eligible contexts on the resulting release. Keep
   existing eligibility thresholds and exact comparison strata. More collection
   time alone will not repair missing language/phase support.

This review changes documentation only. Production settings, classifier, cadence
and release channels are unchanged.
