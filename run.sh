#! /bin/sh

set -e
# convert ${CMD} environment variable value to lower
CMD=$(echo "${CMD}" | tr '[:upper:]' '[:lower:]')
# if ${CMD} is not set
if [ -z "${CMD}" ]; then
    echo "You need to set the CMD environment variable to BACKUP or RESTORE."
    exit 1
fi
# if ${CMD} is set and equals "backup" or "restore"
if [ "${CMD}" = "backup" ] || [ "${CMD}" = "restore" ]; then
    echo "Chosen operation is: ${CMD}"
# if set to any other value, exit
else
    echo "Invalid operation. Please select BACKUP or RESTORE."
    exit 1
fi

if [ "${S3_S3V4}" = "yes" ]; then
    aws configure set default.s3.signature_version s3v4
fi
# if ${SCHEDULE} variable is not set, run the script
if [ -z "${SCHEDULE}" ]; then
    # if operation is "backup", run "backup.sh" script
    if [ "${CMD}" = "backup" ]; then
      sh backup.sh
    # else, run "restore.sh" script (at this point no other value would've been accepted)
    else 
      sh restore.sh
    fi
# if ${SCHEDULE} variable is set, schedule the cronjob
else
    exec go-cron "$SCHEDULE" /bin/sh "${CMD}.sh"
fi
