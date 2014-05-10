mongo-backup
============

Script to backup upe MongoDB databases and optionally store in Amazon S3 (Simple Storage Directory) or a server via rsync.

Dependencies
-------------

1. python-magic.
2. s3cmd (Optional, just if you want to store in Amazon S3).
3. rsync (Optional, just if you want to store in rsync server). 

**Debian or Ubuntu**

`apt-get install s3cmd python-magic rsync`

**CentOS or RedHat**

`yum install s3cmd python-magic rsync`

**Steps for using store in S3:**

1. Set up an Amazon S3 account: <http://aws.amazon.com/s3/>
2. Install the dependency ( s3cmd )
3. configure your s3 account with:
`s3cmd --configure`
4. set your bucket and directory to place the backups on mongobackup.conf

Example:

    S3="1"
    S3_BUCKET_NAME="bkp-mongodb-bucket"
    S3_BUCKET_PATH="mongodb-backups"`

done , now your config is ready to store on s3.

**Steps for using store in rsync server.**

1. Install the dependency ( rsync )
2. Set your rsync configs on mongobackup.conf

Example:

   RSYNC_PATH="/usr/bin/rsync"
   RSYNC_OPTS="-auvvz"
   REMOTE_USER="renanvicente"
   REMOTE_HOST="10.10.50.50"
   REMOTE_MODULE="backup"

done , now your config is ready to store in rsync server.


Using
------

1. edit your mongobackup.conf with your config.
2. change the permission for mongobackup.sh
3. execute.
