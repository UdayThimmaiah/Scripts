#!/bin/bash

# Prompt the user for the file name
echo "Enter the file name:"
read filename

# Search for the file in the entire system starting from the root directory
found_file=$(find / -type f -name "$filename" 2>/dev/null)

# Check if the file was found
if [[ -n "$found_file" ]]; then
    echo "File found: $found_file"
        # Read and display the content of the found file
	    cat "$found_file"
	    else
	        # If the file doesn't exist, show an error
		    echo "File '$filename' not found in the system."
		    fi

