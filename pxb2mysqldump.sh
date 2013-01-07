#!/bin/bash
# A script to turn Percona Xtrabackup to seperate database dumps.

##getopts
## backupdir
## port (9999)
## user (mysql)
## socket ($backupdir/$temp/mysql.sock)

##Check I am root

backupdir=`pwd`

if [ "$backupdir" = "/var/lib/mysql" ]; then
  echo "You probably don't want to run this in /var/lib/mysql." >&2
  exit 1
fi

if [ !-d $backupdir ]; then
  echo "The provided dir: ${backupdir}, doesn't exist" >&2
  exit 1
fi

temp=`mktemp -d -p $backupdir`

# Create a minimal my.cnf
cat > $backupdir/my.cnf << EOF
[mysqld]
skip-networking
datadir=$backupdir/mysql
socket=$backupdir/mysql/mysql.sock
innodb_data_home_dir=$backupdir/mysql
innodb_data_file_path=ibdata1:10M:autoextend
innodb_log_group_home_dir=$backupdir/mysql
innodb_log_files_in_group=2
skip-grant-tables
[mysql.server]
user=mysql
basedir=$backupdir
[mysqld_safe]
err-log=$backupdir/mysql/mysqld.log
pid-file=$backupdir/mysql/mysqld.pid
EOF




# vim:syntax=bash
