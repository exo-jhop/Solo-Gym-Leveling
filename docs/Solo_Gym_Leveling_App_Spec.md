# Solo: Gym Leveling — Fitness RPG App Spec
**Engine:** Godot 4.7 | **Platform:** Android (mobile-first) | **Theme:** Solo Leveling inspired

---

## 1. Concept

A personal fitness tracker skinned as "The System" from Solo Leveling. The user is a Hunter. Real workouts, meals, and supplements are Daily Quests. Completing them grants XP, raises Stats, and moves the Hunter through Ranks (E to S).

**Core differentiator:** quests are generated from the user's *actual* training program (Upper/Lower split + nutrition/supplement targets), not a generic canned routine. This avoids the two most common failure points in existing Solo Leveling apps: paywalled core save functionality, and fixed workouts that ignore recovery state.

---

## 2. Core Systems

### 2.1 Stats
Five stats, mapped from training data:

| Stat | Driven by |
|------|-----------|
| STR | Upper body lift volume/progression |
| VIT | Lower body lift volume/progression + bodyweight trend |
| AGI | Workout completion streak |
| INT | Nutrition/protein target hits |
| SENSE | Supplement consistency (creatine, whey) |

Each stat has a numeric value (starts at 10). Completing related quests adds small increments. Stats are cosmetic/motivational, not gated behind gameplay mechanics (no punishing stat decay for MVP).

### 2.2 Rank System
E → D → C → B → A → S

- Rank is a function of total XP (simple threshold table, tune later)
- Rank-up triggers a full-screen "System" style animation/notification
- No paywall on rank progression, ever

### 2.3 XP and Leveling
- Every completed quest grants XP
- Level = derived from XP (standard RPG curve, e.g. `xp_to_next = 100 * level^1.5`)
- Level and Rank are separate: Level is granular, Rank is the milestone display

### 2.4 Daily Quest Generation
Quests are generated daily based on the day of the training cycle:

**Training days (Day 1, 2, 4, 5 of cycle):**
- One quest per exercise in that day's session (e.g. "Bench Press: 4x6-8")
- Marking a quest complete lets user log actual weight/reps (optional, for progression tracking)

**Every day (training or rest):**
- Protein target quest (e.g. "Hit 80-108g protein")
- Creatine quest (3-5g, daily including rest days)
- Bodyweight log quest (2-3x per week, not daily, to avoid obsessive checking)

**Rest days:**
- No lift quests
- Recovery quest (optional: sleep, mobility, or just a "Rest and recover" checkbox for streak continuity)

### 2.5 Streaks
- Streak tracks consecutive days with at least one quest completed (not all quests, to avoid the "missed one thing, streak dies, I quit" failure mode seen in competitor apps)
- Streak freeze: 1 free miss per week, no purchase required

### 2.6 Adaptive Difficulty (Post-MVP)
- If user skips lift quests 2+ sessions in a row, surface a "recovery week" prompt instead of guilt messaging
- Not required for MVP, flag as v2 feature

---

## 3. Data Model

Use Godot `Resource` classes for save-friendly structured data.

```gdscript
# quest.gd
class_name Quest
extends Resource

@export var id: String
@export var title: String
@export var category: String  # "lift", "nutrition", "supplement", "recovery"
@export var stat_reward: String  # "STR", "VIT", "AGI", "INT", "SENSE"
@export var xp_reward: int
@export var target_value: float  # e.g. reps, grams, sets
@export var unit: String  # "reps", "g", "kg"
@export var completed: bool = false
@export var logged_value: float = 0.0
```

```gdscript
# hunter_stats.gd
class_name HunterStats
extends Resource

@export var level: int = 1
@export var xp: int = 0
@export var rank: String = "E"
@export var str_stat: int = 10
@export var vit_stat: int = 10
@export var agi_stat: int = 10
@export var int_stat: int = 10
@export var sense_stat: int = 10
@export var current_streak: int = 0
@export var longest_streak: int = 0
@export var streak_freezes_available: int = 1
```

```gdscript
# training_day.gd
class_name TrainingDay
extends Resource

@export var day_name: String  # "Upper Body A", "Lower Body A", etc.
@export var exercises: Array[Dictionary]  # [{name, sets, rep_range}]
```

Save format: JSON via `user://save_data.json`, written through Godot's `FileAccess`. No cloud sync for MVP (keep local-only, add cloud/account system in v2 if needed).

---

## 4. Screens

1. **Home / System Dashboard**
   - Hunter level, rank badge, XP bar
   - Today's quests (checklist style)
   - Streak counter

2. **Quest Detail**
   - Tap a quest to log actual performance (weight, reps, grams, etc.)
   - Complete button grants XP immediately, no server round-trip needed

3. **Stats Screen**
   - Radar/pentagon chart of the 5 stats (classic RPG stat sheet look)
   - Rank progress bar

4. **Training Log / History**
   - Calendar view, completed days highlighted
   - Tap a day to see what was done

5. **Settings**
   - Edit program (exercises, protein target, creatine dose)
   - Notification preferences (quest reminders)

---

## 5. Visual Direction

- Dark UI, deep navy/black background
- Accent color: electric blue or violet (System window aesthetic)
- Monospace or angular sci-fi font for stat numbers and System messages
- "System" style modal popups for level-ups and rank-ups (border glow, slide-in animation)
- No cutesy mascot, keep it serious/minimal to match Solo Leveling tone

---

## 6. Godot Architecture Notes

- **Autoloads:** `GameManager` (stats, level, rank logic), `QuestManager` (daily quest generation), `SaveManager` (load/save JSON)
- **Scenes:** one scene per screen listed above, use a `CanvasLayer` for the System popup overlay so it can render above any screen
- **Signals:** `QuestManager.quest_completed(quest: Quest)` → `GameManager` listens and applies XP/stat rewards → emits `GameManager.leveled_up` / `GameManager.ranked_up` → UI listens and plays popup animation
- **Daily reset:** check last-opened date on app start (`OS.get_unix_time()` or `Time.get_date_dict_from_system()`), if it's a new calendar day, generate that day's quests and evaluate streak (did yesterday have a completion?)
- **No backend needed for MVP.** Local save only. This avoids account system, sync conflicts, and lets you ship faster.

---

## 7. MVP Scope (build this first)

- [ ] Home dashboard with today's quests
- [ ] Quest completion → XP → level up logic
- [ ] Rank thresholds and rank-up popup
- [ ] Stats screen (simple bar or radar chart)
- [ ] Local JSON save/load
- [ ] Daily quest generation from the fixed 4-day Upper/Lower cycle
- [ ] Streak counter with 1 weekly freeze

## 8. Explicitly Out of Scope for MVP
- Guilds / multiplayer / leaderboards
- Cloud sync or accounts
- Adaptive difficulty based on recovery
- In-app purchases of any kind
- Shadow Army / companion collection mechanics (fun idea, but scope creep for v1)

---

## 9. Design Principles (carried from market research)

- Never gate save/complete functionality behind a paywall, this is the #1 complaint in existing competitor apps
- Streak should forgive partial misses, don't punish someone for missing one quest out of five
- Keep the quest list tied to the user's real program, not a generic template
- Keep visual polish high but mechanic count low, avoid "gamification fatigue" from stacking too many systems at once
