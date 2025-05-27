#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.cfg"
SOURCE_DIR="$SCRIPT_DIR/../staging-deduplication"

# Source the config file to get the ingest path
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Ensure the ingest path is set
if [[ -z "$INGEST_PATH" ]]; then
    echo "Error: INGEST_PATH is not set in config.cfg"
    exit 1
fi

# Move all files from staging-deduplication to the final ingest directory
for file in "$SOURCE_DIR"/*; do
    [[ -f "$file" ]] || continue  # Skip if not a file

    mv "$file" "$INGEST_PATH/"
    if [[ $? -eq 0 ]]; then
        echo "Moved: $(basename "$file")"
    else
        echo "Failed to move: $(basename "$file")"
    fi

done
