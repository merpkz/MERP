#!/bin/bash
set -eu -o pipefail

# this uses mysql socket file authentication, so no additional parameters to mysql command.

if [ $USER != "root" ]; then
        echo "$0 should run as root user!"
        exit 1;
fi

# where to store backups and for how long ( in days )
backup_dir="/backups/mysql"
backup_age=30

if [ ! -w $backup_dir ]; then
        echo "Backup directory $backup_dir doesn't exist or is not writable!";
        exit 1;
fi

for db in $(mysql -Bse 'show databases where `database` not in("information_schema","performance_schema");'); do
        mysqldump --flush-logs --delete-master-logs $db | gzip > ${backup_dir}/${db}_db_backup_$(date +\%F).sql.gz
done;

# remove old backups after new ones are done.
find $backup_dir -mindepth 1 -maxdepth 1 -mtime +$backup_age -type f -iname \*.sql.gz -delete
