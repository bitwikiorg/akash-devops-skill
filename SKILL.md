---
name: "akash-devops"
description: "Enterprise Akash Network DevOps skill for deployment management, persistent storage, debugging, backup strategies, and self-healing operations. The sentinel for Akash systems."
version: "1.0.0"
author: "Agent Zero Team"
tags: ["akash", "devops", "deployment", "kubernetes", "persistent-storage", "debugging", "backup", "self-healing", "cloud", "web3"]
trigger_patterns:
  - "akash deploy"
  - "akash deployment"
  - "akash debug"
  - "akash storage"
  - "akash backup"
  - "akash troubleshoot"
  - "persistent storage"
  - "akash migration"
  - "akash lease"
  - "provider-services"
---

# Akash DevOps: Enterprise Operations Skill

## Purpose

This skill transforms Agent Zero into a **DevOps CTO Sentinel** for Akash Network deployments, capable of:
- Deploying and managing workloads
- Implementing persistent storage strategies
- Debugging and troubleshooting issues
- Executing backup and disaster recovery
- Self-healing and monitoring deployments

---

## Table of Contents

1. [Environment Setup](#environment-setup)
2. [SDL Reference](#sdl-reference)
3. [Deployment Operations](#deployment-operations)
4. [Persistent Storage Deep Dive](#persistent-storage-deep-dive)
5. [Debugging & Troubleshooting](#debugging--troubleshooting)
6. [Backup & Disaster Recovery](#backup--disaster-recovery)
7. [Self-Healing & Monitoring](#self-healing--monitoring)
8. [Provider Selection & Management](#provider-selection--management)
9. [Common Runbooks](#common-runbooks)

---

## Environment Setup

### Required Environment Variables

```bash
# Mainnet
export AKASH_NODE="https://rpc.akashnet.net:443"
export AKASH_CHAIN_ID="akashnet-2"

# Sandbox/Testnet
export AKASH_NODE="https://rpc.sandbox-2.aksh.pw:443"
export AKASH_CHAIN_ID="sandbox-2"

# Common Settings
export AKASH_KEY_NAME="my-wallet"
export AKASH_KEYRING_BACKEND="os"
export AKASH_GAS="auto"
export AKASH_GAS_PRICES="0.025uakt"
export AKASH_GAS_ADJUSTMENT="1.5"
export AKASH_SIGN_MODE="amino-json"
```

### CLI Installation

```bash
# Linux/Mac
curl -sfL https://raw.githubusercontent.com/akash-network/provider/main/install.sh | bash
sudo mv ./bin/provider-services /usr/local/bin

# Verify
provider-services version
```

### Wallet Setup

```bash
# Create new wallet
provider-services keys add $AKASH_KEY_NAME

# Import existing wallet
provider-services keys add $AKASH_KEY_NAME --recover

# Get address
export AKASH_ACCOUNT_ADDRESS=$(provider-services keys show $AKASH_KEY_NAME -a)

# Check balance
provider-services query bank balances $AKASH_ACCOUNT_ADDRESS
```

---

## SDL Reference

### Complete SDL Structure

```yaml
version: "2.0"

services:
  app:
    image: docker.io/library/nginx:1.25-alpine
    depends-on: []
    command: []
    args: []
    env:
      - KEY=VALUE
    expose:
      - port: 80
        as: 80
        accept:
          - myapp.akash.network
        to:
          - global: true
    params:
      storage:
        - name: data
          mount: /app/data
          readOnly: false
    credentials:
      host: https://index.docker.io/v1/
      username: myuser
      password: dckr_pat_xxx

profiles:
  compute:
    standard:
      resources:
        cpu:
          units: 1.0
        memory:
          size: 1Gi
        storage:
          - name: data
            size: 10Gi
            attributes:
              persistent: true
              class: beta3
        gpu:
          units: 1
          attributes:
            vendor:
              nvidia:
                - model: rtx4090
                - model: a100
                ram: 24Gi
                interface: pcie
  placement:
    akash:
      attributes:
        region: us-west
      signedBy:
        anyOf: []
      pricing:
        standard:
          denom: uakt
          amount: 100

deployment:
  app:
    akash:
      profile: standard
      count: 1
```

### Storage Classes

| Class | Performance | Use Case |
|-------|-------------|----------|
| `beta1` | HDD | Cold storage, backups |
| `beta2` | SSD | General purpose |
| `beta3` | NVMe | Databases, high I/O |
| `ram` | Memory | Shared memory, tmpfs |

### GPU Configuration

```yaml
gpu:
  units: 1
  attributes:
    vendor:
      nvidia:           # or 'amd'
        - model: rtx4090
        - model: a100    # Fallback options
        - model: h100
        ram: 40Gi        # Min VRAM
        interface: pcie  # 'pcie' or 'sxm'
```

### HTTP Options

```yaml
expose:
  - port: 8000
    as: 80
    to:
      - global: true
    http_options:
      max_body_size: 104857600  # 100MB
      read_timeout: 60000       # 60s
      send_timeout: 60000
      next_tries: 3
      next_timeout: 30000
```

---

## Deployment Operations

### Full Deployment Workflow

```bash
# 1. Generate and publish certificate
provider-services tx cert generate client --from $AKASH_KEY_NAME
provider-services tx cert publish client --from $AKASH_KEY_NAME

# 2. Create deployment
provider-services tx deployment create deploy.yaml --from $AKASH_KEY_NAME
# Note: Save the DSEQ from output

# 3. List bids
provider-services query market bid list --owner $AKASH_ACCOUNT_ADDRESS --dseq $DSEQ

# 4. Select provider and create lease
provider-services tx market lease create \
  --dseq $DSEQ \
  --gseq 1 \
  --oseq 1 \
  --provider $PROVIDER_ADDRESS \
  --from $AKASH_KEY_NAME

# 5. Send manifest
provider-services send-manifest deploy.yaml \
  --dseq $DSEQ \
  --provider $PROVIDER_ADDRESS \
  --from $AKASH_KEY_NAME

# 6. Verify deployment
provider-services query market lease list --owner $AKASH_ACCOUNT_ADDRESS --state active
```

### Update Deployment

```bash
# Update SDL and redeploy
provider-services tx deployment update deploy.yaml \
  --dseq $DSEQ \
  --from $AKASH_KEY_NAME

# Re-send manifest to provider
provider-services send-manifest deploy.yaml \
  --dseq $DSEQ \
  --provider $PROVIDER_ADDRESS \
  --from $AKASH_KEY_NAME
```

### Close Deployment

```bash
provider-services tx deployment close \
  --dseq $DSEQ \
  --from $AKASH_KEY_NAME
```

---

## Persistent Storage Deep Dive

### Key Principles

1. **Provider-Local**: Storage is tied to a specific provider
2. **Lease-Bound**: Data is LOST when lease closes
3. **Update-Safe**: Data survives image/env updates
4. **Single Volume**: Maximum 1 persistent volume per service

### Storage Configuration

```yaml
profiles:
  compute:
    db:
      resources:
        storage:
          - name: db-data
            size: 100Gi
            attributes:
              persistent: true
              class: beta3  # NVMe for database

services:
  postgres:
    image: postgres:15
    params:
      storage:
        - name: db-data
          mount: /var/lib/postgresql/data
```

### Storage Migration Strategy

Since persistent storage is lease-bound, implement migration:

```bash
# 1. Backup data from current deployment
provider-services lease-shell \
  --from $AKASH_KEY_NAME \
  --dseq $DSEQ \
  --provider $PROVIDER_ADDRESS \
  postgres \
  "pg_dumpall > /tmp/backup.sql"

# 2. Copy backup out (use curl to upload to temp storage)

# 3. Create new deployment

# 4. Restore data
provider-services lease-shell \
  --from $AKASH_KEY_NAME \
  --dseq $NEW_DSEQ \
  --provider $NEW_PROVIDER_ADDRESS \
  postgres \
  "psql < /tmp/backup.sql"
```

### Storage Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Disk full | Storage capacity reached | Increase storage size, clean logs, use ephemeral for temp |
| Slow I/O | Wrong storage class | Use `beta3` (NVMe) for databases |
| Data loss | Lease closed | Restore from backup |
| Hostname conflict | Duplicate hostname | Use unique hostnames in `accept` field |

---

## Debugging & Troubleshooting

### Access Container Shell

```bash
# Interactive shell
provider-services lease-shell \
  --from $AKASH_KEY_NAME \
  --dseq $DSEQ \
  --provider $PROVIDER_ADDRESS \
  --tty \
  myservice /bin/bash

# Single command
provider-services lease-shell \
  --from $AKASH_KEY_NAME \
  --dseq $DSEQ \
  --provider $PROVIDER_ADDRESS \
  myservice "cat /var/log/app.log"
```

### Check Deployment Status

```bash
# List all active leases
provider-services query market lease list \
  --owner $AKASH_ACCOUNT_ADDRESS \
  --state active

# Get deployment details
provider-services query deployment get \
  --owner $AKASH_ACCOUNT_ADDRESS \
  --dseq $DSEQ

# Check provider status
provider-services status $PROVIDER_ADDRESS
```

### View Logs

```bash
# Provider logs (from provider side)
kubectl logs akash-provider-0 -n akash-services --tail=100 -f

# Tenant logs via CLI
provider-services lease-logs \
  --from $AKASH_KEY_NAME \
  --dseq $DSEQ \
  --provider $PROVIDER_ADDRESS
```

### Common Issues & Fixes

#### Container Won't Start

```bash
# Check if image exists
docker pull myimage:mytag

# Check SDL syntax
provider-services tx deployment validate deploy.yaml

# Check resource allocation - ensure enough CPU/memory
```

#### Manifest Send Fails

```bash
# Common causes:
# 1. Hostname already in use - change accept field
# 2. Certificate expired - regenerate and publish
# 3. Invalid SDL - validate syntax

# Regenerate certificate
provider-services tx cert generate client --from $AKASH_KEY_NAME --override
provider-services tx cert publish client --from $AKASH_KEY_NAME
```

#### Escrow Depleted

```bash
# Check escrow balance
provider-services query deployment get --owner $AKASH_ACCOUNT_ADDRESS --dseq $DSEQ

# Deposit more funds
provider-services tx deployment deposit 5000000uakt \
  --dseq $DSEQ \
  --from $AKASH_KEY_NAME
```

#### Provider Unreachable

```bash
# Check provider status
provider-services query provider get $PROVIDER_ADDRESS

# List alternative providers
provider-services query provider list

# Migrate to new provider (requires data migration)
```

---

## Backup & Disaster Recovery

### Strategy Overview

| Method | Data Survivability | Complexity |
|--------|-------------------|------------|
| Persistent Storage | Lease duration | Low |
| Sidecar Backup | External storage | Medium |
| Database Replication | Real-time | High |
| Scheduled Exports | Manual restore | Medium |

### Sidecar Backup Container

```yaml
services:
  app:
    image: myapp:latest
    expose:
      - port: 80
        to:
          - global: true
    params:
      storage:
        - name: data
          mount: /data

  backup:
    image: restic/restic:latest
    args:
      - "backup"
      - "/data"
    env:
      - RESTIC_REPOSITORY=s3:s3.amazonaws.com/my-bucket
      - RESTIC_PASSWORD=xxx
      - AWS_ACCESS_KEY_ID=xxx
      - AWS_SECRET_ACCESS_KEY=xxx
    params:
      storage:
        - name: data
          mount: /data
          readOnly: true
```

### Database Backup Script

```bash
#!/bin/bash
# backup-postgres.sh
# Run inside container via lease-shell

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/tmp/backup_${DATE}.sql"

pg_dumpall -U postgres > $BACKUP_FILE

# Upload to external storage
curl -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  --data-binary @$BACKUP_FILE \
  "https://storage.example.com/backups/${BACKUP_FILE}"

rm $BACKUP_FILE
```

### Automated Backup with Cron

```yaml
services:
  db:
    image: postgres:15
    env:
      - POSTGRES_PASSWORD=xxx
      - CRON_SCHEDULE=0 2 * * *  # Daily at 2 AM
    command:
      - /bin/sh
      - -c
      - |
        echo "$CRON_SCHEDULE pg_dumpall > /backup/daily.sql" | crontab -
        postgres
    params:
      storage:
        - name: db-data
          mount: /var/lib/postgresql/data
        - name: backup
          mount: /backup
```

---

## Self-Healing & Monitoring

### Health Check Configuration

```yaml
services:
  app:
    image: myapp:latest
    expose:
      - port: 8080
        to:
          - global: true
    http_options:
      max_body_size: 104857600
    # Health monitoring via HTTP endpoint
```

### Monitoring Commands

```bash
# Check deployment health
provider-services query deployment get \
  --owner $AKASH_ACCOUNT_ADDRESS \
  --dseq $DSEQ

# Monitor provider capacity
curl -s https://console-api.akash.network/v1/providers/$PROVIDER_ADDRESS | jq '.capacity'

# Check active leases
provider-services query market lease list \
  --owner $AKASH_ACCOUNT_ADDRESS \
  --state active
```

### Automated Escrow Monitoring

```bash
#!/bin/bash
# check-escrow.sh

BALANCE=$(provider-services query bank balances $AKASH_ACCOUNT_ADDRESS -o json | \
  jq -r '.balances[] | select(.denom=="uakt") | .amount')

if [ "$BALANCE" -lt 1000000 ]; then
  echo "WARNING: Low balance: ${BALANCE} uakt"
  # Alert mechanism (email, webhook, etc.)
fi
```

### Self-Healing Script

```bash
#!/bin/bash
# self-heal-deployment.sh

# Check if deployment is active
DEPLOYMENT_STATE=$(provider-services query deployment get \
  --owner $AKASH_ACCOUNT_ADDRESS \
  --dseq $DSEQ -o json | jq -r '.deployment.state')

if [ "$DEPLOYMENT_STATE" != "active" ]; then
  echo "Deployment not active, attempting recovery..."
  
  # Check for closed lease
  LEASE_STATE=$(provider-services query market lease list \
    --owner $AKASH_ACCOUNT_ADDRESS --dseq $DSEQ -o json | \
    jq -r '.leases[0].lease.state')
  
  if [ "$LEASE_STATE" == "closed" ]; then
    echo "Lease closed. Creating new deployment..."
    # Trigger new deployment
    provider-services tx deployment create deploy.yaml --from $AKASH_KEY_NAME
  fi
fi
```

---

## Provider Selection & Management

### Evaluate Providers

```bash
# List all providers
provider-services query provider list -o json | jq '.[]'

# Get provider details
provider-services query provider get $PROVIDER_ADDRESS -o json

# Check via Console API
curl -s https://console-api.akash.network/v1/providers/$PROVIDER_ADDRESS | jq '.'
```

### Provider Selection Criteria

```yaml
placement:
  akash:
    attributes:
      region: us-west           # Geographic location
      tier: enterprise          # Quality tier
      host: akash               # Provider type
    signedBy:
      anyOf:
        - akash1...             # Audited provider signature
    pricing:
      standard:
        denom: uakt
        amount: 100             # Max price per block
```

### Check Provider Attributes

```bash
# Available attributes to filter by:
# - region: us-west, us-east, eu-west, asia-east
# - tier: community, enterprise
# - host: akash
# - feat-persistent-storage: "true"
# - feat-endpoint-ip: "true"
```

---

## Common Runbooks

### Runbook: Deployment Won't Start

1. Validate SDL syntax
2. Check wallet has sufficient funds
3. Verify certificate is published
4. Check provider has capacity
5. Review provider logs
6. Test image locally

### Runbook: Data Recovery

1. Identify if lease is still active
2. If active: access via lease-shell
3. If closed: restore from backup
4. Verify data integrity
5. Update backup procedures

### Runbook: Provider Migration

1. Backup all persistent data
2. Close current deployment
3. Create new deployment
4. Select new provider
5. Send manifest
6. Restore data from backup
7. Verify application functionality

### Runbook: Escrow Depleted

1. Check escrow balance
2. Deposit additional funds
3. Monitor for auto-restart
4. Set up balance monitoring

---

## Quick Reference Cards

### Essential Commands

| Task | Command |
|------|--------|
| Create deployment | `provider-services tx deployment create deploy.yaml --from $AKASH_KEY_NAME` |
| List bids | `provider-services query market bid list --owner $ADDR --dseq $DSEQ` |
| Create lease | `provider-services tx market lease create --dseq $DSEQ --provider $PROVIDER --from $AKASH_KEY_NAME` |
| Send manifest | `provider-services send-manifest deploy.yaml --dseq $DSEQ --provider $PROVIDER --from $AKASH_KEY_NAME` |
| Shell access | `provider-services lease-shell --tty --from $AKASH_KEY_NAME --dseq $DSEQ --provider $PROVIDER svc /bin/bash` |
| Close deployment | `provider-services tx deployment close --dseq $DSEQ --from $AKASH_KEY_NAME` |
| Check balance | `provider-services query bank balances $AKASH_ACCOUNT_ADDRESS` |
| List providers | `provider-services query provider list` |

### Resource Limits

| Resource | Minimum | Maximum |
|----------|---------|---------|
| CPU | 0.01 cores | 384 cores |
| Memory | 1 Mi | 2 Ti |
| Storage | 1 Mi | 32 Ti per volume |
| Persistent volumes | 0 | 1 per service |

---

## Templates

See `/a0/skills/akash-devops/templates/` for:
- `deploy-base.yaml` - Basic deployment template
- `deploy-persistent.yaml` - Persistent storage template
- `deploy-gpu.yaml` - GPU workload template
- `deploy-multi-service.yaml` - Multi-service template

## Scripts

See `/a0/skills/akash-devops/scripts/` for:
- `deploy.sh` - Full deployment automation
- `backup.sh` - Backup automation
- `monitor.sh` - Health monitoring
- `migrate.sh` - Provider migration
