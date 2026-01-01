#!/bin/bash

echo "Enter the file name: "
read filename

if [ -f "$filename" ]; then
        word_count=$(wc -w < "$filename")

	        line_count=$(wc -l < "$filename")

		        char_count=$(wc -m < "$filename")

			        echo "Number of words in this file: $word_count"
				    echo "Number of lines in this file: $line_count"
				        echo "Number of characters in this file: $char_count"
					else
					    echo "The file does not exist."
					    fi

