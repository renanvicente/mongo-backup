#!/bin/bash
# Project Source: https://github.com/renanvicente/mongo-backup
# Version:        0.0.3
# Author:         Renan Vicente
# Mail:           renanvice@gmail.com
# Website:        http://www.renanvicente.com
# Github:         https://www.github.com/renanvicente
# Linkedin:       http://www.linkedin.com/pub/renan-silva/6a/802/59b/en

DIR=$(dirname "${BASH_SOURCE[0]}")

# Check if have a parameter -f to load config file
while getopts f: OPT
do
        case $OPT in
                f) CONFIG_FILE="$OPTARG"
        esac
done

if [ ! -z "$CONFIG_FILE" ] ; then
  if [ -f $CONFIG_FILE ];then
	. $CONFIG_FILE
  fi
elif [ -f "$DIR/mongobackup.conf" ]; then
  . $DIR/mongobackup.conf
else
  logger -s "unable to read the configuration file, plese create mongobackup.conf"
  exit 1
fi

# Wrapper for Debug mode
runcmd() {

    if [ $DEBUG -eq 1 ]; then
        echo DEBUG: --- "$@"
        "$@" 2>&1 | tee -a $LOG_FILE
    else
	"$@" 2>&1 | tee -a $LOG_FILE
    fi  
}

function control_sync {

        if [ $LOCK_WRITES -eq 1 ];then
          runcmd $MONGO --eval "printjson(db.fsync$1())"
        fi
}

function check_default_values {

  # Check if is all databases
  if [ -z "$MONGO_DATABASE" ] ; then
      MONGO_DATABASE="full"
  fi

  if [ -z $BACKUP_DIR ];then
    BACKUP_DIR="."
  else
    # Create backup dir directory if does not exist
    if [ ! -d $BACKUP_DIR ];then
      mkdir -p $BACKUP_DIR
      if [ $? -ne 0 ];then
        echo "Problem trying to create $BACKUP_DIR directory"
      fi
    fi
  fi

  if [ -z $TIMESTAMP ];then
    TIMESTAMP=`date +%F-%H%M`
  fi

  if [ -z $LOG_FILE ];then
    LOG_FILE="/var/log/mongobackup.log"
  fi

  if [ -z $MONGO_HOST ];then
    MONGO_HOST="127.0.0.1"
  fi

  if [ -z $MONGO_PORT ];then
    MONGO_PORT="27017"
  fi

  if [ -z $LOCK_WRITES ];then
    LOCK_WRITES=0
  fi

  if [ -z $AUTO_PICK_SLAVE ];then
    AUTO_PICK_SLAVE=0
  fi

  if [ -z $DEBUG ];then
    DEBUG=0
  fi

  if [ -z $S3 ];then
    S3=0
  fi

  if [ -z $RSYNC ];then
    RSYNC=0
  fi

  if [ -z $MONGO_PATH ];then
    MONGO_PATH=`which mongo`
  fi

  if [ -z $MONGODUMP_PATH ];then
    MONGODUMP_PATH=`which mongodump`
  fi

  if [ -z $RSYNC_PATH ];then
    RSYNC_PATH=`which rsync`
  fi

  if [ -z $S3CMD_PATH ];then
    S3CMD_PATH=`which s3cmd`
  fi

  if [ -z $TAR_PATH ];then
    TAR_PATH=`which tar`
  fi

  if [ -z $GZIP_PATH ];then
    GZIP_PATH=`which gzip`
  fi

  if [ -z $BZIP2_PATH ];then
    BZIP2_PATH=`which bzip2`
  fi

}


function check_mongo_user  {

  if [ ! -z $MONGO_PASS ];then
          MONGODUMP="$MONGODUMP_PATH $MONGO_DUMP_OPTIONS -u $MONGO_USER -p$MONGO_PASS"
          MONGO="$MONGOCLIENT_PATH $MONGO_HOST:$MONGO_PORT/$DB_ADMIN -u $MONGO_DUMP_OPTIONS $MONGO_USER -p$MONGO_PASS"
  else
          MONGODUMP="$MONGODUMP_PATH $DB_ADMIN $MONGO_DUMP_OPTIONS"
          MONGO="$MONGOCLIENT_PATH $DB_ADMIN $MONGO_DUMP_OPTIONS"
  fi

}

