# QEMU/libvirt Backup Scripts

A collection of scripts to be used with QEMU/libvirt that facilitate incremental backing up of running virtual machines to a remote server. At the moment, only file backed devices are supported.

To install, the files need to be copied to /usr/local/bin on the host:
```
chmod +x *.sh
cp *.sh /usr/local/bin
```

`qemu-img` needs to be available on the remote server. On Debian based machines, this can be installed with:
```
sudo apt install qemu-utils
```

To enable incremental backups of all running virtual machines at midnight every day, execute:
```
echo '0 0 * * * root /usr/local/bin/vm-backup-inc-all.sh REMOTE_DIR HOST' > /etc/cron.d/backup-vms
```

By default, a maximum of 7 incremental backups are kept. Backups are reverse incremental. That is, the most recent backup is a full qcow2 image, and each previous backup uses the next backup as a backing image.

For example, if the first backup was taken on a Monday, it will be a full backup:
```
Monday [F]
```

If another backup is taken on Tuesday, Tuesday will become the full backup, and Monday will become an incremental backup based on Tuesday:
```
Monday [I] > Tuesday [F]
```
If another backup is taken on Wednesday, Wednesday will become the full backup, Tuesday will become an incremental backup based on Wednesday, and Monday will remain as an incremental backup based on Tuesday:
```
Monday [I] > Tuesday [I] > Wednesday [F]
```
