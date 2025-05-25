#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/staging-hashcheck"
DEST_DIR="$SCRIPT_DIR/staging-deduplication"
LOG_FILE="$SCRIPT_DIR/hashcheck-names.log"
HASH_FILE="$SCRIPT_DIR/hashcheck-hashes.log"

# Ensure log files exist
touch "$LOG_FILE"
touch "$HASH_FILE"

# Read logged file names and hashes into arrays
mapfile -t logged_files < "$LOG_FILE"
mapfile -t logged_hashes < "$HASH_FILE"

# Function to check if a file name is already logged
is_logged_name() {
    local filename="$1"
    for logged in "${logged_files[@]}"; do
        if [[ "$logged" == "$filename" ]]; then
            return 0  # Found
        fi
    done
    return 1  # Not found
}

# Function to check if a hash is already logged
is_logged_hash() {
    local hash="$1"
    for logged in "${logged_hashes[@]}"; do
        if [[ "$logged" == "$hash" ]]; then
            return 0  # Found
        fi
    done
    return 1  # Not found
}

# Loop through files in source directory
for file_path in "$SOURCE_DIR"/*; do
    [[ -f "$file_path" ]] || continue  # Skip if not a file

    file_name=$(basename "$file_path")

    # Exclude specific files/folders
    if [[ "$file_name" == ".calnotes" || "$file_name" == ".stfolder" || "$file_name" == "metadata.db" ]]; then
        echo "Skipping $file_name"
        continue
    fi

    # Compute SHA256 hash of the file
    file_hash=$(sha256sum "$file_path" | awk '{print $1}')

    if is_logged_name "$file_name"; then
        echo "Skipping already moved file (name match): $file_name"
        continue
    fi

    if is_logged_hash "$file_hash"; then
        echo "Skipping already moved file (hash match): $file_name"
        continue
    fi

    # Move file and log
    mv "$file_path" "$DEST_DIR/"
    if [[ $? -eq 0 ]]; then
        echo "$file_name" >> "$LOG_FILE"
        echo "$file_hash" >> "$HASH_FILE"
        echo "Moved: $file_name"
    else
        echo "Failed to move: $file_name"
    fi

"$SCRIPT_DIR/deduplication.sh"

done
