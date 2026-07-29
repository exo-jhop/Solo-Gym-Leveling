# 002 — Pause the Home avatar-ring glow loop when the app is backgrounded

- **Status**: DONE
- **Commit**: 519714f
- **Severity**: MEDIUM
- **Category**: Performance / Purpose & frequency
- **Estimated scope**: 1 file, ~10 new lines

## Problem

`scenes/home/home.gd:289-300` defines the `AvatarRing` inner class, whose
`_ready()` starts an infinitely-looping tween:

```gdscript
# scenes/home/home.gd:289-300 — current
class AvatarRing extends Control:
	var ring_color: Color = Color.WHITE
	var _pulse: float = 0.0

	func _ready() -> void:
		var tween := create_tween().set_loops()
		tween.tween_method(_set_pulse, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_method(_set_pulse, 1.0, 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _set_pulse(value: float) -> void:
		_pulse = value
		queue_redraw()
```

`tween_method` calls `_set_pulse` every process frame for the full 1.2s of
each leg, and every call triggers `queue_redraw()`. This is deliberate ambient
motion (the comment above `AvatarRing` at `home.gd:286-288` documents it as
the rank-colored glow ring) and is fine while the screen is actually being
looked at — that's not being second-guessed here. The gap is that this app
targets Android (`project.godot` sets `renderer/rendering_method="mobile"`)
and the loop has no lifecycle awareness: if the OS backgrounds the app while
Home is still the active scene (user switches apps, locks the phone, etc.),
this control keeps re-triggering redraws indefinitely with nothing on screen
to show for it, burning battery for no visible benefit.

## Target

Pause the tween on `NOTIFICATION_APPLICATION_PAUSED` and resume it on
`NOTIFICATION_APPLICATION_RESUMED`, Godot's standard mobile lifecycle hooks,
by overriding `_notification` and keeping a reference to the tween:

```gdscript
# scenes/home/home.gd — target
class AvatarRing extends Control:
	var ring_color: Color = Color.WHITE
	var _pulse: float = 0.0
	var _glow_tween: Tween

	func _ready() -> void:
		_start_glow_loop()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_PAUSED:
			if _glow_tween != null and _glow_tween.is_valid():
				_glow_tween.pause()
		elif what == NOTIFICATION_APPLICATION_RESUMED:
			if _glow_tween != null and _glow_tween.is_valid():
				_glow_tween.play()

	func _start_glow_loop() -> void:
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_method(_set_pulse, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_glow_tween.tween_method(_set_pulse, 1.0, 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _set_pulse(value: float) -> void:
		_pulse = value
		queue_redraw()
```

The pulse cycle itself (1.2s in, 1.2s out, `TRANS_SINE`/`EASE_IN_OUT`) is
correct as-is and must not change — "moving/morphing" ambient motion is
exactly where `EASE_IN_OUT` belongs. Only lifecycle gating is being added.

## Repo conventions to follow

- `scripts/autoload/notification_manager.gd` and other autoloads in this repo
  don't currently use `_notification`, so there's no existing exemplar in
  this codebase — `NOTIFICATION_APPLICATION_PAUSED` /
  `NOTIFICATION_APPLICATION_RESUMED` are Godot 4 engine-level constants
  (available on any `Node`), not a repo-specific pattern, so no local
  convention is being broken by introducing them here.
- Keep the tween-building code in its own `_start_glow_loop()` method rather
  than inlining it in `_ready()` — this mirrors how `home.gd`'s top-level
  `_ready()` already delegates to named `_refresh_*` methods rather than
  building things inline.

## Steps

1. In `scenes/home/home.gd`, inside the `AvatarRing` class (starting at line
   289), add a new member variable `var _glow_tween: Tween` after
   `var _pulse: float = 0.0`.
2. Rename the tween-construction body currently inside `_ready()` into a new
   method `_start_glow_loop() -> void`, storing the tween in `_glow_tween`
   instead of a local `tween` variable, and call `_start_glow_loop()` from
   `_ready()`.
3. Add a `_notification(what: int) -> void` override in `AvatarRing` that
   pauses `_glow_tween` on `NOTIFICATION_APPLICATION_PAUSED` and resumes it
   (`.play()`) on `NOTIFICATION_APPLICATION_RESUMED`, guarding both with a
   `_glow_tween != null and _glow_tween.is_valid()` check as shown in Target.

## Boundaries

- Do NOT change the pulse durations, `TRANS_SINE`, `EASE_IN_OUT`, or the
  0.0↔1.0 value range — only lifecycle pause/resume is in scope.
- Do NOT touch `RankHexBadge` (the sibling class below `AvatarRing`) — it has
  no tween and is out of scope.
- Do NOT add any pause/resume handling to `home.gd`'s top-level script — this
  is scoped to the `AvatarRing` inner class only.
- If `AvatarRing._ready()` doesn't match the code shown above (drift since
  commit `519714f`), STOP and report instead of improvising.

## Verification

- **Mechanical**: open the project in Godot 4.7 and confirm `home.gd` has no
  parse errors.
- **Feel check**: run the app on an Android device or in the editor with
  "Low Processor Mode" toggled off, open Home, and confirm the glow ring
  still pulses continuously and smoothly exactly as before (no visible
  change to the resting-state animation). This finding's actual gate
  (`NOTIFICATION_APPLICATION_PAUSED`) can't be triggered from the desktop
  editor, so functional confirmation on-device (background the app via the
  Android home button while Home is open, then reopen the app) is the real
  test: the glow should not have jumped or glitched on resume.
- **Done when**: `AvatarRing` has a `_glow_tween` member, a `_notification`
  override handling both constants, and the on-device background/resume
  check shows no visual glitch.
