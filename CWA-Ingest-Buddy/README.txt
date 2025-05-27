=======================================================================================
                                CWA-Ingest-Buddy
=======================================================================================

"My-Books" Folder

This folder is where you place your original book files.  
You’re free to download files directly into this folder,  
set it up to sync from Syncthing, connect to an SFTP server,  
clone from Google Drive, or use whichever method you prefer to  
transfer books to your Calibre-Web-Automated instance.

IMPORTANT:
- Do NOT move or modify files or directories in the "CWA-Ingest-Buddy" folder.
- If you set up alerts, you should receive notifications if a file gets hung during ingest.
- After receiving a notification, delete only the file(s) listed in the email and try again.

----------------------------------------------------------------------------------------
Setting Up Your Ingest Folder:

A script called "first-run.sh" will guide you through setting up your ingest folder path.  
If this is your first time running it, you can make it executable and run it by:

- From the terminal, navigate to the directory containing the script and run:

  chmod +x first-run.sh && sudo ./first-run.sh

If you don’t know the full path to your ingest folder:

1. Open a terminal.
2. Navigate inside your ingest folder using the command:

   cd /path/to/your/ingest/folder

3. Run the command:

   pwd

4. Copy the output (this is the full path to your ingest folder).

When you run "first-run.sh", it will prompt you to enter this full path.

Note:  
If you choose to set up email alerts during this process, the SMTP client (msmtp) will be  
installed automatically as a package dependency.

Important notes for Gmail users:  
- Gmail requires the use of **App Passwords** instead of your regular account password for SMTP access.  
- You can create an app password here:  
  https://myaccount.google.com/apppasswords  
- Using your standard Gmail password will cause authentication errors and prevent notifications from sending.

Troubleshooting:  
- If you do not receive email notifications, double-check your SMTP settings and confirm you are using an app password if applicable.  
- Check the log files located in the `log-files` directory for msmtp debug information.

----------------------------------------------------------------------------------------
Disabling Email Notifications:

If you previously set up email notifications but want to disable them later, follow these steps:

1. Run the setup script again:

   sudo ./first-run.sh

2. When prompted to set up email notifications, answer no.  
   This will clear all the saved email configuration entries.

3. When prompted to set up the email notifications cron job, answer no.
   This will remove the crontab entry from your machine.

By doing this, email alerts will be fully disabled and the related cron job will no longer run.

----------------------------------------------------------------------------------------
If you need more information, check the main project README at the root of this repository.

For issues and suggestions for this script, please see the main GitHub page at:  
https://github.com/angelicadvocate/CWA-Ingest-Buddy

Thank you for using CWA-Ingest-Buddy!
