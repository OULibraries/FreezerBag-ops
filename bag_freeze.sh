#!/usr/bin/env bash
PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin
LOGFILE="/var/log/freezerbag.log"
TODAY=`date`

## Require arguments
if [ ! -z "$1" ]
then
  BAGSDIR=$1
else
  echo "Requires bagit source dir (eg. /mnt/bagit) as argument"
  exit 1;
fi

if [ ! -z "$2" ]
then
  VAULT=$2
else
  echo "Requires bagit dest vault (eg. glaciervaultname) as argument"
  exit 1;
fi

if [ ! -z "$3" ]
then
  MAILTO=$3
else
  echo "Requires email address as argument"
  exit 1;
fi

## CC email is optional
if [ ! -z "$4" ]
then
  MAILCC="-c $4"
else
  MAILCC=""
fi

## Make a lock file to prevent runs from overlapping
MYFLOCK=/var/lock/`basename "$0"`.lock

## Go away if we're still running
(
  flock -x -w 10 200 || exit 1

  ## Loop through the bags
  for BAGPATH in `find $BAGSDIR -mindepth 1 -maxdepth 1 -type d`
  do
    ## Get the bag name
    BAGNAME=$(basename "$BAGPATH")
    echo "$BAGNAME - start $TODAY" > ${LOGFILE} 2>&1
    ## Execute the freezerbag script with appropriate options
    ## Send the output to our logfile
    python /opt/ltp/freezerbag.py --freeze --bag ${BAGNAME} --path ${BAGSDIR} --vault ${VAULT} >> ${LOGFILE} 2>&1
    echo "$BAGNAME - completed $TODAY" >> ${LOGFILE} 2>&1
    ## Send one email for each bag
    mail -s "Freezerbag $BAGNAME - $TODAY" $MAILCC $MAILTO < $LOGFILE
  done
) 200>${MYFLOCK}
