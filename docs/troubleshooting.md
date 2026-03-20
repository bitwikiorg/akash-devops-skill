# Akash Troubleshooting Guide

## Common Issues and Solutions

### 1. Deployment Creation Fails

**Symptoms:**
- `insufficient funds` error
- `invalid SDL` error
- `certificate not found` error

**Solutions:**
```bash
# Check balance
provider-services query bank balances $AKASH_ACCOUNT_ADDRESS

# Validate SDL
cat deploy.yaml | head -20  # Check syntax

# Regenerate certificate
provider-services tx cert generate client --from $AKASH_KEY_NAME --override
provider-services tx cert publish client --from $AKASH_KEY_NAME
```

### 2. No Bids Received

**Symptoms:**
- Empty bid list after deployment creation
- Long wait with no provider response

**Solutions:**
- Verify SDL has reasonable pricing
- Check network connectivity
- Try different resource requirements
- Wait longer (can take 2-5 minutes)

```bash
# Check if deployment is active
provider-services query deployment get --owner $AKASH_ACCOUNT_ADDRESS --dseq $DSEQ

# List all bids including closed
provider-services query market bid list --owner $AKASH_ACCOUNT_ADDRESS --dseq $DSEQ
```

### 3. Manifest Send Fails

**Symptoms:**
- `hostname already in use` error
- `certificate expired` error
- Connection timeout

**Solutions:**
```bash
# Change hostname in SDL
# Old: accept: ["myapp.akash.network"]
# New: accept: ["myapp-v2.akash.network"]

# Check certificate expiration
provider-services query cert list --owner $AKASH_ACCOUNT_ADDRESS

# Regenerate certificate
provider-services tx cert generate client --from $AKASH_KEY_NAME --override
provider-services tx cert publish client --from $AKASH_KEY_NAME
```

### 4. Container Won't Start

**Symptoms:**
- Lease active but no response
- Connection refused
- Health check failures

**Solutions:**
```bash
# Shell into container
provider-services lease-shell --tty --from $AKASH_KEY_NAME \
  --dseq $DSEQ --provider $PROVIDER $SERVICE /bin/sh

# Check container logs
provider-services lease-logs --from $AKASH_KEY_NAME \
  --dseq $DSEQ --provider $PROVIDER

# Common issues:
# - Wrong port exposed
# - Missing environment variables
# - Image doesn't exist
# - Insufficient resources
```

### 5. Persistent Storage Issues

**Symptoms:**
- Data disappeared after update
- Disk full errors
- Slow I/O performance

**Solutions:**
```bash
# Storage is LOST when lease closes - this is expected
# Data survives image/env updates

# Check disk usage
provider-services lease-shell --from $AKASH_KEY_NAME \
  --dseq $DSEQ --provider $PROVIDER $SERVICE "df -h"

# Use beta3 class for databases
# Increase storage size in SDL
storage:
  - size: 50Gi  # Increase from 10Gi
    attributes:
      persistent: true
      class: beta3
```

### 6. Escrow Depleted

**Symptoms:**
- Containers stopped unexpectedly
- Deployment shows `insufficient funds`

**Solutions:**
```bash
# Check escrow balance
provider-services query deployment get \
  --owner $AKASH_ACCOUNT_ADDRESS --dseq $DSEQ -o json | \
  jq '.escrow_account'

# Deposit more funds
provider-services tx deployment deposit 10000000uakt \
  --dseq $DSEQ --from $AKASH_KEY_NAME

# Set up monitoring to prevent future depletion
./scripts/monitor.sh
```

### 7. Provider Unreachable

**Symptoms:**
- Cannot send manifest
- Lease shows offline
- Timeouts on connections

**Solutions:**
```bash
# Check provider status
curl -s https://console-api.akash.network/v1/providers/$PROVIDER | jq '.isOnline'

# If offline, migrate to new provider
./scripts/migrate.sh $DSEQ $PROVIDER deploy.yaml
```

### 8. Shell Access Issues

**Symptoms:**
- Connection refused
- Permission denied
- Wrong shell binary

**Solutions:**
```bash
# Try different shells
provider-services lease-shell --tty --from $AKASH_KEY_NAME \
  --dseq $DSEQ --provider $PROVIDER $SERVICE /bin/bash

provider-services lease-shell --tty --from $AKASH_KEY_NAME \
  --dseq $DSEQ --provider $PROVIDER $SERVICE /bin/sh

provider-services lease-shell --tty --from $AKASH_KEY_NAME \
  --dseq $DSEQ --provider $PROVIDER $SERVICE /bin/ash
```

## Diagnostic Commands

```bash
# Full deployment status
provider-services query deployment get \
  --owner $AKASH_ACCOUNT_ADDRESS --dseq $DSEQ -o json | jq '.'

# Lease status
provider-services query market lease list \
  --owner $AKASH_ACCOUNT_ADDRESS --state active

# Provider information
provider-services query provider get $PROVIDER

# Network status
provider-services status
```
