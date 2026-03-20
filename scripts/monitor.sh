#!/bin/bash
# Akash Monitoring Script
# Usage: ./monitor.sh [dseq] [provider]

DSEQ="$1"
PROVIDER="$2"
KEY_NAME="${AKASH_KEY_NAME}"
ACCOUNT_ADDRESS=$(provider-services keys show $KEY_NAME -a 2>/dev/null)

echo "=== Akash Deployment Monitor ==="
echo "Time: $(date)"
echo ""

# Wallet balance
echo "=== Wallet Balance ==="
if [ -n "$ACCOUNT_ADDRESS" ]; then
    provider-services query bank balances $ACCOUNT_ADDRESS -o json | \
        jq -r '.balances[] | "\(.denom): \(.amount)"'
else
    echo "No account address available"
fi

# Active deployments
echo ""
echo "=== Active Deployments ==="
provider-services query deployment list --owner $ACCOUNT_ADDRESS --state active -o json | \
    jq -r '.deployments[] | "DSEQ: \(.deployment.deployment_id.dseq) | State: \(.deployment.state)"'

# Active leases
echo ""
echo "=== Active Leases ==="
provider-services query market lease list --owner $ACCOUNT_ADDRESS --state active -o json | \
    jq -r '.leases[] | "DSEQ: \(.lease.lease_id.dseq) | Provider: \(.lease.lease_id.provider) | Price: \(.lease.price.amount)uakt"'

# Specific deployment status
if [ -n "$DSEQ" ]; then
    echo ""
    echo "=== Deployment $DSEQ Status ==="
    provider-services query deployment get --owner $ACCOUNT_ADDRESS --dseq $DSEQ -o json | \
        jq '.deployment | {state, version, created_at}'
    
    # Escrow info
    echo ""
    echo "=== Escrow Balance ==="
    provider-services query deployment get --owner $ACCOUNT_ADDRESS --dseq $DSEQ -o json | \
        jq '.escrow_account | {balance: .balance, transferred: .transferred}'
fi

# Provider status
if [ -n "$PROVIDER" ]; then
    echo ""
    echo "=== Provider Status ==="
    curl -s "https://console-api.akash.network/v1/providers/$PROVIDER" | \
        jq '{address: .address, isOnline: .isOnline, uptime: .uptime, activeLeases: .leaseCount}' 2>/dev/null || \
        echo "Could not fetch provider status"
fi

echo ""
echo "=== Network Stats ==="
curl -s "https://console-api.akash.network/v1/network/stats" | \
    jq '{activeProviders: .activeProviders, activeLeases: .activeLeases, totalCompute: .totalCompute}' 2>/dev/null || \
    echo "Could not fetch network stats"
