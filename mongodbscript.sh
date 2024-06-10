#!/bin/bash

# Function to show usage

usage() {
    echo "Usage: $0"
    echo "  -t <db_type>"
    echo "  -u <username>"
    echo "  -p <password>"
    echo "  -d <database_names>"
    echo "  -h <hostname>"
    echo "  -P <port>"
    echo "  -a <aws_snap(true/false)>"
    echo "  -b <backup_dir>"
    echo "  -s <s3_bucketname>"
    echo "  -r <retention_days>"
    exit 1
}

# Function to log errors
log_error() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - ERROR: $1" >> backup.log
}

# Parse arguments
while getopts ":t:u:p:d:h:P:a:b:s:r:" opt; do
    case $opt in
        t) DB_TYPE="$OPTARG" ;;
        u) DB_USERNAME="$OPTARG" ;;
        p) DB_PASSWORD="$OPTARG" ;;
        d) DB_NAMES="$OPTARG" ;;  # Accept comma-separated list of database names
        h) DB_HOSTNAME="$OPTARG" ;;
        P) DB_PORT="$OPTARG" ;;
        a) AWS_SNAP="$OPTARG" ;;
        b) BACKUP_DIR="$OPTARG" ;;
        s) S3_BUCKET="$OPTARG" ;;
        r) RETENTION_DAYS="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check for mandatory arguments
if [ -z "$DB_TYPE" ] || [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_NAMES" ] || [ -z "$DB_HOSTNAME" ] || [ -z "$DB_PORT" ] || [ -z "$BACKUP_DIR" ] || [ -z "$S3_BUCKET" ] || [ -z "$RETENTION_DAYS" ]; then
    usage
fi

# Current date
CURRENT_DATE=$(date +"%Y-%m-%d")

# Database backup function
backup_database() {
    if [ "$DB_TYPE" == "mysql" ]; then
        IFS=',' read -ra DB_ARRAY <<< "$DB_NAMES"  # Split database names into an array
        for DB_NAME in "${DB_ARRAY[@]}"; do
            BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${CURRENT_DATE}.sql.gz"
            mysqldump -h $DB_HOSTNAME -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME | gzip > $BACKUP_FILE
            if [ -f "$BACKUP_FILE" ]; then
                echo "Database backup successful: $BACKUP_FILE"
            else
                log_error "Database backup failed for $DB_NAME"
                exit 1
            fi
        done
    else
        case $DB_TYPE in
            mongodb)
                BACKUP_FILE="${BACKUP_DIR}/${DB_NAMES}_${CURRENT_DATE}.gz"
                mongodump --host $DB_HOSTNAME --port $DB_PORT --username $DB_USERNAME --password $DB_PASSWORD --authenticationDatabase admin  --db $DB_NAMES --archive=$BACKUP_FILE --gzip
                ;;
            snowflake)
                echo "Snowflake backup not implemented"
                ;;
            postgrase)
                BACKUP_FILE="${BACKUP_DIR}/${DB_NAMES}_${CURRENT_DATE}.sql.gz"
                PGPASSWORD=$DB_PASSWORD pg_dump -h $DB_HOSTNAME -p $DB_PORT -U $DB_USERNAME $DB_NAMES | gzip > $BACKUP_FILE
                ;;
            hive)
                echo "Hive backup not implemented"
                ;;
            apache-Iceberg)
                echo "Apache Iceberg backup not implemented"
                ;;
            presto)
                echo "Presto backup not implemented"
                ;;
            neo4j)
                BACKUP_FILE="${BACKUP_DIR}/${DB_NAMES}_${CURRENT_DATE}.dump"
                neo4j-admin dump --database=$DB_NAMES --to=$BACKUP_FILE
                ;;
            *)
                log_error "Unsupported database type: $DB_TYPE"
                exit 1
                ;;
        esac

        if [ -f "$BACKUP_FILE" ]; then
            echo "Database backup successful: $BACKUP_FILE"
        else
            log_error "Database backup failed"
            exit 1
        fi
    fi
}

# Application framework backup function
backup_app_framework() {
    APP_BACKUP_FILE="${BACKUP_DIR}/app_framework_${CURRENT_DATE}.tar.gz"
    tar -czvf $APP_BACKUP_FILE /app/framework
    if [ -f "$APP_BACKUP_FILE" ]; then
        echo "Application framework backup successful: $APP_BACKUP_FILE"
    else
        log_error "Application framework backup failed"
        exit 1
    fi
}

# Main script execution
backup_database
if [ $? -ne 0 ]; then
    log_error "Database backup function failed"
    exit 1
fi

backup_app_framework
if [ $? -ne 0 ]; then
    log_error "Application framework backup function failed"
    exit 1
fi

echo "Backup script completed successfully"
