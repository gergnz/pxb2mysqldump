#pxb2mysqldump

This is a simple script that will automatically startup a MySQL instance
and dump all the databases (except mysql,test and information_schema)
out to seperate files as <database name>.sql.gz

Or it will produce one large file, alldatabases.sql.gz.

##usage

* -A: Dump all databases as one large file.
* -u &lt;user&gt;: use this user to runas (default: mysql)
* &lt;directory&gt;: specify a directory where the backup is (default: CWD)

##apparmour

If you get an error like this:
```
140728 15:26:38  InnoDB: Operating system error number 13 in a file operation.
InnoDB: The error means mysqld does not have the access rights to
InnoDB: the directory.
InnoDB: File name /srv/backup/2014-07-28_14-34-17/ibdata1
InnoDB: File operation call: 'open'.
InnoDB: Cannot continue operation.
```
Then you probably need to setup SELinux or Apparmour.

```
echo "/srv/backup/** lrwk," >> /etc/apparmor.d/local/usr.sbin.mysqld
apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld
```
