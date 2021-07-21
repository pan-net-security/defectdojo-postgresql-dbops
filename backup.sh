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

echo "Creating dump of ${POSTGRESQL_DATABASE} database from ${POSTGRESQL_HOST}..."
# print OpenSSL version
openssl version
# online dump the PostgreSQL database
pg_dump -h "${POSTGRESQL_HOST}" -p "${POSTGRESQL_PORT}" -U "${POSTGRESQL_USER}" "${POSTGRESQL_DATABASE}" | gzip > dump.sql.gz
# in case of problems, pg_dump stderr message pipes to gzip,
# causing the error message to be archived instead.
# attempt to sanitize it, assuming error if dump size is less than 1KiB
DUMPSIZE=$(stat -c %s "dump.sql.gz")
echo "${DUMPSIZE}"
if [ "${DUMPSIZE}" -le 1000 ]; then
    echo "Database dump less than 1K in size, assuming an error"
    exit 1
fi
# if AES_KEY does not exist, upload unencrypted database dump to s3
if [ -z "${AES_KEY}" ]; then
    echo "Uploading dump to ${S3_BUCKET}"
    (aws s3 cp - s3://"${S3_BUCKET}"/"${S3_PREFIX}"/"$(date +"%Y")"/"$(date +"%m")"/"$(date +"%d")"/"${POSTGRESQL_DATABASE}"_"$(date +"%H:%M:%SZ")".sql.gz < dump.sql.gz) || exit 2
# if AES_KEY exists, upload encrypted database dump to s3
else
    openssl enc -in dump.sql.gz  -out dump.sql.gz.dat -e -aes256  -pbkdf2 -md sha256 -k "${AES_KEY}"
    (aws s3 cp - s3://"${S3_BUCKET}"/"${S3_PREFIX}"/"$(date +"%Y")"/"$(date +"%m")"/"$(date +"%d")"/"${POSTGRESQL_DATABASE}"_"$(date +"%H:%M:%SZ")".sql.gz.dat < dump.sql.gz.dat) || exit 2
fi
# print success message
echo "SQL backup uploaded successfully"
