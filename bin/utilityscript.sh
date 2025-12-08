#!/bin/bash
set -e

REPO_ROOT=$(pwd)
OUTPUT_DIR="$REPO_ROOT/site_output"
mkdir -p "$OUTPUT_DIR"

HTML_OUTPUT="$OUTPUT_DIR/release.html"
JSON_OUTPUT="$OUTPUT_DIR/release.json"

# Start JSON file structure
echo "{" > "$JSON_OUTPUT"

# Start HTML file structure (W3C compliant minimal skeleton)
cat <<EOF > "$HTML_OUTPUT"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Release Versions</title>
    <style>table, th, td {border: 1px solid black; border-collapse: collapse; padding: 5px;}</style>
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

# Define branches to process: master first, then specific release branches
BRANCHES=("main" "release/crew-2025.1" "release/crew-2024.2" "release/crew-2024.1")
FIRST_ENTRY=true

for BRANCH in "${BRANCHES[@]}"; do
    echo "Processing branch: $BRANCH"
    
    # Temporarily switch to the branch
    git checkout "$BRANCH" > /dev/null 2>&1

    # Define the VERSION_PREFIX needed for the inner script
    # Handle "main" specifically, otherwise strip the "release/crew-" part
    if [[ "$BRANCH" == "main" ]]; then
        VERSION_PREFIX="master"
        # For master/main, the inner script should default to 0.0.0
        export VERSION_PREFIX="" 
        CURRENT_VER=$(./bin/version.sh) # Should return 0.0.0 based on logic
        MAX_VER="0.0.0"
        NEXT_REL="undefined"
        JSON_KEY="master"
    else
        VERSION_PREFIX=$(echo "$BRANCH" | sed 's/release\/crew-//') # e.g., 2025.1
        export VERSION_PREFIX # Pass prefix via ENV var to the script
        CURRENT_VER=$(./bin/version.sh)
        MAX_VER="${VERSION_PREFIX}.999"
        NEXT_REL="${VERSION_PREFIX}.1000"
        JSON_KEY="$BRANCH"
    fi

    # Append to JSON (handle commas correctly)
    if [[ "$FIRST_ENTRY" == "false" ]]; then
        echo "," >> "$JSON_OUTPUT"
    else
        FIRST_ENTRY=false
    fi
    
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

# Switch back to main branch context
git checkout main > /dev/null 2>&1

echo "Generated HTML and JSON files in $OUTPUT_DIR"

# Add validation logic here using tools like 'jq' for JSON and 'html-proofer' (needs installation) for HTML
jq . "$JSON_OUTPUT" > /dev/null # Basic JSON validation
echo "JSON validation successful."
# (HTML validation step would require an external tool installation in the CI runner)
