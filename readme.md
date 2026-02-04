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

### Example XP Scenarios

| Scenario | Calculation | XP Earned |
|----------|-------------|-----------|
| 12/20 correct, 85% accuracy | 2 × (12/20) = **1.2 XP** |
| 20/20 correct, 100% accuracy, new star | 2 × (20/20) × 1.25 = **2.5 XP** |
| 15/20 correct, 75% accuracy | Below 80% threshold = **0 XP** |
| 8/20 correct, 90% accuracy | 2 × (8/20) = **0.8 XP** |

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

The game contains **77 levels** across Grades 1-5, requiring **2,428 total correct answers**. Time to mastery depends on a student's average time per correct answer (including practice and building speed):

| Student Profile | Avg. Time/Answer | Time to Master All Grades |
|-----------------|------------------|---------------------------|
| Already fluent | ~3 sec | **2.5 hours** |
| Near fluent | ~15 sec | **~10 hours** |
| Developing fluency | ~30 sec | **~20 hours** |
| Building from baseline | ~1 min | **~40 hours** |
| Single grade (developing) | — | **3-6 hours per grade** |

The diagnostic assessment identifies fluency gaps and places students appropriately, avoiding repetition of already-mastered content.

---

## Summary

| Feature | Description |
|---------|-------------|
| **Assessment** | 40-standard diagnostic, adapts via prerequisites |
| **Placement** | Auto-unlocks mastered content |
| **Progression** | Grade 1-5 levels with 3-star mastery system |
| **XP System** | Simple formula: 2 × (correct/mastery_count), requires 80%+ accuracy |
