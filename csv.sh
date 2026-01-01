#!/bin/bash

# Define the CSV file name
FILE="output.csv"

# Write headers to the CSV file
echo "Name, Age, City" > "$FILE"

# Add data to the CSV file
echo "John Doe, 28, New York" >> "$FILE"
echo "Jane Smith, 34, Los Angeles" >> "$FILE"
echo "Alice Johnson, 25, Chicago" >> "$FILE"

echo "Data has been written to $FILE"

