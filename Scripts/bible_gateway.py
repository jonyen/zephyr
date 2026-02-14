import json
import os
import sys
import shutil
import tempfile
from meaningless import JSONDownloader

# List of Bible books in canonical order. Note "Song Of Solomon" space is intentional to match scraper.
CANONICAL_BOOKS = ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", "1 Samuel",
                   "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
                   "Psalm", "Proverbs", "Ecclesiastes", "Song Of Solomon", "Isaiah", "Jeremiah", "Lamentations", "Ezekiel",
                   "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai",
                   "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians",
                   "2 Corinthians", "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians",
                   "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter",
                   "1 John", "2 John", "3 John", "Jude", "Revelation"]

def download_all_books(translation, temp_dir):
    """
    Downloads all books of the Bible for a given translation into a temporary directory.
    """
    downloader = JSONDownloader(translation=translation, show_passage_numbers=False, strip_excess_whitespace=True)
    total_books = len(CANONICAL_BOOKS)
    for i, book_name in enumerate(CANONICAL_BOOKS):
        print(f"\rDownloading: [{i + 1}/{total_books}] {book_name}...", end="", flush=True)
        output_path = os.path.join(temp_dir, f"{book_name}.json")
        if not downloader.download_book(book_name, output_path) == 1:
            print(f"\nError: Failed to download {book_name}.")
            return False
    print("\nDownload complete.")
    return True

def transform_and_save_books(temp_dir, final_dir):
    """
    Transforms each book from the temporary directory and saves it to the final destination.
    """
    print("Transforming and saving individual book files...")
    os.makedirs(final_dir, exist_ok=True)
    
    for book_name in CANONICAL_BOOKS:
        temp_file_path = os.path.join(temp_dir, f"{book_name}.json")
        if not os.path.exists(temp_file_path):
            print(f"Warning: Could not find downloaded file for {book_name}. Skipping.")
            continue
        
        try:
            with open(temp_file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                
            # Extract the actual book data, which is nested inside the raw download
            if "Info" in data:
                del data["Info"]
            book_data = next((data[key] for key in data if key != 'Info'), None)
            if not book_data:
                print(f"Warning: No valid book data found in {book_name}.json. Skipping.")
                continue

            # Transform the book data into the desired format
            book_chapters_list = []
            sorted_chapter_nums = sorted(book_data.keys(), key=int)
            for chap_num_str in sorted_chapter_nums:
                verses_data = book_data[chap_num_str]
                chapter_verses_list = []
                
                sorted_verse_nums = sorted(verses_data.keys(), key=int)
                for verse_num_str in sorted_verse_nums:
                    verse_text = verses_data[verse_num_str].strip()
                    chapter_verses_list.append({'number': int(verse_num_str), 'text': verse_text})
                
                book_chapters_list.append({'number': int(chap_num_str), 'verses': chapter_verses_list})
            
            # The app's model uses "Song of Solomon", but the scraper uses "Song Of Solomon"
            book_display_name = "Song of Solomon" if book_name == "Song Of Solomon" else book_name
            final_book_obj = {'name': book_display_name, 'chapters': book_chapters_list}

            # Save the final transformed book object to its own file
            final_file_path = os.path.join(final_dir, f"{book_name.replace(' ', '')}.json")
            with open(final_file_path, 'w', encoding='utf-8') as out_file:
                # Use a compact encoding for the final JSON to save space
                json.dump(final_book_obj, out_file, separators=(',', ':'))

        except (json.JSONDecodeError, KeyError, TypeError) as e:
            print(f"\nError processing {book_name}: {e}")
            continue
    print("All books processed.")

def main():
    """
    Main function to control the download and transformation process.
    """
    if len(sys.argv) != 3:
        print("Usage: python3 bible_gateway.py <TRANSLATION> <output_directory_path>")
        print("Example: python3 bible_gateway.py ESV ESVBible/Resources/")
        sys.exit(1)

    translation = sys.argv[1].upper()
    output_dir = sys.argv[2]
    
    # Create a temporary directory to store intermediate files
    temp_dir = tempfile.mkdtemp(prefix="bible_download_")
    print(f"Using temporary directory: {temp_dir}")

    try:
        # Step 1: Download all books
        if not download_all_books(translation, temp_dir):
            sys.exit(1) # Exit if download fails

        # Step 2: Transform each book and save it to the final directory
        transform_and_save_books(temp_dir, output_dir)

        print("Process completed successfully.")

    finally:
        # Clean up the temporary directory
        print(f"Cleaning up temporary directory: {temp_dir}")
        shutil.rmtree(temp_dir)

if __name__ == '__main__':
    # The 'meaningless' library caps chapters/verses at 200 by default. This overrides that behaviour.
    from meaningless.utilities import common as meaningless_common
    def custom_get_capped_integer(number, min_value=1, max_value=200):
        return int(number)
    meaningless_common.get_capped_integer = custom_get_capped_integer
    main()
