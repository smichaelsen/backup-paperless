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
DAILY_BACKUP_DIR="./backups/daily"
MONTHLY_BACKUP_DIR="./backups/monthly"
YEARLY_BACKUP_DIR="./backups/yearly"

# Ensure backup directories exist
mkdir -p "${DAILY_BACKUP_DIR}"
mkdir -p "${MONTHLY_BACKUP_DIR}"
mkdir -p "${YEARLY_BACKUP_DIR}"

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

echo "Copying to daily backup folder..."
# Copy to daily backup folder with day of the week
cp "${ENCRYPTED_DEST}" "${DAILY_BACKUP_DIR}/backup_$(date +%a).tar.gz.enc"

echo "Copying to monthly backup folder..."
# Copy to monthly backup folder
cp "${ENCRYPTED_DEST}" "${MONTHLY_BACKUP_DIR}/backup_$(date +%-m).tar.gz.enc"

echo "Copying to yearly backup folder..."
# Copy to yearly backup folder
cp "${ENCRYPTED_DEST}" "${YEARLY_BACKUP_DIR}/backup_$(date +%Y).tar.gz.enc"

echo "Cleaning up temporary archives..."
rm -f "${ENCRYPTED_DEST}" "${BACKUP_DEST}"

echo "Syncing to the remote machine..."
# Sync the backup directory to the remote machine
if rsync -avz --delete "${DAILY_BACKUP_DIR}" "${MONTHLY_BACKUP_DIR}" "${YEARLY_BACKUP_DIR}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DEST}"; then
    echo "Sync to remote machine successful."
else
    echo "Sync to remote machine failed!" >&2
    exit 1
fi

echo "Backup process completed successfully."
