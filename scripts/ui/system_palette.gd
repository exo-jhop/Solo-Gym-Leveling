class_name SystemPalette
extends RefCounted

## Design system v2 palette in one place.
##
## Every screen script had grown its own copy of these literals (six near-identical
## `const PRIMARY_ACCENT := Color(0.0, 0.721569, 1.0, 1.0)` declarations across
## lobby/home/stats/training_log/settings/quest_detail), which is exactly the
## "raw hex in components" problem semantic color tokens exist to solve — a palette
## tweak meant hunting down every duplicate. New code should reference these;
## the remaining local copies in older screens are legacy duplicates of the same values.
##
## Note the deliberate split: these are UI-state colors. Rank-tier colors are a separate
## system and live in GameManager.RANK_COLORS, because the design system reserves them
## for rank contexts (badge, hexagon, rank card accent) and bars reusing them as general
## UI accents.

const BACKGROUND := Color(0.0392157, 0.054902, 0.0901961, 1.0)  # #0A0E17
const SURFACE := Color(0.0745098, 0.101961, 0.168627, 1.0)  # #131A2B
const DIVIDER := Color(0.164706, 0.227451, 0.360784, 1.0)  # #2A3A5C

const PRIMARY := Color(0.0, 0.721569, 1.0, 1.0)  # #00B8FF — XP, level, navigation
const SUCCESS := Color(0.227451, 0.858824, 0.462745, 1.0)  # #3ADB76 — completion, consistency
const GOLD := Color(1.0, 0.721569, 0.0, 1.0)  # #FFB800 — streak, achievement, PRs
const WARNING := Color(1.0, 0.419608, 0.207843, 1.0)  # #FF6B35

const TEXT := Color(0.909804, 0.929412, 0.968627, 1.0)  # #E8EDF7
const TEXT_SECONDARY := Color(0.482353, 0.541176, 0.682353, 1.0)  # #7B8AAE


## Same color at a different alpha. Saves the four-field Color(c.r, c.g, c.b, a)
## rebuild that was being written out longhand at nearly every call site.
static func alpha(color: Color, a: float) -> Color:
	return Color(color.r, color.g, color.b, a)
