# Faster Math Question Generator Documentation

## What is the Faster Math Question Generator?

The Faster Math Question Generator is a smart system that creates math problems for students to practice. It's like having a teacher who can instantly give you exactly the type of math problem you want to work on, whether that's addition, subtraction, multiplication, or division.

## How Does It Work?

Think of the question generator like a giant library of math problems, organized into different sections:

- **Grades**: Like different floors of a library (Grade 1, Grade 2, etc.)
- **Tracks**: Like different shelves on each floor, each focusing on specific skills
- **Questions**: Like individual books on each shelf - the actual math problems

When you ask for a math problem, the generator looks through this organized library and picks one that matches what you're looking for.

## The Math Facts Database

Our system uses a file called `math-facts.json`. These problems are organized by:

### Grades Available:
- **Grade 1**: Basic addition within 10
- **Grade 2**: Addition and subtraction with larger numbers
- **Grade 3**: More complex addition, subtraction, and introduction to multiplication
- **Grade 4**: Advanced operations and division
- **Grades 5 and Above**: Complex multi-operation problems

### Tracks Available:
Each grade has different "tracks" (numbered 5-12) that focus on specific math skills. The tracks are organized by educational progression, not numerical order:

#### Track Details:
- **Track 5**: Division (Quotients up to 12) - Advanced level
- **Track 6**: Addition (Sums up to 20) - Intermediate level  
- **Track 7**: Multiplication (Factors up to 12) - Advanced level
- **Track 8**: Subtraction (Minuends and Subtrahends up to 20) - Intermediate level
- **Track 9**: Addition (Single-Digit Addends) - Basic level
- **Track 10**: Subtraction (Single-Digit Subtrahends) - Basic level
- **Track 11**: Multiplication (Single-digit factors) - Intermediate level
- **Track 12**: Addition Within 10 (Sums up to 10) - Beginner level

## Recommended Track Progression

**Important**: The track numbers (5-12) are NOT in difficulty order! The math-facts database organizes them by educational progression. Here's the recommended learning sequence:

### Educational Progression by Grade:

#### **Grade 1** (Beginner Level):
- **Track 12**: Addition Within 10
  - Start here for absolute beginners
  - Problems like "3 + 2 = 5"
  - Builds foundational addition skills

#### **Grade 2** (Basic Level):
1. **Track 9**: Addition (Single-Digit Addends)
   - Next step after Track 12
   - Problems like "7 + 8 = 15"
2. **Track 10**: Subtraction (Single-Digit Subtrahends)  
   - Introduction to subtraction
   - Problems like "9 - 3 = 6"

#### **Grade 3** (Intermediate Level):
1. **Track 6**: Addition (Sums up to 20)
   - More complex addition
   - Problems like "13 + 7 = 20"
2. **Track 8**: Subtraction (Minuends and Subtrahends up to 20)
   - Advanced subtraction
   - Problems like "18 - 9 = 9"
3. **Track 11**: Multiplication (Single-digit factors)
   - Introduction to multiplication
   - Problems like "6 × 4 = 24"

#### **Grade 4** (Advanced Level):
1. **Track 7**: Multiplication (Factors up to 12)
   - Complex multiplication
   - Problems like "11 × 8 = 88"
2. **Track 5**: Division (Quotients up to 12)
   - Introduction to division
   - Problems like "84 ÷ 7 = 12"

#### **Grades 5 and Above** (Mastery Level):
- **All Tracks 5-8**: Mixed practice of all four operations
- Recommended order: Track 6 → Track 8 → Track 7 → Track 5
- This provides comprehensive review and mastery

### Logical Learning Sequence (Ignoring Grade Levels):

If you want to create a custom progression regardless of grade levels:

**Beginner to Advanced:**
1. **Track 12** - Addition within 10 (easiest)
2. **Track 9** - Single-digit addition  
3. **Track 6** - Addition up to 20
4. **Track 10** - Single-digit subtraction
5. **Track 8** - Subtraction up to 20  
6. **Track 11** - Basic multiplication
7. **Track 7** - Advanced multiplication
8. **Track 5** - Division (most challenging)

### Why This Order Matters:

- **Addition First**: Foundation for all other operations
- **Subtraction Second**: Inverse of addition, reinforces number relationships  
- **Multiplication Third**: Builds on addition concepts (repeated addition)
- **Division Last**: Most complex, requires understanding of all previous operations

### Programming Tip:

When creating adaptive learning systems, you can use this progression:

```gdscript
# Recommended track progression array
var track_progression = [12, 9, 6, 10, 8, 11, 7, 5]

# Get next appropriate track based on student progress
func get_next_track(current_track_index):
    if current_track_index < track_progression.size() - 1:
        return track_progression[current_track_index + 1]
    else:
        return track_progression[-1]  # Stay at highest level
```

