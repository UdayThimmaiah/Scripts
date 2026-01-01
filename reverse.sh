#!/bin/bash
echo "Enter the data: "
read a
data=$(echo "$a" | rev)
echo "$data"

