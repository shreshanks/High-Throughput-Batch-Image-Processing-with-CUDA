
import os
import sys

input_dir = "input_data"
output_dir = "output_data"

files = [f for f in os.listdir(input_dir) if f.endswith('.ppm')]
if not files:
    print("FAIL: No input files found.")
    sys.exit(1)

processed_count = 0
for f in files:
    outfile = os.path.join(output_dir, f)
    if os.path.exists(outfile):
        processed_count += 1
        # Basic check: File should not be empty
        if os.path.getsize(outfile) == 0:
             print(f"FAIL: Output file {f} is empty.")
             sys.exit(1)

if processed_count == len(files):
    print(f"SUCCESS: Verified {processed_count} images processed.")
else:
    print(f"FAIL: Processed {processed_count}/{len(files)} images.")
    sys.exit(1)
