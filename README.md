#### DefectDojo PostgreSQL & AWS s3 API Integration Tool ####

The purpose of this integration tool is to provide DefectDojo PostgreSQL database backup, restore and data retention functionality.

OBS - The tool assumes an AWS S3 bucket to save/fetch database dumps. You can tweak the script to a cloud storage option of your choosing, or an NFS share or path on the localhost.

#### Design ####

This integration has been designed in Bash (shellcheck-compliant), with the following Software Design paradigms in mind:

- Don't Repeat Yourself (DRY)
- Procedural Programming
- Containerization Support

#### The Challenge ####

By default, DefectDojo Helm Charts do not provide support for database management operations. This is partly due to the fact that the application ships with multiple database options to choose from, each with its own best-practices and procedures for backup and restore operations.

#### Our Solution ####

Our tool programmatically interacts with the DefectDojo PostgreSQL database to snapshot point-in-time dumps and automatically store them in AWS s3 buckets.

Conversely, the tool can be configured to automatically download a point-in-time dump from s3 and restore the database to a previous state (for disaster recovery purposes).

#### Disclaimer ####

This command-line tool is based on the following product versions at the time of this build:

- DefectDojo v2.0.3
- AWS-CLI 1.19.27

API endpoints might change in future versions of these products and might break functionality of this code.

#### Usage ####

This tool is designed to be automatically scheduled and executed in CI/CD pipelines. However, you can run it as a standalone.

The following environment variables need to be set in your shell environment:

- CMD: which operation to execute (backup | restore)
- AWS_ACCESS_KEY_ID: AWS access key ID
- AWS_SECRET_ACCESS_KEY: AWS secret access key
- S3_BUCKET: DefectDojo AWS s3 bucket name 
- S3_PREFIX: DefectDojo environment (dev | stage | prod)
- POSTGRESQL_DATABASE: DefectDojo database name (defaults to defectdojo)
- POSTGRESQL_USER: DefectDojo database admin user (defaults to defectdojo)
- POSTGRESQL_PASSWORD: DefectDojo database admin password (random generated )
- POSTGRESQL_PORT: DefectDojo database port (defaults to 5432)
- POSTGRESQL_HOST: DefectDojo database host 
- AES_KEY: For backup operations, an optional AES encrypted string to encrypt the database dump

#### Ad-Hoc Backup ####

This manual assumes that you are running DefectDojo on kubernetes. The steps would be similar for Docker-compose deployments.

The process of manual PostgreSQL database backup can be generally described as follows:

* sourcing the appropriate kubeconfig file, relative to the environment you are maintaining
* port-forwarding a local port on your machine to the PostgreSQL port on the target pod(s) in the cluster
* running this container

This container image contains the necessary scripts to:

