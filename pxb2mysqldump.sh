#!/bin/bash
# A script to turn Percona Xtrabackup to seperate database dumps.

##getopts
## backupdir
## user (mysql)

##Check I am root


usage() {
  me=`basename $0`
  echo "$me [-u username] [-h] [directory]"
  exit 1
}

#if [ "$EUID" -ne "0" ]; then
#  echo "you are not running as root" >&2
#  usage
#fi

backupdir=`pwd`
runasuser='mysql'
alldatabases=FALSE

while getopts ":u:hA" opt; do
  case $opt in
    u)
      if [ -z "${OPTARG}" ]; then
        usage
      fi
      runasuser=${OPTARG}
      shift; shift
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

if [ -n "${1}" ]; then
  backupdir=${1}
fi

if [ "${backupdir}" = "/var/lib/mysql" ]; then
  echo "You probably don't want to run this in /var/lib/mysql." >&2
  exit 1
fi

if [ ! -d ${backupdir} ]; then
  echo "The provided dir: ${backupdir}, doesn't exist" >&2
  exit 1
fi

temp=`mktemp -d -p $backupdir`

# Create a minimal my.cnf
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
err-log=$temp/mysqld.log
pid-file=$temp/mysqld.pid
EOF

chown -R ${runasuser} ${backupdir}

mysqld_safe --defaults-file=${temp}/my.cnf

have_innodb=$(mysql -S ${temp}/mysql.sock -NB -e "show variables like 'have_innodb'"|awk '{print $2}')
if [ "$have_innodb" != "YES" ]; then
  echo "InnoDB was not detected, exiting" >&2
  exit 1
fi

if [ "${alldatabases}" == "TRUE" ]; then
  echo "Dumping all databases..."
  mysqldump -S ${temp}/mysql.sock --all-databases --quick --single-transaction | gzip > ${backupdir}/alldatabases.sql.gz
  echo "Done"
  echo "You can import this into an empty or alternative host with something like this:"
  echo "# Example:"
  echo "# zcat ${backupdir}/alldatabases.sql.gz | mysql -uroot -p "
else 
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

kill $(ps -fC mysqld|grep "${backupdir}"|awk '{print $2}')

# vim:syntax=bash
