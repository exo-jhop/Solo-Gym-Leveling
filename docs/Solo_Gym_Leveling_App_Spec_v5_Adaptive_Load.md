# Solo: Gym Leveling — v5: Adaptive Daily Load

Implementation plan for closing the "does the app adjust quests based on gathered feedback?" gap.

**Status:** plan only, nothing in this document is built yet.

---

## 1. Correction to the premise

The app is **not** feedback-blind today. There is already one working adaptive loop, added after
the v4 spec and undocumented in `docs/`:

**Weekly recalibration** — `scripts/data/program_recalibrator.gd`

| Aspect | Current behaviour |
| --- | --- |
| Input signal | Logged bodyweight trend: mean of the last 2 logs vs. the 2 before them (`ProgramRecalibrator.evaluate`) |
| Minimum data | `MIN_LOGS := 4` bodyweight-quest completions |
| Cadence | At most once per `SaveManager.RECALIBRATION_INTERVAL_DAYS` (7), evaluated during day rollover in `check_new_day()` → `_check_recalibration()` |
| Goals covered | `build_muscle`, `lose_fat` only — `get_stronger` / `general_fitness` return `{}` immediately (`program_recalibrator.gd:24`) |
| Effect if accepted | `QuestManager.apply_recalibration()`: `+SET_DELTA` set to **every** lift exercise in `training_cycle` (capped at `MAX_SETS := 6`), profile `weight_kg` synced to the observed average, `calorie_intensity` → `"increased"` |
| UX | Suggestion staged on `QuestManager.pending_recalibration` → `RecalibrationPopup` autoload shows Accept/Dismiss |
| Persistence | `last_recalibration_date` is saved; `pending_recalibration` is deliberately **not** saved |

So the correct framing of the gap is narrower and more interesting than "there's no adaptation."

---

## 2. What's actually missing

### 2.1 Adaptation only ever pushes harder

`apply_recalibration()` adds sets. Nothing in the codebase ever removes them. The only
downward lever is `QuestManager.set_low_energy_mode()`, and it is:

- **manual** — the user must tick `LowEnergyToggle` on Home (`home.gd:301`)
- **single-day** — `generate_daily_quests()` resets `low_energy_mode = false` on every rollover
  (`quest_manager.gd:110`), so a genuinely rough week requires re-ticking it every single day
- **not a trigger for anything** — `was_reduced_intensity` is written into `DailyLog` and then
  never read by any decision logic

v1 spec §2.6 ("Adaptive Difficulty (Post-MVP)") explicitly asked for the missing half:

> If user skips lift quests 2+ sessions in a row, surface a "recovery week" prompt instead of
> guilt messaging

That was flagged as a v2 feature and never built. v2 §4.3 shipped the manual toggle as the
interim "manual out" instead.

### 2.2 Adherence and fatigue data is collected but unused

Every signal needed is already persisted in `DailyLog` and ignored:

| Field | Written by | Read by any adaptation logic? |
| --- | --- | --- |
| `quests_completed` / `quests_total` | `HistoryManager.record_day` | No |
| `quest_summaries[].category` / `.completed` | `HistoryManager.record_day` | No |
| `was_reduced_intensity` | `record_day(..., QuestManager.low_energy_mode)` | No |
| `is_missed` | `HistoryManager.record_missed_day` | No |
| `PRTracker.pr_history` | `PRTracker._on_quest_completed` | No — Stats sparkline only |

`HistoryManager` exposes exactly one analytical read helper (`recent_bodyweight_logs`), built
solely for `ProgramRecalibrator`.

### 2.3 Two of four goals get zero adaptation

`get_stronger` and `general_fitness` map to `maintenance` calories and are never evaluated —
correctly, since scale weight doesn't measure those goals. But adherence and PR progression do,
and neither is used, so those users currently have no adaptive path at all.

### 2.4 The weekly check is often data-starved

