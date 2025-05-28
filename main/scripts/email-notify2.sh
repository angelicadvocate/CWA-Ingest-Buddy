#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.cfg"

LOG_DIR="$SCRIPT_DIR/../log-files"
DEBUG_LOG="$LOG_DIR/msmtp-debug.log"
EMAIL_BODY="$LOG_DIR/email_body.txt"
FAILURES_LOG="$LOG_DIR/failures.log"

echo "Running failure log email check..."

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

# Check if the failures log exists and has content
if [[ -s "$FAILURES_LOG" ]]; then
    echo "To: $ALERT_EMAIL" > "$EMAIL_BODY"
    echo "Subject: CWA-Ingest-Buddy: Failure Log" >> "$EMAIL_BODY"
    echo >> "$EMAIL_BODY"
    cat "$FAILURES_LOG" >> "$EMAIL_BODY"

    echo "Sending failure log email..." >> "$DEBUG_LOG"
    msmtp --file="$MSMTP_CONFIG" "$ALERT_EMAIL" < "$EMAIL_BODY" >> "$DEBUG_LOG" 2>&1

    if [[ $? -eq 0 ]]; then
        echo "Email sent successfully. Clearing the failure log." >> "$DEBUG_LOG"
        > "$FAILURES_LOG"
    else
        echo "Failed to send email." >> "$DEBUG_LOG"
    fi
else
    echo "No failure log entries. No email sent." >> "$DEBUG_LOG"
fi