function do_backup { 

  # Create backup
  if [ $MONGO_DATABASE == "full" ];then
        runcmd $MONGODUMP -h $MONGO_HOST:$MONGO_PORT
  else
        runcmd $MONGODUMP -h $MONGO_HOST:$MONGO_PORT -d $MONGO_DATABASE
  fi

  # Add timestamp to backup
  DUMP_FILE="$BACKUP_DIR/mongodb-$HOSTNAME-$TIMESTAMP"
  JUST_DUMP_FILE="mongodb-$HOSTNAME-$TIMESTAMP"
  runcmd mv dump $DUMP_FILE

}

function do_compress {

  runcmd $TAR_PATH cf $DUMP_FILE.tar $DUMP_FILE
  runcmd rm -r $DUMP_FILE
  DUMP_FILE="$DUMP_FILE.tar"
  JUST_DUMP_FILE="$JUST_DUMP_FILE.tar"
  if [ $COMPRESS == "gzip" ];then
        runcmd $GZIP_PATH $DUMP_FILE
	DUMP_FILE="$DUMP_FILE.gz"
	JUST_DUMP_FILE="$JUST_DUMP_FILE.gz"
  elif [ $COMPRESS == "bzip2" ];then
        runcmd $BZIP2_PATH $DUMP_FILE
	DUMP_FILE="$DUMP_FILE.bz2"
	JUST_DUMP_FILE="$JUST_DUMP_FILE.bz2"
  fi

}

function upload_s3 {

  if [ ! -z $S3_BUCKET_NAME ] && [ ! -z $S3_BUCKET_PATH ] && [ $S3 == "1" ];then
        # Upload to S3
        runcmd $S3CMD_PATH put $DUMP_FILE s3://$S3_BUCKET_NAME/$S3_BUCKET_PATH/$JUST_DUMP_FILE
  fi
}

function check_rpl {

  IS_RPL="`$MONGO --eval 'printjson(rs.status().ok)' | tail -n1`"

}

function pick_slave {

  if [ $IS_RPL -eq 1 ];then
    if [ $AUTO_PICK_SLAVE -eq 1 ];then
       MONGO_HOST=`$MONGO --eval "printjson(rs.printSlaveReplicationInfo())" | grep source | awk '{print $2}' | awk -F: '{print $1}'`
       MONGO_PORT=`$MONGO --eval "printjson(rs.printSlaveReplicationInfo())" | grep source | awk '{print $2}' | awk -F: '{print $2}'`
       check_mongo_user
    fi
  fi
}

function send_rsync {

  if [ $RSYNC -eq 1 ];then
    if [ ! -z $RSYNC_PATH ] && [ ! -z $RSYNC_OPTS ] && [ ! -z $DUMP_FILE ] && [ ! -z $REMOTE_USER ] && [ ! -z $REMOTE_HOST ] && [ ! -z $REMOTE_MODULE ];then
      if [[ ! $REMOTE_MODULE =~ ^/ ]];then
        REMOTE_MODULE="/$REMOTE_MODULE"
      fi
      runcmd $RSYNC_PATH $RSYNC_OPTS $DUMP_FILE rsync://$REMOTE_USER@$REMOTE_HOST/$REMOTE_MODULE
    fi
  fi
}

function erase_old_backups {
  if [ $MAX_DAYS_LOCAL -gt 1 ];then
    runcmd find $BACKUP_DIR -name "mongodb-*" -type f -mtime +$MAX_DAYS_LOCAL -delete
  else
    runcmd find $BACKUP_DIR -name "mongodb-*" -type f -delete
  fi
}


check_default_values
check_mongo_user
check_rpl
pick_slave
##Force file syncronization and lock writes
control_sync Lock
do_backup
#Unlock database writes
control_sync Unlock
do_compress
upload_s3
send_rsync
erase_old_backups
if [ $DEBUG -ne 1 ];then
  echo "check the output on $LOG_FILE"
fi
