#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(dirname "$SCRIPT_DIR")/My-Books"
DEST_DIR="$SCRIPT_DIR/staging-hashcheck"
PROCESSED_LOG="$SCRIPT_DIR/processed-files.log"
NAMECHECK_LOG="$SCRIPT_DIR/namecheck.log"

# Ensure log files exist
touch "$PROCESSED_LOG"
touch "$NAMECHECK_LOG"

# Read processed file names into an array
mapfile -t processed_files < "$PROCESSED_LOG"

# Function to check if a file is already processed
is_processed() {
    local filename="$1"
    for processed in "${processed_files[@]}"; do
        if [[ "$processed" == "$filename" ]]; then
            return 0  # Found
        fi
    done
    return 1  # Not found
}

# Copy new files from source to destination
for file_path in "$SOURCE_DIR"/*; do
    file_name=$(basename "$file_path")

    # Exclude specific files/folders
    if [[ "$file_name" == ".calnotes" || "$file_name" == ".stfolder" || "$file_name" == "metadata.db" ]]; then
        echo "Skipping $file_name"
        continue
    fi

    if is_processed "$file_name"; then
        echo "Skipping already copied file: $file_name"
    else
        cp "$file_path" "$DEST_DIR/"
        if [[ $? -eq 0 ]]; then
            echo "$file_name" >> "$PROCESSED_LOG"
            echo "Copied: $file_name"
        else
            echo "Failed to copy: $file_name"
        fi
    fi
done

# Directory containing the files
DIR="$DEST_DIR"

# Maximum length for the filename (including extension)
MAX_LENGTH=150

# Process files to truncate long names and log the truncated names
for FILE in "$DIR"/*; do
    FILENAME=$(basename "$FILE")

    # Extract extension
    EXTENSION="${FILENAME##*.}"

    # Skip if no extension
    if [ -z "$EXTENSION" ]; then
        continue
    fi

    BASE_NAME="${FILENAME%.*}"
    MAX_FILENAME_LENGTH=$((MAX_LENGTH - ${#EXTENSION} - 1)) # account for dot

    if [ ${#BASE_NAME} -gt $MAX_FILENAME_LENGTH ]; then
        TRUNCATED_BASE=$(echo "$BASE_NAME" | cut -c1-$MAX_FILENAME_LENGTH)
        NEW_FILENAME="$TRUNCATED_BASE.$EXTENSION"

        # Rename file
        mv "$FILE" "$DIR/$NEW_FILENAME"

        # Log the truncated name
        echo "$NEW_FILENAME" >> "$NAMECHECK_LOG"
        echo "Renamed: $FILENAME to $NEW_FILENAME"
    fi
done

sleep 30

# Call the next script: hashcheck.sh
"$SCRIPT_DIR/hashcheck.sh"
