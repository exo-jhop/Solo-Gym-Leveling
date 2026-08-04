# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

"Solo: Gym Leveling" — a Godot 4.7 (Mobile renderer) Android app that turns a real gym program into an RPG-style quest/XP/rank system. GDScript throughout, no external package manager, no build step. Full product rationale lives in `docs/Solo_Gym_Leveling_App_Spec_v2.md` (core loop) and `docs/Solo_Gym_Leveling_App_Spec_v4_Onboarding_Profile.md` (onboarding/profile/program-generation) — read the relevant one before making product/UX decisions, since several implementation choices (streak forgiveness, no paywall, no penalty mechanics, no social features, calorie *direction* instead of a number) are deliberate constraints from those specs, not omissions.

## Running / testing

There is no CLI build or test runner — this is a Godot project, opened and run through the Godot 4.7 editor.

- Main scene: `scenes/lobby/lobby.tscn` (set in `project.godot`).
- Data-layer smoke test: `scenes/test/test_main.tscn` — a UI-less scene that exercises `GameManager`/`QuestManager`/`SaveManager` end-to-end (generate quests, complete them, save, reload, verify state) and prints results to the console. Run this scene directly in the editor after touching autoload logic, since there's no automated test suite.
- **Godot is installed on this machine** at `C:\Users\user\Desktop\Godot_v4.7-stable_win64.exe` — it is a portable binary on the Desktop, not on PATH and not in Program Files, so `godot` and `where godot` both fail. Don't conclude Godot is missing; invoke it by full path.
- To run from the command line: `& "C:\Users\user\Desktop\Godot_v4.7-stable_win64.exe" --path "E:\Solo Gym Leveling" res://scenes/test/test_main.tscn` (PowerShell needs the `&` call operator because the path contains spaces). Add `--headless` for console-only runs like the smoke test.

## Architecture

### Autoload singletons own all state (`scripts/autoload/`)

Scenes are thin views; all persistent/business logic lives in seven global autoloads wired in `project.godot`. Know the split before adding a feature — putting state in a scene script instead of the right autoload is the most common way to break save/load:

- **GameManager** — XP, level, rank, five core stats (STR/VIT/AGI/INT/SENSE), streak. Listens for `QuestManager.quest_completed` and applies XP/stat rewards. Owns rank thresholds, rank colors, and cosmetic milestone titles.
- **QuestManager** — builds the day's quest list from a 7-day `training_cycle` (`Array[TrainingDay]`) and tracks completion of `current_quests`. Emits `quests_generated` and `quest_completed`. Owns the "low energy mode" set-reduction toggle and the protein/creatine daily targets (the former is pushed in by `ProfileManager.apply_targets()`, not calculated here).
- **SaveManager** — serializes/deserializes everything to a single JSON blob at `user://save_data.json`. `check_new_day()` (called at startup) detects a calendar-day rollover, evaluates yesterday's streak via `GameManager.evaluate_streak()`, snapshots yesterday into `HistoryManager`, and generates today's quests. Any new persisted field must be added to both `save_game()` and `load_game()` here, with a `.get(key, default)` fallback for old saves. Also drives the `HunterProfile` migration path: a save with no `hunter_profile` key calls `ProfileManager.migrate_legacy_save()` instead of failing or reopening onboarding.
- **HistoryManager** — day-by-day completed-quest history (`date -> DailyLog`) for the Training Log/calendar view. Does **not** include today — today lives in `QuestManager.current_quests` until the day rolls over.
- **PRTracker** — per-exercise personal records, kept separate from `HunterStats` on purpose. A completion's weight/reps metric is decided per-completion (`logged_weight > 0.0` → "weight", else "reps") rather than being a static property of the exercise, and the two metrics are never compared against each other.
- **ProfileManager** — owns the Hunter's intake profile (`HunterProfile`): goal, weight, days/week, equipment access, and whether onboarding is complete. `Lobby` checks `needs_onboarding()` at startup and routes to `scenes/onboarding/` before anything else if the profile isn't set up. `just_migrated` is unpersisted, session-only scratch state: set for one launch right after a legacy-save migration so `Lobby` can route to Settings > Profile once for the user to confirm the guessed weight, then cleared so it doesn't fire again.
- **NotificationManager** — per-category reminder hours/enabled flags. This is an **in-app banner only** shown when the app is foregrounded after a category's reminder hour with quests still incomplete — Godot has no core OS-level local-notification API, and this project doesn't have the native Android plugin/custom Gradle build that would require. Don't assume it fires while the app is closed.

