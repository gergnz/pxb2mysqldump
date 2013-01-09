#!/bin/bash
# A script to turn Percona Xtrabackup to seperate or one large database dump.
set -e

## Print basic usage
usage() {
  me=`basename $0`
  echo "$me [-u username] [-A] [-h] [directory]"
  exit 1
}

## Check I am root
if [ "$EUID" -ne "0" ]; then
  echo "you are not running as root" >&2
  usage
fi

## Set some defaults
backupdir=`pwd`
runasuser='mysql'
alldatabases=FALSE

## Grab the options, and setup variables
while getopts ":u:hA" opt; do
  case $opt in
    u)
      if [ -z "${OPTARG}" ]; then
        usage
      fi
      runasuser=${OPTARG}
      ;;
    A)
      alldatabases=TRUE
      ;;
    h)
      usage
      ;;
    \?)
      usage
      ;;
    :)
      usage
      ;;
  esac
done

## Set the backupdir if supplied
shift $(($OPTIND - 1))
if [ -n "${1}" ]; then
  backupdir=${1}
fi

## Safe guard
## TODO: Use a special override incase this is what people want to do.
if [ "${backupdir}" = "/var/lib/mysql" ]; then
  echo "You probably don't want to run this in /var/lib/mysql." >&2
  exit 1
fi

## Does the supplied directory exist?
if [ ! -d ${backupdir} ]; then
  echo "The provided dir: ${backupdir}, doesn't exist" >&2
  exit 1
fi

## Dump all the logs, config, etc, in a unique directory
temp=`mktemp -d`
chown ${runasuser} ${temp}

## Create a minimal my.cnf
cat > $temp/my.cnf << EOF
[mysqld]
skip-networking
datadir=$backupdir
socket=$temp/mysql.sock
innodb_data_home_dir=$backupdir
innodb_data_file_path=ibdata1:10M:autoextend
innodb_log_group_home_dir=$temp
innodb_log_files_in_group=2
skip-grant-tables
[mysql.server]
user=$runasuser
basedir=$backupdir
[mysqld_safe]
log-error=$temp/mysqld.log
pid-file=$temp/mysqld.pid
EOF

## Make all the files owned by the user we are going to run as.
chown -R ${runasuser} ${backupdir}

## Start mysql
mysqld_safe --defaults-file=${temp}/my.cnf

## Check that mysql has innodb
have_innodb=$(mysql -S ${temp}/mysql.sock -NB -e "show variables like 'have_innodb'"|awk '{print $2}')
if [ "$have_innodb" != "YES" ]; then
  echo "InnoDB was not detected, exiting" >&2
  exit 1
fi

if [ "${alldatabases}" == "TRUE" ]; then
  ## Full database dump
  echo "Dumping all databases..."
  mysqldump -S ${temp}/mysql.sock --all-databases --quick --single-transaction | gzip > ${backupdir}/alldatabases.sql.gz
  echo "Done"
  echo "You can import this into an empty or alternative host with something like this:"
  echo "# Example:"
  echo "# zcat ${backupdir}/alldatabases.sql.gz | mysql -uroot -p "
else 
  ## Just dump useful databases
  for database in $(mysql -S ${temp}/mysql.sock -BN -e "show databases"|grep -Ev 'mysql|test|information_schema'); do
    echo "Found: $database"
    echo -n "Dumping $database to: $database.sql..."
    mysqldump -S ${temp}/mysql.sock $database | gzip > ${backupdir}/${database}.sql.gz
    echo "Done"
    echo "You can import this into an instance with something like this:"
    echo "# Example:"
    echo "# zcat ${backupdir}/${database}.sql.gz | mysql -uroot -p $database"
  done
fi

## Destory the mysql running
kill $(ps -fC mysqld|grep "${backupdir}"|awk '{print $2}')

# vim:syntax=bash
