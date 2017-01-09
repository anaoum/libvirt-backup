# Libvirt Backup

A collection of scripts to be used with libvirt that facilitate incremental backing up of running virtual machines to a remote server.

To install, the files need to be copied to /usr/local/bin on both the host and the backup server:

```
chmod +x backup-all-vms.sh vm-backup.sh vm-consolidate-backups.sh vm-inc-backup.sh
cp *.sh /usr/local/bin
```

To enable incremental backups of all running virtual machines at midnight every day, execute:

```
echo '0 0 * * * root /usr/local/bin/backup-all-vms.sh BACKUP_HOST REMOTE_FOLDER' > /etc/cron.d/backup-vm
```

By default, a maximum of 7 incremental backups are kept. Full backups roll forward.

For example, if the first backup was taken on a Monday, it will be a full backup. If 6 backups are taken every day after, they will each be incremental images backed by the prior day:

```
Monday [F] > Tuesday [I] > Wednesday [I] > Thursday [I] > Friday [I] > Saturday [I] > Sunday [I]
```

The following Monday, another backup will cause the Tuesday backup to become the full backup:

```
Tuesday [F] > Wednesday [I] > Thursday [I] > Friday [I] > Saturday [I] > Sunday [I] > Monday [I]
```

This is achieved by pulling the `Monday [F]` image into the `Tuesday [I]` image.

## TODO
- Test on domains with spaces.
- Test on images with spaces.
- Test with other snapshots.
- Test on raw images.
