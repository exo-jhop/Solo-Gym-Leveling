# 004 — Add press feedback to every Button in the app

- **Status**: DONE
- **Commit**: 519714f
- **Severity**: MEDIUM
- **Category**: Missed opportunity / Physicality
- **Estimated scope**: 1 new file, 11 existing files touched (additive lines only)

## Problem

The theme (`resources/theme/hunter_theme.tres`) already swaps `Button`'s
background/border color on press (`Button_pressed` StyleBoxFlat), but no
`Button` anywhere in the app has any *motion* feedback — no scale, no
transform response to a tap. On a touch-first Android app (`project.godot`:
`renderer/rendering_method="mobile"`), that's a real gap: every pressable
element (nav buttons, the quest LOG button, calendar day cells, exercise
row Swap/Remove buttons, onboarding choice buttons) currently only tells the
user "you pressed this" via a color change, with nothing physical backing it
up — the audit's press-feedback rule (`transform: scale(0.97)` on press,
~160ms ease-out release) has no equivalent anywhere in this codebase.

## Target

One new static utility, `scripts/ui/press_feedback.gd`:

```gdscript
class_name PressFeedback

## Scale-based press feedback for any BaseButton (Button, including
## toggle_mode buttons like the training-log calendar cells). Call
## PressFeedback.attach(button) once per button, right after it's created.

const PRESS_SCALE := Vector2(0.97, 0.97)
const PRESS_DURATION := 0.1
const RELEASE_DURATION := 0.15


static func attach(button: BaseButton) -> void:
	button.button_down.connect(_on_down.bind(button))
	button.button_up.connect(_on_up.bind(button))


static func _on_down(button: BaseButton) -> void:
	_animate(button, PRESS_SCALE, PRESS_DURATION)


static func _on_up(button: BaseButton) -> void:
	_animate(button, Vector2.ONE, RELEASE_DURATION)


static func _animate(button: BaseButton, target_scale: Vector2, duration: float) -> void:
	button.pivot_offset = button.size / 2.0
	var tween := button.create_tween()
	tween.tween_property(button, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

`PRESS_SCALE = 0.97` sits at the subtle end of the audit's recommended
0.95–0.98 press-feedback range. `PRESS_DURATION`/`RELEASE_DURATION` (100ms /
150ms) are inside the audit's 100–160ms button-press-feedback budget.
`button_down`/`button_up` (not `pressed`) are used so the scale responds to
the physical touch-down/touch-up, not just the logical click event.

Every existing `Button` in the app gets one `PressFeedback.attach(...)` call.
For buttons created in a scene file and bound via `@onready`, the call goes
in `_ready()` alongside the existing `.pressed.connect(...)` wiring. For
buttons created dynamically in code (`Button.new()`), the call goes right
after creation, next to where the button is added as a child.

## Repo conventions to follow

- This mirrors the existing pattern of small static utility classes with a
  `class_name` and no instance state — `ChamferedStyleBox`
  (`scripts/ui/chamfered_stylebox.gd`) is the closest exemplar for "drop this
  onto any node via one call, no new scene/node type required," except
  `ChamferedStyleBox` is a `Resource` subclass and `PressFeedback` here is
  plain static methods on a bare `class_name` script (no `extends` needed
  since it's never instantiated) — use `attach(...)` the same way
  `ChamferedStyleBox.new()` is used inline.
- Keep this in `scripts/ui/` next to `chamfered_stylebox.gd`, not under
  `scripts/autoload/` — it's a stateless utility, not a singleton.

## Steps

1. Create `scripts/ui/press_feedback.gd` with the exact contents shown in
   Target.
2. `scenes/lobby/lobby.gd` — in `_ready()`, after the existing
   `.pressed.connect(...)` lines, add one `PressFeedback.attach(...)` call
   each for: `dismiss_button`, `quests_button`, `stats_button`,
   `training_log_button`, `weekly_summary_button`, `settings_button`.
3. `scenes/home/home.gd`:
   - In `_ready()` (after line 61's `lobby_button.pressed.connect(...)`),
     add `PressFeedback.attach(stats_button)` and
     `PressFeedback.attach(lobby_button)`.
   - In `_refresh_quests()`, right after `log_button.pressed.connect(_on_log_pressed.bind(quest))`
     (line 195) and before `row.add_child(log_button)` (line 196), add
     `PressFeedback.attach(log_button)`.
4. `scenes/settings/settings.gd`:
   - In `_ready()` (near the existing `save_button.pressed.connect(...)` /
     `back_button.pressed.connect(...)` / `regenerate_button.pressed.connect(...)`
     lines 88–91), add `PressFeedback.attach(...)` for `save_button`,
     `back_button`, `regenerate_button`.
   - In the day-section builder (after `add_button.pressed.connect(_on_add_exercise.bind(day))`
     at line 217, before `section.add_child(add_button)` at line 218), add
     `PressFeedback.attach(add_button)`.
   - In `_build_exercise_row` (after `swap_button.pressed.connect(...)` at
     line 258, before `row.add_child(swap_button)` at line 259), add
     `PressFeedback.attach(swap_button)`. After
     `remove_button.pressed.connect(...)` at line 263, before
     `row.add_child(remove_button)` at line 264, add
     `PressFeedback.attach(remove_button)`.
4. `scenes/quest_detail/quest_detail.gd` — in `_ready()`, alongside the
   existing `complete_button.pressed.connect(...)` /
   `back_button.pressed.connect(...)` lines (22–23), add
   `PressFeedback.attach(complete_button)` and
   `PressFeedback.attach(back_button)`.
5. `scenes/stats/stats.gd`:
   - In `_ready()`, alongside `back_button.pressed.connect(...)` (line 40),
     add `PressFeedback.attach(back_button)`.
   - Where `expand_button` is built (after `header_row.add_child(expand_button)`
     at line 170, and its `.pressed.connect(...)` at line 177), add
     `PressFeedback.attach(expand_button)`.
6. `scenes/training_log/training_log.gd`:
   - In `_ready()`, alongside `prev_button.pressed.connect(...)`,
     `next_button.pressed.connect(...)`, `back_button.pressed.connect(...)`
     (lines 83–85), add `PressFeedback.attach(...)` for all three.
   - In `_refresh_calendar()`, after `calendar_grid.add_child(cell)` (line
     142), add `PressFeedback.attach(cell)` — apply this to every calendar
     cell `Button`, not only ones with data (disabled cells still get the
     motion utility attached; `BaseButton` handles the disabled state fine
     since `button_down`/`button_up` don't fire when `disabled = true`).
7. `scenes/weekly_summary/weekly_summary.gd` — in `_ready()`, alongside
   `back_button.pressed.connect(_go_back)` (line 57), add
   `PressFeedback.attach(back_button)`.
8. `scenes/onboarding/onboarding_welcome.gd` — in `_ready()`, alongside
   `begin_button.pressed.connect(_on_begin_pressed)` (line 9), add
   `PressFeedback.attach(begin_button)`.
9. `scenes/onboarding/onboarding_goal.gd` — in the `_ready()` loop, after
   `button.pressed.connect(_on_goal_pressed.bind(goal))` (line 14) and before
   `goal_list.add_child(button)` (line 15), add
   `PressFeedback.attach(button)`.
10. `scenes/onboarding/onboarding_metrics.gd` — in `_ready()`, alongside
    `continue_button.pressed.connect(_on_continue_pressed)` (line 21), add
    `PressFeedback.attach(continue_button)`.
11. `scenes/onboarding/onboarding_confirmation.gd` — in `_ready()`, alongside
    `finish_button.pressed.connect(_on_finish_pressed)` (line 16), add
    `PressFeedback.attach(finish_button)`.

## Boundaries

- Do NOT attach `PressFeedback` to `CheckBox` nodes (the quest-completion
  checkboxes in `home.gd`) — those are out of scope for this finding; only
  `Button`-typed nodes were identified.
- Do NOT change any existing `.pressed.connect(...)` wiring — only add new
  `PressFeedback.attach(...)` lines alongside them.
- Do NOT modify `resources/theme/hunter_theme.tres` — the color-based press
  states there are correct and unrelated to this motion-only addition.
- Do NOT add press feedback inside `scenes/system_popup/system_popup.gd` (it
  has no `Button` nodes — its dismiss is a `gui_input` handler on the `Dim`
  `ColorRect`) or `scenes/test/test_main.gd` / `scenes/ui/*` test scaffolding.
- If any cited line's surrounding code doesn't match what's shown here
  (drift since commit `519714f`), STOP on that file and report instead of
  guessing where to insert the call — apply the parts that do match, and
  list what didn't.

## Verification

- **Mechanical**: open the project in Godot 4.7 and confirm no parse errors
  in `scripts/ui/press_feedback.gd` or any of the 11 edited files.
- **Feel check**: run the full app from `scenes/lobby/lobby.tscn` (or the
  onboarding flow on a fresh save) and press every button type at least
  once — lobby nav buttons, Home's LOG button, Settings' Save/Back/Swap/
  Remove/Add Exercise buttons, a Training Log calendar day, an onboarding
  goal choice. Confirm for each:
  - The button visibly shrinks slightly on touch-down and springs back to
    full size on release — subtle, not cartoonish (should read as "solid,
    responsive," not "bouncy").
  - Rapidly double-tapping the same button never leaves it stuck at the
    shrunk scale or snapping oddly (the tween should retarget cleanly each
    press since a new `create_tween()` on the same button interrupts any
    tween still running on it).
  - A `disabled` button (e.g. a training-log day with no data, or a Swap
    button with no alternatives) does not scale at all when tapped.
- **Done when**: all 11 files call `PressFeedback.attach(...)` for every
  `Button` node listed in Steps, and the feel-check above passes across all
  of them.
