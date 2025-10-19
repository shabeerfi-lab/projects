import pdfplumber
import pandas as pd
from tqdm import tqdm
import os

# --- Configuration ---
PDF_PATH = r'C:\Users\SFISMAIL\Desktop\Testing latest files\large_test_document.pdf'
CSV_PATH = 'output_data.csv'

def convert_pdf_to_csv(pdf_path, csv_path):
    """
    Extracts tables from all pages of a PDF and saves them to a single CSV file,
    correctly handling a single header row.
    """
    if not os.path.exists(pdf_path):
        print(f"Error: The file '{pdf_path}' was not found.")
        return

    all_data_rows = []
    header = None
    
    print(f"Opening PDF: {pdf_path}")
    try:
        with pdfplumber.open(pdf_path) as pdf:
            page_count = len(pdf.pages)
            print(f"Found {page_count} pages. Starting extraction...")
            
            # Use tqdm for a progress bar
            for page in tqdm(pdf.pages, desc="Processing Pages"):
                tables = page.extract_tables()
                if not tables:
                    continue # Skip pages with no tables

                for table in tables:
                    # If we haven't found a header yet, grab it from the first table
                    if header is None:
                        header = table[0]
                        # Add the data rows from this first table
                        all_data_rows.extend(table[1:])
                    else:
                        # For all subsequent tables, just add the data rows, skipping the header
                        all_data_rows.extend(table[1:])
    
        if header is None or not all_data_rows:
            print("No tables with a header and data rows were found in the PDF.")
            return

        # Create a pandas DataFrame using the single header and all collected data rows
        df = pd.DataFrame(all_data_rows, columns=header)
        
        print(f"\nExtraction complete. Saving data to {csv_path}...")
        df.to_csv(csv_path, index=False, encoding='utf-8')
        
        print(f"✅ Successfully converted {len(df)} rows to {csv_path}")

    except Exception as e:
        print(f"An error occurred: {e}")

# --- Run the conversion ---
if __name__ == '__main__':
    convert_pdf_to_csv(PDF_PATH, CSV_PATH)