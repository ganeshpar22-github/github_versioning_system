#!/bin/bash
# scripts/validation.sh
set -e

HTML_FILE="site_output/release.html"
JSON_FILE="site_output/release.json"
SUMMARY="${GITHUB_STEP_SUMMARY:-/tmp/version_summary.md}"
VALIDATION_FAILURE=0

echo "## Quality Validation Summary" >> "$SUMMARY"

# --- HTML Validation ---
echo "### HTML Validation" >> "$SUMMARY"
if [[ ! -s "$HTML_FILE" ]]; then
    echo "- [ ] HTML output file is empty or missing." >> "$SUMMARY"
    VALIDATION_FAILURE=1
else
    echo "- [x] HTML output file exists." >> "$SUMMARY"
    missing_tags=()
    # List of mandatory W3C tags
    for tag in "<!DOCTYPE html>" "<html" "<head>" "<meta charset=" "<title>" "<body>" "<table>" "</table>" "</body>" "</html>"; do
        grep -qiE "$tag" "$HTML_FILE" || missing_tags+=("$tag")
    done

    if [ ${#missing_tags[@]} -eq 0 ]; then
        echo "- [x] All essential W3C HTML tags are present." >> "$SUMMARY"
    else
        echo "- [ ] Missing essential tags: ${missing_tags[*]}" >> "$SUMMARY"
        VALIDATION_FAILURE=1
    fi
fi

# --- JSON Validation ---
echo "### JSON Validation" >> "$SUMMARY"
if command -v jq &> /dev/null; then
    if jq . "$JSON_FILE" > /dev/null 2>&1; then
        echo "- [x] JSON structure is valid." >> "$SUMMARY"
    else
        echo "- [ ] JSON structure is INVALID." >> "$SUMMARY"
        VALIDATION_FAILURE=1
    fi
fi

# Exit with error if any validation failed
if [ $VALIDATION_FAILURE -ne 0 ]; then
    echo "### [RESULT] Validation Failed ❌" >> "$SUMMARY"
    exit 1
else
    echo "### [RESULT] Validation Passed ✅" >> "$SUMMARY"
    exit 0
fi
