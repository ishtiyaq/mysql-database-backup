#!/bin/bash

## crontab
# 00 23 * * 1-5 /__DatabaseBackup/database_backup.sh 2>&1

## change the values below where needed.....
DBNAMES="<database-name>"
HOST="--host=localhost"
USER="--user=user"
PASSWORD="--password=password"
BACKUP_DIR="/__DatabaseBackup/"

## you can change these values but they are optional....
OPTIONS="--default-character-set=latin1 --complete-insert --no-create-info --compact -q"
RESTORESCRIPT="$BACKUP_DIR/__restoreData.sql"
DATE=`date '+%Y%m%d_%H%M%S'`
#DATE=`date +%a`
#DATE=`date +%Y%m%d`
dayvar2=`date +%a -d "5day ago"`

## make no changes after this....
echo removing old temporary files if they exists...
rm -f ${BACKUP_DIR}/*_${dayvar2}.tar.gz
rm -f ${BACKUP_DIR}/*.sql > /dev/null 2>&1
rm -f ${BACKUP_DIR}/*.tar > /dev/null 2>&1
cd ${BACKUP_DIR}

for DB in $DBNAMES
do
    echo "=========================================="
    echo ${DB}
    echo "=========================================="
    echo 'SET FOREIGN_KEY_CHECKS=0;' > $RESTORESCRIPT

    mysqldump --no-data $HOST $USER $PASSWORD $DB > ${BACKUP_DIR}/__createTables.sql
    echo 'source __createTables.sql;' >> $RESTORESCRIPT

    for TABLE in `mysql $HOST $USER $PASSWORD $DB -e 'show tables' | egrep -v 'Tables_in_' `; do
        TABLENAME=$(echo $TABLE|awk '{ printf "%s", $0 }')
        FILENAME="${TABLENAME}.sql"
        echo Dumping $TABLENAME
        echo 'source' $FILENAME';' >> $RESTORESCRIPT
        mysqldump $OPTIONS $HOST $USER $PASSWORD $DB $TABLENAME > ${BACKUP_DIR}/${FILENAME}
    done

    echo 'SET FOREIGN_KEY_CHECKS=1;' >> $RESTORESCRIPT

    # echo making tar...
    # tar -cf ${DB}_${DATE}.tar *.sql  > /dev/null 2>&1

    echo compressing...
    # gzip -9 ${DB}_${DATE}.tar > /dev/null 2>&1
    tar cjf ${DB}_${DATE}.tar.gz *.sql

    echo removing temporary files...
    rm -f ${BACKUP_DIR}/*.sql > /dev/null 2>&1
    rm -f ${BACKUP_DIR}/*.tar > /dev/null 2>&1

    echo "done with " $DB
done

# ### FTP ###
echo "=========================================="
echo "uploading backup file to FTP server..."
echo "=========================================="

FTP_DIRECTORY="ftp_backup_direcotry"
FTP_USER="ftp_user"
FTP_PASS="ftp_password"
FTP_SERVER="ftp_server"

# ### Binaries ###
FTP="$(which ftp)"

# ### ftp ###
cd $BACKUP_DIR
DUMPFILE=${DB}_${DATE}.tar.gz
$FTP -n $FTPS <<END_SCRIPT
quote USER $FTP_USER
quote PASS $FTP_PASS
cd $FTP_DIRECTORY
mput $DUMPFILE
quit

echo "done with FTP "
