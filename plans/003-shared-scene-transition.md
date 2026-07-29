# 003 — Add a shared cross-fade for every scene transition

- **Status**: DONE
- **Commit**: 519714f
- **Severity**: HIGH
- **Category**: Missed opportunity / Cohesion
- **Estimated scope**: 2 new files (script + scene), 1 `project.godot` edit, 19 call-site edits across 11 existing files

## Problem

Every screen change in the app is an instant hard cut via
`get_tree().change_scene_to_file(...)` called directly. There is no shared
transition mechanism anywhere — none of the app's 8 modules soften the swap
into the next one. All 19 call sites, verbatim:

```gdscript
# scenes/lobby/lobby.gd:63 — current
		get_tree().change_scene_to_file("res://scenes/onboarding/onboarding_welcome.tscn")
# scenes/lobby/lobby.gd:70 — current
		get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")
# scenes/lobby/lobby.gd:91 — current
	get_tree().change_scene_to_file("res://scenes/home/home.tscn")
# scenes/lobby/lobby.gd:95 — current
	get_tree().change_scene_to_file("res://scenes/stats/stats.tscn")
# scenes/lobby/lobby.gd:99 — current
	get_tree().change_scene_to_file("res://scenes/training_log/training_log.tscn")
# scenes/lobby/lobby.gd:103 — current
	get_tree().change_scene_to_file("res://scenes/weekly_summary/weekly_summary.tscn")
# scenes/lobby/lobby.gd:107 — current
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")
# scenes/home/home.gd:274 — current
	get_tree().change_scene_to_file("res://scenes/stats/stats.tscn")
# scenes/home/home.gd:278 — current
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
# scenes/home/home.gd:283 — current
	get_tree().change_scene_to_file("res://scenes/quest_detail/quest_detail.tscn")
# scenes/settings/settings.gd:306 — current
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
# scenes/stats/stats.gd:243 — current
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
# scenes/quest_detail/quest_detail.gd:68 — current
	get_tree().change_scene_to_file("res://scenes/home/home.tscn")
# scenes/training_log/training_log.gd:304 — current
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
# scenes/weekly_summary/weekly_summary.gd:131 — current
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
# scenes/onboarding/onboarding_welcome.gd:13 — current
	get_tree().change_scene_to_file("res://scenes/onboarding/onboarding_goal.tscn")
# scenes/onboarding/onboarding_goal.gd:20 — current
	get_tree().change_scene_to_file("res://scenes/onboarding/onboarding_metrics.tscn")
# scenes/onboarding/onboarding_metrics.gd:32 — current
	get_tree().change_scene_to_file("res://scenes/onboarding/onboarding_confirmation.tscn")
# scenes/onboarding/onboarding_confirmation.gd:25 — current
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
```

A jarring content swap with no transition is exactly the "teleport" case the
audit's missed-opportunities category calls out, and it's the single
highest-leverage motion gap in the project since it touches literally every
module.

## Target

A new autoload, `SceneTransition`, wraps every one of the 19 calls above.
Callers change from `get_tree().change_scene_to_file(path)` to
`SceneTransition.go_to_scene(path)` — same string argument, nothing else
about the call site changes.

**New file `scenes/scene_transition/scene_transition.gd`:**

```gdscript
extends CanvasLayer

## Shared cross-fade wrapper around `change_scene_to_file`, used by every
## scene navigation in the app so all module switches share one motion
## language instead of each being an instant hard cut.

const FADE_SECONDS := 0.2
const FADE_COLOR := Color(0.039, 0.055, 0.094, 1.0)  # project.godot default_clear_color

@onready var fade_rect: ColorRect = $FadeRect

var _busy: bool = false


func _ready() -> void:
	layer = 110
	fade_rect.color = FADE_COLOR
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)


func go_to_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "modulate:a", 1.0, FADE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame

	var fade_out := create_tween()
	fade_out.tween_property(fade_rect, "modulate:a", 0.0, FADE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_out.finished

	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
```

**New file `scenes/scene_transition/scene_transition.tscn`:**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/scene_transition/scene_transition.gd" id="1"]

[node name="SceneTransition" type="CanvasLayer"]
layer = 110
script = ExtResource("1")

