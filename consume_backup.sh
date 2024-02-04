#!/bin/bash

# Determine the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Load environment variables from .env file in the script's directory
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
    echo "Error: .env file not found in ${SCRIPT_DIR}."
    exit 1
fi
source "${SCRIPT_DIR}/.env"

# Abort if any required environment variables are not set
: ${CONSUME_FOLDER:?}
: ${TARGET_FOLDER:?}

echo "🤗  Let's check for new backup archives to consume!"
echo ""

# Function to copy files from CONSUME_FOLDER to a subfolder of TARGET_FOLDER with a prefix
copy_files() {
    local subfolder=$1
    local prefix=$2

    # Path to the subfolder
    local subfolder_dir="${TARGET_FOLDER}/${subfolder}"

    # Create subfolder if it doesn't exist
    mkdir -p "$subfolder_dir"

    # Loop through each file in the CONSUME_FOLDER
    for file in "$CONSUME_FOLDER"/*; do
        # Skip if it's a directory
        [ -d "$file" ] && continue

        # Get the base name of the file
        local filename=$(basename "$file")

        # Construct the target file path with prefix
        local target_file="${subfolder_dir}/${prefix}_${filename}"

        # Copy the file to the target directory with prefix
        echo -n "  ➡️  Copying $file to $target_file..."
        cp "$file" "$target_file"

        # Check if copy was successful
        if [ $? -eq 0 ]; then
            echo "  ✅"
        else
            echo "  ❌  Copy failed. File $file was not copied to $target_file."
            return 1
        fi
    done

    return 0
}

# Function to remove files from CONSUME_FOLDER after successful copy
remove_source_files() {
    echo -n "  🧹  Cleaning up consumption folder..."
    for file in "$CONSUME_FOLDER"/*; do
        # Skip if it's a directory
        [ -d "$file" ] && continue

        # Remove the file from the source directory
        rm "$file"
    done

    echo " ✅"
}

# Get the day of the week, month, and year
DAY_OF_WEEK=$(date +%a)
MONTH=$(date +%m)
YEAR=$(date +%Y)

# Check if the source directory is not empty
if [ "$(ls -A "$CONSUME_FOLDER")" ]; then
    echo "  📥  Files found in $CONSUME_FOLDER."

    # Copy files to the daily, monthly, and yearly subfolders
    if copy_files "daily" "$DAY_OF_WEEK" && copy_files "monthly" "$MONTH" && copy_files "yearly" "$YEAR"; then
        # If all copies were successful, remove the files from the source directory
        remove_source_files
    else
        echo "  ❌  Some files were not copied successfully. Check the output for details."
    fi
else
    echo "  📭  No files to backup. $CONSUME_FOLDER is empty."
fi

echo "Backup process completed."
