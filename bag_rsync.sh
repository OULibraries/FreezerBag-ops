#!/usr/bin/env bash

## Require arguments
if [ ! -z "$1" ]
then
  INBAGSDIR=$1
else
  echo "Requires bagit source dir (eg. /mnt/bagitin) as argument"
  exit 1;
fi

if [ ! -z "$2" ]
then
  OUTBAGSDIR=$2
else
  echo "Requires bagit dest dir (eg. /mnt/bagitout) as argument"
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
(
  flock -x -w 10 200 || exit 1
  for BAGNAME in `diff -sq ${INBAGSDIR} ${OUTBAGSDIR} | grep "Only in ${INBAGSDIR}" | cut -d ':' -f 2 | xargs`
  do

    ## Get the date
    TODAY=`date`
  
    ## Holds our email message body
    BODY=''
  
    ## Make a named pipe to hold the email contents.
    ## We\'re going to the trouble for cron compatibility
    BAGPIPE=/tmp/${BAGNAME}.pipe
    ## Kill the pipe on exit
    trap "rm -f ${BAGPIPE}" EXIT
  
    ## Create the pipe on start
    if [[ ! -p $BAGPIPE ]]; then
      mkfifo $BAGPIPE
    fi
  
    ## Attach a file descriptor.
    ## This causes the shell to buffer the pipe so we don\'t worry about blocking
    exec 3<>$BAGPIPE

    BAGPATH=${INBAGSDIR}/${BAGNAME}
    echo $TODAY>&3

    ## Skip this folder if it isn\'t a valid bag
    bagit.py --validate $BAGPATH 2>&3
    BAGSTATUS="$?"
    if [ "$BAGSTATUS" -gt 0  ]; then
      echo 'EOF'>&3
      DEAD=false
      until $DEAD; do
        read -u 3 LINE || DEAD=true
        if [[ "$LINE" == 'EOF' ]]; then
          break
        fi
        ## Append body
        BODY=${BODY}$'\n'${LINE}
      done
      echo "$BODY" | mail -s "Bag invalid: $BAGNAME $TODAY" $MAILCC $MAILTO; continue
    else
      ## If it is a valid bag, sync it.
      ## Don\'t keep permissions from source, as they are irrelevant to the file archive
      ## Skip empty files, as those are our placeholders.
      rsync -rltozvD --min-size=1 $BAGPATH $OUTBAGSDIR >&3 2>&3
      echo 'EOF'>&3
      DEAD=false
      until $DEAD; do
        read -u 3 LINE || DEAD=true
        if [[ "$LINE" == 'EOF' ]]; then
          break
        fi
        ## Append body
        BODY=${BODY}$'\n'${LINE}
      done
      echo "$BODY" | mail -s "Bag rsync: $BAGNAME $TODAY" $MAILCC $MAILTO
    fi
  done
) 200>$MYFLOCK
