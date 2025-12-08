#!/bin/bash

# Exit on error
set -e

# Define constants
MASTER_INFINITY="0.0.0"
BRANCH_NFO_FILE="./bin/branch.nfo"

# Function to log errors to stderr
log_error() {
    echo "[ERROR] $1" >&2
}

# Function to calculate YYYY.R.W.D version from a start date
calculate_version() {
    START_DATE_STR=$1

    # Input validation
    if [[ -z "$START_DATE_STR" ]]; then
        log_error "Start date string is empty."
        exit 1
    fi
    
    # Use 'date' command to validate and get epoch time
    # We wrap this in an if condition to capture potential parsing errors gracefully
    if ! START_EPOCH=$(date -d "$START_DATE_STR" +%s 2>/dev/null); then
        log_error "Invalid date format in branch.nfo: '$START_DATE_STR'."
        log_error "Expected format: YYYY-MM-DD"
        exit 1
    fi
    
    CURRENT_EPOCH=$(date +%s)

    # Arithmetic checks (basic sanity check)
    if [[ "$START_EPOCH" -gt "$CURRENT_EPOCH" ]]; then
        log_error "Start date cannot be in the future. Check branch.nfo ($START_DATE_STR)."
        # We might continue with 0.0.0 or exit, depending on business rules. Exiting for strictness:
        exit 1
    fi

    DAYS_DIFF=$(( (CURRENT_EPOCH - START_EPOCH) / 86400 ))
    WEEKS=$(( DAYS_DIFF / 7 ))
    DAYS=$(( DAYS_DIFF % 7 ))

    # Determine branch prefix, fall back to "UNDEFINED" if not set by CI/CD environment
    BRANCH_PREFIX=${VERSION_PREFIX:-"UNDEFINED"}
    if [[ "$BRANCH_PREFIX" == "UNDEFINED" ]]; then
        log_error "VERSION_PREFIX is not set correctly for release branch"
        # Decide if this should exit 0 or 1 based on requirements
    fi

    echo "$BRANCH_PREFIX.$WEEKS.$DAYS"
}

# Main execution logic
if [[ -f "$BRANCH_NFO_FILE" ]]; then
    # Read the start date from the file
    START_DATE=$(cat "$BRANCH_NFO_FILE" | tr -d '\n')
    calculate_version "$START_DATE"
else
    # Fallback for master branch or error case where file is missing
    echo "$MASTER_INFINITY"
fi
