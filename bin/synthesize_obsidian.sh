#!/bin/bash

# This script combines the content of all markdown files in a directory and
# copies it to the clipboard. Useful for injecting into GTP.
#
# Check if the directory parameter is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

# The directory containing markdown files, passed as the first argument
DIRECTORY="$1"

# Temporary file to hold the combined content
TMP_FILE=$(mktemp)

# Iterate over all markdown files in the directory
find "$DIRECTORY" -name "*.md" -print0 | while IFS= read -r -d '' file; do
    # Extract filename without path and extension
    filename=$(basename -- "$file" .md)

    # Format and append content to temporary file
    echo '---START---' >> "$TMP_FILE"
    echo "Title: $filename" >> "$TMP_FILE"
    echo "Content: " >> "$TMP_FILE"
    cat "$file" >> "$TMP_FILE"
    echo '---END---' >> "$TMP_FILE"
    echo '' >> "$TMP_FILE" # Adds a newline for separation between files
done

# Copy the contents of the temporary file to the clipboard
cat "$TMP_FILE" | pbcopy

# Clean up the temporary file
rm "$TMP_FILE"

# Notify user of completion
echo "Markdown files from '$DIRECTORY' have been copied to the clipboard."
