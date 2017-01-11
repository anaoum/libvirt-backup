#!/bin/bash

BACKUP_FOLDER="$1"

if [ -z "$BACKUP_FOLDER" ]; then
    >&2 echo "Usage: $(basename $0) <backup-folder>"
    exit 1
fi

virsh list --all --name | while IFS= read -r domain; do
    [ -z "$domain" ] && continue
    $(dirname "$0")/vm-backup.sh "$domain" "$BACKUP_FOLDER"
    echo
done
