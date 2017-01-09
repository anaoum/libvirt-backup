#!/bin/bash

BACKUP_HOST="$1"
BACKUP_FOLDER="$2"
MAX_BACKUPS="$3"

if [ -z "$BACKUP_HOST" -o -z "$BACKUP_FOLDER" ]; then
    >&2 echo "Usage: $(basename $0) <backup-host> <backup-folder> [max-backups]"
    exit 1
fi

if [ -z "$MAX_BACKUPS" ]; then
    MAX_BACKUPS=7
fi

virsh list --all --name | while read domain; do
    [ -z "$domain" ] && continue
    /usr/local/bin/vm-inc-backup.sh "$BACKUP_HOST" "$BACKUP_FOLDER" "$domain" "$MAX_BACKUPS"
    echo
done
