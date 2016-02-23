#!/usr/bin/env bash

## Require arguments
if [ ! -z "$1" ]
then
  INBAGSDIR1=$1
else
  echo "Requires bagit source dir (eg. /mnt/bagitin1) as argument"
  exit 1;
fi

if [ ! -z "$2" ]
then
  INBAGSDIR2=$2
else
  echo "Requires bagit source dir (eg. /mnt/bagitin2) as argument"
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

## Get the date
TODAY=`date`

## Holds our email message body
BODY=''

## Make a named pipe to hold the email contents.
## We're going to the trouble for cron compatibility
MYPIPE=/tmp/`basename "$0"`.pipe
## Kill the pipe on exit
trap "rm -f ${MYPIPE}" EXIT

## Crete the pipe on start
if [[ ! -p $MYPIPE ]]; then
    mkfifo $MYPIPE
fi

## Attach a file descriptor.
## This causes the shell to buffer the pipe so we don't worry about blocking
exec 3<>$MYPIPE

## Check for name conflicts
CONFLICTBAG=`diff -sq ${INBAGSDIR1} ${INBAGSDIR2} | grep 'Common subdirectories:'`
echo $TODAY>&3
echo $CONFLICTBAG>&3
echo 'End of List'>&3

DEAD=false
until $DEAD; do
  read -u 3 LINE || DEAD=true
  if [[ "$LINE" == 'End of List' ]]; then
    break
  fi
  ## Append body
  BODY=${BODY}$'\n'${LINE}
done

## Cleanup output a bit
BODY=`echo "$BODY" | sed -e 's/Common subdirectories: /\n/g'`
echo "$BODY" | mail -s "Bag name conflict: $TODAY" $MAILCC $MAILTO
