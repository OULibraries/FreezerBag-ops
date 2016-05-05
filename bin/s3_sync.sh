#!/usr/bin/env bash

# Require arguments
if [ ! -z "$1" ]
then
  SOURCE=$1
else
  echo "Requires LocalPath as source."
  exit 1;
fi

if [ ! -z "$2" ]
then
  DEST=$2
else
  echo "Requires LocalPath OR S3Uri as destination."
  exit 1;
fi

if [[ ! -z "$3" ]]; then
  TYPE=$3
  if [[ "$TYPE" -ne 'bag' || "$TYPE" -ne 'any' ]]
 then
    echo "Requires type of bag or any."
    exit 1;
  fi
else
  echo "Requires type of bag or any."
  exit 1;
fi

if [ ! -z "$4" ]
then
  MAILTO=$4
else
  echo "Requires email address as argument"
  exit 1;
fi

# CC email is optional
if [ ! -z "$5" ]
then
  MAILCC="-c $5"
else
  MAILCC=""
fi

SYNCOPTS="--dryrun"

BASENAME=`basename ${SOURCE}`

ME=`basename "$0"`

# Make a lock file to prevent runs from overlapping
FLOCK=/var/lock/${ME}_${BASENAME}.lock
 
# Make a named pipe to hold the email contents.
# We go to the trouble for cron compatibility
PIPE=/tmp/${ME}_${BASENAME}.pipe

function finish {
  # Kill the pipe on exit
  rm $PIPE
  # Kill the lock on exit
  rm $FLOCK
}

trap finish EXIT

(
  flock -x -w 10 200 || exit 1

  # Holds our email message body
  BODY=''
  
  # Create the pipe on start
  if [[ ! -p $PIPE ]]; then
    mkfifo $PIPE
  fi
  
  # Attach a file descriptor.
  # This causes the shell to buffer the pipe so we avoid worries about blocking
  exec 3<>$PIPE

  # Get the time
  NOW=`date`
  
  echo $NOW>&3

  # Skip this source if it is invalid
  # This currently only works for LocalPath sources

  # If you were running this against bags, you might want this.  
  if [[ "$TYPE" == "bag" ]]; then
    ## Check for bagname/bagit.txt. If that exists, then validate the bag.
    stat --format=%F:\ %n $SOURCE/bagit.txt >&3 2>&3 && bagit.py --validate $SOURCE 2>&3
    SOURCESTATUS="$?"
  # Is there something there?
  elif [[ "$TYPE" == "any" ]]; then
    stat --format=%F:\ %n $SOURCE >&3 2>&3
    SOURCESTATUS="$?"
  fi

  if [ "$SOURCESTATUS" -gt 0  ]; then
    echo 'EOF'>&3
    DEAD=false
    until $DEAD; do
      read -u 3 LINE || DEAD=true
      if [[ "$LINE" == 'EOF' ]]; then
        break
      fi
      # Append body
      BODY=${BODY}$'\n'${LINE}
    done

    # Get the time
    NOW=`date`
  
    echo "$BODY" | mail -s "s3sync source invalid: $BASENAME $NOW" $MAILCC $MAILTO
  else
    # If it is a valid bag, sync it.
    SYNC=`aws s3 sync ${SYNCOPTS} ${SOURCE} ${DEST}`
    DEAD=false

    # Print the output to our pipe in a subshell
    printf "${SYNC}\nEOF\n" >&3 2>&3 &

    until $DEAD; do
      read -u 3 LINE || DEAD=true
      if [[ $LINE == 'EOF' ]]; then
        break
      fi
      #echo "$LINE"
      # Append body
      BODY=${BODY}$'\n'${LINE}
    done

    # Get the time
    NOW=`date`
  
    echo "$BODY" | mail -s "s3sync: $BASENAME $NOW" $MAILCC $MAILTO
  fi
) 200>$FLOCK
