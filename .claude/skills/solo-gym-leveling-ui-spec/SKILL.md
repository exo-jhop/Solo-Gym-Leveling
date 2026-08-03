---
name: solo-gym-leveling-ui-spec
description: UI/visual design spec for the Solo Gym Leveling app (colors, typography, chamfered-card component, rank visualizations), based on Arise Solo reference screenshots. Use whenever building or editing any UI scene, theme resource, or visual component. Not related to gameplay logic, program generation, or streak/quest systems.
---

# Solo Gym Leveling — Design System (v2, reference-matched)

## Color Palette
- Background base: #0A0E17
- Surface/card: #131A2B
- Border/divider (default): #2A3A5C
- Primary accent (XP/level/nav): #00B8FF
- Success/consistency/completed: #3ADB76
- Streak/achievement/gold: #FFB800
- Warning: #FF6B35
- Text primary: #E8EDF7
- Text secondary: #7B8AAE

## Rank-tier colors (separate system from UI-state colors above)
- E-Rank: #7B8AAE (gray)
- D-Rank: #3ADB76 (green)
- C-Rank: #00B8FF (blue)
- B-Rank: #A855F7 (purple)
- A-Rank: #FFB800 (gold)
- S-Rank: #FF3B3B (red)
Rank color always applies to: rank badge, rank hexagon nodes, rank detail card border/accent.

## Signature component: chamfered HUD card
Every card/panel uses angled (chamfered) corners, NOT simple rounded rects.
- Top-right and bottom-left corners are cut at 45°, traced with a colored
  accent line (color depends on card category, e.g. blue for XP cards,
  gold for streak cards, teal for analytics cards)
- Top-left and bottom-right corners stay square
- Implement via custom StyleBox (draw via _draw() on a Control, or a
  Polygon2D-based panel) — Godot's built-in StyleBoxFlat corner radius
  cannot produce angled chamfers, so this needs a custom stylebox script
- This chamfer treatment is the single most important visual signature —
  apply it consistently to every card across every screen

## Typography
- All labels/headers: uppercase, letter-spacing increased (+1-2px)
- Big numeric readouts (LVL, XP, streak count): bold, large, tech-leaning
  sans-serif (Rajdhani or similar geometric sans — NOT monospace, the
  reference uses a rounded/geometric display font, not code-style mono)
- Body/description text: standard sans-serif, secondary text color

## Charts
- Line charts with filled gradient area under the curve (accent color,
  fading to transparent toward the X-axis)
- Some contexts show visible dot markers on data points (Stats screens),
  others show smooth line only (Progress screen) — match per-screen intent,
  don't apply markers everywhere
- Radar/pentagon chart: KEPT, scoped specifically to the 5-stat display
  (STR/VIT/AGI/INT/SENSE) on Home and Stats. This is a different data
  domain from rank progression and isn't something the reference
  screenshots address either way — it stays as an existing, working
  feature. Do not remove it, and do not use radar/pentagon styling for
  anything else (rank progression uses the dial/ladder below instead).

## Rank visualizations (two distinct components, both needed)
1. Radial dial (Core view): center hexagon = current rank, circular arc
   gauge around it showing progress %, other rank hexagons dimmed at
   compass points, "SYNC STATUS: X%" text readout below
2. Rank ladder (Orig view): vertical chain of hexagon nodes connected by
   circuit-style branch lines, each node colored per rank-tier palette
   above, tapping a node opens a detail card (min/max level, XP multiplier,
   description) bordered in that rank's color

## Navigation
- Bottom tab bar: Home, Quests, Analytics, Profile
- Active tab icon uses success-green (#3ADB76), not the primary blue accent
- Segmented pill control (e.g. Overview/Progress/Stats) at top of
  multi-view screens: active segment = solid filled blue pill, inactive =
  transparent/outlined

## Mobile Constraints (mandatory for all screens)
- Minimum touch target size: 48x48px (Android accessibility guideline) for
  any tappable element — buttons, checkboxes, quest rows, nav icons. Text
  links or small icons alone are not tappable-safe below this size.
- Design canvas: assume a portrait viewport around 1080x2400 (common
  Android resolution), NOT the current desktop-window aspect ratio used in
  screenshots so far.
- Safe area margins: reserve top ~24-48px for status bar area, bottom
  ~24-48px for gesture nav bar area — no interactive elements flush against
  screen edges.
- Font sizes: body text minimum 14sp-equivalent, numeric readouts (XP,
  level, stats) minimum 16-18sp — verify current font sizes against this,
  desktop-comfortable sizes may be too small on an actual phone screen.
- Scrollable content: any screen with more content than fits one viewport
  (Training Log, Settings, future Analytics tabs) must use a ScrollContainer
  — verify this is actually in place, not just visually appearing to fit in
  a desktop window.
- Bottom navigation bar (Home/Quests/Analytics/Profile) must stay fixed/
  pinned, not scroll with content.
- Test all touch targets and layouts against Godot's mobile viewport
  preview or an actual portrait aspect ratio, not the default desktop editor
  window size.

## Anti-patterns to avoid
- Do not use plain rounded-rect cards — chamfered corners are mandatory
- Do not use radar/pentagon charts for rank progression — that's reserved
  for the 5-stat display only; rank uses the dial/ladder components
- Do not reuse rank-tier colors as general UI accent colors outside rank
  contexts — they're reserved for rank-related elements only
- Do not use copyrighted character artwork for the avatar — use a generic
  silhouette or user-uploaded photo in the circular glowing-ring frame
