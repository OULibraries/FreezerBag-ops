#!/usr/bin/env bash

## Number of subshells to spawn
SUBSHELL_COUNT=8

# Require arguments
if [ ! -z "$1" ]
then
  INPUTDIR=$1
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

## Get current Directory
WD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

## Add it to path
PATH=$PATH:$WD

## Loop through the sources
declare -a SOURCES
while IFS= read -r -d '' SOURCE; do
  SOURCES+=( "$SOURCE" )
done < <(find "${INPUTDIR}" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

for SOURCE in "${SOURCES[@]}"; do
  ## Fire off the specified number of subshells.
  ## Repeat after they all complete. A simple way to go wide, but not the most efficient.
  ((i=i%SUBSHELL_COUNT)); ((i++==0)) && wait

  ## Treat the following as one lump
  (
    ## Get the bag name
    CONTENT=$(basename "${SOURCE}")

    ## Execute the s3_sync script with appropriate options
    bash -c "${WD}/s3_sync.sh \"${INPUTDIR}/${CONTENT}\" \"${DEST}/${CONTENT}\" ${TYPE} ${MAILTO} ${MAILCC}"
  ) &
done