Bodyweight quests only appear on `QuestManager.BODYWEIGHT_LOG_DAYS := [0, 3]` — two per 7-day
cycle. `MIN_LOGS := 4` therefore needs ~2 weeks of consistent logging, while the check itself
runs every 7 days. Early weeks silently no-op.

---

## 3. Design constraints this plan must respect

Pulled from the specs, not invented here:

1. **Detect → suggest → user opts in. Never silently rewrite the plan.**
   Precedents: v4 §101 ("no auto-adjusting protein target over time without user re-input");
   `ProgramGenerator` runs only at onboarding and on an explicit Settings button;
   `apply_recalibration` only runs from an Accept press.
2. **No penalty, guilt, or fear framing** (v2 §6 "Rejected: Penalty systems"). A recovery prompt
   is an offer, never a reprimand, and never phrased as falling behind.
3. **Reuse the existing set-reduction machinery.** `set_low_energy_mode()` already handles
   target reduction and reversal via `original_target_value`. Do not build a second difficulty
   system alongside it.
4. **No new recovery-tracking surface.** v2 §4.3 states recovery tracking is "out of scope for a
   personal app." No RPE prompts, soreness scales, or sleep input.
5. **One decision per launch.** Two competing modal choices on one cold start is unacceptable UX.
6. **Save-format discipline** (CLAUDE.md): every new persisted field must be added to *both*
   `save_game()` and `load_game()` with a `.get(key, default)` fallback.

---

## 4. Proposed feature: Adaptive Daily Load

### 4.1 Cadence — resolving "daily"

The literal ask is daily adjustment. The recommendation is to split evaluation from suggestion:

- **Evaluate daily** during `check_new_day()`. Cheap (a bounded backward walk over
  `HistoryManager.days`) and catches the "2 missed lift sessions" trigger the day it becomes true
  instead of up to 6 days later.
- **Suggest at most every `LOAD_ADJUSTMENT_COOLDOWN_DAYS := 5`.** A prompt on every launch is
  nagging, which is the failure mode v2 §4.1 already guards against for notifications
  ("don't nag someone who already did the work").
- **A dismissal starts the cooldown too**, so declining buys real quiet, not a re-ask tomorrow.

An accepted *recovery week* is itself multi-day, so it needs no separate prompt suppression
beyond the cooldown.

### 4.2 New static class: `scripts/data/load_adjuster.gd`

Mirrors `ProgramRecalibrator` exactly in shape — `class_name LoadAdjuster`, `extends RefCounted`,
one static `evaluate()` that takes plain values in and returns a suggestion `Dictionary` or `{}`.
No autoload reads inside it, which is what makes `ProgramRecalibrator` testable and should be
preserved here.

```gdscript
class_name LoadAdjuster
extends RefCounted

const MISSED_SESSIONS_TRIGGER := 2      # v1 spec 2.6
const RECOVERY_WEEK_DAYS := 3           # training days, not calendar days
const REDUCED_DAYS_WINDOW := 7
const REDUCED_DAYS_TRIGGER := 3
const PROGRESS_WINDOW_DAYS := 14
const PROGRESS_RATE_TRIGGER := 0.9
const SET_DELTA := 1
const MIN_SETS := 2
const MAX_SETS := 6                     # keep identical to ProgramRecalibrator.MAX_SETS

static func evaluate(signals: Dictionary) -> Dictionary
```

`signals` is assembled by the caller (`SaveManager`) from `HistoryManager` helpers, keeping
`LoadAdjuster` a pure function:
`{missed_lift_sessions, reduced_days, lift_completion_rate, training_days_seen}`.

### 4.3 Decision table

Evaluated in priority order; **at most one** suggestion is ever returned.

| Priority | Condition | `kind` | Effect if accepted |
| --- | --- | --- | --- |
| 1 | `missed_lift_sessions >= 2` | `recovery_week` | `QuestManager.recovery_days_remaining = 3` — auto-applies the existing single-set reduction for the next 3 training days. `training_cycle` is left untouched. |
| 2 | `reduced_days >= 3` within last 7 | `reduce_volume` | `-1` set on every lift exercise in `training_cycle`, floored at `MIN_SETS`. A persistent change, the mirror of `apply_recalibration`. |
| 3 | `lift_completion_rate >= 0.9` over 14 days **and** `reduced_days == 0` **and** `training_days_seen >= 6` | `ready_to_progress` | `+1` set on every lift exercise, capped at `MAX_SETS`. Gives `get_stronger` / `general_fitness` their first adaptive path. |

