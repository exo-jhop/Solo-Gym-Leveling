extends Control

## Lobby / Hub screen (design system v2, portrait pass). Main entry point — the Hunter's
## standing status at a glance, plus routing to the app's top-level sections.
##
## Reworked away from the old side-by-side character/button split: on the real 1080x2400
## portrait viewport that layout left the nav column roughly 500px wide for five stacked
## full-width buttons, and surfaced nothing but the rank title — so the app's landing
## screen said less about the Hunter than any screen behind it. The hub now stacks
## (status hero → one primary CTA → 2x2 secondary grid) and reads level, XP, streak and
## today's quest progress off the existing autoloads. Nothing here is new state: every
## readout is derived from GameManager/QuestManager, so the Lobby stays a pure view.

const PRIMARY_ACCENT := Color(0.0, 0.721569, 1.0, 1.0)  # #00B8FF (design system v2)
const SUCCESS_COLOR := Color(0.227451, 0.858824, 0.462745, 1.0)  # #3ADB76
const GOLD_ACCENT := Color(1.0, 0.721569, 0.0, 1.0)  # #FFB800
const WARNING_COLOR := Color(1.0, 0.419608, 0.207843, 1.0)  # #FF6B35
const DIVIDER_COLOR := Color(0.164706, 0.227451, 0.360784, 1.0)  # #2A3A5C
const SECONDARY_TEXT := Color(0.482353, 0.541176, 0.682353, 1.0)  # #7B8AAE

const WEEKDAY_NAMES := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
const MONTH_NAMES := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

## Entrance stagger between hub cards, inside the design system's 150-300ms
## micro-interaction band once the per-card fade is added on top.
const STAGGER_STEP := 0.045
const CARD_FADE_TIME := 0.22

@onready var date_label: Label = $Margin/ScrollContainer/Root/HeaderRow/TitleBox/DateLabel
@onready var rank_hex_slot: Control = $Margin/ScrollContainer/Root/HeaderRow/RankHexSlot
@onready var reminder_banner: PanelContainer = $Margin/ScrollContainer/Root/ReminderBanner
@onready var reminder_glyph_slot: Control = $Margin/ScrollContainer/Root/ReminderBanner/ReminderMargin/ReminderRow/ReminderGlyphSlot
@onready var dismiss_button: Button = $Margin/ScrollContainer/Root/ReminderBanner/ReminderMargin/ReminderRow/DismissButton
@onready var hero_card: PanelContainer = $Margin/ScrollContainer/Root/HeroCard
@onready var portrait_frame: Control = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/PortraitFrame
@onready var backdrop: TextureRect = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/PortraitFrame/Backdrop
@onready var aura_glow: TextureRect = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/PortraitFrame/AuraGlow
@onready var platform_glow: TextureRect = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/PortraitFrame/PlatformGlow
@onready var character_panel: TextureRect = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/PortraitFrame/CharacterPanel
@onready var hunter_title_label: Label = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/PortraitFrame/OverlayMargin/OverlayRow/IdentityBox/HunterTitleLabel
@onready var level_label: Label = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/PortraitFrame/OverlayMargin/OverlayRow/IdentityBox/LevelLabel
@onready var streak_pill: PanelContainer = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/PortraitFrame/OverlayMargin/OverlayRow/StreakPill
@onready var flame_slot: Control = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/PortraitFrame/OverlayMargin/OverlayRow/StreakPill/StreakMargin/StreakRow/FlameSlot
@onready var streak_count_label: Label = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/PortraitFrame/OverlayMargin/OverlayRow/StreakPill/StreakMargin/StreakRow/StreakCountLabel
@onready var streak_unit_label: Label = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/PortraitFrame/OverlayMargin/OverlayRow/StreakPill/StreakMargin/StreakRow/StreakUnitLabel
@onready var xp_value_label: Label = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/XPBox/XPHeaderRow/XPValueLabel
@onready var xp_bar: ProgressBar = $Margin/ScrollContainer/Root/HeroCard/HeroMargin/HeroStack/XPBox/XPBar
@onready var quests_button: Button = $Margin/ScrollContainer/Root/QuestsButton
@onready var quests_glyph_slot: Control = $Margin/ScrollContainer/Root/QuestsButton/GlyphSlot
@onready var quest_count_label: Label = $Margin/ScrollContainer/Root/QuestsButton/CountLabel
@onready var nav_grid: GridContainer = $Margin/ScrollContainer/Root/NavGrid
@onready var stats_button: Button = $Margin/ScrollContainer/Root/NavGrid/StatsButton
@onready var training_log_button: Button = $Margin/ScrollContainer/Root/NavGrid/TrainingLogButton
@onready var weekly_summary_button: Button = $Margin/ScrollContainer/Root/NavGrid/WeeklySummaryButton
@onready var settings_button: Button = $Margin/ScrollContainer/Root/NavGrid/SettingsButton
@onready var notification_sfx: AudioStreamPlayer = $NotificationSfx

