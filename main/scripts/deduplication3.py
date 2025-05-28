import os
import sys
import shutil
import sqlite3
import hashlib
import subprocess
from rapidfuzz import fuzz

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "../../My-Books"))
CONFIG_FILE = os.path.abspath(os.path.join(SCRIPT_DIR, "../config.cfg"))
DB_PATH = os.path.abspath(os.path.join(SCRIPT_DIR, "../log-files/cwa-ingest-buddy.db"))
TEMP_DIR = os.path.join(SCRIPT_DIR, "../temp-books")
LOG_FILE = os.path.abspath(os.path.join(SCRIPT_DIR, "../log-files/failures.log"))
MAX_LENGTH = 150
FUZZY_THRESHOLD = 85

EXCLUDE_FILES = {".calnotes", ".stfolder", "metadata.db"}
EXCLUDE_EXTS = {".part", ".crdownload", ".tmp", ".txt", ".log", ".bak", ".old"}

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

def extract_sample_text(txt_file_path):
    sample_text = ""
    try:
        with open(txt_file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        lowered = content.lower()
        chapter_pos = lowered.find("chapter")
        intro_pos = lowered.find("introduction")
        prologue_pos = lowered.find("prologue")

        start_pos_candidates = [pos for pos in [chapter_pos, intro_pos, prologue_pos] if pos != -1]
        start_pos = min(start_pos_candidates) if start_pos_candidates else 0

        sample_text = content[start_pos:start_pos + 1000].strip()

    except Exception as e:
        print(f"Failed to extract sample text: {e}")

    return sample_text

def extract_metadata(file_path):
    try:
        result = subprocess.run([
            "ebook-meta", file_path
        ], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        output = result.stdout

        title = ""
        author = ""
        for line in output.splitlines():
            if line.startswith("Title"):
                title = line.split(":", 1)[1].strip()
            elif line.startswith("Author(s)"):
                author = line.split(":", 1)[1].strip()
        return title, author
    except Exception as e:
        print(f"Failed to extract metadata: {e}")
        return "", ""

def convert_to_txt(source_file, output_txt):
    try:
        subprocess.run([
            "ebook-convert", source_file, output_txt
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception as e:
        print(f"Failed to convert {source_file} to text: {e}")
        return False

def fuzzy_match_text(cursor, new_sample_text, filename):
    cursor.execute("SELECT original_filename, sample_text FROM books WHERE sample_text IS NOT NULL")
    matches = []
    for row in cursor.fetchall():
        other_file, other_text = row
        if not other_text:
            continue
        similarity = fuzz.partial_ratio(new_sample_text, other_text)
        if similarity >= FUZZY_THRESHOLD:
            matches.append((other_file, similarity))

    if matches:
        with open(LOG_FILE, 'a') as logf:
            for match_file, score in matches:
                logf.write(f"{filename} - potential duplicate found (fuzzy match with {match_file}, score={score})\n")
        print(f"Potential duplicate(s) found for {filename}: {matches}")

def main():
    DEST_DIR = get_ingest_path()
    os.makedirs(DEST_DIR, exist_ok=True)
    os.makedirs(TEMP_DIR, exist_ok=True)

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

        # Check DB for existing file by filename or hash
        cursor.execute("""
            SELECT 1 FROM books WHERE 
            original_filename = ? OR 
            truncated_filename = ? OR 
            filehash = ?
        """, (filename, filename, file_hash))
        if cursor.fetchone():
            print(f"Skipping already processed file: {filename}")
            continue

        # Extract metadata
        metadata_title, metadata_author = extract_metadata(full_path)

        # Check for duplicate by metadata
        if metadata_title and metadata_author:
            cursor.execute("""
                SELECT original_filename FROM books 
                WHERE metadata_title = ? AND metadata_author = ?
            """, (metadata_title, metadata_author))
            if cursor.fetchone():
                print(f"Duplicate found by metadata for {filename} ({metadata_title} by {metadata_author}). Skipping.")
                with open(LOG_FILE, 'a') as logf:
                    logf.write(f"{filename} - definite duplicate by metadata match\n")
                continue

        # Truncate filename if needed
        truncated = truncate_filename(filename)
        dest_path = os.path.join(DEST_DIR, truncated)

        # Convert to text
        temp_txt_path = os.path.join(TEMP_DIR, f"{os.path.splitext(filename)[0]}.txt")
        if not convert_to_txt(full_path, temp_txt_path):
            with open(LOG_FILE, 'a') as logf:
                logf.write(f"{filename} - conversion failed\n")
            continue

        # Extract sample text
        sample_text = extract_sample_text(temp_txt_path)

        # Fuzzy match as fallback
        fuzzy_match_text(cursor, sample_text, filename)

        try:
            shutil.copy2(full_path, dest_path)
            print(f"Copied to ingest: {truncated}")

            # Insert into DB
            cursor.execute("""
                INSERT INTO books (original_filename, truncated_filename, filehash, sample_text, metadata_title, metadata_author)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (filename, truncated, file_hash, sample_text, metadata_title, metadata_author))
            conn.commit()
        except Exception as e:
            print(f"Failed to copy {filename}: {e}")
            with open(LOG_FILE, 'a') as logf:
                logf.write(f"{filename} - copy failed: {e}\n")

        # Clean up temporary text file
        if os.path.exists(temp_txt_path):
            os.remove(temp_txt_path)

    # Clean up temp directory
    if os.path.exists(TEMP_DIR):
        shutil.rmtree(TEMP_DIR)

    conn.close()

if __name__ == "__main__":
    main()
