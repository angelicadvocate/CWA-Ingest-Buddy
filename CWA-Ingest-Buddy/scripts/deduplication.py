import os
import sys
import shutil
import sqlite3
import hashlib
import configparser

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "../../My-Books"))
CONFIG_FILE = os.path.abspath(os.path.join(SCRIPT_DIR, "../config.cfg"))
DB_PATH = os.path.abspath(os.path.join(SCRIPT_DIR, "../log-files/cwa-ingest-buddy.db"))
MAX_LENGTH = 150

EXCLUDE_FILES = {".calnotes", ".stfolder", "metadata.db"}
EXCLUDE_EXTS = {".part", ".crdownload", ".tmp"}

def get_ingest_path():
    with open(CONFIG_FILE, 'r') as f:
        for line in f:
            if line.startswith('INGEST_PATH='):
                path = line.strip().split('=', 1)[1].strip().strip('"').strip("'")
                return os.path.abspath(path)
    raise ValueError("INGEST_PATH not found in config.cfg")

def connect_db():
    if not os.path.isfile(DB_PATH):
        print(f"Error: Database file not found at {DB_PATH}. Please make sure it exists.")
        sys.exit(1)
    return sqlite3.connect(DB_PATH)

def truncate_filename(filename):
    if '.' not in filename:
        return filename
    base, ext = filename.rsplit('.', 1)
    max_base_len = MAX_LENGTH - len(ext) - 1
    if len(base) > max_base_len:
        return base[:max_base_len] + '.' + ext
    return filename

def file_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()

def should_skip(filename):
    if filename in EXCLUDE_FILES:
        return True
    for ext in EXCLUDE_EXTS:
        if filename.endswith(ext):
            return True
    return False

def main():
    DEST_DIR = get_ingest_path()
    os.makedirs(DEST_DIR, exist_ok=True)
    conn = connect_db()
    cursor = conn.cursor()

    files = [f for f in os.listdir(SOURCE_DIR) if os.path.isfile(os.path.join(SOURCE_DIR, f))]
    if not files:
        print(f"No files to process in {SOURCE_DIR}")
        return

    for filename in files:
        if should_skip(filename):
            print(f"Skipping {filename}")
            continue

        full_path = os.path.join(SOURCE_DIR, filename)
        file_hash = file_sha256(full_path)

        # Check DB for existing file (by name or hash)
        cursor.execute("""
            SELECT 1 FROM books WHERE 
            original_filename = ? OR 
            truncated_filename = ? OR 
            filehash = ?
        """, (filename, filename, file_hash))
        if cursor.fetchone():
            print(f"Skipping already processed file: {filename}")
            continue

        # Truncate filename if needed
        truncated = truncate_filename(filename)
        dest_path = os.path.join(DEST_DIR, truncated)

        try:
            shutil.copy2(full_path, dest_path)
            print(f"Copied to ingest: {truncated}")

            # Insert into DB
            cursor.execute("""
                INSERT INTO books (original_filename, truncated_filename, filehash)
                VALUES (?, ?, ?)
            """, (filename, truncated, file_hash))
            conn.commit()
        except Exception as e:
            print(f"Failed to copy {filename}: {e}")

    conn.close()

if __name__ == "__main__":
    main()
