#!/bin/bash

set -e

DOMAIN="$1"
BACKUP_FOLDER="$2"
BACKUP_HOST="$3"
MAX_BACKUPS="$4"

if [ -z "$DOMAIN" -o -z "$BACKUP_FOLDER" -o -z "$BACKUP_HOST" ]; then
    >&2 echo "Usage: $(basename $0) <domain> <backup-folder> <backup-host> [max-backups]"
    exit 1
fi
if [ -z "$MAX_BACKUPS" ]; then
    MAX_BACKUPS=7
fi

echo "Beginning incremental backup for $DOMAIN at $(date '+%Y-%m-%d %H:%M:%S')."

REMOTE_BACKUP_LOCATION="$BACKUP_FOLDER/$DOMAIN"
echo "Creating $REMOTE_BACKUP_LOCATION on $BACKUP_HOST."
ssh -n "$BACKUP_HOST" mkdir -p "$REMOTE_BACKUP_LOCATION"

SNAPSHOT_NAME="$(date +%Y%m%d%H%M%S)"
LOCAL_BACKUP_DIR="$(mktemp --tmpdir -d)"
echo "Performing a local full backup to $LOCAL_BACKUP_DIR:"
$(dirname "$0")/vm-backup.sh "$DOMAIN" "$LOCAL_BACKUP_DIR" "$SNAPSHOT_NAME" | sed 's/^/  /'

find "$LOCAL_BACKUP_DIR/$DOMAIN/" -type f -name "*.$SNAPSHOT_NAME.qcow2" | while IFS= read -r BACKUP_SRC; do

    echo "Backup source is $BACKUP_SRC."

    BACKUP_FILENAME="$(basename "$BACKUP_SRC")"
    TARGET="${BACKUP_FILENAME/%.$SNAPSHOT_NAME.qcow2/}"
    BACKUP_FINDER=".*/$TARGET.[0-9]{14}.qcow2"

    BACKUP_DST="$REMOTE_BACKUP_LOCATION/$BACKUP_FILENAME"
    echo "Backup destination is $BACKUP_HOST:$BACKUP_DST."

    LAST_BACKUP="$(ssh -n "$BACKUP_HOST" find "$REMOTE_BACKUP_LOCATION" -regextype posix-extended -regex "$BACKUP_FINDER" | sort -n | tail -1)"

    if [ -z "$LAST_BACKUP" ]; then
        echo "There are no previous backups for $DOMAIN:/dev/$TARGET on $BACKUP_HOST."

        echo "Syncing from $BACKUP_SRC to $BACKUP_HOST:$BACKUP_DST."
        rsync --info=progress2 --sparse --chmod=0400 "$BACKUP_SRC" "$BACKUP_HOST:$BACKUP_DST"
    else
        echo "Last backup for $DOMAIN:/dev/$TARGET on $BACKUP_HOST is $LAST_BACKUP."

        ssh "$BACKUP_HOST" /bin/bash <<EOF
echo "Connected to $BACKUP_HOST:"
echo "  copying last backup to $BACKUP_DST."
qemu-img convert -p -O qcow2 "$LAST_BACKUP" "$BACKUP_DST"
EOF

        echo "Syncing from $BACKUP_SRC to $BACKUP_HOST:$BACKUP_DST."
        rsync --info=progress2 --inplace "$BACKUP_SRC" "$BACKUP_HOST:$BACKUP_DST"

        ssh "$BACKUP_HOST" /bin/bash <<EOF
echo "Connected to $BACKUP_HOST:"
echo "  changing permissions of $BACKUP_DST to 0400."
chmod 0400 "$BACKUP_DST"
LAST_BACKUP_INCREMENTAL="\$(mktemp --tmpdir "\$(basename "$LAST_BACKUP")-incremental-XXXXX")"
echo "  creating \$LAST_BACKUP_INCREMENTAL based on last backup."
qemu-img create -q -f qcow2 -b "$LAST_BACKUP" "\$LAST_BACKUP_INCREMENTAL"
echo "  rebasing \$LAST_BACKUP_INCREMENTAL on to current backup."
qemu-img rebase -p -f qcow2 -b "$BACKUP_DST" "\$LAST_BACKUP_INCREMENTAL"
echo "  changing permissions of \$LAST_BACKUP_INCREMENTAL to 0400."
chmod 0400 "\$LAST_BACKUP_INCREMENTAL"
echo "  replacing last backup with \$LAST_BACKUP_INCREMENTAL."
mv -f "\$LAST_BACKUP_INCREMENTAL" "$LAST_BACKUP"
find "$REMOTE_BACKUP_LOCATION" -regextype posix-extended -regex "$BACKUP_FINDER" | sort -n | head -n -"$MAX_BACKUPS" | while IFS= read -r old_backup; do
    echo "  deleting old backup \$old_backup."
    rm -f "\$old_backup"
done
EOF
    fi

done

echo "Copying $LOCAL_BACKUP_DIR/$DOMAIN/$DOMAIN.xml to $BACKUP_HOST:$REMOTE_BACKUP_LOCATION/$DOMAIN.xml"
scp "$LOCAL_BACKUP_DIR/$DOMAIN/$DOMAIN.xml" "$BACKUP_HOST:$REMOTE_BACKUP_LOCATION/$DOMAIN.xml"

ARGS="-regextype posix-extended -mindepth 1 -maxdepth 1 -not -name $DOMAIN.xml $(find "$LOCAL_BACKUP_DIR/$DOMAIN/" -type f -name "*.$SNAPSHOT_NAME.qcow2" | while IFS= read -r BACKUP_SRC; do
    BACKUP_FILENAME="$(basename "$BACKUP_SRC")"
    echo -n "-not -regex ".*/${BACKUP_FILENAME/%.$SNAPSHOT_NAME.qcow2/}.[0-9]\{14\}.qcow2" "
done)"
ssh -n "$BACKUP_HOST" find "$REMOTE_BACKUP_LOCATION" $ARGS | while IFS= read -r unknown_file; do
    >&2 echo "Unknown file $BACKUP_HOST:$unknown_file."
done

echo "Deleting local full backup at $LOCAL_BACKUP_DIR."
rm -rf "$LOCAL_BACKUP_DIR"

echo "Completed incremental backup for $DOMAIN at $(date '+%Y-%m-%d %H:%M:%S')."
