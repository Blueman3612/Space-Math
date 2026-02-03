## What is Astro Math?

Astro Math is an adaptive math fluency game covering **Grades 1-5** with 40+ skill standards across addition, subtraction, multiplication, division, fractions, and decimals.

---

## 🎯 The Assessment

When a student first opens Astro Math, they take a **diagnostic assessment** before accessing any content. This assessment:

- **Tests 40 math standards** in order of complexity
- **Takes 3-15 minutes** depending on skill level
- **Has no timer** — students work at their own pace
- **Automatically places students** by unlocking mastered content

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    ASSESSMENT FLOW                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Student answers 2-10 questions per standard               │
│                           ↓                                 │
│   ┌─────────────────────────────────────────────┐          │
│   │  Did they meet the CQPM* target with        │          │
│   │  acceptable accuracy?                        │          │
│   └─────────────────────────────────────────────┘          │
│              ↓ YES                    ↓ NO                  │
│        ┌──────────┐            ┌──────────────┐            │
│        │ MASTERED │            │    FAILED    │            │
│        │ Standard │            │   Standard   │            │
│        │ unlocked │            │   + skips    │            │
│        └──────────┘            │  dependents  │            │
│                                └──────────────┘            │
│                                                             │
│   *CQPM = Correct Questions Per Minute                     │
└─────────────────────────────────────────────────────────────┘
```

### Skill Hierarchy & Prerequisites

Standards are organized in **prerequisite chains**. If a student fails an early standard, all dependent standards are automatically skipped:

```
ADDITION CHAIN                    SUBTRACTION CHAIN
─────────────────                 ─────────────────
Sums to 6                         Subtraction 0-5
    ↓                                 ↓
Sums to 12                        Subtraction 0-9
    ↓                                 ↓
Sums to 20 ──────────────────┐    Subtraction 0-12
    ↓                        │        ↓
2-Digit Add (no regroup)     │    Subtraction 0-15
    ↓                        │        ↓
2-Digit Add (regroup)        │    Subtraction 0-20
    ↓                        │        │
3-Digit Add                  │        │
                             │        │
                             ↓        ↓
                    ┌─────────────────────────┐
                    │   GRADE 2+ STANDARDS    │
                    │  • Expression Comparison │
                    │  • Equivalence Problems  │
                    │  • 2-Digit Subtraction   │
                    └─────────────────────────┘

MULTIPLICATION CHAIN              DIVISION CHAIN
────────────────────              ──────────────
Multiply 0-4                      Divide 0-4
    ↓                                 ↓
Multiply 5-8                      Divide 5-8
    ↓                                 ↓
Multiply 9-12                     Divide 9-12 ────────→ Fractions
    ↓                                 ↓                 (Number Lines)
Multi-digit × (no regroup)        Multi-digit ÷
    ↓                                 │
Multi-digit × (regroup)               │
    ↓                                 ↓
2-Digit × 2-Digit ───────────→ Grade 4-5 Content
                               (Decimals, Advanced Fractions)
