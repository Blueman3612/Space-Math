---

**Game Name**: Astro Math

**Developer(s)**: Nathan Hall

**Date**: 12/12/2025

---

## 0. TL;DR

**Two sentence pitch**: An improved FasttMath clone covering all of Springmath 1-5 with Timeback integration.

**Target**: Grade **1-5** FastMath

**Learning outcome**: Students will **master ALL FastMath content grades 1-5**

**Test**: **Springmath**

**Time to mastery**: **2 - 2.5** hours

**Better than**: **Zearn, Freckle, Edia,** because **gamified and more polished UI, minimal distraction, problem types and mastery standards directly from Springmath**

---

## 1. Grade Level & Standards

**Target Grade(s)**: 1-5

**Subject/Topic**: FastMath

**Curriculum Standard** (CCSS/AP/etc), **Specific Skills Covered**: https://docs.google.com/spreadsheets/d/1YAla0nvCPYaLF_5lcPr5VdgoXNNuBwAwgtk5SmtUpWU/edit?usp=sharing

---

## 2. Student Activities

**What do students actually DO in your game/app?**

List all activity types (e.g., "spell words from audio", "solve equations under time pressure", "write arguments", "match definitions to images"):

1. Solve fast math problems
2. Master Springmath standards at 85% accuracy
(~98%)
3. UI interaction
(~2%)

**Roughly what % of time in each activity?**

---

---

## 3. Testing Strategy

**Success Criteria** (what score = mastery?): 85% accuracy with Springmath's given CQPM standard for the specific skill.

---

## 4. Learning Science & Engine

**Which learning mechanisms is your game/app built on?**

**Tier 0 - Foundational** (pick all that apply):

- [x] Faultless communication (clear examples, non-examples, minimal confusion)
- [x] Retrieval practice (not re-study)
- [x] Mastery gating (90% accuracy before advancing)
- [x] Immediate error correction

**Tier 1 - Amplifiers** (pick all that apply):

- [x] Spaced repetition (expanding intervals)
- [x] Interleaving (mixing problem types)
- [x] Example variation (diverse instantiations)
- [x] Worked examples → faded practice
- [ ] Elaborated feedback (why, not just right/wrong)

**Tier 2 - Context-Dependent** (pick if applicable):

- [ ] Dual coding (visual + verbal when both add value)
- [ ] Segmenting (breaking complex tasks into chunks)
- [ ] Pre-training on component concepts
- [ ] Metacognitive prompts

**How do you decide which content to serve when?**

**Spaced repetition approach** (Leitner/SM-2/custom/none):

**Mastery criteria** (when does a student "pass" a concept?): Upon reaching 85% accuracy per Springmath's specific CQPM standards per skill.

**How are wrong answers handled?** Incorrect answers are immediately corrected with a visual example of the correct answer, with a brief unskippable period that then requires input to skip.

---

## 5. Time to Mastery & Learning Rate

**Total learning units** (facts/words/concepts): 76 skills across 5 grades

**Exposures per unit**: 4-80 depending on the skill

**Time per exposure**: 1.5-30 seconds depending on the skill

**Fundamental metric**: It takes **2** minutes to master one skill (upon success)"

**Total time to mastery**: **1.5-2.5** hours

**Compared to existing solutions**: Gamified and more polished UI, minimal distraction, problem types and mastery standards directly from Springmath

**XP Calculation Approach**: "1 XP per minute over 80% accuracy" or "based on time spent by average student on activity"

---

## 6. Question/Fact Bank

**Total unique questions/facts**: 76 problem types with all possible problems in the given range

**Content source**: Springmath

**Example question/fact**: "962 + 567 = _", "12 + 4 = 4 + 10 + _", "Place 7/8 on Number Line"

---

## 7. Competitive Analysis

**Existing solution you're competing with**: Zearn, Freckle, Edia

**Why yours is better**: Gamified and more polished UI, minimal distraction, problem types and mastery standards directly from Springmath. Students can start or train on any standards category.

**Time comparison** (yours vs theirs):

---

## 8. Pilot/MVP

**What is the minimal product that can be tested with students?** FasttMath Clone

**Number of students**: Any

**Duration**: Any

**Measurable outcome**: CQPM and mastery of standards measured via star-based mastery and Timeback integration.

**Success looks like**: Improvement in these CQPM and mastery standards before and after Astro Math

---

## 9. Anti-Pattern Prevention

**How do you prevent students from:**

- **Skipping content**: Must wait and then confirm incorrect answer feedback

- **Rushing/clicking through**: Impossible

- **Guessing randomly**: Only 1 correct answer, ~95% non multiple-choice

- **Idle time**: Fast-paced gameplay and idle time doesn't give xp

---

## 10. Content Quality Control

**Where does content come from?**

- [ ] AI-generated (describe QC process):
- [x] Expert-created
- [x] Question banks (which ones):
- [ ] Licensed content
- [ ] Other:

Directly from Springmath; dynamically generated questions based on ranges and formulas from Springmath worksheets.

**Who reviews for correctness?** Both I and an LLM review trends + ranges + formulas present in Springmath worksheets and construct question generation based on them.

**How do you catch errors before students see them?** Thoroughly testing every single level.

---

## 11. Stakeholders & Research

**Academic team contacts** (who you're working with): Andy Montgomery

**External collaborators** (BRI, content partners, etc): Springmath content

**Target students/guides** (who will use this): Students grades 1-5

**Research sources** (which brain lifts/documents informed this):

- [x] Brain lift: **Playcademy** https://workflowy.com/s/playcademy-project-b/bN3lbLv0Hw7yUGW1#/49c3ac1b5660

---

## 12. Andy's Critical Questions (Real Quotes from Past Demos)

**"Is this all multiple choice? Do they have to produce anything?"**

_Andy cares about production vs recognition. Students must speak/write/draw, not just click._

Your answer: Minimal multiple choice, students have to type exact answer.

---

**"I have a new student. How do I make sure they don't waste their time on stuff they already know?"**

_Andy needs diagnostic efficiency. If a student already knows it, how many minutes do they waste proving that?_

Your answer: Students can easily be placed in their grade level, pending backend functionality

---

**"You should not limit them to one learning session a day. That's completely unaligned with alpha school. No cap. They can work 24 straight hours if they want."**

_Andy hates artificial time/session limits. Natural limits from content availability are fine, arbitrary caps are not._

Your answer: There are absolutely no daily caps. Students can play grades 1-5 in a single session, if they want.

---