Rationale for the ordering: fatigue outranks ambition. Someone skipping sessions needs rest
offered before volume is either raised or permanently cut.

`training_days_seen >= 6` guards priority 3 against firing off a near-empty history, the same
role `MIN_LOGS` plays in `ProgramRecalibrator`.

### 4.4 New `HistoryManager` read helpers

Pure reads over `days`, modelled on `recent_bodyweight_logs`. `HistoryManager` stays a store with
read helpers; no decisions live here.

```gdscript
## Consecutive most-recent training days on which no lift quest was completed.
## Walks backward from the newest recorded day and stops at the first day with a
## completed lift. Rest days are skipped (they carry no lift signal). Days with
## is_missed set are also skipped rather than counted — record_missed_day() writes
## an empty quest_summaries, so an unopened day is an absence, not evidence of fatigue.
func consecutive_missed_lift_sessions() -> int

## How many of the last `limit` recorded days had was_reduced_intensity set.
func reduced_intensity_count(limit: int) -> int

## Completed lift summaries / total lift summaries across the last `limit` recorded
## days. Returns -1.0 when no lift quests appear in the window, so callers can
## distinguish "no data" from "0% completion".
func lift_completion_rate(limit: int) -> float

## Count of recorded days in the last `limit` that contained at least one lift quest.
func training_days_seen(limit: int) -> int
```

**Note on `is_missed` (a real correctness trap):** `record_missed_day()` produces a `DailyLog`
with empty `quest_summaries`, and `check_new_day()` can backfill up to
`MAX_BACKFILL_DAYS := 30` of them. If those counted as missed lift sessions, returning from a
two-week holiday would instantly trigger a recovery week — cutting volume for someone who is
detrained but rested, which is backwards. Skipping them means the signal only accrues from days
the user was actually present and chose not to lift. Layoff re-entry is a distinct problem;
see §9.

### 4.5 `QuestManager` changes

**New state:**

```gdscript
# Remaining training days in an accepted recovery week (v5). Persisted — unlike
# pending_* scratch state, an accepted multi-day commitment must survive both restarts
# and day rollovers, which is exactly what low_energy_mode alone cannot do.
var recovery_days_remaining: int = 0

# Staged by SaveManager's daily check (see LoadAdjuster). Not persisted, matching
# pending_recalibration: if the app closes before the user answers, it is simply
# re-evaluated on the next rollover rather than reappearing stale.
var pending_load_adjustment: Dictionary = {}
```

**Recovery-day re-application — mind the ordering.** `set_low_energy_mode()` cannot simply be
called after `generate_daily_quests()`:

- it early-returns when `enabled == low_energy_mode` (`quest_manager.gd:204`)
- it mutates `current_quests`, so it must run after the list is built
- it emits `quests_generated` itself, so calling it right after `generate_daily_quests()`
  produces a **double emit** on every rollover of a recovery week

Cleanest fix: apply the reduction **inline inside `generate_daily_quests()`**, before its single
`quests_generated.emit()` at line 140. Extract the per-quest reduction loop out of
`set_low_energy_mode()` into a shared private `_apply_set_reduction(enabled: bool)` that does not
emit, and have both call sites use it. `set_low_energy_mode()` keeps its guard clauses and its
emit; `generate_daily_quests()` decrements `recovery_days_remaining` and calls the shared helper
only when the day has lift quests (a rest day must not consume a recovery day).

**New methods, mirroring `apply_recalibration` / `dismiss_recalibration`:**

