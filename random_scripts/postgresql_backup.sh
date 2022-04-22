#!/bin/bash
set -eu -o pipefail

if [ ${USER:-$(whoami)} != "postgres" ]; then
	echo "$0 should run as postgres user!"
	exit 1;
fi

# where to store backups and for how many days
backup_dir="/backups/postgres"
backup_age=3

if [ ! -w $backup_dir ]; then
	echo "Backup directory $backup_dir doesn't exist or is not writable!";
	exit 1;
fi

for db in `psql -A -t -c 'select datname from pg_database where not datistemplate'`; do
	pg_dump -F t $db | gzip > ${backup_dir}/${db}_db_backup_$(date +\%F).tar.gz
done;

# remove old backups once we are done taking new backups.
find $backup_dir -mindepth 1 -maxdepth 1 -mtime +$backup_age -type f -iname \*.tar.gz -delete