### Resources (`scripts/resources/`)

Plain `Resource` subclasses used as data records, not scene-attached nodes: `Quest`, `Exercise`, `TrainingDay`, `HunterStats`, `DailyLog`, `HunterProfile`. Each implements `to_dict()` / `from_dict()` (static) for the JSON save format — keep these in sync manually when adding fields, there's no serialization framework doing it for you. `from_dict()` should tolerate and discard keys that no longer exist (see `HunterProfile.from_dict()` dropping legacy `height_cm`/`age`) rather than erroring, so old saves keep loading.

Quest lift-reduction fields (`exercise_name`, `rep_range`, `original_target_value`) are stored as real data on `Quest` rather than parsed back out of the display `title` string — follow that pattern rather than deriving state from formatted text.

### Program generation (`scripts/data/`)

- **ProgramGenerator** (`class_name ProgramGenerator`, static) — builds a 7-day `training_cycle` (same shape `QuestManager` expects) from `days_per_week`/`goal`/`equipment_access`, pulling exercises from `ExerciseCatalog`. Only invoked explicitly: once at the end of onboarding, and later via Settings' "Regenerate Program" button — never automatically when a profile field changes, so editing your profile mid-cycle doesn't silently rewrite today's plan.
- **ExerciseCatalog** (`class_name ExerciseCatalog`, static) — read-only lookup of known exercises by muscle group. Only powers the Settings "Swap exercise" picker and `ProgramGenerator`'s pools — it is *not* wired into quest generation, XP, or PR tracking, where exercise identity stays free-text.

### Scenes (`scenes/`)

Each screen is a `Control`-derived `.tscn` + `.gd` pair: `lobby`, `home`, `quest_detail`, `stats` (includes `radar_chart.gd` for the five-stat visualization, `rank_dial.gd` for the radial rank gauge, and `pr_sparkline.gd`), `training_log`, `weekly_summary` (includes `week_bars.gd`), `settings`, `system_popup`, and `onboarding/`

Chart-style components live next to the screen that owns them rather than in `scripts/ui/`, and take their data through a setter (`set_values`, `set_state`, `set_days`) instead of reading autoloads — they stay renderers, so the screen keeps the domain logic. Every one is a custom `_draw()`; there is no charting addon, and the design system's specifics (chamfered bars, gradient area fill under a line, rank-tier hexagons) wouldn't come from one anyway.

Two mobile constraints from the design system are worth knowing before laying out a screen: the 1080px-wide design canvas is 360dp, so the **48dp minimum touch target is 144 canvas px** (declared as a local `TOUCH_TARGET` const on the screens that build controls in code), and screens reserve ~80px top / ~88px bottom margin for the status bar and gesture nav. A 7-column month grid can't reach 144px per cell at any usable side margin — `training_log.gd` documents that tradeoff where it makes it. (`onboarding_welcome` → `onboarding_goal` → `onboarding_metrics` → `onboarding_confirmation`, first-launch only, gated by `ProfileManager.needs_onboarding()`). Navigation is direct `get_tree().change_scene_to_file(...)` calls, no router/nav-stack abstraction. `system_popup.gd` is an autoloaded scene (not a node autoload) reserved specifically for Level-up/Rank-up moments per the spec's visual-hierarchy rules — routine quest completion should stay a lightweight toast, not reuse this popup.

### Data flow for "complete a quest"

`Home` UI → `QuestManager.complete_quest(id, ...)` → emits `quest_completed` → `GameManager` (XP/stats) and `PRTracker` (records) both react independently as signal listeners → UI screens re-render on `stats_changed`/`quests_generated`. When adding a new quest-completion side effect, hook into the `quest_completed` signal rather than calling into it from `QuestManager` directly, to keep these systems decoupled.

