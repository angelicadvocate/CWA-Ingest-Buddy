#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG_FILE="$SCRIPT_DIR/config.cfg"

# Source the config file
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Provide defaults if not set
SMTP_HOST="${SMTP_HOST:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"

# Check required variables
if [[ -z "$ALERT_EMAIL" || -z "$SMTP_EMAIL" || -z "$SMTP_PASSWORD" ]]; then
    echo "Error: ALERT_EMAIL, SMTP_EMAIL, and SMTP_PASSWORD must be set in config.cfg"
    exit 1
fi

# Directories to check
declare -A CHECK_DIRS=(
    ["staging-deduplication"]="$SCRIPT_DIR/staging-deduplication"
    ["staging-hashcheck"]="$SCRIPT_DIR/staging-hashcheck"
    ["staging-namecheck"]="$SCRIPT_DIR/staging-namecheck"
)

# Create msmtp config file on the fly (in tmp) using provided SMTP credentials
MSMTP_CONFIG=$(mktemp)
chmod 600 "$MSMTP_CONFIG"
cat > "$MSMTP_CONFIG" <<EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /dev/null

account default
host           $SMTP_HOST
port           $SMTP_PORT
user           $SMTP_EMAIL
password       $SMTP_PASSWORD
from           $SMTP_EMAIL
EOF

# Prepare email content if stale files found
email_body=$(mktemp)
email_found=0

{
  echo "To: $ALERT_EMAIL"
  echo "Subject: Stale Files Found in CWA-Ingest-Buddy Staging Folders"
  echo
  echo "The following files have been in the staging folders for more than 1 day and are larger than 1MB:"
  echo
} > "$email_body"

for folder_name in "${!CHECK_DIRS[@]}"; do
    folder_path="${CHECK_DIRS[$folder_name]}"

    if [[ ! -d "$folder_path" ]]; then
        continue
    fi

    # Find files older than 1 day
    mapfile -t old_files < <(find "$folder_path" -type f -mtime +1 -size +1M)

    if [[ ${#old_files[@]} -gt 0 ]]; then
        email_found=1
        echo "Folder: $folder_name" >> "$email_body"
        for file in "${old_files[@]}"; do
            echo "  - $(basename "$file")" >> "$email_body"
        done
        echo >> "$email_body"
    fi
done

if [[ $email_found -eq 1 ]]; then
    msmtp --file="$MSMTP_CONFIG" "$ALERT_EMAIL" < "$email_body"
fi

rm "$email_body" "$MSMTP_CONFIG"
