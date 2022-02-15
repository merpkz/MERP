#!/bin/bash
set -e
set -o pipefail

if [ $USER != "postgres" ]; then
	echo "$0 should run as postgres user!"
	exit 1;
fi

backup_dir="/backups/postgres"

if [ ! -w $backup_dir ]; then
	echo "Backup directory $backup_dir doesn't exist or is not writable!";
	exit 1;
fi

for db in `psql -A -t -c 'select datname from pg_database where not datistemplate'`; do
	pg_dump -F t $db | gzip > ${backup_dir}/${db}_db_backup_$(date +\%F).tar.gz
done;

# clean up old backups while at it:
find $backup_dir -mindepth 1 -maxdepth 1 -mtime +3 -type f -iname \*.tar.gz -delete
