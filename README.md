pxb2mysqldump
=============

This is a simple script that will automatically startup a MySQL instance
and dump all the databases (except mysql,test and information_schema)
out to seperate files as <database name>.sql.gz

Or it will produce one large file, alldatabases.sql.gz.

usage
-----

* -A: Dump all databases as one large file.
* -u <user>: use this user to runas (default: mysql)
* <directory>: specify a directory where the backup is (default: CWD)