```gdscript
## Applies an accepted load adjustment. recovery_week only sets a counter — the
## training_cycle is untouched, since a recovery week is a temporary dial, not a
## program change. reduce_volume/ready_to_progress do edit the cycle, the same way
## apply_recalibration does. Caller is expected to save afterward.
func apply_load_adjustment(suggestion: Dictionary) -> void

func dismiss_load_adjustment() -> void

## True while a recovery week is in progress, for Home's indicator and Settings' cancel.
func recovery_week_active() -> bool

## User override: cancels the remaining recovery week (see home.gd interaction note).
func cancel_recovery_week() -> void
```

### 4.6 `SaveManager` changes

**New persisted fields** — added to `save_game()`'s dictionary and read back in `load_game()`
with `.get()` defaults, per CLAUDE.md:

```gdscript
"last_load_adjustment_date": last_load_adjustment_date,     # String, "" bootstraps blank
"recovery_days_remaining": QuestManager.recovery_days_remaining,
```

```gdscript
last_load_adjustment_date = data.get("last_load_adjustment_date", "")
QuestManager.recovery_days_remaining = data.get("recovery_days_remaining", 0)
```

`last_load_adjustment_date` bootstraps from `""` and is set to `today` on first encounter without
firing — the same guard `_check_recalibration` uses (`save_manager.gd:181`) so a long-idle
reinstall doesn't immediately fire a stale suggestion.

**New check, called from `check_new_day()`:**

```gdscript
const LOAD_ADJUSTMENT_COOLDOWN_DAYS := 5

func _check_load_adjustment(today: String) -> void
```

**Call ordering inside `check_new_day()`** matters. It must run *after*
`HistoryManager.record_day(...)` (line 162) so yesterday is part of the window, and *before*
`QuestManager.generate_daily_quests()` (line 172) so an accepted recovery week's counter is
already in place when today's quests are built:

```
GameManager.evaluate_streak(days_gap)
HistoryManager.record_day(...)
_backfill missed days
_check_load_adjustment(today)     # NEW — before recalibration
_check_recalibration(today)
_check_streak_freeze_replenish(today)
QuestManager.generate_daily_quests()
```

**Conflict gating — the part most likely to be got wrong:**

1. `_check_load_adjustment` returns immediately if `QuestManager.pending_recalibration` is
   non-empty (one decision per launch, §3.5). Load adjustment runs first, so on a week where both
   would fire, `_check_recalibration` is the one that yields.
2. `_check_recalibration` gains an early return when `QuestManager.recovery_week_active()` or a
   `pending_load_adjustment` is staged. Escalating volume during a recovery week directly
   contradicts it.
3. `reduce_volume` and `ready_to_progress` both edit `training_cycle`, exactly like
   `apply_recalibration`. Because both are capped/floored (`MAX_SETS` / `MIN_SETS`), repeated
   accepts cannot drift volume unbounded in either direction.

### 4.7 UI: generalize the existing popup, don't add a second one

`RecalibrationPopup` is already the project's accept/decline modal, already an autoload
(`project.godot`), and already correctly distinguished from `SystemPopup` (which is
tap-to-acknowledge, reserved for Level-up/Rank-up/PR). Adding a near-identical second scene would
duplicate it for no reason.

Changes to `scenes/recalibration_popup/recalibration_popup.gd`:

- `check_pending()` checks `pending_recalibration` first, then `pending_load_adjustment`.
- Store which source was staged, and dispatch Accept to `apply_recalibration()` or
  `apply_load_adjustment()` accordingly. Dismiss dispatches the same way.
- `_suggestion["message"]` already drives the label, so `LoadAdjuster` supplies its own copy the
  same way `ProgramRecalibrator._message()` does.
- Update the docstring to say it serves both checks.

Renaming the scene/autoload to something neutral (`ChoicePopup`) is *optional* and deliberately
not part of this plan — it touches `project.godot` and the `test_main` debug hook for cosmetic
gain.

**Message copy** (v2 §6, no guilt framing):

