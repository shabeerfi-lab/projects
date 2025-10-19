import os
from faker import Faker
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, PageBreak
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib import colors
from tqdm import tqdm

# --- Configuration ---
# Set the desired name for your output test PDF file
FILE_NAME = 'large_test_document.pdf'
# Set the number of pages you want to generate
NUM_PAGES = 500
# Set the number of data rows per table on each page
NUM_ROWS_PER_TABLE = 25

def create_test_pdf(file_path, num_pages, rows_per_page):
    """
    Generates a native PDF with a table of fake data on each page.

    Args:
        file_path (str): The path to save the generated PDF.
        num_pages (int): The total number of pages to create.
        rows_per_page (int): The number of rows in the table on each page.
    """
    print(f"Starting PDF generation for {num_pages} pages...")
    
    # Initialize Faker to generate mock data
    fake = Faker()
    
    # Setup the ReportLab document template
    doc = SimpleDocTemplate(file_path, pagesize=letter)
    styles = getSampleStyleSheet()
    elements = []
    
    # Table header
    table_header = ['ID', 'Name', 'Email Address', 'Company', 'Phone Number']

    # Use tqdm for a progress bar
    for page_num in tqdm(range(1, num_pages + 1), desc="Generating Pages"):
        # Add a title for the page
        title = Paragraph(f"Customer Data - Page {page_num}", styles['h2'])
        elements.append(title)
        elements.append(Spacer(1, 12)) # Add a little space

        # Generate fake data for the table
        page_data = [table_header]
        for i in range(rows_per_page):
            row_id = (page_num - 1) * rows_per_page + i + 1
            page_data.append([
                str(row_id),
                fake.name(),
                fake.email(),
                fake.company(),
                fake.phone_number()
            ])
        
        # Create the table object
        table = Table(page_data)
        
        # Add styling to the table (grid lines, header color, etc.)
        style = TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
            ('GRID', (0, 0), (-1, -1), 1, colors.black)
        ])
        table.setStyle(style)
        
        elements.append(table)
        elements.append(PageBreak()) # End the page

    # Build the PDF
    try:
        doc.build(elements)
        print(f"\n✅ Successfully created PDF: {file_path}")
        print(f"   - Pages: {num_pages}")
        print(f"   - Total Rows: {num_pages * rows_per_page}")
    except Exception as e:
        print(f"An error occurred during PDF generation: {e}")

# --- Run the generator ---
if __name__ == '__main__':
    create_test_pdf(FILE_NAME, NUM_PAGES, NUM_ROWS_PER_TABLE)