### Shared UI primitives (`scripts/ui/`)

These are the design system's building blocks, all `class_name`-registered globals with no scene of their own. Reach for one of these before hand-rolling a shape or a color in a screen script — the visual language only holds together because every screen draws from the same set:

- **`SystemPalette`** (static) — the design system v2 palette as semantic tokens (`PRIMARY`, `SUCCESS`, `GOLD`, `WARNING`, `SURFACE`, `DIVIDER`, `TEXT`, `TEXT_SECONDARY`) plus `alpha(color, a)`. New code should reference these rather than re-declaring `Color(0.0, 0.721569, 1.0, 1.0)`; the local `const PRIMARY_ACCENT`-style copies still in `lobby.gd`/`home.gd`/`quest_detail.gd` are legacy duplicates of the same values, not a separate palette. Note the deliberate split: rank-tier colors are a *different* system and stay in `GameManager.RANK_COLORS`, since the spec reserves them for rank contexts.
- **`HudCard`** (static) — card factory. `style()`/`apply(panel)` build a `ChamferedStyleBox` and set its padding, so a `PanelContainer` no longer needs a `MarginContainer` wrapper just for inset; `row_style()` is the toned-down variant for repeated list rows (a full-strength shadow and bloom repeated down a list competes with the content); `metric_tile()` is the big-number KPI tile used by the Weekly Summary and Training Log rollups. `apply()` returns the box, since rank-accented cards recolor it later.
- **`ChamferedStyleBox`** (`extends StyleBox`) — the signature card shape: top-right/bottom-left corners cut at 45°, top-left/bottom-right square, with a colored accent line tracing just the chamfered edges. `StyleBoxFlat.corner_radius` can only round corners, not angle-cut them, hence the custom `_draw()`. Drop it onto any `Panel`/`PanelContainer` via `add_theme_stylebox_override("panel", ...)`. Content margins come from `StyleBox`'s native `content_margin_*` properties (don't redeclare them); `Button` styling needs those set explicitly on the instance since buttons have no margin-wrapping container.
- **`NavButtonStyle`** (static) — wraps `ChamferedStyleBox` into the normal/hover/pressed/focus/**disabled** set every button needs (the disabled box matters: without it the theme's rounded-rect `StyleBoxFlat` shows through and a button changes *shape* when it greys out). `apply(button)` with no optional args is the plain "Back" button on every screen; the optional `accent`/`margins`/`emphasis` args cover accent recoloring, `ICON_CONTENT_MARGIN` for a leading glyph, and `emphasis` for a screen's single primary CTA. `apply_icon(button, accent)` is the separate variant for square icon-only buttons — the card-sized chamfer and bloom are proportioned for a wide panel and visibly break down on a 144px square.
- **`HudGlyph`** (`extends Control`) — procedural line-art icons drawn over a normalized 0..1 space. The project ships no icon set and the design system bars emoji as structural icons, so add a `Shape` enum entry and a `_draw_*` method rather than importing a raster icon. Ignores mouse input, so it can be parented straight to a `Button`.
- **`RankHexBadge`** (`extends Control`) — the rank hexagon (fill, rank-colored border, centered rank letter) shared by Home and Lobby.
- **`PressFeedback`** (static) — `attach(button)` once per button for the scale-down + click-sound press response.

## Conventions observed in the code

- GDScript static typing is used throughout (`var x: Type`, typed `Array[T]`) — match this in new code.
- Comments explain *why* (spec references, non-obvious invariants), not *what* — follow that bar rather than narrating obvious code.
- `.uid` files next to every `.gd` file are Godot-generated; don't hand-edit or worry about them.
- Cross-scene scratch state (a value set by one scene and read/cleared by another, e.g. `QuestManager.selected_quest_id`, `ProfileManager.just_migrated`) lives directly on the relevant autoload as a plain var, not persisted, not routed through signals.
