#!/bin/bash

# Exit on error
set -e

# Define infinity constants
MASTER_INFINITY="0.0.0"
RELEASE_INFINITY_SUFFIX=".999"
NEXT_RELEASE_SUFFIX=".1000"

# Path to the start date file
NFO_FILE="./bin/branch.nfo"

# Function to calculate YYYY.R.W.D version from a start date
calculate_version() {
    START_DATE_STR=$1
    # Convert start date to Epoch seconds
    START_EPOCH=$(date -d "$START_DATE_STR" +%s)
    CURRENT_EPOCH=$(date +%s)

    # Calculate difference in days: (Current Time - Start Time) / Seconds per Day
    DAYS_DIFF=$(( (CURRENT_EPOCH - START_EPOCH) / 86400 ))

    # Calculate weeks (total days // 7) and days (total days % 7)
    WEEKS=$(( DAYS_DIFF / 7 ))
    DAYS=$(( DAYS_DIFF % 7 ))

    # Determine branch prefix (YYYY.R) - this script runs *within* the branch context
    # We need a mechanism to get the branch name YYYY.R part dynamically.
    # For now, we assume the NFO file might contain it, or we derive it differently later.
    # We will pass the branch prefix in via environment variable from the CI/CD script in Step 6.
    BRANCH_PREFIX=${VERSION_PREFIX:-"UNKNOWN"}

    echo "$BRANCH_PREFIX.$WEEKS.$DAYS"
}

# Main execution logic
if [[ -f "$NFO_FILE" ]]; then
    # Read the start date from the file
    START_DATE=$(cat "$NFO_FILE" | tr -d '\n')
    calculate_version "$START_DATE"
else
    # Fallback for master branch or error case
    echo "$MASTER_INFINITY"
fi
