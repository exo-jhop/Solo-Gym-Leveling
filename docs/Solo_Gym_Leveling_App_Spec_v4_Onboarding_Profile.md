# Hunter System: Spec v4 — Profile & Goal-Driven Onboarding

**Engine:** Godot 4.7 | **Builds on:** v1 (core loop) + v2 (refinement) + v3 (PR tracker, per-supplement reminders)

---

## 1. Why This Feature

Right now, protein targets, calorie direction, and quest emphasis are all hardcoded to one fixed program (yours, at 49-50kg, building muscle). A profile system makes the app actually reusable if your goal changes, and honestly makes it feel more like a real "System" calibrating to *you* specifically, which is the core fantasy the whole app is built around.

**Note on competitor research:** Arise Solo's public marketing page doesn't detail their onboarding flow, so this design isn't copying a documented pattern, it's built from the nutrition/goal logic already established earlier in this project, adapted into a first-launch flow.

---

## 2. New Concept: HunterProfile

A one-time (editable later) intake that drives calculated targets across the app.

### 2.1 Fields Collected

| Field | Type | Purpose |
|---|---|---|
| Goal | enum: Build Muscle / Get Stronger / Lose Fat / General Fitness | Drives calorie direction + quest emphasis |
| Height | float (cm) | Used for reference only in MVP, no BMI moralizing |
| Weight | float (kg) | Drives protein target calculation |
| Age | int (optional) | Reference only, not used in calculations for MVP |
| Training days/week | int (already implicit from program, but confirm here) | Sanity check against actual program length |

### 2.2 What Gets Calculated From This

- **Protein target (g/day):** `weight_kg * 1.6 to 2.2`, using the same range already established for your own program. Goal shifts where in that range: Build Muscle → upper end, General Fitness → lower end.
- **Calorie direction (not a hard number, a direction):** Build Muscle → surplus, Lose Fat → deficit, Get Stronger/General Fitness → maintenance. **Deliberately not calculating an exact calorie number in-app**, that requires activity-level assumptions that are easy to get wrong and this isn't a medical app. Show the *direction* and a rough guideline, point back to the reasoning already used earlier in this project (maintenance formula + adjust by trend) rather than a precise fixed figure.
- **Quest emphasis:** Lose Fat goal could surface an optional cardio/step quest category, Build Muscle keeps the current lift-heavy emphasis as-is.

---

## 3. Onboarding Flow (First Launch Only)

1. **Welcome screen**: "The System has chosen you." (brief, on-theme, skip-able for returning users)
2. **Goal selection**: single-select, the 4 goals above
3. **Body metrics**: height, weight, age (age explicitly optional, allow skip)
4. **Confirmation screen**: shows calculated protein target and calorie direction, explains these feed into daily quests
5. Lands on Lobby as normal afterward

**Editable later:** Settings gets a "Profile" section to revisit any of this, recalculates targets immediately on save.

---

## 4. Data Model

```gdscript
# hunter_profile.gd
class_name HunterProfile
extends Resource

@export var goal: String = "general_fitness"  # "build_muscle", "get_stronger", "lose_fat", "general_fitness"
@export var height_cm: float = 0.0
@export var weight_kg: float = 0.0
@export var age: int = 0  # 0 = not provided
@export var onboarding_complete: bool = false

func calculate_protein_target_g() -> float:
    var multiplier := 2.0  # default, mid-high range
    match goal:
        "build_muscle": multiplier = 2.2
        "get_stronger": multiplier = 2.0
        "lose_fat": multiplier = 2.0  # protein stays high in a deficit to preserve muscle
        "general_fitness": multiplier = 1.6
    return weight_kg * multiplier

func calorie_direction() -> String:
    match goal:
        "build_muscle": return "surplus"
        "lose_fat": return "deficit"
        _: return "maintenance"
```

---

## 5. Integration Points

- **QuestManager**: the daily protein-target quest reads `HunterProfile.calculate_protein_target_g()` instead of a hardcoded number
- **Weekly Summary / Stats**: could optionally show calorie direction as a small label, not a hard number (avoid implying false precision)
- **Save/Load**: HunterProfile persists like every other Resource, `onboarding_complete` gates whether the first-launch flow shows again

---

## 6. Migration for Existing Save

You already have a save file with a hardcoded program (build muscle, ~49kg). On first load after this update:
- If no HunterProfile exists in the save, construct one from what's already known: `goal = "build_muscle"`, `weight_kg` from your last logged bodyweight quest (if available) or prompt once
- Mark `onboarding_complete = true` so you don't get the full first-launch flow again, just land in Settings > Profile with fields pre-filled to confirm/adjust

---

## 7. Explicitly Out of Scope

- Precise calorie-number calculation (activity-level multipliers, TDEE formulas), direction-only per Section 2.2's reasoning
- BMI display or any weight-judgment framing, this app's tone should stay motivating, not clinical
- Multiple goals at once (bulk + cardio simultaneously), pick one goal, keep quest generation simple
- Auto-adjusting protein target over time without user re-input, changes to weight/goal are manual edits in Settings, not automatic

---

## 8. Build Order

1. **HunterProfile resource + calculation methods** (small, isolated)
2. **Settings > Profile section** (edit existing values, recalculate on save) — build before onboarding flow so the underlying data/logic is tested via a simpler UI first
3. **First-launch onboarding flow** (Welcome → Goal → Metrics → Confirmation), gated by `onboarding_complete`
4. **QuestManager integration** (swap hardcoded protein target for the calculated one)
5. **Migration logic for existing save**, build and test last, since it's the one-time path that's hardest to re-test once you've run it

---

## 9. Self-Review Note

Checked this against the app's existing tone/scope: kept calorie guidance directional instead of a hard number specifically because a wrong precise number feels authoritative and could be trusted uncritically, direction + pointing back to the trend-based adjustment approach already established is more honest. Also confirmed this doesn't reopen the "penalty/judgment" pattern rejected in v2, no BMI, no shame-based framing, goal selection stays neutral and practical.
