#!/bin/bash

set -e

source "$(dirname "$0")/vm-backup-functions.sh"

BACKUP_HOST="$1"
BACKUP_FOLDER="$2"
DOMAIN="$3"
MAX_BACKUPS="$4"

if [ -z "$BACKUP_HOST" -o -z "$BACKUP_FOLDER" -o -z "$DOMAIN" ]; then
    >&2 echo "Usage: $(basename $0) <backup-host> <backup-folder> <domain> [max-backups]"
    exit 1
fi
if [ -z "$MAX_BACKUPS" ]; then
    MAX_BACKUPS=7
fi

verify_domain_exists "$DOMAIN"
verify_domain_running "$DOMAIN"

echo "Beginning backup for $DOMAIN."

BACKUP_LOCATION="$BACKUP_FOLDER/$DOMAIN"
ssh -n "$BACKUP_HOST" mkdir -p "$BACKUP_LOCATION"

get_disks "$DOMAIN" | while read disk; do
    if has_backing "$disk"; then
        LAST_BACKUP="$BACKUP_LOCATION/$(basename "$disk")"
        if ssh -n "$BACKUP_HOST" [ ! -e "$LAST_BACKUP" ]; then
            >&2 echo "$LAST_BACKUP does not exist on $BACKUP_HOST."
            >&2 echo "Performing a full backup for $(basename "$disk"). There may be old files left on $BACKUP_HOST."
            >&2 echo "Committing $disk to base."
            virsh blockcommit "$DOMAIN" "$disk" --pivot > /dev/null
            delete_snapshot_chain "$disk"
        fi
    fi
done

QUIESCE=""
if virsh domfsthaw "$DOMAIN" >/dev/null 2>&1; then
    echo "QEMU guest agent detected. Using --quiesce."
    QUIESCE="--quiesce"
fi
DISKSPEC=""
get_disks "$DOMAIN" | while read disk; do
    DISKSPEC="$DISKSPEC --diskspec $disk,snapshot=external"
done
virsh snapshot-create-as --domain "$DOMAIN" --name "S$(date +%Y%m%d%H%M%S)" --no-metadata --atomic $QUIESCE --disk-only $DISKSPEC

get_disks "$DOMAIN" | while read disk; do
    BACKUP_SRC="$(get_backing "$disk")"
    BACKUP_DST="$BACKUP_LOCATION/$(basename "$disk")"
    echo "Copying "$BACKUP_SRC" to "$BACKUP_HOST:$BACKUP_DST"."
    rsync --sparse "$BACKUP_SRC" "$BACKUP_HOST:$BACKUP_DST"
    if has_backing "$BACKUP_SRC"; then
        LAST_BACKUP="$BACKUP_LOCATION/$(basename "$BACKUP_SRC")"
        echo "Rebasing "$BACKUP_DST" to use "$LAST_BACKUP"."
        ssh -n "$BACKUP_HOST" qemu-img rebase -u -b "$LAST_BACKUP" "$BACKUP_DST"
        echo "Cleaning up backing chain for "$disk" by committing "$BACKUP_SRC" to base."
        virsh blockcommit "$DOMAIN" "$disk" --top "$BACKUP_SRC" --wait > /dev/null
        delete_snapshot_chain "$BACKUP_SRC"
    fi
    ssh -n "$BACKUP_HOST" /usr/local/bin/vm-consolidate-backups.sh "$BACKUP_DST" "$MAX_BACKUPS"
done

echo "Completed backup for $DOMAIN."
