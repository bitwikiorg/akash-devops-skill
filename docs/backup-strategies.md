# Backup Strategies for Akash

## Critical Understanding

⚠️ **Persistent storage data is LOST when:**
- Lease is closed
- Deployment migrates to new provider
- Provider experiences storage failure

## Backup Methods

### 1. Sidecar Backup Container

Run a backup service alongside your main application:

```yaml
services:
  app:
    image: myapp:latest
    params:
      storage:
        - name: data
          mount: /data

  backup:
    image: restic/restic:latest
    args: ["backup", "/data"]
    env:
      - RESTIC_REPOSITORY=s3:s3.amazonaws.com/bucket
      - RESTIC_PASSWORD=xxx
      - AWS_ACCESS_KEY_ID=xxx
      - AWS_SECRET_ACCESS_KEY=xxx
    params:
      storage:
        - name: data
          mount: /data
          readOnly: true
```

### 2. Scheduled Database Dumps

For PostgreSQL:
```bash
# Inside container
echo "0 2 * * * pg_dumpall -U postgres > /backup/daily.sql" | crontab -
```

For MySQL:
```bash
echo "0 2 * * * mysqldump -u root -p\$MYSQL_ROOT_PASSWORD --all-databases > /backup/daily.sql" | crontab -
```

### 3. External Replication

Replicate to external database:
- AWS RDS
- Google Cloud SQL
- Self-hosted server

### 4. Manual Backups

```bash
# Create backup
provider-services lease-shell --from $AKASH_KEY_NAME \
  --dseq $DSEQ --provider $PROVIDER $SERVICE \
  "pg_dumpall > /tmp/backup.sql"

# Transfer to external storage
provider-services lease-shell --from $AKASH_KEY_NAME \
  --dseq $DSEQ --provider $PROVIDER $SERVICE \
  "curl -X PUT --data-binary @/tmp/backup.sql https://storage.example.com/backup"
```

## Recovery Procedures

### From Backup

1. Create new deployment
2. Restore data from backup
3. Verify integrity
4. Update DNS/hostname if needed

### Full Migration

1. Backup current deployment
2. Close old deployment
3. Create new deployment
4. Restore data
5. Verify application
