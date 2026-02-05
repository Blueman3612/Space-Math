## What is Astro Math?

Astro Math is an adaptive math fluency game covering **Grades 1-5** with 40+ skill standards across addition, subtraction, multiplication, division, fractions, and decimals.

---

## Who is it for?

Astro Math is designed for **students rostered in grades 2-8** who have not yet mastered 5th grade FastMath. The diagnostic assessment places each student at their appropriate skill level, so students work on exactly the math facts they need to build fluency with — regardless of their rostered grade.

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
│  • 3-star levels are grayed out and cannot be replayed     │
└────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────┐
│  For each FAILED/SKIPPED standard:                         │
│  • Corresponding level(s) remain at 0 stars                │
│  • Student earns full XP when they master these later      │
└────────────────────────────────────────────────────────────┘
                            ↓
┌────────────────────────────────────────────────────────────┐
│  Student proceeds to MAIN MENU                             │
│  • Locked to first non-mastered grade                      │
│  • Cannot navigate to other grades until current           │
│    grade is fully mastered (all levels at 3 stars)         │
│  • Levels unlock sequentially within each category         │
│    (3 stars required to unlock next level)                 │
│  • After completing all levels in a grade, student takes   │
│    an official test to confirm mastery before advancing    │
└────────────────────────────────────────────────────────────┘
```

---

## ⭐ XP & TimeBack Integration

Astro Math uses **TimeBack** for XP tracking with a simple, performance-based system.

### Star Requirements

Stars are earned based on **both** correct answers and accuracy within the 2-minute level timer:

| Stars | Correct Answers | Accuracy |
|-------|-----------------|----------|
| ☆☆☆ (0 stars) | Below thresholds | Below 80% |
| ⭐☆☆ (1 star) | ≥33% of mastery count | ≥80% |
| ⭐⭐☆ (2 stars) | ≥66% of mastery count | ≥85% |
| ⭐⭐⭐ (3 stars) | 100% of mastery count | ≥90% |

**Important:** If accuracy falls below 80%, the player earns **0 stars and 0 XP** regardless of correct answers.

### XP Formula

XP is calculated based on progress toward the level's mastery count:

```
Base XP = 2 × (correct_answers / mastery_count)
```

| Condition | XP Awarded |
|-----------|------------|
| Accuracy < 80% | **0 XP** |
| Accuracy ≥ 80% | **Base XP** |
| 100% accuracy + new star earned | **Base XP × 1.25** |

### Replay XP Falloff

When replaying a level **without earning a new star**, XP is reduced with diminishing returns to discourage farming:

| Consecutive Replays Without New Star | XP Multiplier |
|--------------------------------------|---------------|
| 1st replay without new star | **0.5x** |
| 2nd replay without new star | **0.25x** |
| 3rd+ replay without new star | **0.1x** |

Earning a new star **resets** the falloff counter back to full XP.

### Example XP Scenarios

| Scenario | Calculation | XP Earned |
|----------|-------------|-----------|
| 12/20 correct, 85% accuracy | 2 × (12/20) | **1.2 XP** |
| 20/20 correct, 100% accuracy, new star | 2 × (20/20) × 1.25 | **2.5 XP** |
| 15/20 correct, 75% accuracy | Below 80% threshold | **0 XP** |
| 8/20 correct, 90% accuracy | 2 × (8/20) | **0.8 XP** |
| 15/20 correct, 85% acc, 1st replay no new star | 2 × (15/20) × 0.5 | **0.75 XP** |
| 15/20 correct, 85% acc, 3rd replay no new star | 2 × (15/20) × 0.1 | **0.15 XP** |

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
│  │  Stars earned by: Correct answers + Accuracy        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## ⏱️ Time to Mastery

Astro Math is a **fluency training tool**—it builds automaticity with math facts, not conceptual understanding. Students are expected to understand operations; Astro Math trains them to perform those operations automatically by improving their **CQPM (Correct Questions Per Minute)**.

### Per-Grade Breakdown

| Grade | Levels | Correct Answers to Master | Categories |
|-------|--------|---------------------------|------------|
| 1 | 11 | 385 | Addition, Subtraction, Add./Sub. |
| 2 | 15 | 372 | Addition, Subtraction, Add./Sub., 2-Digit, Equivalence, 3-Digit |
| 3 | 19 | 689 | Add./Sub., 3-Digit, Multiplication, Division, Mul./Div., Fractions |
| 4 | 17 | 562 | Addition, Subtraction, Multiplication, Division, Mul./Div., Decimals, Fractions |
| 5 | 15 | 430 | Addition, Subtraction, Decimals, Multiplication, Division, Mul./Div., Fractions |
| **Total** | **77** | **2,438** | |

### Estimated Time Per Grade

Time to mastery depends on a student's average time per correct answer (including practice and repeat attempts to build speed):

| Grade | Developing (~30s/ans) | Near Fluent (~15s/ans) | Already Fluent (~3s/ans) |
|-------|-----------------------|------------------------|--------------------------|
| 1 | ~3 hours | ~1.5 hours | ~20 min |
| 2 | ~3 hours | ~1.5 hours | ~20 min |
| 3 | ~6 hours | ~3 hours | ~35 min |
| 4 | ~5 hours | ~2.5 hours | ~30 min |
| 5 | ~3.5 hours | ~2 hours | ~20 min |
| **All Grades** | **~20 hours** | **~10 hours** | **~2 hours** |

The diagnostic assessment identifies fluency gaps and places students at their first non-mastered grade, skipping already-mastered content entirely.

---

## Summary

| Feature | Description |
|---------|-------------|
| **Assessment** | 40-standard diagnostic, adapts via prerequisites |
| **Placement** | Auto-unlocks mastered content |
| **Progression** | Grade 1-5 levels with 3-star mastery system |
| **XP System** | Simple formula: 2 × (correct/mastery_count), requires 80%+ accuracy, diminishing returns on replays without new stars |