| `kind` | Copy |
| --- | --- |
| `recovery_week` | "Rough stretch — want to run the next 3 sessions a set lighter?" |
| `reduce_volume` | "You've been going lighter often. Want to drop a set from the program so it fits properly?" |
| `ready_to_progress` | "You've hit nearly every session lately. Ready to add a set?" |

None reference missed days, streaks, or failure.

### 4.8 Home interaction

`home.gd:137-139` currently drives `LowEnergyToggle` from `has_lift_quests()`,
`low_energy_mode`, and `any_lift_quest_completed()`. During a recovery week the toggle will
already read as on, because `generate_daily_quests()` applied the reduction.

Required addition: **manually toggling it off must cancel the remaining recovery week.**
Otherwise the reduction silently returns tomorrow and the toggle appears broken. In
`_on_low_energy_toggled(pressed)`, when `pressed == false` and `recovery_week_active()`, call
`QuestManager.cancel_recovery_week()` before/alongside `set_low_energy_mode(false)`, then save.

Optional and low-cost: a small "Recovery week — 2 sessions left" label beside the toggle, using
`HudCard.row_style()` and `SystemPalette.TEXT_SECONDARY`. Without it, an auto-applied reduction
has no on-screen explanation, which reads as a bug.

### 4.9 Settings escape hatch

An accepted multi-day commitment needs a visible exit that isn't Home's toggle. Add a row to
Settings, visible only while `recovery_week_active()`, showing sessions remaining with a Cancel
button calling `cancel_recovery_week()` + `SaveManager.save_game()`. Mirrors how "Regenerate
Program" is an explicit user action.

---

## 5. Build order

Sequenced so each step is independently verifiable, mirroring v2 §8's style.

1. **`HistoryManager` read helpers** (§4.4). Pure additions, zero behaviour change — can be
   verified in isolation against synthetic `days` entries.
2. **`LoadAdjuster`** (§4.2/4.3) + its checks in `test_main.gd`. Still inert: nothing calls it.
3. **`QuestManager` refactor + state** (§4.5). Extract `_apply_set_reduction()`, add
   `recovery_days_remaining` handling in `generate_daily_quests()`, add the apply/dismiss/cancel
   methods. Verify the existing manual toggle still works and does not double-emit.
4. **`SaveManager` wiring** (§4.6): persist both fields, add `_check_load_adjustment()`, add the
   conflict gates. First point at which the feature is live.
5. **Popup generalization** (§4.7).
6. **Home interaction** (§4.8) — the override-cancels rule is functionally required, the
   indicator label is strongly recommended.
7. **Settings escape hatch** (§4.9).