## How to Use the Question Generator

### The Main Function: `get_math_question()`

This is the heart of our system. You can ask it for math problems in several ways:

#### Method 1: Ask for a Specific Track
```
get_math_question(7)
```
This gives you a random problem from Track 7 (division problems).

#### Method 2: Ask for a Specific Grade
```gdscript
get_math_question(null, 3)
```
This gives you any random problem suitable for Grade 3 students.

#### Method 3: Ask for a Specific Type of Math Operation
```gdscript
get_math_question(null, null, 0)
```
This gives you any addition problem from the entire database.

**Operation Numbers:**
- 0 = Addition (+)
- 1 = Subtraction (-)
- 2 = Multiplication (×)
- 3 = Division (/)

#### Method 4: Combine Requirements
```gdscript
get_math_question(null, 2, 1)
```
This asks for subtraction problems specifically from Grade 2.

#### Method 5: Exclude Problems with Zero
```gdscript
get_math_question(null, null, 0, true)
```
This gives you addition problems, but skips any that have 0 as one of the numbers (like "0 + 5" or "3 + 0").

### What You Get Back

When you ask for a math problem, the generator gives you a complete package of information:

- **Question**: The math problem without the answer (e.g., "6 + 4")
- **Expression**: The complete problem with the answer (e.g., "6 + 4 = 10")
- **Operands**: The numbers being used (e.g., [6, 4])
- **Operator**: The math symbol being used (e.g., "+")
- **Result**: The correct answer (e.g., 10)
- **Title**: What type of math skill this problem practices
- **Grade**: Which grade level this problem is appropriate for

## Using the Output for Gameplay

When building an actual math game, you'll want to store each piece of information in separate variables for different purposes. Here's how to do that:

### Basic Variable Storage
```gdscript
# Get a math problem (Grade 2 addition)
var problem = get_math_question(null, 2, 0)

# Store each piece of information separately
var question_text = problem.question        # "7 + 3" - show this to the player
var correct_answer = problem.result         # 10 - use this to check if player is right
var first_number = problem.operands[0]      # 7 - individual numbers if needed
var second_number = problem.operands[1]     # 3 - individual numbers if needed
var math_symbol = problem.operator          # "+" - the operation being performed
var full_solution = problem.expression      # "7 + 3 = 10" - show after they answer
var skill_name = problem.title              # "Addition (Single-Digit)" - for progress tracking
var grade_level = problem.grade             # "Grade 2" - for difficulty tracking
```

### Practical Game Examples

#### Example 1: Simple Quiz Game
```gdscript
# Generate a new question (addition only)
var problem = get_math_question(null, null, 0)

# Show the question to the player
question_label.text = problem.question  # Displays "5 + 8"

# Wait for player input...
# When player submits their answer:
func check_answer(player_answer):
    if player_answer == problem.result:
        show_message("Correct! " + problem.expression)
        score += 1
    else:
        show_message("Try again! The answer is " + str(problem.result))
```

#### Example 2: Adaptive Difficulty Game
```gdscript
var current_grade = 1
var problems_correct = 0

func generate_next_question():
    # Get problem for current difficulty level
    var problem = get_math_question(null, current_grade)
    
    # Store what we need for gameplay
    current_question = problem.question
    current_answer = problem.result
    current_skill = problem.title
    
    # Show to player
    display_question(current_question)

func on_correct_answer():
    problems_correct += 1
    
    # After 5 correct answers, increase difficulty
    if problems_correct >= 5:
        current_grade += 1
        problems_correct = 0
        show_message("Great job! Moving to " + str(current_grade))
```

#### Example 3: Skill-Focused Practice
```gdscript
# Let player choose what to practice
func practice_multiplication():
    var problem = get_math_question(null, null, 2, true)  # Multiplication, no zeroes
    
    # Store for game logic
    var question = problem.question          # "6 × 4"
    var answer = problem.result              # 24
    var numbers = problem.operands           # [6, 4]
    
    # You could use individual numbers for hints
    hint_text = "Think: " + str(numbers[0]) + " groups of " + str(numbers[1])
    
    return {
        "question": question,
        "answer": answer,
        "hint": hint_text
    }

func practice_division():
    var problem = get_math_question(null, null, 3)  # Division
    
    # Division problems might need special handling
    var dividend = problem.operands[0]       # Number being divided
    var divisor = problem.operands[1]        # Number dividing by
    var quotient = problem.result            # The answer
    
    # Create a word problem version
    var word_problem = "If you have " + str(dividend) + " items and put them into " + str(divisor) + " equal groups, how many items are in each group?"
    
    return {
        "math_question": problem.question,   # "12 ÷ 3"
        "word_problem": word_problem,
        "answer": quotient
    }
```

