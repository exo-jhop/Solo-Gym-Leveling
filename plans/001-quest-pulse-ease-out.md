# 001 — Fix ease-in on quest-completion glow pulse

- **Status**: DONE
- **Commit**: 519714f
- **Severity**: HIGH
- **Category**: Easing & Duration
- **Estimated scope**: 1 file, 1 line

## Problem

`scenes/home/home.gd:245-251` pulses a completed quest card's accent-border width
up then back down using two chained `Tween.tween_method` calls. The *contract*
phase (the border shrinking back to its resting width) uses `Tween.EASE_IN`:

```gdscript
# scenes/home/home.gd:245-251 — current
func _pulse_card(style: ChamferedStyleBox) -> void:
	var base_width := style.accent_width
	var tween := create_tween()
	tween.tween_method(func(w): _set_accent_width(style, w), base_width, base_width + 4.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(w): _set_accent_width(style, w), base_width + 4.0, base_width, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
```

`EASE_IN` starts a motion slow and accelerates into the change — exactly the
moment the user's eye is on the card they just checked off. Per the audit
decision order, both the expand ("entering") and contract ("exiting") legs of
a UI micro-animation should be `ease-out`; `ease-in` on UI is always a finding.

## Target

Only the second `set_ease(...)` call changes, from `EASE_IN` to `EASE_OUT`:

```gdscript
# scenes/home/home.gd:245-251 — target
func _pulse_card(style: ChamferedStyleBox) -> void:
	var base_width := style.accent_width
	var tween := create_tween()
	tween.tween_method(func(w): _set_accent_width(style, w), base_width, base_width + 4.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(w): _set_accent_width(style, w), base_width + 4.0, base_width, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
```

Durations (0.18s expand, 0.35s contract) stay as-is — both are already inside
the sub-300ms feedback budget and the asymmetric timing (fast in, slower
settle) is fine; only the easing curve of the contract leg is wrong.

## Repo conventions to follow

- This file already uses `Tween.TRANS_SINE` consistently for this effect —
  don't introduce a different transition type, only change the ease constant.
- Godot's `Tween.EASE_OUT` / `Tween.EASE_IN` / `Tween.EASE_IN_OUT` map directly
  onto the audit's CSS `ease-out`/`ease-in`/`ease-in-out` vocabulary — treat
  `EASE_OUT` as this repo's equivalent of the strong `--ease-out` token.

## Steps

1. In `scenes/home/home.gd`, in `_pulse_card`, change the second
   `tween_method(...)` call's `.set_ease(Tween.EASE_IN)` to
   `.set_ease(Tween.EASE_OUT)`. No other lines change.

## Boundaries

- Do NOT touch the expand leg (first `tween_method` call) — it's already correct.
- Do NOT change durations, `TRANS_SINE`, or the accent-width delta (`+4.0`).
- Do NOT touch any other function in `home.gd`.
- If the line numbers or code shown above don't match what you find (drift
  since commit `519714f`), STOP and report instead of improvising.

## Verification

- **Mechanical**: open the project in the Godot 4.7 editor and confirm no
  parse errors in `home.gd` (Script editor shows no red squiggles / the scene
  runs).
- **Feel check**: run `scenes/home/home.tscn` (or the full app from
  `scenes/lobby/lobby.tscn`), complete a quest via its checkbox, and watch the
  card's accent border pulse. Confirm:
  - The border widens quickly then the return-to-rest motion also feels like
    it's decelerating into place (fast start, soft landing) rather than
    slowly creeping and then snapping — i.e. no "slow start" on the way back
    down.
  - Toggling the same quest's checkbox repeatedly still produces a clean
    pulse each time (no visual glitching from the eased-value change).
- **Done when**: the second `tween_method` call in `_pulse_card` reads
  `.set_ease(Tween.EASE_OUT)` and the visual check above passes.
