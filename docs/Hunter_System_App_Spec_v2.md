# Hunter System: Fitness RPG App — Spec v2
**Engine:** Godot 4.7 | **Platform:** Android (mobile-first) | **Status:** Refinement pass on working MVP

---

## 1. What Changed Since v1

v1 built the functional core: quests, XP, stats, rank, streak, save/load, navigation. This pass reviews the competitive landscape and real user feedback to decide what to add, what to deliberately avoid, and how to sharpen what already exists.

---

## 2. Competitive Landscape

| App | Core Loop | Notable Feature | Notable Complaint |
|---|---|---|---|
| Arise Solo | Quests → XP → Rank E-S | Clean RPG-inspired UI | Most features paywalled, free-plan save bugs |
| Solo Hunter: Level Up | Quests → Dungeons → Penalty System | 5-stat system near-identical to ours, Job Classes at level milestones | Punishment-based (penalties, "immunity tokens") |
| LevelUp: Fitness | Quests → Dungeons → Turn-based battles | Equipment/gear economy, 180+ items | Users want workouts decoupled from combat, want social/guilds |
| Lifted | Group check-ins → shared Level | Real accountability via group stakes | Missing a check-in resets the WHOLE group to Level 1 |
| LEVELING Fitness | Quests → Manga-style missions | Immersive interface, no-equipment routines | Limited public feedback available |

**Where our app already differs (keep this):**
- No paywall on save/complete, ever
- No penalty system, streak forgiveness already built in (weekly freeze)
- Quests generated from a real, user-specific program, not generic templates

**Where we're currently behind (address in v2):**
- No reminder/notification system (direct ADHD-relevant complaint from competitor reviews)
- No milestone rewards beyond Rank up (competitors use Job Classes/titles to give levels emotional weight)
- No visual identity yet (still default Godot theme)

---

## 3. Design Principles (Carried Forward, Now Explicit Rules)

1. **Never gate save or quest-completion behind a paywall.** This is the single most common complaint across every competitor with a free tier.
2. **No penalty mechanics.** No stat decay, no "immunity tokens," no group resets. Missing a day costs nothing except the honest fact that you missed it.
3. **Streak forgiveness stays, doesn't get removed for "engagement" reasons.** One freeze per week, non-negotiable.
4. **Quests stay tied to the real program.** Never generic "do 20 pushups" filler.
5. **Social/multiplayer stays out of scope entirely**, not deferred, not planned for later. This is a personal tool, not a social product. (Explicit reversal of the "add guilds" feedback trend, see Section 6 for reasoning.)

---

## 4. New/Revised Features for v2

