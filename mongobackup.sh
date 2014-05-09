#!/bin/bash
# Author: Renan Vicente < renanvice@gmail.com>


# Check if have a parameter -f to load config file
while getopts f,h: OPT
do
        case $OPT in
                f) CONFIG_FILE="$OPTARG"
		;;
		h) echo "This is my help"
        esac
done

if [ ! -z "$CONFIG_FILE" ] ; then
  if [ -f $CONFIG_FILE ];then
	. $CONFIG_FILE
  fi
elif [ -f "mongobackup.conf" ]; then
  . ./mongobackup.conf
else
  logger -s "mongobackup unable to read the configuration file, plese create mongobackup.conf or use -f file"
  exit 1
fi

# Wrapper for Debug mode
runcmd() {

    if [ $DEBUG -eq 1 ]; then
        echo DEBUG: --- "$@"
        "$@"
    else
	"$@"
    fi  
}

 

function control_sync {

          runcmd $MONGO --eval "printjson(db.fsync$1())"
}

function check_mongo_user  {

  if [ ! -z $MONGO_PASS ];then
          MONGODUMP="$MONGODUMP_PATH $MONGO_DUMP_OPTIONS -u $MONGO_USER -p$MONGO_PASS"
          MONGO="$MONGOCLIENT_PATH $DB_ADMIN -u $MONGO_DUMP_OPTIONS $MONGO_USER -p$MONGO_PASS"
  else
          MONGODUMP="$MONGODUMP_PATH $DB_ADMIN $MONGO_DUMP_OPTIONS"
          MONGO="$MONGOCLIENT_PATH $MONGO_DUMP_OPTIONS"
  fi

}

function do_backup { 
  # Check if is all databases
  if [ -z "$MONGO_DATABASE" ] ; then
      MONGO_DATABASE="full"
  fi
  # Create backup
  if [ $MONGO_DATABASE == "full" ];then
        runcmd $MONGODUMP -h $MONGO_HOST:$MONGO_PORT
  else
        runcmd $MONGODUMP -h $MONGO_HOST:$MONGO_PORT -d $MONGO_DATABASE
  fi

  # Add timestamp to backup
  if [ ! -d $BACKUP_DIR ];then
    mkdir -p $BACKUP_DIR
  fi
  DUMP_FILE="$BACKUP_DIR/mongodb-$HOSTNAME-$TIMESTAMP"
  runcmd mv dump $DUMP_FILE

}

function do_compress {

  runcmd tar cf $DUMP_FILE.tar $DUMP_FILE
  DUMP_FILE="$DUMP_FILE.tar"
  if [ $COMPRESS == "gzip" ];then
        runcmd gzip $DUMP_FILE
	DUMP_FILE="$DUMP_FILE.gz"
  elif [ $COMPRESS == "bzip2" ];then
        runcmd bzip2 $DUMP_FILE
	DUMP_FILE="$DUMP_FILE.bz2"
  fi

}

function upload_s3 {

  if [ ! -z $S3_BUCKET_NAME ] && [ ! -z $S3_BUCKET_PATH ] && [ $S3 == "1" ];then
  	# Upload to S3
  	runcmd s3cmd put $DUMP_FILE s3://$S3_BUCKET_NAME/$S3_BUCKET_PATH/$DUMP_FILE
  fi
}


check_mongo_user
#Force file syncronization and lock writes
control_sync Lock
do_backup
#Unlock database writes
control_sync Unlock
do_compress
upload_s3
