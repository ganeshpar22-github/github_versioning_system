#!/bin/bash
# Description: Orchestrates version fetching and generates the final HTML and JSON files.

set -e

REPO_ROOT=$(pwd)
OUTPUT_DIR="$REPO_ROOT/site_output"
mkdir -p "$OUTPUT_DIR"

HTML_OUTPUT="$OUTPUT_DIR/release.html"
JSON_OUTPUT="$OUTPUT_DIR/release.json"

MASTER_INFINITY="0.0.0"
RELEASE_INFINITY_SUFFIX=".999"
NEXT_RELEASE_SUFFIX=".1000"

echo "Starting pages generation process..."

# Start JSON file structure
echo "{" > "$JSON_OUTPUT"

# Start HTML file structure (W3C compliant minimal skeleton)
cat <<EOF > "$HTML_OUTPUT"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Release Versions</title>
    <style>
        table, th, td {
            border: 1px solid black;
            border-collapse: collapse;
            padding: 8px;
            text-align: left;
        }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Current Release Versions</h1>
    <table>
        <thead>
            <tr>
                <th>Branch</th>
                <th>Current Version</th>
                <th>Max Version</th>
                <th>Next Release</th>
            </tr>
        </thead>
        <tbody>
EOF

# Function to calculate version components from an anchor date (Used only for Master branch here)
calculate_master_version_components() {
    START_DATE_STR=$1
    PREFIX=$2 # e.g., 2026.1
    
    START_EPOCH=$(date -d "$START_DATE_STR" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_DIFF=$(( (CURRENT_EPOCH - START_EPOCH) / 86400 ))
    
    # Master branch specific logic: Weeks are always 0. Days increment daily.
    WEEKS=0
    DAYS=$DAYS_DIFF

    echo "$PREFIX.$WEEKS.$DAYS"
}


FIRST_ENTRY=true

# --- Process 'main' branch data first (Hardcoded as requested by user) ---

# !!! Developer Note: Update these two variables when cutting a new release branch !!!
MASTER_PREFIX="2026.1"
MASTER_ANCHOR_DATE="2025-12-01" 
# ----------------------------------------------------------------------------------

echo "--- Processing branch: main (master) using hardcoded values ---"

CURRENT_VER=$(calculate_master_version_components "$MASTER_ANCHOR_DATE" "$MASTER_PREFIX")
JSON_KEY="master" MAX_VER="$MASTER_INFINITY" NEXT_REL="undefined"

# Add main entry to JSON and HTML
cat <<EOF >> "$JSON_OUTPUT"
  "$JSON_KEY":{
    "current-version":"$CURRENT_VER",
    "max-version": "$MAX_VER"
  }
EOF

cat <<EOF >> "$HTML_OUTPUT"
            <tr>
                <td>main</td>
                <td>$CURRENT_VER</td>
                <td>$MAX_VER</td>
                <td>$NEXT_REL</td>
            </tr>
EOF

FIRST_ENTRY=false


# --- Process Release Branches using git checkout and the required version.sh script ---

# Dynamically find all release branches (main is excluded by name pattern)
RELEASE_BRANCHES=$(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/release/crew-*)

for BRANCH in $RELEASE_BRANCHES; do
    echo "--- Processing branch: $BRANCH ---"
    
    # CRITICAL STEP: Temporarily switch to the branch to satisfy the functional requirement
    # that the local version.sh script must run in its own context.
    git checkout "$BRANCH" > /dev/null 2>&1

    # Extract the YYYY.R part (e.g., 2025.1)
    export VERSION_PREFIX=$(echo "$BRANCH" | sed 's/release\/crew-//')

    # Execute the version.sh script which *is* present in this specific branch context
    if CURRENT_VER=$(./bin/version.sh); then
        echo "Generated Version for $BRANCH: $CURRENT_VER"
    else
        echo "[ERROR] version.sh failed for $BRANCH. Logging and degrading gracefully." >&2
        continue # Skip this branch, but don't break the whole script
    fi
    
    MAX_VER="${VERSION_PREFIX}${RELEASE_INFINITY_SUFFIX}"
    NEXT_REL="${VERSION_PREFIX}${NEXT_RELEASE_SUFFIX}"
    JSON_KEY="$BRANCH"

    # Add this branch data to JSON/HTML
    echo "," >> "$JSON_OUTPUT"
    cat <<EOF >> "$JSON_OUTPUT"
  "$JSON_KEY":{
    "current-version":"$CURRENT_VER",
    "max-version":"$MAX_VER",
    "next-release":"$NEXT_REL"
  }
EOF

    cat <<EOF >> "$HTML_OUTPUT"
            <tr>
                <td>$BRANCH</td>
                <td>$CURRENT_VER</td>
                <td>$MAX_VER</td>
                <td>$NEXT_REL</td>
            </tr>
EOF

done

# Finalize HTML and JSON files
echo "    </tbody></table></body></html>" >> "$HTML_OUTPUT"
echo "}" >> "$JSON_OUTPUT"

# Switch back to main branch context before finishing
git checkout main > /dev/null 2>&1

echo "Successfully generated $HTML_OUTPUT and $JSON_OUTPUT"

# Add basic JSON validation using 'jq' (must be installed in the CI runner)
if command -v jq &> /dev/null; then
    jq . "$JSON_OUTPUT" > /dev/null
    echo "JSON validation successful."
else
    echo "[WARNING] jq not installed, skipping JSON format validation."
fi
echo "Pages generation process completed."