# Rank-tied styling, mutated as rank changes (design system v2: rank color owns the rank
# badge and the rank card's border/accent), so these can't be baked into the scene.
var _hero_style: ChamferedStyleBox
var _streak_style: ChamferedStyleBox
var _rank_hex: RankHexBadge
var _flame_glyph: HudGlyph
var _quests_glyph: HudGlyph

# The CTA's accent flips to success green once the day is cleared. Tracked so a refresh
# only rebuilds its three StyleBoxes when the state actually changed.
var _cta_accent: Color = Color(0, 0, 0, 0)


func _ready() -> void:
	# First-launch gate (spec v4 3): onboarding is skip-able for returning users, so this
	# only fires once, until ProfileManager.profile.onboarding_complete is set. Checked
	# before any view setup — there's no point styling a screen we're leaving this frame.
	if ProfileManager.needs_onboarding():
		SceneTransition.go_to_scene("res://scenes/onboarding/onboarding_welcome.tscn")
		return

	# Post-migration confirmation pass (spec v4 6): route to Settings > Profile once so
	# the guessed goal/weight can be confirmed/adjusted, instead of the full onboarding flow.
	if ProfileManager.just_migrated:
		ProfileManager.just_migrated = false
		SceneTransition.go_to_scene("res://scenes/settings/settings.tscn")
		return

	_build_cards()
	_build_glyphs()
	_connect_nav()

	GameManager.stats_changed.connect(_refresh_status)
	GameManager.stats_changed.connect(_refresh_avatar)
	QuestManager.quests_generated.connect(_refresh_quest_cta)

	_refresh_date()
	_refresh_status()
	_refresh_avatar()
	_refresh_quest_cta()
	_refresh_reminder()
	_play_entrance()


func _build_cards() -> void:
	_hero_style = ChamferedStyleBox.new()
	hero_card.add_theme_stylebox_override("panel", _hero_style)

	_streak_style = ChamferedStyleBox.new()
	# Pill-scale version of the card shape: the defaults are tuned for full-width panels,
	# and at ~200px wide a 30px chamfer with a 5px accent eats the badge. The opaque
	# default fill is kept as-is — this one sits over the character render, not over a
	# card surface, so it has to carry its own background.
	_streak_style.chamfer_size = 16.0
	_streak_style.shadow_size = 8.0
	_streak_style.accent_width = 3.0
	streak_pill.add_theme_stylebox_override("panel", _streak_style)

	var reminder_style := ChamferedStyleBox.new()
	reminder_style.accent_color = WARNING_COLOR
	reminder_banner.add_theme_stylebox_override("panel", reminder_style)

	NavButtonStyle.apply(dismiss_button, WARNING_COLOR)
	for button in [stats_button, training_log_button, weekly_summary_button, settings_button]:
		NavButtonStyle.apply(button, PRIMARY_ACCENT, NavButtonStyle.ICON_CONTENT_MARGIN)


func _build_glyphs() -> void:
	_rank_hex = RankHexBadge.new()
	_rank_hex.set_anchors_preset(Control.PRESET_FULL_RECT)
	rank_hex_slot.add_child(_rank_hex)

	_flame_glyph = _add_glyph(flame_slot, HudGlyph.Shape.FLAME, GOLD_ACCENT)
	_quests_glyph = _add_glyph(quests_glyph_slot, HudGlyph.Shape.QUESTS, PRIMARY_ACCENT)
	_add_glyph(reminder_glyph_slot, HudGlyph.Shape.ALERT, WARNING_COLOR)
	_add_glyph(stats_button.get_node("GlyphSlot") as Control, HudGlyph.Shape.STATS, PRIMARY_ACCENT)
	_add_glyph(training_log_button.get_node("GlyphSlot") as Control, HudGlyph.Shape.CALENDAR, PRIMARY_ACCENT)
	_add_glyph(weekly_summary_button.get_node("GlyphSlot") as Control, HudGlyph.Shape.TREND, PRIMARY_ACCENT)
	_add_glyph(settings_button.get_node("GlyphSlot") as Control, HudGlyph.Shape.GEAR, PRIMARY_ACCENT)


func _add_glyph(slot: Control, shape: HudGlyph.Shape, color: Color) -> HudGlyph:
	var glyph := HudGlyph.new()
	glyph.shape = shape
	glyph.color = color
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(glyph)
	return glyph


