#!/bin/bash
# Akash Backup Script
# Usage: ./backup.sh <dseq> <provider> <service> [key-name]

set -e

DSEQ="$1"
PROVIDER="$2"
SERVICE="$3"
KEY_NAME="${4:-$AKASH_KEY_NAME}"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Akash Backup Script ==="
echo "DSEQ: $DSEQ"
echo "Provider: $PROVIDER"
echo "Service: $SERVICE"

mkdir -p $BACKUP_DIR

# Interactive shell commands
# Note: For database backups, adapt commands to your database type

echo "\nSelect backup type:"
echo "1) Filesystem (tar.gz)"
echo "2) PostgreSQL (pg_dump)"
echo "3) MySQL (mysqldump)"
echo "4) MongoDB (mongodump)"
read -p "Choice [1-4]: " CHOICE

case $CHOICE in
    1)
        echo "Creating filesystem backup..."
        provider-services lease-shell \
            --from $KEY_NAME \
            --dseq $DSEQ \
            --provider $PROVIDER \
            $SERVICE "tar czf /tmp/backup_${TIMESTAMP}.tar.gz -C /data ."
        
        echo "Backup created: /tmp/backup_${TIMESTAMP}.tar.gz"
        echo "Use lease-shell or additional tooling to transfer to external storage"
        ;;
    2)
        echo "Creating PostgreSQL backup..."
        provider-services lease-shell \
            --from $KEY_NAME \
            --dseq $DSEQ \
            --provider $PROVIDER \
            $SERVICE "pg_dumpall -U postgres > /tmp/backup_${TIMESTAMP}.sql"
        
        echo "Backup created: /tmp/backup_${TIMESTAMP}.sql"
        ;;
    3)
        echo "Creating MySQL backup..."
        provider-services lease-shell \
            --from $KEY_NAME \
            --dseq $DSEQ \
            --provider $PROVIDER \
            $SERVICE "mysqldump -u root -p\$MYSQL_ROOT_PASSWORD --all-databases > /tmp/backup_${TIMESTAMP}.sql"
        ;;
    4)
        echo "Creating MongoDB backup..."
        provider-services lease-shell \
            --from $KEY_NAME \
            --dseq $DSEQ \
            --provider $PROVIDER \
            $SERVICE "mongodump --archive=/tmp/backup_${TIMESTAMP}.archive"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo "\n=== Backup Complete ==="
echo "Backup file is in container's /tmp directory"
echo "Transfer to external storage using:"
echo "  provider-services lease-shell --from $KEY_NAME --dseq $DSEQ --provider $PROVIDER $SERVICE \"curl -X PUT --data-binary @/tmp/backup_${TIMESTAMP}.tar.gz https://your-storage/backup\""
