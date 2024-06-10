#!/bin/bash

# Function to show usage
usage() {
    echo "Usage: $0 -t <db_type> -u <username> -p <password> -d <database_name> -h <hostname> -P <port> -a <aws_snap> -b <backup_dir> -s <s3_bucket> -r <retention_days>"
    exit 1
}

# Parse arguments
while getopts ":t:u:p:d:h:P:a:b:s:r:" opt; do
    case $opt in
        t) DB_TYPE="$OPTARG" ;;
        u) DB_USERNAME="$OPTARG" ;;
        p) DB_PASSWORD="$OPTARG" ;;
        d) DB_NAME="$OPTARG" ;;
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
if [ -z "$DB_TYPE" ] || [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_NAME" ] || [ -z "$DB_HOSTNAME" ] || [ -z "$DB_PORT" ] || [ -z "$BACKUP_DIR" ] || [ -z "$S3_BUCKET" ] || [ -z "$RETENTION_DAYS" ]; then
    usage
fi

# Current date
CURRENT_DATE=$(date +"%Y-%m-%d")

# Database backup function
backup_database() {
    case $DB_TYPE in
        mysql)
            BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${CURRENT_DATE}.sql.gz"
            mysqldump -h $DB_HOSTNAME -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME | gzip > $BACKUP_FILE
            ;;
        mongodb)
            BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${CURRENT_DATE}.gz"
            mongodump --host $DB_HOSTNAME --port $DB_PORT --username $DB_USERNAME --password $DB_PASSWORD --db $DB_NAME --archive=$BACKUP_FILE --gzip
            ;;
        snowflake)
            # Snowflake backups would typically use Snowflake-specific tools or API calls
            echo "Snowflake backup not implemented"
            ;;
        postgrase)
            BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${CURRENT_DATE}.sql.gz"
            PGPASSWORD=$DB_PASSWORD pg_dump -h $DB_HOSTNAME -p $DB_PORT -U $DB_USERNAME $DB_NAME | gzip > $BACKUP_FILE
            ;;
        hive)
            # Hive backup would typically require specific commands, not shown here
            echo "Hive backup not implemented"
            ;;
        apache-Iceberg)
            # Apache Iceberg backup would typically require specific commands, not shown here
            echo "Apache Iceberg backup not implemented"
            ;;
        presto)
            # Presto backup would typically require specific commands, not shown here
            echo "Presto backup not implemented"
            ;;
        neo4j)
            BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${CURRENT_DATE}.dump"
            neo4j-admin dump --database=$DB_NAME --to=$BACKUP_FILE
            ;;
        *)
            echo "Unsupported database type: $DB_TYPE"
            exit 1
            ;;
    esac

    if [ -f "$BACKUP_FILE" ]; then
        echo "Database backup successful: $BACKUP_FILE"
    else
        echo "Database backup failed"
        exit 1
    fi
}

# Application framework backup function
backup_app_framework() {
    APP_BACKUP_FILE="${BACKUP_DIR}/app_framework_${CURRENT_DATE}.tar.gz"
    tar -czvf $APP_BACKUP_FILE /app/framework
    if [ -f "$APP_BACKUP_FILE" ]; then
        echo "Application framework backup successful: $APP_BACKUP_FILE"
    else
        echo "Application framework backup failed"
        exit 1
    fi
}

# EC2 snapshot function
#create_ec2_snapshot() {
#    if [ "$AWS_SNAP" == "true" ]; then
#        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
#        SNAPSHOT_ID=$(aws ec2 create-snapshot --description "EC2 snapshot on $CURRENT_DATE" --volume-id $INSTANCE_ID --query SnapshotId --output text)
#        if [ -n "$SNAPSHOT_ID" ]; then
#            echo "EC2 snapshot created: $SNAPSHOT_ID"
#        else
#            echo "EC2 snapshot failed"
#            exit 1
#        fi
#    fi
#}

# Upload to S3
upload_to_s3() {
    aws s3 cp $1 s3://$S3_BUCKET/
    if [ $? -eq 0 ]; then
        echo "Upload to S3 successful: $1"
    else
        echo "Upload to S3 failed: $1"
        exit 1
    fi
}

# Remove old backups from S3
remove_old_backups() {
    aws s3 ls s3://$S3_BUCKET/ | while read -r line; do
        CREATE_DATE=$(echo $line | awk {print $1" "$2})
        CREATE_DATE=$(date -d"$CREATE_DATE" +%s)
        CURRENT_DATE=$(date +%s)
        AGE=$(( ($CURRENT_DATE - $CREATE_DATE) / 86400 ))
        if [ $AGE -gt $RETENTION_DAYS ]; then
            FILE_NAME=$(echo $line | awk {print $4})
            if [ "$FILE_NAME" != "" ]; then
                aws s3 rm s3://$S3_BUCKET/$FILE_NAME
                echo "Deleted $FILE_NAME from S3 bucket"
            fi
        fi
    done
}

# Main script execution
backup_database
backup_app_framework
#create_ec2_snapshot

# Compress and upload backups to S3
upload_to_s3 $BACKUP_FILE
upload_to_s3 $APP_BACKUP_FILE

# Remove old backups from S3
remove_old_backups

echo "Backup script completed successfully"