func _connect_nav() -> void:
	quests_button.pressed.connect(_on_quests_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	training_log_button.pressed.connect(_on_training_log_pressed)
	weekly_summary_button.pressed.connect(_on_weekly_summary_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	dismiss_button.pressed.connect(_on_dismiss_reminder_pressed)
	for button in [quests_button, stats_button, training_log_button, weekly_summary_button, settings_button, dismiss_button]:
		PressFeedback.attach(button)


func _refresh_date() -> void:
	var date := Time.get_datetime_dict_from_system()
	date_label.text = "%s · %s %d" % [WEEKDAY_NAMES[date.weekday], MONTH_NAMES[date.month - 1], date.day]


func _refresh_status() -> void:
	var stats := GameManager.hunter_stats
	var rank_color := GameManager.rank_color(stats.rank)

	_hero_style.accent_color = rank_color
	_hero_style.emit_changed()
	_rank_hex.rank_color = rank_color
	_rank_hex.rank_letter = stats.rank
	_rank_hex.queue_redraw()
	# Rank-tinted lighting behind the render, in three layers, so the character is lit
	# rather than pasted onto a flat card: a vertical wash that peaks behind the torso and
	# fades out at the top (the identity/streak overlay lives up there and needs the dark
	# scrim to stay readable), a radial halo the silhouette reads against, and the floor
	# glow at the feet. All three tint from the rank color, so a rank-up visibly changes
	# the light in the room instead of only swapping a letter in the badge.
	backdrop.modulate = Color(rank_color.r, rank_color.g, rank_color.b, 0.85)
	aura_glow.modulate = Color(rank_color.r, rank_color.g, rank_color.b, 0.7)
	platform_glow.modulate = Color(rank_color.r, rank_color.g, rank_color.b, 0.8)

	hunter_title_label.text = stats.current_title.to_upper() if stats.current_title != "" else "HUNTER"
	hunter_title_label.add_theme_color_override("font_color", rank_color)
	level_label.text = "LEVEL %d" % stats.level

	_refresh_streak(stats)
	_refresh_xp(stats)


## A zero streak has nothing to celebrate, so the pill drops to secondary text rather
## than showing a bright gold "0 DAYS" badge — that keeps gold meaningful. It stays at
## secondary rather than the divider color so the zero is still readable over the render
## (divider #2A3A5C is a border weight, too dark to carry text).
func _refresh_streak(stats: HunterStats) -> void:
	var live := stats.current_streak > 0
	var tint := GOLD_ACCENT if live else SECONDARY_TEXT
	streak_count_label.text = "%d" % stats.current_streak
	streak_unit_label.text = "DAY" if stats.current_streak == 1 else "DAYS"

	_streak_style.accent_color = tint
	_streak_style.emit_changed()
	_flame_glyph.color = tint
	streak_count_label.add_theme_color_override("font_color", tint)


func _refresh_xp(stats: HunterStats) -> void:
	var xp_needed := GameManager.xp_to_next_level(stats.level)
	xp_value_label.text = "%d / %d" % [stats.xp, xp_needed]
	xp_bar.max_value = xp_needed
	var tween := create_tween()
	tween.tween_property(xp_bar, "value", stats.xp, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The CTA carries the day's progress so the hub answers "is there anything left to do?"
## without a tap. Cleared days flip it to success green — the day's state is the single
## most useful thing this screen can show.
func _refresh_quest_cta() -> void:
	var quests := QuestManager.current_quests
	var completed := 0
	for quest in quests:
		if quest.completed:
			completed += 1

	var all_clear := not quests.is_empty() and completed == quests.size()
	quests_button.text = "ALL QUESTS CLEAR" if all_clear else "TODAY'S QUESTS"
	quest_count_label.text = "%d / %d" % [completed, quests.size()]

	var accent := SUCCESS_COLOR if all_clear else PRIMARY_ACCENT
	if accent == _cta_accent:
		return
	_cta_accent = accent
	NavButtonStyle.apply(quests_button, accent, NavButtonStyle.ICON_CONTENT_MARGIN, true)
	_quests_glyph.color = accent
	quest_count_label.add_theme_color_override("font_color", accent)


func _refresh_reminder() -> void:
	reminder_banner.visible = NotificationManager.any_reminder_due()
	if reminder_banner.visible:
		notification_sfx.play()


## Swaps the character panel to the current rank's physique tier. The scene's own
## texture is the Rank E render, so this is a no-op on a fresh save.
func _refresh_avatar() -> void:
	var path := GameManager.rank_avatar_path(GameManager.hunter_stats.rank)
	# stats_changed fires on every XP gain, but the avatar only moves at a rank
	# boundary — skip the multi-MB texture load unless the tier actually changed.
	if character_panel.texture and character_panel.texture.resource_path == path:
		return
	character_panel.texture = load(path)


## Staggered fade-in down the hub, so the eye is led status → primary action → secondary
## nav instead of the whole screen arriving flat. Alpha only: these are container
## children, and a container overwrites any position offset on the next layout pass.
func _play_entrance() -> void:
	var cards: Array[Control] = [hero_card, quests_button]
	for child in nav_grid.get_children():
		cards.append(child as Control)

	for i in cards.size():
		var card := cards[i]
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(STAGGER_STEP * float(i))
		tween.tween_property(card, "modulate:a", 1.0, CARD_FADE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_quests_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/home/home.tscn")


func _on_stats_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/stats/stats.tscn")


func _on_training_log_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/training_log/training_log.tscn")


func _on_weekly_summary_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/weekly_summary/weekly_summary.tscn")


func _on_settings_pressed() -> void:
	SceneTransition.go_to_scene("res://scenes/settings/settings.tscn")


func _on_dismiss_reminder_pressed() -> void:
	reminder_banner.visible = false
