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

echo "🤗  Let's make a backup of your Paperless-NGX data!"
echo ""

echo -n "  📤  Starting export of paperless data..."
if docker exec paperless-ngx document_exporter /usr/src/paperless/export > /dev/null 2>&1; then
    echo " ✅"
else
    echo " ❌ Data export failed!" >&2
    exit 1
fi

echo -n "  📦  Creating gzipped tar archive..."
BACKUP_DEST=$(realpath "${BACKUP_DEST}")
cd "$(dirname "${BACKUP_SRC}")"
if tar -czf "${BACKUP_DEST}" "$(basename "${BACKUP_SRC}")"; then
    echo " ✅"
else
    echo " ❌ Archive creation failed!" >&2
    exit 1
fi
cd - > /dev/null 2>&1

echo -n "  🧹  Clearing export directory..."
rm -rf "${BACKUP_SRC}/*"
echo " ✅"

echo -n "  🔐  Encrypting the archive..."
if openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -salt -in "${BACKUP_DEST}" -out "${ENCRYPTED_DEST}" -k "${PASSWORD}"; then
    echo " ✅"
else
    echo " ❌ Encryption failed!" >&2
    exit 1
fi

# Function to copy backup to remote server using scp
copy_to_remote_scp() {
    local remote_dir=$1
    local remote_file="backup_$(date +${2}).tar.gz.enc"
    echo -n "  ☁️  Copying to ${remote_dir}..."

    # Ensure remote directory exists
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DEST}/${remote_dir}"

    # Copy the file
    if scp "${ENCRYPTED_DEST}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DEST}/${remote_dir}/${remote_file}" > /dev/null; then
        echo " ✅"
    else
        echo " ❌ Copy to ${remote_dir} failed!" >&2
        return 1
    fi
}

# Copy to respective remote directories
copy_to_remote_scp "daily" "%a" || exit 1
copy_to_remote_scp "monthly" "%-m" || exit 1
copy_to_remote_scp "yearly" "%Y" || exit 1

echo -n "  🧹  Cleaning up temporary archives..."
rm -f "${ENCRYPTED_DEST}" "${BACKUP_DEST}"
echo " ✅"

echo ""
echo "👌  Backup process completed successfully."
