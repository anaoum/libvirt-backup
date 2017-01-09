#!/bin/bash

# TODOs:
#  Test on domains with spaces.
#  Test on images with spaces.
#  Test with other snapshots.
#  Test on raw images.

set -e

source "$(dirname "$0")/vm-backup-functions.sh"

BACKUP_FOLDER="$1"
DOMAIN="$2"

if [ -z "$BACKUP_FOLDER" -o -z "$DOMAIN" ]; then
    >&2 echo "Usage: $(basename $0) <backup-folder> <domain>"
    exit 1
fi

if ! virsh dominfo "$DOMAIN" > /dev/null 2>&1; then
    >&2 echo "Domain '$DOMAIN' does not exist. Aborting."
    exit 2
fi

if ! virsh dominfo "$DOMAIN" | grep -q 'State:\s*running'; then
    >&2 echo "Domain '$DOMAIN' is not running. Must be running to backup. Skipping..."
    exit 3
fi

echo "Beginning backup for $DOMAIN."

BACKUP_LOCATION="$BACKUP_FOLDER/$DOMAIN"
mkdir -p "$BACKUP_LOCATION"

QUIESCE=""
if virsh domfsthaw "$DOMAIN" >/dev/null 2>&1; then
    echo "QEMU guest agent detected. Using --quiesce."
    QUIESCE="--quiesce"
fi
DISKSPEC=""
get_disks "$DOMAIN" | while read disk; do
    DISKSPEC="$DISKSPEC --diskspec $disk,snapshot=external"
done
virsh snapshot-create-as --domain "$DOMAIN" --name "$(date +%Y%m%d%H%M%S).qcow2" --no-metadata --atomic $QUIESCE --disk-only $DISKSPEC

get_disks "$DOMAIN" | while read disk; do
    BACKUP_SRC="$(get_backing "$disk")"
    BACKUP_DST="$BACKUP_LOCATION/$(basename "$disk")"
    echo "Copying $BACKUP_SRC to $BACKUP_DST."
    qemu-img convert -O qcow2 "$BACKUP_SRC" "$BACKUP_DST"
    echo "Committing from $disk down to $BACKUP_SRC."
    virsh blockcommit "$DOMAIN" "$disk" --base "$BACKUP_SRC" --pivot > /dev/null
    echo "Deleting temporary snapshot $disk."
    rm -f "$disk"
done

echo "Completed backup for $DOMAIN."
