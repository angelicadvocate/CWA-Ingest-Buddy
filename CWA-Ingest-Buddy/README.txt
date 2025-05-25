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
- Do NOT move or modify files in the "CWA-Ingest-Buddy" folder.
- This folder should only contain your source book files.

----------------------------------------------------------------------------------------
Setting Up Your Ingest Folder

A script called "first-run.sh" will guide you through setting up your ingest folder path.  
If this is your first time running it, you can make it executable and run it in one of two ways:

- In your GUI file manager, right-click the script, make it executable, and then double-click it.  
- Or, from the terminal, navigate to the directory containing the script and run:

  chmod +x first-run.sh && ./first-run.sh

If you don’t know the full path to your ingest folder:

1. Open a terminal.
2. Navigate inside your ingest folder using the command:
   cd /path/to/your/ingest/folder
3. Run the command:
   pwd
4. Copy the output (this is the full path to your ingest folder).

When you run "first-run.sh", it will prompt you to enter this full path.

----------------------------------------------------------------------------------------
If you need more information, check the main project README at the root of this repository.

For issues and suggestions for this script, please see the main GitHub page at:  
https://github.com/angelicadvocate/CWA-Ingest-Buddy

Thank you for using CWA-Ingest-Buddy!
