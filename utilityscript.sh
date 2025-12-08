#!/bin/bash
# Description: Orchestrates fetching versions from all release branches and generates
#              the final release.html and release.json files for GitHub Pages deployment.

set -e

REPO_ROOT=$(pwd)
OUTPUT_DIR="$REPO_ROOT/site_output"
mkdir -p "$OUTPUT_DIR"

HTML_OUTPUT="$OUTPUT_DIR/release.html"
JSON_OUTPUT="$OUTPUT_DIR/release.json"

# Define infinity constants used in the final output
RELEASE_INFINITY_SUFFIX=".999"
NEXT_RELEASE_SUFFIX=".1000"
MASTER_INFINITY="0.0.0" # Matches the special version number for master branch parameters

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
        th {
            background-color: #f2f2f2;
        }
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

# Define branches to process: main/master first, then specific release branches from newest to oldest
# ex: full branch name -> origin/release/crew-2023.1
BRANCHES=("main" $(git branch -r | grep "release/crew-" | sed 's/origin\///'))
FIRST_ENTRY=true

for BRANCH in "${BRANCHES[@]}"; do
    echo "--- Processing branch: $BRANCH ---"
    
    # Temporarily switch to the branch to run its local version script
    git checkout "$BRANCH" > /dev/null 2>&1

    # Set the environment variable required by version.sh script
    if [[ "$BRANCH" == "main" ]]; then
        export VERSION_PREFIX="" # version.sh defaults to 0.0.0 based on this empty prefix
        MAX_VER="$MASTER_INFINITY"
        NEXT_REL="undefined" # Matches epic requirement for master branch
        JSON_KEY="master"
    else
        # Extract the YYYY.R part (e.g., 2025.1)
        export VERSION_PREFIX=$(echo "$BRANCH" | sed 's/release\/crew-//')
        MAX_VER="${VERSION_PREFIX}${RELEASE_INFINITY_SUFFIX}"
        NEXT_REL="${VERSION_PREFIX}${NEXT_RELEASE_SUFFIX}"
        JSON_KEY="$BRANCH"
    fi

    # Execute the version generation script located in the *current branch* context
    if CURRENT_VER=$(./bin/version.sh); then
        echo "Generated Version for $BRANCH: $CURRENT_VER"
    else
        echo "[FATAL] Failed to generate version for $BRANCH. Exiting script." >&2
        # Fails the entire pipeline as per requirement "workflow fails if: version generation fails"
        exit 1 
    fi

    # Append to JSON (handle commas correctly)
    if [[ "$FIRST_ENTRY" == "false" ]]; then
        echo "," >> "$JSON_OUTPUT"
    else
        FIRST_ENTRY=false
    fi
    
    # Generate JSON structure based on branch type (master vs release)
    if [[ "$BRANCH" == "main" ]]; then
        cat <<EOF >> "$JSON_OUTPUT"
  "$JSON_KEY":{
    "current-version":"$CURRENT_VER",
    "max-version": "$MAX_VER"
  }
EOF
    else
        cat <<EOF >> "$JSON_OUTPUT"
  "$JSON_KEY":{
    "current-version":"$CURRENT_VER",
    "max-version":"$MAX_VER",
    "next-release":"$NEXT_REL"
  }
EOF
    fi

    # Append to HTML table
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

# Note: HTML W3C validation needs an external tool in the CI runner environment
echo "Pages generation process completed."