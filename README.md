# Backup your paperless installation

This assumes you have a paperless-ngx installation running as docker container called `paperless-ngx`.

The script will perform an export, zip and encrypt it, store 7 daily, 12 monthly and unlimited yearly backups and the rsync the backups to a specified remote server.

## Setup

* Copy the `.env.dist` to `.env`.
* Set a password (you will need it to decrypt the backups later).
* Set remote server credentials
* Make sure your machine has SSH access to the remote machine.
* Adjust `EXPORT_MOUNT` to where the export folder of your paperless is mounted.

## Perform backup

`./backup_paperless.sh`
