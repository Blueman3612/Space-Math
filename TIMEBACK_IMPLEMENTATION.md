# TimeBack XP System Implementation

## Overview
This document describes the enhanced TimeBack integration that awards XP based on active play time with CQPM (Correct Questions Per Minute) multipliers.

## Core Principle
**1 minute of active time = 1 base XP**, multiplied by a performance-based CQPM multiplier.

## Key Features

### 1. Wall-Clock Session Tracking
- Sessions tracked using Unix timestamps (not paused game timer)
- Start timestamp recorded when level/drill mode begins
- End timestamp recorded when level/drill mode completes

### 2. Idle Time Detection
- Tracks time between player inputs
- After 10 seconds (configurable) of no input, time is considered "idle"
- Idle time is subtracted from total session duration
- Only active time counts toward XP

### 3. Individual Level Multipliers
#Note: ALL MULTIPLIER/CQPM THRESHOLDS ARE JUST FOR EXAMPLE PURPOSES

Each of the 11 levels has its own CQPM multiplier scale:
- **Addition Levels (1-3)**: 30+ CQPM = 3x, 20+ = 2x, 15+ = 1.5x, etc.
- **Subtraction Levels (4-5)**: 25+ CQPM = 3x, 18+ = 2x, 12+ = 1.5x, etc.
- **Multiplication Levels (6-7)**: 20+ CQPM = 3x, 15+ = 2x, 10+ = 1.5x, etc.
- **Division Level (8)**: 15+ CQPM = 3x, 12+ = 2x, 8+ = 1.5x, etc.
- **Fraction Levels (9-11)**: 10+ CQPM = 3x (Level 9), scales down for harder levels

### 4. Star-Based XP Gating (Normal Levels Only)
Reduces XP rewards for mastered levels to encourage progression:
- **0-1 stars**: 100% XP (still learning)
- **2 stars**: 75% XP (getting good)
- **3 stars**: 25% XP (mastered, move on to harder content)

This prevents farming easy/mastered levels for XP.

### 5. Drill Mode Multiplier
Separate multiplier scale for drill mode (no star gating):
- 25+ CQPM = 3x
- 18+ CQPM = 2.5x
- 12+ CQPM = 2x
- 8+ CQPM = 1.5x
- 5+ CQPM = 1.2x
- 2+ CQPM = 1x
- <2 CQPM = 0.5x

## Configuration Variables

All settings in `scripts/game_config.gd`:

```gdscript
# Core Settings
timeback_base_xp_per_minute = 1.0     # Base XP rate
timeback_idle_threshold = 10.0         # Seconds before idle
timeback_min_session_duration = 5.0    # Minimum session to count
timeback_max_multiplier = 4.0          # Cap on multiplier
timeback_min_multiplier = 0.1          # Floor for multiplier

# Star-based XP gating (normal levels only)
timeback_star_multipliers = {
    0: 1.0,   # 0 stars = 100% XP
    1: 1.0,   # 1 star = 100% XP
    2: 0.75,  # 2 stars = 75% XP
    3: 0.25   # 3 stars = 25% XP
}

# Level-specific multipliers
timeback_level_multipliers = {
    1: [[60.0, 4.0], [45.0, 2.0], ...],
    2: [[60.0, 4.0], [45.0, 2.0], ...],
    # ... for all 11 levels
}

# Drill mode multipliers
timeback_drill_mode_multipliers = [
    [60.0, 3.0], [50.0, 2.0], ...
]
```

## XP Calculation Formula

```
Active Time = Total Session Time - Idle Time
Active Minutes = Active Time / 60
Game Time = In-game timer (pauses during transitions)
CQPM = (Correct Answers / Game Time) × 60
CQPM Multiplier = lookup from level-specific scale based on CQPM
Star Multiplier = lookup from star count (normal levels only, drill = 1.0)
Base XP = Active Minutes × Base XP Per Minute (1.0)
XP After CQPM = Base XP × CQPM Multiplier
Final XP = XP After CQPM × Star Multiplier (rounded to nearest integer)
```

**Key distinction:**
- **Active Time** (wall clock - idle) is used for base XP calculation (rewards engagement)
  - Measures real time player was present and active
  - Subtracts idle time but includes transition delays
- **Game Time** (in-game timer) is used for CQPM calculation (rewards pure performance)
  - Only counts active gameplay time (pauses during transitions)
  - Provides fair measure of problem-solving speed
  - Matches the timer displayed to the player