#### Example 4: Progress Tracking System
```gdscript
var student_progress = {}

func track_student_progress(problem, was_correct):
    var skill = problem.title
    var grade = problem.grade
    var operation = problem.operator
    
    # Initialize tracking if first time seeing this skill
    if not student_progress.has(skill):
        student_progress[skill] = {
            "attempts": 0,
            "correct": 0,
            "grade_level": grade
        }
    
    # Update progress
    student_progress[skill].attempts += 1
    if was_correct:
        student_progress[skill].correct += 1
    
    # Calculate success rate
    var success_rate = float(student_progress[skill].correct) / student_progress[skill].attempts
    
    # Decide what to practice next based on performance
    if success_rate < 0.7:  # Less than 70% correct
        return get_math_question(null, extract_grade_number(grade), get_operator_number(operation))
    else:  # Doing well, try harder problems
        return get_math_question(null, extract_grade_number(grade) + 1, get_operator_number(operation))
```

### Tips for Game Development

1. **Always store the answer separately** - Don't parse it from the expression string
2. **Use the question field for display** - It's already formatted nicely without decimals
3. **Track the skill name** - Great for showing progress ("You're getting better at Addition!")
4. **Consider the grade level** - Use it to adjust game difficulty or unlock new content
5. **Individual operands are useful** - For creating hints, animations, or alternative question formats

## Smart Features

### Priority System
If you ask for multiple things at once, the system has a smart priority system:

1. **Track comes first**: If you specify a track number, it will focus on that above all else
2. **Grade comes second**: If no track is specified, it will focus on the grade you requested  
3. **Operation comes third**: If neither track nor grade is specified, it will find problems with the math operation you want

### Fallback System
The generator is smart about handling requests that might not have perfect matches:

- **Invalid Track Numbers**: If you ask for a track that doesn't exist, it will randomly pick from available tracks (5-12)
- **Grade + Operation Combinations**: If you ask for subtraction problems from Grade 1, but Grade 1 doesn't have subtraction, it will find the closest grade that does have subtraction problems
- **No Matches Found**: If your request can't be fulfilled at all, the system will tell you instead of giving you something random

### Zero Filtering
Problems with zeroes may not be desirable. You can ask the system to skip these entirely by setting the `no_zeroes` option to `true`.

## Example Scenarios

### Scenario 1: "I want my Grade 2 student to practice addition"
```gdscript
get_math_question(null, 2, 0)
```
Result: You'll get addition problems appropriate for Grade 2 level.

### Scenario 2: "Give me any multiplication problem"
```gdscript
get_math_question(null, null, 2)
```
Result: You'll get a multiplication problem from anywhere in the database.

### Scenario 3: "I want a specific type of problem from Track 8"
```gdscript
get_math_question(8)
```
Result: You'll get a random problem from Track 8 (complex subtraction).

### Scenario 4: "Give me division problems, but avoid zeros"
```gdscript
get_math_question(null, null, 3, true)
```
Result: You'll get division problems that don't include 0 as one of the numbers.

## Technical Implementation

### In Your Game
The system is set up to work seamlessly in your Godot game:

1. **Automatic Loading**: When the game starts, it automatically loads all math problems into memory
2. **Instant Response**: Once loaded, getting a new math problem is instant - no waiting or loading times
3. **Random Selection**: Each time you ask for a problem, you get a truly random selection from the matching problems

### Display Format
The engine returns all the information about each problem:
```
Track: 9
Grade: Grade 2  
Title: Addition (Single-Digit Addends)
Question: 0 + 5
Expression: 0 + 5 = 5
Operands: [0, 5]
Operator: +
Result: 5
```

## Benefits of This System

1. **Massive Variety**: Students won't see repeats very often
2. **Targeted Practice**: You can focus on exactly the type of math skill that needs work
3. **Appropriate Difficulty**: Problems are organized by grade level to ensure appropriate challenge
4. **Flexible Usage**: Works for individual practice, classroom activities, or assessment
5. **No Internet Required**: Everything works offline once the game is loaded

## Troubleshooting

### "I'm not getting the type of problems I expect"
- Check that the grade level you're requesting actually has the type of math operation you want
- Remember the priority system: track overrides grade, grade overrides operation
- Some combinations (like multiplication in Grade 1) might not exist in the database

### "The problems seem too easy or too hard"
- Make sure you're requesting the right grade level
- Check the track number - different tracks have different difficulty levels even within the same grade
- Look at the "Title" output to see exactly what type of math skill the problem is practicing

### "I keep getting problems with zero"
- Add `true` as the fourth parameter to exclude zero-based problems
- Example: `get_math_question(null, 3, 0, true)` for Grade 3 addition without zeros
