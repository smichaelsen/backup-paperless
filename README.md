# Backup your paperless installation

This assumes you have a paperless-ngx installation running as docker container called `paperless-ngx`.

The script will perform an export, zip and encrypt it and store 7 daily, 12 monthly and unlimited yearly backups on a specified remote server.

## Setup

* Copy the `.env.dist` to `.env`.
* Set a password (you will need it to decrypt the backups later).
* Set remote server credentials
* Make sure your machine has SSH access to the remote machine.
* Adjust `EXPORT_MOUNT` to where the export folder of your paperless is mounted.

## Perform backup

`./backup_paperless.sh`

![Screenshot 2023-12-11 at 16 39 31](https://github.com/smichaelsen/backup-paperless/assets/912435/f35ea425-646c-4fbc-bee8-ad024df2d8f6)
