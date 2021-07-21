# this image is a port from https://github.com/dsever/dockerfiles-1/postgres-backup-s3
# with a few differences:
# - bump alpine to 3.12
# - comment out ENV directives
# - Python2.7 is deprecated, Python3 stack is installed instead
# - merge backup/restore Dockerfiles into a single one
#
# NOTE: This image uses pip3 to install AWS-CLI.
# Amazon does provide binaries for AWS-CLI, but none for Alpine.
# Setting up the environment for an Alpine binary build requires too many
# packages, bloats the image and defeats the purpose of using Alpine at all.
# The same goes for environment variables.
#
# pull base image
FROM alpine:3.13.5
# set labels
LABEL maintainer="original: Johannes Schickling <schickling.j@gmail.com>, update: Yuri Neves <yuri.neves@pan-net.eu>, Dubravko Sever <dubravko.sever@pan-net.eu>" \
      app="defectdojo-postgresql-s3" \
      description="Periodic PostgreSQL Backup to AWS S3" \
      sourcerepo="https://github.com/dsever/dockerfiles-1"
# update APK repositories 
# install Python3 and Py3-PIP (Python2.7 is deprecated)
# install AWS CLI
# install Go-Cron Linux
# set appropriate permissions to executable file and remove APK cache
RUN apk update && \
    apk add openssl \
    postgresql curl python3 py3-pip && \
    pip3 install --upgrade pip && \
    pip3 install awscli && \
    python3 -m pip install --upgrade awscli && \
    curl -L --insecure https://github.com/odise/go-cron/releases/download/v0.0.6/go-cron-linux.gz | zcat > /usr/local/bin/go-cron && \
    chmod u+x /usr/local/bin/go-cron && \
    apk del curl && \
    rm -rf /var/cache/apk/*
# default environment variables
# these are kept as comment for historical reasons
# these variables should be injected at container runtime
# ENV POSTGRESQL_DATABASE **None**
# ENV POSTGRESQL_HOST **None**
# ENV POSTGRESQL_PORT 5432
# ENV POSTGRESQL_USER **None**
# ENV POSTGRESQL_PASSWORD **None**
# ENV AWS_ACCESS_KEY_ID **None**
# ENV AWS_SECRET_ACCESS_KEY **None**
# ENV AWS_DEFAULT_REGION eu-central-1
# ENV S3_S3V4 no
# ENV SCHEDULE **None**
# ENV AES_KEY **None*
# ENV RESTORE_TO **None**
# ENV CMD **None*
# copy scripts over
COPY . .
# ideally, run the application as un unprivileged user
# however, I didn't have the chance to test it with this
# user, so I'm commenting the line.
# USER 5000
# run scripts
CMD ["sh", "run.sh"]
