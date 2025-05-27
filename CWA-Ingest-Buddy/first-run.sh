#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or with sudo."
  echo "Please try again with sudo or as root."
  sleep 2
  exit 1
fi

CONFIG_FILE="config.cfg"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Welcome to CWA-Ingest-Buddy setup!"
echo "-----------------------------------"
echo "Please enter the full path to your ingest folder."
echo "If you need to find it, run the 'pwd' command in that folder first."
echo

# Prompt user for ingest path
read -rp "Full path to ingest folder: " ingest_path

# Check if the path exists and is a directory
if [ -d "$ingest_path" ]; then
  echo "Ingest folder found: $ingest_path"

  # Remove existing INGEST_PATH line if present
  if grep -q '^INGEST_PATH=' "$CONFIG_FILE" 2>/dev/null; then
      sed -i '/^INGEST_PATH=/d' "$CONFIG_FILE"
  fi

  # Save the path to config.cfg (append)
  echo "INGEST_PATH=\"$ingest_path\"" >> "$CONFIG_FILE"
  echo "Path saved to config.cfg!"

  # Ask about alerting
  read -rp "Do you want to set up email alerts for files hung in the ingest process? (y/n): " alert_choice

  # Remove existing alert-related lines if present (always clean first)
  for var in ALERT_EMAIL SMTP_EMAIL SMTP_PASSWORD SMTP_HOST SMTP_PORT; do
    if grep -q "^$var=" "$CONFIG_FILE" 2>/dev/null; then
      sed -i "/^$var=/d" "$CONFIG_FILE"
    fi
  done

  if [[ "$alert_choice" =~ ^[Yy]$ ]]; then
      echo "Installing SMTP client (e.g. msmtp)..."
      apt-get update && apt-get install -y msmtp || {
        echo "Failed to install msmtp. Please install it manually."
        exit 1
      }
      echo "SMTP client installed."
      read -rp "Enter the recipient email address for alerts: " alert_email
      read -rp "Enter the sender email address (SMTP user): " smtp_email
      read -rsp "Enter the SMTP password (input hidden): " smtp_password
      echo
      read -rp "Enter the SMTP host (default: smtp.gmail.com): " smtp_host
      smtp_host=${smtp_host:-smtp.gmail.com}
      read -rp "Enter the SMTP port (default: 587): " smtp_port
      smtp_port=${smtp_port:-587}

      echo "ALERT_EMAIL=\"$alert_email\"" >> "$CONFIG_FILE"
      echo "SMTP_EMAIL=\"$smtp_email\"" >> "$CONFIG_FILE"
      echo "SMTP_PASSWORD=\"$smtp_password\"" >> "$CONFIG_FILE"
      echo "SMTP_HOST=\"$smtp_host\"" >> "$CONFIG_FILE"
      echo "SMTP_PORT=\"$smtp_port\"" >> "$CONFIG_FILE"

      echo "Alert settings saved."
  else
      echo "Skipping alerting setup."
      # Since user declined email alerts, remove any existing email notification cron job
      # Remove line with email-notify.sh from current crontab (if any)
      crontab -l 2>/dev/null | grep -v 'email-notify.sh' | crontab -
      echo "Removed any existing email notification cron jobs."
  fi

else
  echo "Error: The path \"$ingest_path\" does not exist or is not a directory."
  echo "Please check the path and try again."
  sleep 2
  exit 1
fi

# Make sure main scripts are executable
chmod +x "$SCRIPT_DIR/scripts/namecheck.sh"
chmod +x "$SCRIPT_DIR/scripts/hashcheck.sh"
chmod +x "$SCRIPT_DIR/scripts/deduplication.sh"
chmod +x "$SCRIPT_DIR/scripts/email-notify.sh"

echo "Scripts have been made executable!"

# Create directories for staging directories if they don't exist
mkdir -p "$SCRIPT_DIR/staging-hashcheck"
mkdir -p "$SCRIPT_DIR/staging-deduplication"
mkdir -p "$SCRIPT_DIR/staging-namecheck"

echo "Staging directories created!"

# CWA-Ingest-Buddy Crontab Setup
SCRIPT_PATH="$SCRIPT_DIR/scripts/namecheck.sh"

echo "Would you like to set up a cron job to run the main script automatically?"
read -rp "Enter Y to proceed, or N to skip: " cron_choice

if [[ "$cron_choice" =~ ^[Yy]$ ]]; then
    while true; do
        read -rp "How often should the main script run (in minutes, minimum 5)? " interval

        # Check if it's a number
        if [[ ! "$interval" =~ ^[0-9]+$ ]]; then
            echo "Invalid input. Please enter a number."
            continue
        fi

        # Check if it's at least 5
        if [[ "$interval" -lt 5 ]]; then
            echo "Please enter a number greater than or equal to 5."
            continue
        fi

        # Valid input, break the loop
        break
    done

    # Remove any existing cron job for namecheck.sh to avoid duplicates
    crontab -l 2>/dev/null | grep -v 'namecheck.sh' | crontab -

    # Build the cron schedule
    cron_schedule="*/$interval * * * *"

    # Add the cron job
    (crontab -l 2>/dev/null; echo "$cron_schedule $SCRIPT_PATH") | crontab -

    echo "Cron job set to run every $interval minutes!"
else
    echo "Skipping main script cron setup."
    # Optional: Remove any existing cron job for namecheck.sh if user does not want it
    crontab -l 2>/dev/null | grep -v 'namecheck.sh' | crontab -
    echo "Removed any existing main script cron jobs."
fi

# Email Notification Cron Setup
echo "Would you like to set up a cron job to run the email-notify script automatically?"
read -rp "Enter Y to proceed, or N to skip: " cron_choice

if [[ "$cron_choice" =~ ^[Yy]$ ]]; then
    while true; do
        read -rp "How often should the email notifications run (in days, minimum 1)? " days_interval
        if [[ ! "$days_interval" =~ ^[0-9]+$ ]] || [[ "$days_interval" -lt 1 ]]; then
            echo "Please enter a valid number 1 or greater."
            continue
        fi
        break
    done

    while true; do
        read -rp "Enter the hour of the day for the email to be sent (0-23): " hour
        if [[ ! "$hour" =~ ^([0-9]|1[0-9]|2[0-3])$ ]]; then
            echo "Invalid hour. Please enter a number between 0 and 23."
            continue
        fi
        break
    done

    while true; do
        read -rp "Enter the minute of the hour for the email to be sent (0-59): " minute
        if [[ ! "$minute" =~ ^([0-9]|[1-5][0-9])$ ]]; then
            echo "Invalid minute. Please enter a number between 0 and 59."
            continue
        fi
        break
    done

    # Remove existing email-notify.sh cron job to avoid duplicates
    crontab -l 2>/dev/null | grep -v 'email-notify.sh' | crontab -

    # Build the cron schedule to run every $days_interval days at specified time
    cron_schedule="$minute $hour */$days_interval * *"

    (crontab -l 2>/dev/null; echo "$cron_schedule $SCRIPT_DIR/scripts/email-notify.sh") | crontab -

    echo "Cron job set to run every $days_interval days at $hour:$minute!"
else
    echo "Skipping email notification cron setup."
    # Remove any existing email-notify.sh cron job
    crontab -l 2>/dev/null | grep -v 'email-notify.sh' | crontab -
    echo "Removed any existing email notification cron jobs."
fi

# Closing messages
echo "Thank you for using the CWA-Ingest-Buddy setup!"
echo "------------------------------------------------"
echo "If you need to modify this info later, just rerun this script."
echo "Goodbye!"
echo
sleep 2

# End of first-run.sh
