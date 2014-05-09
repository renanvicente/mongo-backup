mongo-backup
============

Script to backup upe MongoDB databases and optionally store in Amazon S3 (Simple Storage Directory) or a server via rsync.

** Dependencies **

1 - python-magic
2 - s3cmd (Optional, just if your want to store in Amazon S3)

Debian or Ubuntu

`apt-get install s3cmd`

CentOS or RedHat

`yum install s3cmd`

** Steps for using store on S3:**

1 - Set up an Amazon S3 account: <http://aws.amazon.com/s3/>
2 - Install the dependency ( s3cmd )
3 - configure your s3 account with `s3cmd --configure`
4 - set your bucket and directory to place the backups on mongobackup.conf
example:
`
S3="1"
S3_BUCKET_NAME="bkp-mongodb-bucket"
S3_BUCKET_PATH="mongodb-backups"`

done , now your config is ready to store on s3.

** Using **

1 - edit your mongobackup.conf with your configs.
2 - change the permission for mongobackup.sh
3 - execute.
