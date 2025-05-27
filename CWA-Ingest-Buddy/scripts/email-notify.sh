#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.cfg"

LOG_DIR="$SCRIPT_DIR/../log-files"
mkdir -p "$LOG_DIR"
DEBUG_LOG="$LOG_DIR/msmtp-debug.log"
EMAIL_BODY="$LOG_DIR/email_body.txt"

echo "Running stale file check..."

# Source the config file
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    echo "Loaded config from $CONFIG_FILE" >> "$DEBUG_LOG"
else
    echo "Error: Config file not found at $CONFIG_FILE" >> "$DEBUG_LOG"
    exit 1
fi

# Provide defaults if not set
SMTP_HOST="${SMTP_HOST:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"

# Check required variables
if [[ -z "$ALERT_EMAIL" || -z "$SMTP_EMAIL" || -z "$SMTP_PASSWORD" ]]; then
    echo "Error: ALERT_EMAIL, SMTP_EMAIL, and SMTP_PASSWORD must be set in config.cfg" >> "$DEBUG_LOG"
    exit 1
fi

declare -A CHECK_DIRS=(
    ["staging-deduplication"]="$SCRIPT_DIR/../staging-deduplication"
    ["staging-hashcheck"]="$SCRIPT_DIR/../staging-hashcheck"
    ["staging-namecheck"]="$SCRIPT_DIR/../staging-namecheck"
)

# Create msmtp config file in log folder
MSMTP_CONFIG="$LOG_DIR/msmtp.cfg"
cat > "$MSMTP_CONFIG" <<EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        $DEBUG_LOG

account default
host           $SMTP_HOST
port           $SMTP_PORT
user           $SMTP_EMAIL
password       $SMTP_PASSWORD
from           $SMTP_EMAIL
EOF

chmod 600 "$MSMTP_CONFIG"
echo "Created msmtp config at $MSMTP_CONFIG" >> "$DEBUG_LOG"

# Prepare email content if stale files found
email_found=0
{
  echo "To: $ALERT_EMAIL"
  echo "Subject: Stale Files Found in CWA-Ingest-Buddy Staging Folders"
  echo
  echo "The following files have been in the staging folders for more than 1 day and are larger than 1MB:"
  echo
} > "$EMAIL_BODY"

echo "Scanning folders for stale files..." >> "$DEBUG_LOG"

for folder_name in "${!CHECK_DIRS[@]}"; do
    folder_path="${CHECK_DIRS[$folder_name]}"

    if [[ ! -d "$folder_path" ]]; then
        echo "Warning: Folder $folder_path does not exist." >> "$DEBUG_LOG"
        continue
    fi

    mapfile -t old_files < <(find "$folder_path" -type f -mtime +1 -size +1M 2>>"$DEBUG_LOG")

    if [[ ${#old_files[@]} -gt 0 ]]; then
        email_found=1
        echo "Folder: $folder_name" >> "$EMAIL_BODY"
        for file in "${old_files[@]}"; do
            echo "  - $(basename "$file")" >> "$EMAIL_BODY"
        done
        echo >> "$EMAIL_BODY"
    fi
done

if [[ $email_found -eq 1 ]]; then
    echo "Stale files detected, sending email..."
    msmtp --file="$MSMTP_CONFIG" "$ALERT_EMAIL" < "$EMAIL_BODY" >> "$DEBUG_LOG" 2>&1
    echo "Email sent. Details logged to $DEBUG_LOG."
else
    echo "No stale files detected."
fi

echo "Script finished."