[node name="FadeRect" type="ColorRect" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.039, 0.055, 0.094, 1)
mouse_filter = 2
```

**`project.godot` `[autoload]` section** — add one line, after the existing
`SystemPopup` line:

```
# project.godot — target, [autoload] section
GameManager="*res://scripts/autoload/game_manager.gd"
QuestManager="*res://scripts/autoload/quest_manager.gd"
HistoryManager="*res://scripts/autoload/history_manager.gd"
PRTracker="*res://scripts/autoload/pr_tracker.gd"
ProfileManager="*res://scripts/autoload/profile_manager.gd"
SaveManager="*res://scripts/autoload/save_manager.gd"
NotificationManager="*res://scripts/autoload/notification_manager.gd"
SystemPopup="*res://scenes/system_popup/system_popup.tscn"
SceneTransition="*res://scenes/scene_transition/scene_transition.tscn"
```

**Every one of the 19 call sites** changes `get_tree().change_scene_to_file("res://...")`
to `SceneTransition.go_to_scene("res://...")` — identical argument, just the
receiver changes.

## Repo conventions to follow

- `SystemPopup` (`scenes/system_popup/system_popup.tscn` +
  `scenes/system_popup/system_popup.gd`) is the existing exemplar for "an
  autoloaded `CanvasLayer` scene that renders above whatever screen is
  active" — `SceneTransition` follows the exact same shape (autoloaded
  `.tscn`, not a plain `.gd` autoload, because it needs a `ColorRect` child).
  `SystemPopup` uses `layer = 100`; `SceneTransition` uses `layer = 110` so a
  fade can still cover a lingering popup if one is ever on screen during a
  navigation.
- `FADE_COLOR` matches `project.godot`'s `[rendering]` →
  `environment/defaults/default_clear_color = Color(0.039, 0.055, 0.094, 1)`,
  the app's actual background color, not an arbitrary black.
- Duration: 0.2s per leg (0.4s round trip) is inside the "Modals, drawers →
  200–500ms" budget from the audit, appropriate for a full-screen swap.
- Easing: `TRANS_SINE`/`EASE_OUT` on both legs — "entering or exiting →
  ease-out" per the audit's decision order — matching how `home.gd`'s
  `_pulse_card` and `system_popup.gd`'s show/hide tweens are already built.
- Do NOT hand-write a `uid="uid://..."` attribute in the new `.tscn`'s
  `[gd_scene]` header, and do NOT create a `.uid` file next to the new
  `.gd` script — per this repo's convention, `.uid` files are Godot-generated
  and get created automatically the first time the project is opened in the
  Godot 4.7 editor.

## Steps

1. Create `scenes/scene_transition/scene_transition.gd` with the exact
   contents shown in Target.
2. Create `scenes/scene_transition/scene_transition.tscn` with the exact
   contents shown in Target.
3. In `project.godot`, add the `SceneTransition="*res://scenes/scene_transition/scene_transition.tscn"`
   line to the `[autoload]` section, directly after the existing
   `SystemPopup=` line.
4. In each of the 11 files below, replace every `get_tree().change_scene_to_file("res://...")`
   call with `SceneTransition.go_to_scene("res://...")`, keeping the exact
   same path string and the same indentation the current line has:
   - `scenes/lobby/lobby.gd` — lines 63, 70, 91, 95, 99, 103, 107 (7 call sites)
   - `scenes/home/home.gd` — lines 274, 278, 283 (3 call sites)
   - `scenes/settings/settings.gd` — line 306
   - `scenes/stats/stats.gd` — line 243
   - `scenes/quest_detail/quest_detail.gd` — line 68
   - `scenes/training_log/training_log.gd` — line 304
   - `scenes/weekly_summary/weekly_summary.gd` — line 131
   - `scenes/onboarding/onboarding_welcome.gd` — line 13
   - `scenes/onboarding/onboarding_goal.gd` — line 20
   - `scenes/onboarding/onboarding_metrics.gd` — line 32
   - `scenes/onboarding/onboarding_confirmation.gd` — line 25

## Boundaries

- Do NOT change any of the path strings being navigated to — only the
  receiver (`get_tree()` → `SceneTransition`) and method name
  (`change_scene_to_file` → `go_to_scene`) change.
- Do NOT add a transition to `scenes/system_popup/system_popup.gd`'s own
  show/hide logic — that's a separate, already-correct animation, out of
  scope here.
- Do NOT touch `scenes/test/test_main.gd` or anything under `scenes/ui/` —
  these are test/dev scaffolding, not part of the real navigation flow.
- Do NOT add a loading spinner, progress indicator, or any UI beyond the
  fade rect.
- If any listed line number doesn't match the `change_scene_to_file` call
  shown for it (drift since commit `519714f`), STOP and report instead of
  guessing which line to change.

## Verification

- **Mechanical**: open the project in Godot 4.7; confirm the editor shows no
  parse errors on any of the 11 modified `.gd` files, no errors on the new
  `scene_transition.gd`, and that `project.godot`'s autoload list shows
  `SceneTransition` from the Project Settings → Autoload tab.
- **Feel check**: run from `scenes/lobby/lobby.tscn` and click through every
  nav button (Quests, Stats, Training Log, Weekly Summary, Settings), plus
  each screen's Back button, plus the full onboarding flow on a fresh save
  (delete `user://save_data.json` or run in an exported build with no prior
  save). Confirm for each transition:
  - The screen fades to the app's background color and back in, rather than
    cutting instantly — same fade feel on every single transition (Lobby ↔
    every module, and all 4 onboarding steps).
  - Rapidly double-tapping a nav button never launches two overlapping
    transitions or leaves the fade stuck at partial opacity (the `_busy`
    guard should make the second tap a no-op until the first transition
    completes).
  - The fade overlay blocks taps to the screen underneath while active (tap
    the area behind where a button was during the fade — nothing should
    trigger).
- **Done when**: all 19 call sites use `SceneTransition.go_to_scene`, the
  autoload is registered, and every screen-to-screen navigation in the app
  shows the same fade-through-background transition.
