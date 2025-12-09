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

# Function to calculate version components from an anchor date (Used only for Master branch here)
calculate_master_version_components() {
    START_DATE_STR=$1
    PREFIX=$2 # e.g., 2026.1
    
    if ! START_EPOCH=$(date -d "$START_DATE_STR" +%s 2>/dev/null); then
        echo "[ERROR] Invalid date format for master anchor date: '$START_DATE_STR'." >&2
        exit 1
    fi
    
    CURRENT_EPOCH=$(date +%s)
    DAYS_DIFF=$(( (CURRENT_EPOCH - START_EPOCH) / 86400 ))
    
    WEEKS=0
    DAYS=$DAYS_DIFF

    echo "$PREFIX.$WEEKS.$DAYS"
}

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

FIRST_ENTRY=true

# --- Process 'main' branch data first (Hardcoded values) ---
# NOTE: Update these variables when cutting a new release branch
MASTER_PREFIX="2026.1"
MASTER_ANCHOR_DATE="2025-12-01" 

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


# --- Process Release Branches using temporary clones and referencing remotes ---

# Find branches in the remote references
mapfile -t RELEASE_REFS < <(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/remotes/origin/release/crew-*)

for BRANCH_REF in "${RELEASE_REFS[@]}"; do
    echo "--- Processing branch ref: $BRANCH_REF ---"

    # Derive clean branch name (e.g., release/crew-2025.1) from the remote ref (origin/release/crew-2025.1)
    BRANCH_NAME=$(echo "$BRANCH_REF" | sed 's/origin\///')
    
    # Create a temporary directory for this specific branch context
    TEMP_DIR=$(mktemp -d)
    
    # Clone the repo into the temp directory
    git clone "$REPO_ROOT" "$TEMP_DIR" > /dev/null 2>&1
    cd "$TEMP_DIR"
    
    # Checkout the specific branch name so the files are present locally in temp dir
    git checkout "$BRANCH_NAME" > /dev/null 2>&1

    chmod +x ./bin/version.sh # Ensure version.sh is executable

    # Extract the YYYY.R part (e.g., 2025.1)
    export VERSION_PREFIX=$(echo "$BRANCH_NAME" | sed 's/release\/crew-//')

    # Execute the version.sh script which IS present in this temp directory
    if CURRENT_VER=$(./bin/version.sh); then
        echo "Generated Version for $BRANCH_NAME: $CURRENT_VER"
    else
        echo "[ERROR] version.sh failed for $BRANCH_NAME. Logging and degrading gracefully." >&2
        cd "$REPO_ROOT"
        rm -rf "$TEMP_DIR"
        continue
    fi
    
    # Return to the main repository root directory to write the outputs
    cd "$REPO_ROOT"

    MAX_VER="${VERSION_PREFIX}${RELEASE_INFINITY_SUFFIX}"
    NEXT_REL="${VERSION_PREFIX}${NEXT_RELEASE_SUFFIX}"
    JSON_KEY="$BRANCH_NAME"

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
                <td>$BRANCH_NAME</td>
                <td>$CURRENT_VER</td>
                <td>$MAX_VER</td>
                <td>$NEXT_REL</td>
            </tr>
EOF

    # Clean up the temporary directory
    rm -rf "$TEMP_DIR"

done


# Finalize HTML and JSON files
echo "    </tbody></table></body></html>" >> "$HTML_OUTPUT"
echo "}" >> "$JSON_OUTPUT"


echo "Successfully generated $HTML_OUTPUT and $JSON_OUTPUT"

# Add basic JSON validation using 'jq' (must be installed in the CI runner)
if command -v jq &> /dev/null; then
    jq . "$JSON_OUTPUT" > /dev/null
    echo "JSON validation successful."
else
    echo "[WARNING] jq not installed, skipping JSON format validation."
fi
