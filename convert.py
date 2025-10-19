from pdf2docx import Converter

# Specify the path to your PDF file
pdf_file = r'C:\Users\SFISMAIL\Desktop\Testing latest files\SWIG UK ECO Claim Form.pdf'

# Specify the path for the output Word file
docx_file = r'C:\Users\SFISMAIL\Desktop\Testing latest files\SWIG UK ECO Claim Form.docx'

# Create a Converter object
cv = Converter(pdf_file)

# Perform the conversion
# You can specify a range of pages using start and end arguments, e.g., pages=[0,1]
cv.convert(docx_file, start=0, end=None)

# Close the converter object
cv.close()

print("Conversion complete!")