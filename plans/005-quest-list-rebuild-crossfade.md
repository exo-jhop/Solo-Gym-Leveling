# 005 — Mask the quest list's full-rebuild-on-toggle with a crossfade

- **Status**: DONE
- **Commit**: 519714f
- **Severity**: LOW
- **Category**: Cohesion / Missed opportunity
- **Estimated scope**: 1 file, 1 function split into two

## Problem

`scenes/home/home.gd:131-202` (`_refresh_quests`) destroys every quest card
and rebuilds the whole list from scratch on *any* change — toggling one
quest's checkbox, or flipping the low-energy switch:

```gdscript
# scenes/home/home.gd:131-141 — current (relevant excerpt)
func _refresh_quests() -> void:
	low_energy_toggle.visible = QuestManager.has_lift_quests()
	low_energy_toggle.set_pressed_no_signal(QuestManager.low_energy_mode)
	low_energy_toggle.disabled = QuestManager.any_lift_quest_completed()

	for child in quest_list.get_children():
		child.queue_free()

	for quest in QuestManager.current_quests:
		var card := PanelContainer.new()
		# ... (builds the full card tree, unchanged by this plan)
```

Because every card is freed and recreated, checking off one quest makes
every *other*, unrelated card teleport out and back in alongside it — an
instant flicker across the whole list for a change that only affects one
row. A proper per-card diff/reuse rewrite is out of scope for a motion-only
fix (it would change how cards are identified and updated, not just how they
animate) — but the audit's cohesion guidance covers exactly this case: a
jarring crossfade that visibly double-exposes two states can be masked with
a brief transition. Wrapping the destroy-and-rebuild in a quick fade turns an
accidental flicker into an intentional, quick content-swap transition.

## Target

Split the function: `_refresh_quests()` keeps the low-energy-toggle lines
and now drives a fade around a call to a new `_rebuild_quest_cards()`, which
contains exactly the destroy/rebuild loop (moved verbatim, unchanged):

```gdscript
# scenes/home/home.gd — target
func _refresh_quests() -> void:
	low_energy_toggle.visible = QuestManager.has_lift_quests()
	low_energy_toggle.set_pressed_no_signal(QuestManager.low_energy_mode)
	low_energy_toggle.disabled = QuestManager.any_lift_quest_completed()

	var tween := create_tween()
	tween.tween_property(quest_list, "modulate:a", 0.0, 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_rebuild_quest_cards)
	tween.tween_property(quest_list, "modulate:a", 1.0, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _rebuild_quest_cards() -> void:
	for child in quest_list.get_children():
		child.queue_free()

	for quest in QuestManager.current_quests:
		# ... everything currently inside the `for quest in QuestManager.current_quests:`
		# loop body (lines 139-202 in the current file) moves here UNCHANGED,
		# including the trailing _pulse_card / _last_completed_id check.
```

0.1s fade-out + 0.15s fade-in (0.25s total) sits inside the audit's
"Dropdowns, selects → 150–250ms" bucket, appropriate for a list content
swap. Both legs use `TRANS_SINE`/`EASE_OUT` — "entering or exiting →
ease-out" — matching the easing already used elsewhere in this file
(`_pulse_card`).

## Repo conventions to follow

- `quest_list` is the existing `@onready var quest_list: VBoxContainer`
  (line 40) — animate its `modulate:a`, don't wrap it in a new container.
- This file already uses the `create_tween() → tween_property(...).set_trans(...).set_ease(...)`
  pattern in `_refresh_header` (line 109) and `_pulse_card` (lines 247-251)
  — follow that exact call shape, don't introduce `AnimationPlayer` or a
  different tweening style.
- `tween_callback(_rebuild_quest_cards)` is the correct way to sequence a
  plain function call between two tweened steps on the same `Tween` chain —
  don't call `_rebuild_quest_cards()` directly outside the tween or use
  `await`.

## Steps

1. In `scenes/home/home.gd`, rename the current `_refresh_quests` function
   to `_rebuild_quest_cards`, keeping its entire body (the `for child in
   quest_list.get_children(): child.queue_free()` loop and the `for quest in
   QuestManager.current_quests:` loop) exactly as-is, EXCEPT remove the
   three `low_energy_toggle.*` lines at the top (they move to the new
   `_refresh_quests`, not duplicated).
2. Add a new `_refresh_quests() -> void` function above
   `_rebuild_quest_cards`, containing: the three `low_energy_toggle.*` lines
   (moved from step 1), followed by the tween-building code shown in
   Target.
3. Leave every existing caller of `_refresh_quests()` unchanged (it's still
   called the same way from `_ready()`, `_on_low_energy_toggled`, and
   `_on_quest_toggled` — those call sites don't need to know the rebuild is
   now wrapped in a fade).

## Boundaries

- Do NOT change anything inside the card-building loop body (card styles,
  labels, buttons, the `_pulse_card` call, the `_last_completed_id` check) —
  move it verbatim into `_rebuild_quest_cards`.
- Do NOT add a fade to `low_energy_toggle` itself — only `quest_list`'s
  `modulate:a` is in scope.
- Do NOT touch `_refresh_header` or `_refresh_reset_card` — this plan is
  scoped to `_refresh_quests`/`_rebuild_quest_cards` only.
- If the current `_refresh_quests` body (lines 131-202) doesn't match what's
  shown here (drift since commit `519714f`), STOP and report instead of
  guessing which lines belong in which function.

## Verification

- **Mechanical**: open the project in Godot 4.7 and confirm `home.gd` has no
  parse errors, and that `_refresh_quests`/`_rebuild_quest_cards` both exist
  with the split shown above.
- **Feel check**: run `scenes/home/home.tscn` with at least two quests for
  the day, then check off one quest. Confirm:
  - The whole quest list briefly and smoothly fades down and back up around
    the moment the list changes, rather than instantly flickering.
  - The completed quest's card still gets its accent-border pulse
    (`_pulse_card`), visible during/just after the fade back in.
  - Toggling the low-energy switch (if lift quests are present) produces
    the same brief fade around the list rebuild.
  - Rapidly toggling the same quest's checkbox on and off doesn't leave
    `quest_list` stuck at partial opacity (each new `_refresh_quests()` call
    starts a fresh `create_tween()`, which runs independently — check that
    spamming the toggle doesn't visibly break the fade).
- **Done when**: the function split matches Target, the fade plays on every
  quest-list change, and the feel-check items above hold.
