#!/bin/bash

if [ -f .env ]; then
  source .env
fi

# Abort if any required environment variables are not set
: ${BACKUP_PASSWORD:?}
: ${BACKUP_REMOTE_USER:?}
: ${BACKUP_REMOTE_HOST:?}
: ${BACKUP_REMOTE_DEST:?}

PASSWORD="${BACKUP_PASSWORD}"
REMOTE_USER="${BACKUP_REMOTE_USER}"
REMOTE_HOST="${BACKUP_REMOTE_HOST}"
REMOTE_DEST="${BACKUP_REMOTE_DEST}"

BACKUP_SRC="/mnt/user/appdata/paperless-ngx/export"
BACKUP_DEST="backup.tar.gz"
ENCRYPTED_DEST="backup.tar.gz.enc"

echo "Starting export of paperless data..."
# Export data from paperless
if docker exec paperless-ngx document_exporter /usr/src/paperless/export; then
    echo "Data export successful."
else
    echo "Data export failed!" >&2
    exit 1
fi

echo "Creating gzipped tar archive..."
# Create a gzipped tar archive
if tar -czf "${BACKUP_DEST}" "${BACKUP_SRC}"; then
    echo "Archive created successfully."
else
    echo "Archive creation failed!" >&2
    exit 1
fi

echo "Encrypting the archive..."
# Encrypt the archive
if openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -salt -in "${BACKUP_DEST}" -out "${ENCRYPTED_DEST}" -k "${PASSWORD}"; then
    echo "Encryption successful."
else
    echo "Encryption failed!" >&2
    exit 1
fi

# Function to copy backup to remote server using scp
copy_to_remote_scp() {
    local remote_dir=$1
    local remote_file="backup_$(date +${2}).tar.gz.enc"
    echo "Copying to ${remote_dir}..."

    # Ensure remote directory exists
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DEST}/${remote_dir}"

    # Copy the file
    if scp "${ENCRYPTED_DEST}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DEST}/${remote_dir}/${remote_file}"; then
        echo "Copy to ${remote_dir} successful."
    else
        echo "Copy to ${remote_dir} failed!" >&2
        return 1
    fi
}

# Copy to respective remote directories
copy_to_remote_scp "daily" "%a" || exit 1
copy_to_remote_scp "monthly" "%-m" || exit 1
copy_to_remote_scp "yearly" "%Y" || exit 1

echo "Cleaning up temporary archives..."
rm -f "${ENCRYPTED_DEST}" "${BACKUP_DEST}"

echo "Backup process completed successfully."
