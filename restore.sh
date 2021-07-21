#!/bin/sh

set -e

# check if necessary environment variables are in place

if [ -z "${AWS_ACCESS_KEY_ID}" ]; then
    echo "You need to set the AWS_ACCESS_KEY_ID environment variable."
    exit 1
fi

if [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
    echo "You need to set the AWS_SECRET_ACCESS_KEY environment variable."
    exit 1
fi

if [ -z "${S3_BUCKET}" ]; then
    echo "You need to set the S3_BUCKET environment variable."
    exit 1
fi

if [ -z "${POSTGRESQL_DATABASE}" ]; then
    echo "You need to set the POSTGRESQL_DATABASE environment variable."
    exit 1
fi

if [ -z "${POSTGRESQL_HOST}" ]; then
    echo "You need to set the POSTGRESQL_HOST environment variable."
    exit 1
fi

if [ -z "${POSTGRESQL_USER}" ]; then
    echo "You need to set the POSTGRESQL_USER environment variable."
    exit 1
fi

if [ -z "${POSTGRESQL_PASSWORD}" ]; then
    echo "You need to set the POSTGRESQL_PASSWORD environment variable."
    exit 1
fi

if [ -z "${POSTGRESQL_PORT}" ]; then
    POSTGRESQL_PORT=5432
fi

export PGPASSWORD=${POSTGRESQL_PASSWORD}

# get "point-in-time" backup parameter (can be a file or "latest")
PIT=$(echo "${RESTORE_TO}" | tr  '[:upper:]' '[:lower:]' )
export PIT

echo "Requesting backup file ${RESTORE_TO}"
# custom fuction to derive s3 backup path (e.g. 2021/03/05/defectdojo_14:41:57Z.sql.gz.dat)
generateAWSPath(){
    # if a specific file is defined
    if [ "$RESTORE_TO" != "latest" ]; then
        # request file metadata to verify its existence ()
        aws s3api head-object --bucket "${S3_BUCKET}" --key "${S3_PREFIX}/${RESTORE_TO}" || not_exist=true
        # if not found
        if [ $not_exist ]; then
            echo "Wrong filename or file doesn't exist"
            exit 1
        # if found, assign file path to "${BACKUP} variable"
        else
            BACKUP=$(aws s3 ls s3://"${S3_BUCKET}"/"${S3_PREFIX}"/"${RESTORE_TO}" --recursive | tail -n 1  | awk '{print $4}')
        fi
    # if "latest" file is defined 
    else
        # if there is no encryption string
        if [ -z "$AES_KEY" ]; then
            # request "raw" backup file
            BACKUP=$(aws s3 ls s3://"${S3_BUCKET}"/"${S3_PREFIX}"/ --recursive  | tail -n 1 | awk '{print $4}')
        else
            # request encrypted backup file
            BACKUP=$(aws s3 ls s3://"${S3_BUCKET}"/"${S3_PREFIX}"/ --recursive  | tail -n 1| grep dat | awk '{print $4}')
        fi
    fi
}

# invoke custom fuction
generateAWSPath

echo "Fetching ${BACKUP} from S3."
# if backup is not encrypted, download as/is
if [ -z "${AES_KEY}" ]; then
    aws s3 cp s3://"${S3_BUCKET}"/"${BACKUP}" dump.sql.gz
# if backup is encrypted, download and unencrypt
else    
    aws s3 cp s3://"${S3_BUCKET}"/"${BACKUP}" dump.sql.gz.dat
    openssl enc -in dump.sql.gz.dat  -out dump.sql.gz -d -aes256 -md sha256 -pbkdf2 -k "${AES_KEY}"
fi

# decompress backup file
gzip -d dump.sql.gz

# find out if database exists
echo "Obtaining list of databases"
DOJO=$(psql -h "${POSTGRESQL_HOST}" -p "${POSTGRESQL_PORT}" -U postgres -c "\l" | grep defectdojo)

# if "defectdojo" in grep result, then database exists
if [ ! "${DOJO}" = "" ]; then
    echo "Database ${POSTGRESQL_DATABASE} exists, checking active connections"
    # find out if there are active connections in the database
    NUM_ACTIVE_CONN=$(psql -h "${POSTGRESQL_HOST}" -p "${POSTGRESQL_PORT}" -U "${POSTGRESQL_USER}" -d "${POSTGRESQL_DATABASE}" -c "select count(*) from pg_stat_activity;" | awk 'FNR==3 { print $1 }')
    echo "There are ${NUM_ACTIVE_CONN} active connections to the ${POSTGRESQL_DATABASE} database"

    # if there are active connections, we must drop them first
    if [ "${NUM_ACTIVE_CONN}" -gt 0 ]; then
        # drop active connections
        echo "Dropping connections"
        psql -h "${POSTGRESQL_HOST}" -p "${POSTGRESQL_PORT}" -U postgres -d "${POSTGRESQL_DATABASE}" -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();"   
    fi

    # drop database
    echo "Dropping the ${POSTGRESQL_DATABASE} database"
    psql -h "${POSTGRESQL_HOST}" -p "${POSTGRESQL_PORT}" -U postgres -c "DROP DATABASE IF EXISTS ${POSTGRESQL_DATABASE};" 
fi

# (re)create database
echo "Creating a fresh ${POSTGRESQL_DATABASE} database"
psql -h "${POSTGRESQL_HOST}" -p "${POSTGRESQL_PORT}" -U postgres -c "CREATE DATABASE ${POSTGRESQL_DATABASE};"

echo "Restoring ${BACKUP}"
# restore backup
psql -h "${POSTGRESQL_HOST}" -p "${POSTGRESQL_PORT}" -U "${POSTGRESQL_USER}" -d "${POSTGRESQL_DATABASE}" < dump.sql
echo "Restore complete"
