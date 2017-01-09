#!/bin/bash

set -e

source /usr/local/bin/vm-backup-functions.sh

LAST_BACKUP="$1"
MAX_BACKUPS="$2"

if [ -z "$LAST_BACKUP" -o -z "$MAX_BACKUPS" ]; then
    >&2 echo "Usage: $(basename $0) <last-backup> <max-backups>"
    exit 1
fi

BACKUP_CHAIN_LENGTH="$(get_backing_chain_length "$LAST_BACKUP")"

echo "Length of backing chain for "$LAST_BACKUP" is "$BACKUP_CHAIN_LENGTH"."

while [ "$BACKUP_CHAIN_LENGTH" -gt "$MAX_BACKUPS" ]; do
    LAST="$(get_base "$LAST_BACKUP")"
    SECOND_LAST="$(get_backing_chain "$LAST_BACKUP" | tail -2 | head -1)"
    echo "Committing "$SECOND_LAST" into "$LAST"."
    qemu-img commit "$SECOND_LAST" -d -b "$LAST"
    echo "Moving "$LAST" to "$SECOND_LAST"."
    mv "$LAST" "$SECOND_LAST"
    BACKUP_CHAIN_LENGTH="$(get_backing_chain_length "$LAST_BACKUP")"
    echo "Length of backing chain for "$LAST_BACKUP" is now "$BACKUP_CHAIN_LENGTH"."
done
