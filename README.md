# 🚀 CWA-Ingest-Buddy

**CWA-Ingest-Buddy** is a helper script for Calibre-Web-Automated (CWA) that sorts, truncates file names, and deduplicates files before they are ingested. It ensures your original book files remain untouched while preparing them for seamless ingestion into your Calibre Web library. 📚✨

---

### 🔧 What it does

- Moves files from your “My-Books” folder to temporary folders to protect your originals. 📂➡️🗂️
- Checks for duplicate file names and matching hash values. 🔍✅
- Truncates and formats file names for better compatibility with CWA’s ingest workflow. ✂️📝
- Safely moves prepared files into the “ingest” folder for CWA to process. 🚚📥

This helps you maintain a clean and organized library while working within the limitations of the Calibre book processor.

---

### ❓ Why use it?

Many users want to keep their original book files intact, but CWA’s ingest feature deletes files from the ingest folder after processing. **CWA-Ingest-Buddy** solves this by creating a temporary staging area and ensuring no duplicates or messy filenames interfere with your ingestion process. 🛡️📚

---

### ⚙️ Usage

To download this repository to your local machine, navigate to the folder where you’d like to set it up and run:

```bash
git clone https://github.com/angelicadvocate/CWA-Ingest-Buddy.git
```

Then navigate to the internal `CWA-Ingest-Buddy` folder and be sure to read the `README.txt` there for setup instructions.

**NOTE:** Currently the deduplication check is not complete. The script in its current form checks for duplicate names and matching hash values. Additional functionality is planned to match file contents but has not been implemented yet. Feel free to use it in its current form if you wish to do so. 🛠️⌛

**NOTE:** Currently the notifications are handled by setting up an email with msmtp. If you answer yes to setup the email notifications in the setup process then msmtp will be installed automatically for you. If you do not wish to use this feature or have a dependency installed be sure to answer no in the first-run.sh setup script.

---

### 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/angelicadvocate/CWA-Ingest-Buddy/issues) or submit a pull request. Let's make this tool even better together! 💡🐙

---

### 📄 License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0). See the [LICENSE](LICENSE) file for details.

---
