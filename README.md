# Solo: Gym Leveling

A personal fitness RPG app built in Godot 4.7 (mobile). Turns your real gym program into quests: complete quests, earn XP, level up stats, and climb Hunter ranks — no paywalls, no penalty mechanics, no social features.

## Core Loop

- Quests are generated from your actual training program (not generic filler)
- Completing quests grants XP and tracks personal records (PRs) per exercise
- XP drives rank progression (E → S) and cosmetic milestone titles
- Streaks are tracked with one forgiveness freeze per week — missing a day never resets or penalizes progress

## Design Principles

- Never gate save or quest-completion behind a paywall
- No penalty mechanics (no stat decay, no "immunity tokens")
- Quests stay tied to the real program, never generic templates
- No social/multiplayer — this is a personal tool, not a social product

See [`docs/Solo_Gym_Leveling_App_Spec_v2.md`](docs/Solo_Gym_Leveling_App_Spec_v2.md) for the full product spec and design rationale.

## Project Structure

```
scenes/       UI screens (lobby, home, quest_detail, stats, settings, training_log, weekly_summary, system_popup)
scripts/
  autoload/   Global singletons: GameManager, QuestManager, HistoryManager, PRTracker, SaveManager, NotificationManager
  resources/  Custom Resource definitions
resources/    Godot resources, including the hunter_theme
data/         Program/quest data
assets/       Art, fonts, and other static assets
docs/         App specs
```

## Getting Started

1. Open the project in [Godot 4.7](https://godotengine.org/) (Mobile rendering method).
2. The main scene is `scenes/lobby/lobby.tscn`.
3. Run the project from the editor, or export for Android via **Project > Export**.

### Installing the APK

A prebuilt Android package is attached to the [`beta` release](https://github.com/exo-jhop/Solo-Gym-Leveling/releases/tag/beta) as `Solo Gym Leveling.apk`, signed with its matching `.apk.idsig`. Download it from the release and sideload it onto an Android device (enable "Install unknown apps" for your file manager/browser) instead of building from source.

## Tech

- Engine: Godot 4.7
- Platform: Android (mobile-first)
- Rendering: Mobile renderer
