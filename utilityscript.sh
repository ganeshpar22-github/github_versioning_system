#!/bin/bash
# Description: Orchestrates version fetching and generates the final HTML and JSON files.



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
    
    # Master branch specific logic: Weeks are always 0. Days increment daily.
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
    <title>Crew Release Versions</title>
    <style>
        table, th, td {
            border: 1px solid #ddd;
            border-collapse: collapse;
            padding: 8px;
            text-align: left;
        }
        th {
         background-color: #f2f2f2;
         display: table-cell;
        }
        table {
         width: 100%;
        }
    </style>
</head>
<body>
    <h1>Releases</h1>
    <br>
    <a href="https://ganeshpar22-github.github.io/github_versioning_system/release.json">release.json</a>
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
JSON_KEY="master"
MAX_VER="$MASTER_INFINITY"
NEXT_REL="undefined"

# Add main entry to JSON and HTML
cat <<EOF >> "$JSON_OUTPUT"
  "$JSON_KEY":{
    "current-version":"$CURRENT_VER",
    "max-version": "$MAX_VER",
    "next-release":"$NEXT_REL"
  }
EOF

cat <<EOF >> "$HTML_OUTPUT"
            <tr>
                <td>master</td>
                <td>$CURRENT_VER</td>
                <td>$MAX_VER</td>
                <td>$NEXT_REL</td>
            </tr>
EOF

FIRST_ENTRY=false


# --- Process Release Branches using a single repository approach ---

# Find branches in the remote references
# here we can use different sort options as per requirement and different format used in commit history
mapfile -t RELEASE_REFS < <(git for-each-ref --sort=-refname --format='%(refname:short)' refs/remotes/origin/release/crew-*)

for BRANCH_REF in "${RELEASE_REFS[@]}"; do
    echo "--- Processing branch ref: $BRANCH_REF ---"

    # Forcefully switch the working directory to this branch's content
    git reset --hard "$BRANCH_REF" > /dev/null 2>&1
    
    # Ensure the script has execute permissions just in case
    chmod +x ./bin/version.sh

    # Derive clean branch name (e.g., release/crew-2025.1) from the remote ref (origin/release/crew-2025.1)
    # here we can make changes by removing number of slashes
    BRANCH_NAME=$(echo "$BRANCH_REF" | sed 's/origin\///')

    # Extract the YYYY.R part (e.g., 2025.1)
    RELEASE_PREFIX=$(echo "$BRANCH_NAME" | sed 's/release\/crew-//')
    echo "Derived RELEASE_PREFIX: $RELEASE_PREFIX"

    # Execute the version.sh script which IS present in this branch context
    # here first give only release prefix, it will give error, after then give full version prefix
    if CURRENT_VER=$(VERSION_PREFIX="$RELEASE_PREFIX" ./bin/version.sh); then
        echo "Generated Version for $BRANCH_NAME: $CURRENT_VER"
    else
        echo "[ERROR] version.sh failed for $BRANCH_NAME. Logging and degrading gracefully." >&2
        continue # Skip this branch
    fi
    
    MAX_VER="${VERSION_PREFIX}${RELEASE_INFINITY_SUFFIX}"
    NEXT_REL="${VERSION_PREFIX}${NEXT_RELEASE_SUFFIX}"
    JSON_KEY="$BRANCH_NAME"

    # Add this branch data to JSON/HTML
    #HERE ALSO we can skip out , and then again add back
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

done

# Switch back to main/master branch context before finishing
# Use the correct name of your default branch here (e.g., 'master' or 'main')
# here we have to give main as a branch name
git reset --hard "master" > /dev/null 2>&1 


# Finalize HTML and JSON files
echo "    </tbody></table></body></html>" >> "$HTML_OUTPUT"
echo "}" >> "$JSON_OUTPUT"


echo "Successfully generated $HTML_OUTPUT and $JSON_OUTPUT"

# # Add basic JSON validation using 'jq' (must be installed in the CI runner)
# if command -v jq &> /dev/null; then
#     jq . "$JSON_OUTPUT" > /dev/null
#     echo "JSON validation successful."
# else
#     echo "[WARNING] jq not installed, skipping JSON format validation."
# fi