## Example Output

When a level completes, you'll see detailed metrics:

```
============================================================
[TimeBack] LEVEL COMPLETION METRICS
============================================================
Level: Addition - Level 1 (Global Level 1)
Stars Earned: 3

TIME METRICS:
  Total session duration: 85.3s (1.42 minutes)
  Idle time subtracted:   12.5s (0.21 minutes)
  Active time counted:    72.8s (1.21 minutes) [for XP base]
  Game timer (in-game):   68.0s (1.13 minutes) [for CQPM]

PERFORMANCE METRICS:
  Correct answers: 35
  CQPM (35 / 68.0s × 60): 30.88
  CQPM Multiplier for Level 1: 2.00x
  Star Multiplier (3 stars): 0.25x

XP CALCULATION:
  Base XP (1.21 min × 1.0 XP/min) = 1.21
  After CQPM (1.21 × 2.00x) = 2.42
  After Star Gate (2.42 × 0.25x) = 1 XP
============================================================
```

## Implementation Details

### Session Lifecycle

1. **Session Start** (`state_manager.gd`)
   - Called when level begins: `PlaycademyManager.start_session_tracking(pack_name, level_index)`
   - Records start timestamp, resets idle tracking

2. **Input Tracking** (`input_manager.gd`)
   - Every input calls: `PlaycademyManager.record_player_input()`
   - Checks time since last input
   - If > idle threshold, adds to idle time accumulator

3. **Session End** (`state_manager.gd`)
   - Called when level completes: `PlaycademyManager.end_session_and_award_xp(...)`
   - Calculates all metrics
   - Prints detailed breakdown
   - Awards XP through Playcademy TimeBack API

### Key Functions

**In `playcademy_manager.gd`:**

- `start_session_tracking(pack_name, level_index)` - Begin tracking
- `record_player_input()` - Track each input, detect idle time
- `end_session_and_award_xp(...)` - Calculate and award XP for normal levels
- `end_drill_session_and_award_xp()` - Calculate and award XP for drill mode
- `get_cqpm_multiplier_for_level(level_number, cqpm)` - Get level-specific multiplier
- `get_cqpm_multiplier_for_drill_mode(cqpm)` - Get drill mode multiplier

## Tuning the System

### To adjust difficulty/generosity:

1. **Change base XP rate**: Modify `timeback_base_xp_per_minute` (default: 1.0)
2. **Change idle threshold**: Modify `timeback_idle_threshold` (default: 10.0 seconds)
3. **Adjust level multipliers**: Edit the arrays in `timeback_level_multipliers`
4. **Cap multipliers**: Change `timeback_max_multiplier` or `timeback_min_multiplier`
5. **Adjust star gating**: Modify `timeback_star_multipliers` to change how much mastered levels are penalized

### To make a level more rewarding:
- Lower the CQPM thresholds for higher multipliers
- Example: Change `[20.0, 2.0]` to `[15.0, 2.0]` to give 2x at 15 CQPM instead of 20

### To reduce/increase farming penalties:
- Increase star multipliers for more XP on replays (e.g., 3 stars: 0.25 → 0.5)
- Decrease star multipliers to further discourage farming (e.g., 3 stars: 0.25 → 0.1)

### To make drill mode more challenging:
- Raise the CQPM thresholds in `timeback_drill_mode_multipliers`

## Testing Recommendations

1. Play a full level and verify the metrics printout
2. Test with deliberate idle time (stop playing for 15+ seconds)
3. Check that idle time is properly subtracted
4. Verify CQPM calculation matches expectations
5. Test both fast and slow play to see multiplier changes
6. Confirm XP is awarded to Playcademy platform

## Integration with Playcademy

The system sends progress data including:
- XP earned
- Correct/total questions
- Time spent (active time only)
- Stars earned
- Metadata: CQPM, multiplier, idle time, etc.

This data is sent to `PlaycademySdk.timeback.record_progress()` and appears in the Playcademy dashboard for analytics.

## Notes

- Minimum session duration (5 seconds) prevents trivial sessions from awarding XP
- Session tracking is independent of the game's paused timer
- Idle time detection starts after the configurable threshold (10 seconds)
- All CQPM multipliers are clamped between min (0.1x) and max (4.0x)
- Star-based gating only applies to normal levels, NOT drill mode
- Star gating encourages players to progress to new content rather than farm mastered levels
- The system gracefully handles missing SDK or network issues

