# TimeBack XP System Implementation

## Overview

Astro Math uses a simplified XP system based purely on **accuracy** and **progress toward mastery**.

## Core Formula

```
Base XP = 2 × (correct_answers / mastery_count)
```

**Conditions:**
- If accuracy < 80%: **0 XP** (and 0 stars)
- If accuracy ≥ 80%: **Base XP**
- If 100% accuracy AND at least 1 new star earned: **Base XP × 1.25**

## Star Requirements

Stars require meeting **BOTH** correct answer count AND accuracy thresholds:

| Stars | Correct Answers | Accuracy |
|-------|-----------------|----------|
| 0 stars | Below thresholds | Below 80% |
| 1 star | ≥33% of mastery_count | ≥80% |
| 2 stars | ≥66% of mastery_count | ≥85% |
| 3 stars | 100% of mastery_count | ≥90% |

**Important:** Accuracy below 80% results in 0 stars AND 0 XP, regardless of correct answer count.

## Configuration Variables

All settings in `scripts/game_config.gd`:

```gdscript
# Star requirements - correct answers (percentage of mastery_count)
var star1_correct_percent = 0.33  # 33% for 1 star
var star2_correct_percent = 0.66  # 66% for 2 stars
var star3_correct_percent = 1.0   # 100% for 3 stars

# Star requirements - accuracy thresholds
var star1_accuracy_threshold = 0.80  # 80% for 1 star
var star2_accuracy_threshold = 0.85  # 85% for 2 stars
var star3_accuracy_threshold = 0.90  # 90% for 3 stars

# XP multiplier for perfect accuracy + new star
var perfect_accuracy_xp_multiplier = 1.25
```

## XP Calculation Examples

### Example 1: Good Performance
- Mastery count: 20
- Correct answers: 15
- Accuracy: 88%

```
Base XP = 2 × (15/20) = 2 × 0.75 = 1.5 XP
Stars: 2 (meets 66% correct + 85% accuracy)
Final XP: 1.5 XP
```

### Example 2: Perfect Performance with New Star
- Mastery count: 20
- Correct answers: 20
- Accuracy: 100%
- Previous stars: 2, New stars: 3 (earned 1 new star)

```
Base XP = 2 × (20/20) = 2 × 1.0 = 2.0 XP
Perfect accuracy bonus: 2.0 × 1.25 = 2.5 XP
Stars: 3 (meets 100% correct + 90% accuracy)
Final XP: 2.5 XP
```

### Example 3: Low Accuracy
- Mastery count: 20
- Correct answers: 18
- Accuracy: 72%

```
Accuracy below 80% threshold
Stars: 0
Final XP: 0 XP
```

### Example 4: High Accuracy, Low Progress
- Mastery count: 20
- Correct answers: 5
- Accuracy: 100%
- Previous stars: 0, New stars: 0 (didn't reach 33% for 1 star)

```
Base XP = 2 × (5/20) = 2 × 0.25 = 0.5 XP
No new star earned, so no perfect accuracy bonus
Stars: 0 (below 33% correct threshold)
Final XP: 0.5 XP
```

## Implementation Details

### Session Lifecycle

1. **Session Start** (`state_manager.gd`)
   - Called when level begins
   - Records start timestamp for idle detection

2. **Input Tracking** (`input_manager.gd`)
   - Tracks player inputs for idle time detection
   - Idle time (>10 seconds no input) is subtracted from session

3. **Session End** (`state_manager.gd`)
   - Calculates correct answers, accuracy, and stars
   - Computes XP using simplified formula
   - Awards XP through Playcademy TimeBack API

### Key Functions

**In `playcademy_manager.gd`:**

- `start_session_tracking()` - Begin tracking
- `record_player_input()` - Track inputs for idle detection
- `end_grade_level_session_and_award_xp()` - Calculate and award XP

**In `score_manager.gd`:**

- `evaluate_stars_for_mastery_count()` - Determine stars earned based on correct answers + accuracy
- `get_star_requirements()` - Get thresholds for each star tier

## Assessment Mode XP

Assessment mode uses a simplified calculation:
- **1 XP per minute of active play time**
- No performance multipliers
- Idle time is subtracted (10-second threshold)

## Idle Time Detection

- Tracks time between player inputs
- After 10 seconds of no input, time is considered "idle"
- Idle time is subtracted from session duration
- Only affects assessment mode XP (grade levels use performance-based XP)

## Integration with Playcademy

The system sends progress data including:
- XP earned
- Correct/total questions
- Stars earned
- Accuracy percentage

This data is sent to `PlaycademySdk.timeback.record_progress()` for analytics.

## Replay XP Falloff

When a player replays a level **without earning a new star** (e.g., they had 1 star and only earned 1 star again), XP is reduced with diminishing returns:

| Consecutive Replays Without New Star | XP Multiplier |
|--------------------------------------|---------------|
| 1st replay | **0.5x** |
| 2nd replay | **0.25x** |
| 3rd+ replay | **0.1x** |

**Key rules:**
- The falloff counter is tracked **per level** in save data (`no_new_star_replays`)
- When a player **earns a new star**, the counter resets to 0 (full XP on next play)
- The falloff multiplier is applied **after** the base XP and perfect accuracy bonus calculations
- If accuracy is below 80%, XP is 0 regardless (falloff doesn't apply to 0)

### Configuration

In `scripts/game_config.gd`:

```gdscript
# Replay XP falloff - multipliers applied when replaying without earning a NEW star
# Index 0 = first replay without new star, index 1 = second, last value = all subsequent
var replay_no_new_star_xp_multipliers = [0.5, 0.25, 0.1]
```

### Example: Replay Falloff

- Mastery count: 20
- Correct answers: 15
- Accuracy: 88%
- Previous stars: 2, New stars: 2 (no new star earned)
- This is the player's 2nd consecutive replay without a new star

```
Base XP = 2 × (15/20) = 1.5 XP
No new star (replay #2): 1.5 × 0.25 = 0.375 XP
Stars: 2 (no change)
Final XP: 0.38 XP
```

If the player then earns a 3rd star on their next attempt, the counter resets and they receive full XP (plus the perfect accuracy bonus if applicable).

## Notes

- The 80% accuracy threshold ensures players are answering carefully, not rushing
- The 1.25x perfect accuracy bonus rewards precision
- Replaying levels without earning new stars yields diminishing XP to discourage farming
- Earning a new star resets the falloff counter, rewarding genuine improvement
- Maximum possible XP per level: 2.5 XP (100% correct + 100% accuracy + new star)