* backup the database with [pg_dump](https://www.postgresql.org/docs/9.3/app-pgdump.html)
* upload the database dump to AWS s3 with [awscli](https://aws.amazon.com/cli/)

#### Ad-Hoc Backup Checklist ####

What you need:

* kubeconfig file or similar, to access k8s cluster resources in the target namespace
* Docker daemon running on your local machine
* AWS access key ID
* AWS secret access key
* Optionally (but highly advised), an AES encrypted string to encrypt the database dump
* PostgreSQL password

#### Backing up the Database ####

Source the __kubeconfig__ file and run the following command to connect an arbitrary local port (any port of your choosing) to the database port (5432, as of this writing):

```
$ export KUBECONFIG=${PATH/TO/KUBECONFIG}
$ kubectl port-forward pods/defectdojo-postgresql-0 3000:5432

Forwarding from 127.0.0.1:3000 -> 5432
Forwarding from [::1]:3000 -> 5432
```

Now, if you haven't yet, build the Docker image and run the following command (in a separate terminal):

```
# if you haven't yet, build the image and give it a name and tag of your liking
$ docker build -t ${IMAGE}:${TAG}
# run the backup command
$ docker run --rm --network host -e CMD=backup -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" -e S3_BUCKET="${BUCKET}" -e S3_PREFIX="${PREFIX}" -e POSTGRESQL_DATABASE="defectdojo" -e POSTGRESQL_USER="defectdojo" -e POSTGRESQL_PASSWORD="${POSTGRESQL_PASSWORD}" -e POSTGRESQL_PORT=${LOCAL_PORT} -e POSTGRESQL_HOST="{localhost|host.docker.internal}" -e AES_KEY="${AES_KEY}" ${IMAGE}:${TAG}

Creating dump of defectdojo database from host.docker.internal...
OpenSSL 1.1.1j  21 Jul 2021
SQL backup uploaded successfully
```

Replace the placeholders with appropriate values.

The database dump process can take several minutes depending on the size of the database.

If you are following this procedure on MacOS, use `host.docker.internal` or `gateway.docker.internal` instead of `localhost`.

#### Validating the Backup  ####

To validate that the database dump has been stored on AWS, run the following commands:

```
$ aws configure list

     Name                    Value             Type    Location
      ----                    -----             ----    --------
   profile                <not set>             None    None
access_key     ********************              env    
secret_key     ********************              env    
    region                eu-central-1          None    AWS_DEFAULT_REGION

$ aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX}/${YYYY}/${MM}/${DD}/
2021-03-05 12:14:36    2125904 defectdojo_12:14:33Z.sql.gz.dat
```

To get access to a shell session with awscli installed by default (and with credentials pre-configured), you can run the same previous docker command, adding the `--rm -it --entrypoint /bin/sh` flags to the `docker run` command.

The best way to assess the effectiveness of this process is by conducting a full backup/restore drill in development/staging environments regularly.

#### Restoring the Database ####

The process of manual PostgreSQL database restore can be generally described as follows:

* sourcing the appropriate kubeconfig file, relative to the environment you are maintaining
* port-forwarding a local port on your machine to the PostgreSQL port on the target pod(s) in the cluster
* running this container

This container image contains the necessary scripts to:

* download the database dump from AWS s3 with [awscli](https://aws.amazon.com/cli/)
* restore the database with [psql](https://www.postgresql.org/docs/13/app-psql.html)

#### Manual Restore Checklist ####

What you need:

* kubeconfig file or similar, to access k8s cluster resources in the target namespace
* Docker daemon running on your local machine
* AWS access key ID
* AWS secret access key
* The AES encrypted string to decrypt the database dump (only applicable if/when database dump is encrypted)
* PostgreSQL password

#### Restoring the Database ####

Source the __kubeconfig__ file and run the following command to connect an arbitrary local port (any port of your choosing) to the database port (5432, as of this writing):

```
$ export KUBECONFIG=${PATH/TO/KUBECONFIG}
$ kubectl port-forward pods/defectdojo-postgresql-0 3000:5432

Forwarding from 127.0.0.1:3000 -> 5432
Forwarding from [::1]:3000 -> 5432
```

Now, run the following command in a separate terminal:

```
$ docker run --rm --network host -e CMD=restore -e RESTORE_TO=${PIT_FILE} -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" -e S3_BUCKET="${BUCKET}" -e S3_PREFIX="${PREFIX}" -e POSTGRESQL_DATABASE="defectdojo" -e POSTGRESQL_USER="defectdojo" -e POSTGRESQL_PASSWORD="${POSTGRESQL_PASSWORD}" -e POSTGRESQL_PORT=${LOCAL_PORT} -e POSTGRESQL_HOST="{localhost|host.docker.internal}" -e AES_KEY="${AES_KEY}" ${IMAGE}:${TAG}

Requesting backup file 2021/03/10/defectdojo_14:41:57Z.sql.gz.dat
Fetching defectdojo_14:41:57Z.sql.gz.dat from S3
Restoring defectdojo_14:41:57Z.sql.gz.dat
Restore complete
```

Replace the placeholders with appropriate values. The image and tag are the same as the ones you used to build this image before the backup operation.

The database restore process can take several minutes depending on the size of the database.

If you are following this procedure on MacOS, use `host.docker.internal` or `gateway.docker.internal` instead of `localhost`.

#### Validating the Restore  ####

The best way to properly validate that the database has been restored is to head over to the DefectDojo GUI and see if your products, engagements, users and objects are there.