Steps 1–3 are safe to land without the feature being reachable, which keeps the risky part
(step 4's interaction with the existing weekly check) to a single small diff.

---

## 6. Test plan

No automated test suite exists, so this follows the project's actual pattern: extend
`scenes/test/test_main.tscn` (`scenes/test/test_main.gd`), which already prints to console and
calls `get_tree().quit()`.

```
& "C:\Users\user\Desktop\Godot_v4.7-stable_win64.exe" --path "E:\Solo Gym Leveling" --headless res://scenes/test/test_main.tscn
```

Because `LoadAdjuster.evaluate()` is a pure static over a plain `Dictionary`, the decision table
can be exercised without touching the save file or `HistoryManager` at all.

**Cases to cover:**

| # | Setup | Expected |
| --- | --- | --- |
| 1 | `missed_lift_sessions = 2` | `kind == "recovery_week"` |
| 2 | `missed_lift_sessions = 1` | `{}` |
| 3 | `missed_lift_sessions = 2` **and** `reduced_days = 5` | `recovery_week` (priority 1 wins) |
| 4 | `reduced_days = 3`, no missed | `reduce_volume` |
| 5 | `lift_completion_rate = 1.0`, `training_days_seen = 8`, `reduced_days = 0` | `ready_to_progress` |
| 6 | `lift_completion_rate = 1.0`, `training_days_seen = 3` | `{}` (insufficient history) |
| 7 | `lift_completion_rate = 1.0`, `reduced_days = 2` | `{}` (reductions disqualify progression) |

**Integration checks needing seeded `HistoryManager.days`:**

- Backfilled `is_missed` days do **not** produce a `recovery_week` (§4.4 trap).
- `consecutive_missed_lift_sessions()` skips rest days without resetting the count.
- `lift_completion_rate()` returns `-1.0` on a window containing no lift quests.

**Integration checks needing rollover simulation:**

- Accept `recovery_week` → next `generate_daily_quests()` yields lift targets one set lower,
  `recovery_days_remaining` decremented, and `quests_generated` fired exactly once.
- A rest day inside a recovery week does **not** consume a counter day.
- `recovery_days_remaining` survives `save_game()` → `load_game()`.
- With `pending_recalibration` staged, `_check_load_adjustment` stages nothing.
- With a recovery week active, `_check_recalibration` stages nothing.
- Accept `reduce_volume` twice in a row → sets floor at `MIN_SETS`, never below.

**Device/editor check:** run `scenes/lobby/lobby.tscn` with a recovery week active and confirm
the Home toggle state, the indicator label, and that toggling off cancels the week.

---

## 7. Save-format compatibility

Both new keys are additive and read with `.get()` defaults, so an existing save loads unchanged:
`last_load_adjustment_date` → `""` (bootstraps without firing),
`recovery_days_remaining` → `0` (no recovery week). No `Resource` class gains a field, so no
`to_dict()` / `from_dict()` pair needs touching — a deliberate simplification over the
alternative of storing per-day adjustment history.

`SAVE_VERSION` stays `1`; the existing scheme is additive-with-fallback rather than versioned
migration (see the `hunter_profile` migration path for how a real breaking change was handled).

---

## 8. Explicitly out of scope

- **No RPE / soreness / sleep input.** v2 §4.3 rules recovery tracking out; this plan infers
  fatigue from behaviour already logged rather than adding a data-collection surface.
- **No per-exercise adaptation.** Adjustments apply cycle-wide, matching `apply_recalibration`.
  Per-lift autoregulation needs per-exercise performance history that `pr_history` only holds
  at new-best moments, not per session.
- **No automatic `ProgramGenerator` re-run.** The 7-day split is only ever rebuilt from
  onboarding or the explicit Settings button.
- **No silent application of anything.** Every effect in §4.3 requires an Accept press.
- **No penalty framing, streak consequences, or notification of a missed session.**
- **No `PRTracker`-driven stagnation signal** in this iteration — see §9.

---

## 9. Open questions and risks

1. **Thresholds are estimates.** `2` missed sessions comes from v1 §2.6; `3`-in-`7` reduced days
   and the `0.9` completion rate do not come from the specs. They should be treated as tunable
   constants and revisited against real usage.
2. **Layoff re-entry is unhandled.** §4.4 deliberately excludes `is_missed` days, which means
   returning after a long break produces no suggestion at all. A dedicated
   `return_from_layoff` kind (offer a lighter re-entry week after an N-day gap, using the
   `days_gap` already computed in `check_new_day()`) is the natural follow-up, but it is a
   different signal with different copy and is not part of this plan.
3. **Two adaptive systems now share one popup and one `training_cycle`.** The gating in §4.6
   keeps them from firing together, but they can still alternate week to week (recalibration
   +1 set, then `reduce_volume` -1 set). Worth watching; a possible later simplification is
   folding `ProgramRecalibrator` into `LoadAdjuster` as a fourth priority row, so one component
   owns all volume decisions.
4. **`ready_to_progress` overlaps `apply_recalibration`'s escalation** for `build_muscle` /
   `lose_fat` users, who could receive both paths to `+1` set. The `MAX_SETS := 6` cap bounds the
   damage. Restricting `ready_to_progress` to `get_stronger` / `general_fitness` — the goals with
   no adaptation today — is the more conservative option and is worth considering before step 4.
5. **Recovery week counts training days, not calendar days**, so an inactive user could hold an
   open recovery week for weeks. Consider expiring it after ~14 calendar days.
