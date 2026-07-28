# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

"Solo: Gym Leveling" — a Godot 4.7 (Mobile renderer) Android app that turns a real gym program into an RPG-style quest/XP/rank system. GDScript throughout, no external package manager, no build step. Full product rationale lives in `docs/Solo_Gym_Leveling_App_Spec_v2.md` — read it before making product/UX decisions, since several implementation choices (streak forgiveness, no paywall, no penalty mechanics, no social features) are deliberate constraints from that spec, not omissions.

## Running / testing

There is no CLI build or test runner — this is a Godot project, opened and run through the Godot 4.7 editor.

- Main scene: `scenes/lobby/lobby.tscn` (set in `project.godot`).
- Data-layer smoke test: `scenes/test/test_main.tscn` — a UI-less scene that exercises `GameManager`/`QuestManager`/`SaveManager` end-to-end (generate quests, complete them, save, reload, verify state) and prints results to the console. Run this scene directly in the editor after touching autoload logic, since there's no automated test suite.
- To run from the command line: `godot --path "E:\Solo Gym Leveling" res://scenes/test/test_main.tscn` (requires the Godot 4.7 editor binary on PATH).

## Architecture

### Autoload singletons own all state (`scripts/autoload/`)

Scenes are thin views; all persistent/business logic lives in six global autoloads wired in `project.godot`. Know the split before adding a feature — putting state in a scene script instead of the right autoload is the most common way to break save/load:

- **GameManager** — XP, level, rank, five core stats (STR/VIT/AGI/INT/SENSE), streak. Listens for `QuestManager.quest_completed` and applies XP/stat rewards. Owns rank thresholds, rank colors, and cosmetic milestone titles.
- **QuestManager** — builds the day's quest list from a 7-day `training_cycle` (`Array[TrainingDay]`) and tracks completion of `current_quests`. Emits `quests_generated` and `quest_completed`. Owns the "low energy mode" set-reduction toggle.
- **SaveManager** — serializes/deserializes everything to a single JSON blob at `user://save_data.json`. `check_new_day()` (called at startup) detects a calendar-day rollover, evaluates yesterday's streak via `GameManager.evaluate_streak()`, snapshots yesterday into `HistoryManager`, and generates today's quests. Any new persisted field must be added to both `save_game()` and `load_game()` here, with a `.get(key, default)` fallback for old saves.
- **HistoryManager** — day-by-day completed-quest history (`date -> DailyLog`) for the Training Log/calendar view. Does **not** include today — today lives in `QuestManager.current_quests` until the day rolls over.
- **PRTracker** — per-exercise personal records, kept separate from `HunterStats` on purpose. A completion's weight/reps metric is decided per-completion (`logged_weight > 0.0` → "weight", else "reps") rather than being a static property of the exercise, and the two metrics are never compared against each other.
- **NotificationManager** — per-category reminder hours/enabled flags. This is an **in-app banner only** shown when the app is foregrounded after a category's reminder hour with quests still incomplete — Godot has no core OS-level local-notification API, and this project doesn't have the native Android plugin/custom Gradle build that would require. Don't assume it fires while the app is closed.

### Resources (`scripts/resources/`)

Plain `Resource` subclasses used as data records, not scene-attached nodes: `Quest`, `Exercise`, `TrainingDay`, `HunterStats`, `DailyLog`. Each implements `to_dict()` / `from_dict()` (static) for the JSON save format — keep these in sync manually when adding fields, there's no serialization framework doing it for you.

Quest lift-reduction fields (`exercise_name`, `rep_range`, `original_target_value`) are stored as real data on `Quest` rather than parsed back out of the display `title` string — follow that pattern rather than deriving state from formatted text.

### Scenes (`scenes/`)

Each screen is a `Control`-derived `.tscn` + `.gd` pair: `lobby`, `home`, `quest_detail`, `stats` (includes `radar_chart.gd` for the five-stat visualization), `training_log`, `weekly_summary`, `settings`, `system_popup`. Navigation is direct `get_tree().change_scene_to_file(...)` calls, no router/nav-stack abstraction. `system_popup.gd` is an autoloaded scene (not a node autoload) reserved specifically for Level-up/Rank-up moments per the spec's visual-hierarchy rules — routine quest completion should stay a lightweight toast, not reuse this popup.

### Data flow for "complete a quest"

`Home` UI → `QuestManager.complete_quest(id, ...)` → emits `quest_completed` → `GameManager` (XP/stats) and `PRTracker` (records) both react independently as signal listeners → UI screens re-render on `stats_changed`/`quests_generated`. When adding a new quest-completion side effect, hook into the `quest_completed` signal rather than calling into it from `QuestManager` directly, to keep these systems decoupled.

## Conventions observed in the code

- GDScript static typing is used throughout (`var x: Type`, typed `Array[T]`) — match this in new code.
- Comments explain *why* (spec references, non-obvious invariants), not *what* — follow that bar rather than narrating obvious code.
- `.uid` files next to every `.gd` file are Godot-generated; don't hand-edit or worry about them.
