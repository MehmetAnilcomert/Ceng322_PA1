#!/bin/bash

# Getting script arguments
MAX_POINTS="$1"
CORRECT_OUTPUT="$2"
SUBMISSIONS_FOLDER="$3"

# Validating arguments
if [[ ! "$MAX_POINTS" =~ ^[0-9]+$ || "$MAX_POINTS" -le 0 ]]; then
  echo "Error: Invalid maximum points. Please provide a positive integer."
  exit 1
fi

if [ ! -f "$CORRECT_OUTPUT" ]; then
  echo "Error: Correct output file '$CORRECT_OUTPUT' not found!"
  exit 1
fi

if [ ! -d "$SUBMISSIONS_FOLDER" ]; then
  echo "Error: Submissions folder '$SUBMISSIONS_FOLDER' does not exist!"
  exit 1
fi

# Checking if there are any files in the submissions folder
if [ -z "$(ls -A "$SUBMISSIONS_FOLDER")" ]; then
  echo "Error: Submissions folder '$SUBMISSIONS_FOLDER' is empty!"
  exit 1
fi

# Creating grading folder
GRADING_FOLDER="grading"
mkdir -p "$GRADING_FOLDER"

# Log file for grading process
LOG_FILE="$GRADING_FOLDER/log.txt"
touch "$LOG_FILE"

# Defining timeout limit (in seconds)
TIMEOUT=60

# Creating result file
RESULT_FILE="$GRADING_FOLDER/result.txt"
echo -n "" > "$RESULT_FILE"  # Clearing contents of result file

TOTAL_LINES_CORRECT_OUTPUT=$(wc -l < "$CORRECT_OUTPUT")
# Loop through each submission file
for submission in "$SUBMISSIONS_FOLDER"/*; do
  # Check if it's a regular file (not a directory)
  if [ ! -f "$submission" ]; then
    continue
  fi
  
  # Extracting filename without path
  filename=$(basename "$submission")

  # Validating filename format (replace with your specific format if needed)
  if [[ ! "$filename" =~ ^[0-9]{3}_h[0-9]_([0-9]{9}).sh$ ]]; then
    echo "Grading: $filename - Incorrect file name format" >> "$LOG_FILE"
    continue
  fi

  # Checking execute permission for current user
  if [ ! -x "$submission" ]; then
    echo "Grading: $filename - Insufficient permission. Changing file mode..." >> "$LOG_FILE"
    chmod +x "$submission"  # Change to executable if needed
  fi

  # Temporary output file
  TEMP_OUTPUT="$GRADING_FOLDER/${filename}_out.txt"

  # Executing script with timeout handling
  output=$(timeout $TIMEOUT bash -c "$submission" > "$TEMP_OUTPUT" 2>&1)
  exit_code=$?
  
  if [ $exit_code -eq 124 ]; then
    echo "Grading: $filename - Script execution timed out." >> "$LOG_FILE"
    grade=0
  elif [ $exit_code -ne 0 ]; then
    echo "Grading: $filename - Script execution failed." >> "$LOG_FILE"
    grade=0
  else
    if cmp -s "$TEMP_OUTPUT" "$CORRECT_OUTPUT"; then  # If there is no lines that differ then it is graded as max points.
      grade=$MAX_POINTS
    else
      # Counting the number of lines that differ
      num_diff_lines=$(diff -w "$TEMP_OUTPUT" "$CORRECT_OUTPUT" | grep -c '^')
      # Calculating the ratio of different lines to total lines
      ratio_diff=$(echo "scale=2; $num_diff_lines / $TOTAL_LINES_CORRECT_OUTPUT" | bc)
      # Calculating the penalty to subtract from the maximum point
      penalty_with_round=$(echo "scale=2; $ratio_diff * $MAX_POINTS + 0.5" | bc)

      # Converting to an integer to effectively round the number
      penalty=${penalty_with_round%.*}

      # Subtracting the rounded penalty from the maximum points
      grade=$(echo "$MAX_POINTS - $penalty" | bc)
    fi
  fi
  # Appending final grade to result file
  student_id=$(echo "$filename" | cut -d '_' -f 3 | cut -d '.' -f 1)
  echo "Student ID: $student_id Grade: $grade" >> "$RESULT_FILE"
done

echo "Grading completed. Check the '$RESULT_FILE' file for results."

