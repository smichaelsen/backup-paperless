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
: ${BACKUP_PASSWORD:?}
: ${BACKUP_REMOTE_USER:?}
: ${BACKUP_REMOTE_HOST:?}
: ${BACKUP_REMOTE_DEST:?}
: ${EXPORT_MOUNT:?}
: ${PAPERLESS_CONTAINER_NAME:?}

BACKUP_DEST="backup.tar.gz"
ENCRYPTED_DEST="backup.tar.gz.enc"

echo "🤗  Let's make a backup of your Paperless-NGX data!"
echo ""

echo -n "  📤  Exporting paperless data..."
if docker exec "${PAPERLESS_CONTAINER_NAME}" document_exporter /usr/src/paperless/export > /dev/null 2>&1; then
    echo " ✅"
else
    echo " ❌ Data export failed!" >&2
    exit 1
fi

echo -n "  📦  Packing the archive..."
BACKUP_DEST=$(realpath "${BACKUP_DEST}")
cd "$(dirname "${EXPORT_MOUNT}")"
if tar -czf "${BACKUP_DEST}" "$(basename "${EXPORT_MOUNT}")"; then
    echo " ✅"
else
    echo " ❌ Archive creation failed!" >&2
    exit 1
fi
cd - > /dev/null 2>&1

echo -n "  🧹  Clearing export directory..."
if [[ -d "${EXPORT_MOUNT}" && -f "${EXPORT_MOUNT}/manifest.json" ]]; then
    find "${EXPORT_MOUNT}" -type f -exec rm {} \;
    echo " ✅"
else
    echo " ⚠️  Warning: Export directory not found or not a directory."
fi

echo -n "  🔐  Encrypting the archive..."
if openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -salt -in "${BACKUP_DEST}" -out "${ENCRYPTED_DEST}" -k "${BACKUP_PASSWORD}"; then
    rm -f "${BACKUP_DEST}"
    echo " ✅"
else
    echo " ❌ Encryption failed!" >&2
    exit 1
fi

copy_to_remote_scp() {
    local remote_file="backup.tar.gz.enc"
    echo -n "  ☁️  Copying to remote ..."

    # Ensure remote directory exists
    ssh "${BACKUP_REMOTE_USER}@${BACKUP_REMOTE_HOST}" "mkdir -p ${BACKUP_REMOTE_DEST}"

    # Copy the file
    if scp "${ENCRYPTED_DEST}" "${BACKUP_REMOTE_USER}@${BACKUP_REMOTE_HOST}:${BACKUP_REMOTE_DEST}/${remote_file}" > /dev/null; then
        echo " ✅"
    else
        echo " ❌ Copy to ${remote_dir} failed!" >&2
        return 1
    fi
}

copy_to_remote_scp || exit 1

echo -n "  🧹  Cleaning up local archive..."
rm -f "${ENCRYPTED_DEST}"
echo " ✅"

echo ""
echo "👌  Backup process completed successfully."