### 4.1 End-of-Day Reminder (addresses the #1 concrete complaint found)
- Local notification (Godot's `OS` / Android notification API) fires at a configurable time (default 8:00 PM) **only if today's quests aren't fully logged**
- No notification at all if the day's quests are already complete, don't nag someone who already did the work
- Setting to disable entirely, respect people who don't want notifications

### 4.2 Milestone Titles (lightweight alternative to Job Classes)
- At specific Rank-ups, the Hunter earns a cosmetic **Title** (text only, no stat effect): e.g. Rank D → "Awakened", Rank B → "Vanguard", Rank S → "Monarch"
- Titles display on the Lobby/hub screen next to the Hunter's name
- Deliberately **no gear/equipment/shop economy.** Competitors' 180-item shops exist to drive IAP engagement, we have no monetization, so there's no reason to add inventory-management complexity for its own sake. If this ever feels genuinely motivating later, revisit, but don't build it preemptively.

### 4.3 Quest Difficulty Signals (not full adaptive AI, but a manual out)
- Add a "Feeling low energy today?" toggle on Home, visible only on training days
- If toggled, that day's lift quests show reduced target values (e.g. drop one set) and are tagged `reduced` in the DailyLog
- This directly answers the "fixed workouts don't know if you're recovering" gap, without building a real recovery-tracking system (out of scope for a personal app)

### 4.4 Calendar Heatmap Refinement (Training Log)
- Beyond just showing completed/incomplete per day, color-intensity by `quests_completed / quests_total` ratio (partial days show a lighter shade, not just binary complete/incomplete)
- Tapping a day shows the `quest_summaries` from that `DailyLog` entry

### 4.5 Weekly Summary Screen (new, small addition)
- Simple screen off the Lobby: this week's total XP, quests completed vs. total, current streak, one stat that grew the most
- Answers a psychological gap competitors' pure-daily-quest UIs have: no way to see the week as a whole without scrolling a calendar

---

## 5. UI/UX Direction (Refined from v1 Section 5)

- **Palette:** deep navy/near-black base (`#0A0E1A` range), electric blue accent (`#3B82F6`-ish) for active/positive states, violet accent (`#8B5CF6`-ish) reserved specifically for Rank-up moments so it stays special
- **Typography:** angular/monospace font for numbers (XP, stats, streak count), a cleaner sans-serif for body text, don't make everything hard to read for the sake of theme
- **System popup overlay:** border-glow + slide-in, as specified in v1, now explicitly reserved for Level-up and Rank-up only, don't overuse it for routine quest completion (that stays a quick, small toast/checkmark animation instead, so the big moment still feels big)
- **Home screen hierarchy:** today's quests should be the visually dominant element, XP bar and streak are secondary/header elements, don't let stat numbers compete for attention with the actual task list

---

## 6. Why We're Rejecting Some Competitor Feedback

Being deliberate about what NOT to build matters as much as what to build.

**Rejected: Guilds/social/messaging.** Multiple reviews ask for this, but it requires a backend, accounts, and moderation, none of which fit a solo personal tool built by one person in Godot with local-only saves. Adding it would also violate the "no scope creep" principle from v1 Section 8. This is correctly staying out of scope.

**Rejected: Penalty systems.** Competitors use fear (penalties, group resets) to drive engagement. Research on gamification and exercise adherence suggests this backfires for sustained use, punishment-based mechanics increase short-term compliance but damage long-term motivation once someone inevitably misses a day. Our forgiveness-based streak system is the better long-term bet, keep it.

**Rejected: Full equipment/gear economy.** This exists in competitor apps to support in-app purchases (buying gold, buying premium gear). We have no monetization goal, so this feature would add UI complexity and save-data surface area for no real benefit.

**Partially accepted: Turn-based battle layer.** One reviewer's idea (decouple combat from raw workout completion, make it a separate mini-game) is creatively interesting but is a genuinely large feature (combat system, enemy design, balance). Flagging as a **possible v3 idea**, explicitly not v2 scope.

---

## 7. Updated Data Model Additions

```gdscript
# Added to HunterStats
@export var current_title: String = ""  # set on rank-up per milestone table

# Added to DailyLog (from history model already approved)
@export var was_reduced_intensity: bool = false  # true if "low energy" toggle was used
```

```gdscript
# New: NotificationManager (autoload)
extends Node
## Owns the end-of-day reminder scheduling logic.

var reminder_hour: int = 20  # 8 PM default, user-configurable in Settings
var reminder_enabled: bool = true

func schedule_check() -> void:
    # Checks if today's quests are fully complete; if not, and reminder_enabled,
    # schedules a local notification via Android's notification API.
    pass
```

---

## 8. v2 Build Order

1. **Milestone Titles** (small, touches HunterStats + rank-up popup logic already built)
2. **Weekly Summary screen** (small, read-only, no new data model beyond what exists)
3. **Calendar heatmap refinement** (builds directly on approved DailyLog/HistoryManager work)
4. **Quest Difficulty toggle** (touches QuestManager's daily generation logic)
5. **End-of-day reminder notifications** (most technically distinct, touches Android-specific APIs, do last since it's the most likely to need platform-specific debugging)
6. **Visual polish pass**, now informed by the refined palette/typography direction in Section 5

---

## 9. Explicitly Out of Scope (v2 and beyond, unless truly reconsidered)

- Guilds, social features, messaging, leaderboards
- Penalty/punishment mechanics of any kind
- Equipment/gear/shop economy
- Cloud sync or accounts
- Turn-based battle layer (flagged as v3 idea only, not committed)

---

## 10. Self-Review Notes

Before finalizing, checked this spec against a few failure modes:

- **Does it contradict v1's "no scope creep" principle?** No, every addition is small and directly tied to a specific piece of user feedback, not speculative feature-adding.
- **Does it accidentally reintroduce a rejected pattern?** Checked Milestone Titles against the "no penalty" rule, titles are purely positive/cosmetic, no downside for not having one yet, so it's consistent.
- **Is anything here undoable without real Reddit-thread access?** The one gap is not having the specific thread's comments, everything above is grounded in App Store/Play Store review data and one industry blog's research citation, which is a reasonable substitute but worth noting as a limitation.