```

### Error Tolerance

Early standards allow **1-2 mistakes** to account for careless errors:
- Basic facts (Sums to 6, Subtraction 0-5): **2 errors allowed**
- Other basic operations: **1 error allowed**
- Advanced standards: **No errors allowed** (immediate fail on mistake)

### Time Per Grade

| Student Grade | Standards Passed | Standards Skipped | Early Exits | Est. Time |
|---------------|------------------|-------------------|-------------|-----------|
| Grade 1 | 5-7 | 30-33 | 2-3 | **~3 min** |
| Grade 2 | 12-15 | 18-22 | 3-5 | **~6 min** |
| Grade 3 | 22-26 | 8-12 | 4-6 | **~10 min** |
| Grade 4 | 30-33 | 3-5 | 2-4 | **~12 min** |
| Grade 5 | 36-40 | 0-2 | 0-2 | **~14 min** |

---

## 📊 Post-Assessment Flow

After the assessment completes:

```
┌────────────────────────────────────────────────────────────┐
│                  ASSESSMENT COMPLETE                        │
└────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────┐
│  For each MASTERED standard:                               │
│  • Corresponding level(s) marked as 3-star complete        │
│  • Student can replay for practice (minimal XP)            │
└────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────┐
│  For each FAILED/SKIPPED standard:                         │
│  • Corresponding level(s) remain locked or 0-star          │
│  • Student earns full XP when they master these later      │
└────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────┐
│  Student proceeds to MAIN MENU                             │
│  • All grades now accessible                               │
│  • Recommended starting point visible                      │
└────────────────────────────────────────────────────────────┘
```

---

## ⭐ XP & TimeBack Integration

Astro Math uses **TimeBack** for XP tracking, rewarding students for genuine learning progress while discouraging repetitive farming of easy content.

### XP Components

| Component | XP Value |
|-----------|----------|
| Base time XP | **0.5 XP per minute** of active play |
| First star earned | **+0.25 XP** bonus |
| Second star earned | **+0.25 XP** bonus |
| Third star earned (mastery) | **+0.5 XP** bonus |

### Star Requirements

Stars are earned based on correct answers and accuracy within the 2-minute level timer:

| Stars | Requirement |
|-------|-------------|
| ☆☆☆ (0 stars) | Did not meet 1-star threshold |
| ⭐☆☆ (1 star) | 50% of mastery count + 55% accuracy |
| ⭐⭐☆ (2 stars) | 75% of mastery count + 70% accuracy |
| ⭐⭐⭐ (3 stars) | 100% of mastery count + 85% accuracy |

### Mastery Guarantee

When a student achieves **3 stars** (mastery) on a level, they are guaranteed a **minimum of 2 XP** for that level. If their cumulative XP from time + star bonuses is below 2 XP, they receive a top-up to reach this minimum.

### Replay XP Scaling

To discourage farming already-mastered content, XP is scaled based on previously earned stars:

| Previous Stars | XP Multiplier |
|----------------|---------------|
| 0 stars (first attempt) | **100%** |
| 1 star | **75%** |
| 2 stars | **50%** |
| 3 stars (already mastered) | **25%** |

### Example XP Scenarios

| Scenario | Calculation | XP Earned |
|----------|-------------|-----------|
| First attempt, earns 3 stars in 1.5 min | (0.75 time + 1.0 star bonus) × 100% = 1.75 → **2.0 XP** (mastery minimum) |
| First attempt, earns 1 star in 2 min | (1.0 time + 0.25 star bonus) × 100% = **1.25 XP** |
| Replay (had 1 star), earns 3 stars | (1.0 time + 0.75 new stars) × 75% = **1.31 XP** |
| Replay (had 3 stars), earns 3 stars | (1.0 time + 0 new stars) × 25% = **0.25 XP** |

---

## 🎮 Game Structure

```
┌─────────────────────────────────────────────────────────────┐
│                      ASTRO MATH                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐                                           │
│  │ ASSESSMENT  │ ◄── Required for new students              │
│  │   (40 skills)│                                          │
│  └──────┬──────┘                                           │
│         ↓                                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    GRADES 1-5                        │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐               │   │
│  │  │ Level 1 │ │ Level 2 │ │ Level 3 │  ...          │   │
│  │  │ ⭐⭐⭐  │ │ ⭐⭐☆  │ │ ☆☆☆   │               │   │
│  │  └─────────┘ └─────────┘ └─────────┘               │   │
│  │                                                     │   │
│  │  Each level: 2-minute timed challenge               │   │
│  │  Stars earned by: Correct answers + Speed (CQPM)    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## ⏱️ Time to Mastery

Astro Math contains **77 levels** across Grades 1-5, requiring **2,428 correct answers** for full 3-star completion. Mastery counts are calibrated so that fluent students complete each level in ~2 minutes—higher counts mean simpler questions, lower counts mean fewer but more complex questions.

| Student Profile | Time to Master All Grades (1-5) |
|-----------------|--------------------------------|
| Already fluent (demonstrating mastery) | **2.5 hours** |
| Fast learner | **8-12 hours** |
| Average learner | **15-25 hours** |
| Single grade (appropriate level) | **2-6 hours per grade** |

The diagnostic assessment ensures students start at their appropriate level, avoiding wasted time on already-mastered content.

---

## Summary

| Feature | Description |
|---------|-------------|
| **Assessment** | 40-standard diagnostic, adapts via prerequisites |
| **Placement** | Auto-unlocks mastered content |
| **Progression** | Grade 1-5 levels with 3-star mastery system |
| **XP System** | Rewards new learning, not repetition |
