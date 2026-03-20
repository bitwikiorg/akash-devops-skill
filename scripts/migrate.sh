#!/bin/bash
# Akash Provider Migration Script
# Usage: ./migrate.sh <old-dseq> <old-provider> <sdl-file> [key-name]

set -e

OLD_DSEQ="$1"
OLD_PROVIDER="$2"
SDL_FILE="${3:-deploy.yaml}"
KEY_NAME="${4:-$AKASH_KEY_NAME}"

if [ -z "$OLD_DSEQ" ] || [ -z "$OLD_PROVIDER" ]; then
    echo "Usage: $0 <old-dseq> <old-provider> <sdl-file> [key-name]"
    echo ""
    echo "This script helps migrate a deployment to a new provider."
    echo "Note: Persistent storage data will be LOST - backup first!"
    exit 1
fi

echo "=== Akash Provider Migration ==="
echo ""
echo "⚠️  WARNING: Migration will LOSE all persistent storage data!"
echo "Ensure you have backed up any important data before proceeding."
echo ""
read -p "Have you backed up your data? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Migration cancelled. Please backup your data first."
    echo "Use: ./backup.sh $OLD_DSEQ $OLD_PROVIDER <service-name>"
    exit 1
fi

ACCOUNT_ADDRESS=$(provider-services keys show $KEY_NAME -a)

echo ""
echo "Step 1: Creating new deployment..."
NEW_DEPLOY_OUTPUT=$(provider-services tx deployment create $SDL_FILE --from $KEY_NAME -y -o json)
NEW_DSEQ=$(echo "$NEW_DEPLOY_OUTPUT" | jq -r '.tx_response.events[] | select(.type=="akash.v1.EventDeploymentCreated") | .attributes[] | select(.key=="dseq") | .value' | head -1)

if [ -z "$NEW_DSEQ" ] || [ "$NEW_DSEQ" == "null" ]; then
    NEW_DSEQ=$(echo "$NEW_DEPLOY_OUTPUT" | grep -oP '"dseq":"\K[^"]+' | head -1)
fi

echo "New DSEQ: $NEW_DSEQ"

echo ""
echo "Step 2: Waiting for bids..."
sleep 10

# List available providers (excluding old one)
echo "Available providers (excluding current):"
provider-services query market bid list --owner $ACCOUNT_ADDRESS --dseq $NEW_DSEQ --state open -o json | \
    jq -r --arg old "$OLD_PROVIDER" '.bids[] | select(.bid.provider_address != $old) | "Provider: \(.bid.provider_address) | Price: \(.bid.price.amount)uakt"'

# Get best bid (excluding old provider)
BEST_BID=$(provider-services query market bid list --owner $ACCOUNT_ADDRESS --dseq $NEW_DSEQ --state open -o json | \
    jq -r --arg old "$OLD_PROVIDER" '[.bids[] | select(.bid.provider_address != $old)] | sort_by(.bid.price.amount) | .[0]')

NEW_PROVIDER=$(echo "$BEST_BID" | jq -r '.bid.provider_address')

echo ""
echo "Step 3: Selected provider: $NEW_PROVIDER"
read -p "Use this provider? (yes/no): " USE_PROVIDER

if [ "$USE_PROVIDER" != "yes" ]; then
    echo "Enter provider address manually:"
    read NEW_PROVIDER
fi

echo ""
echo "Step 4: Creating lease with new provider..."
provider-services tx market lease create \
    --dseq $NEW_DSEQ \
    --gseq 1 \
    --oseq 1 \
    --provider $NEW_PROVIDER \
    --from $KEY_NAME -y

echo ""
echo "Step 5: Sending manifest to new provider..."
provider-services send-manifest $SDL_FILE \
    --dseq $NEW_DSEQ \
    --provider $NEW_PROVIDER \
    --from $KEY_NAME

echo ""
echo "Step 6: Closing old deployment..."
read -p "Close old deployment $OLD_DSEQ? (yes/no): " CLOSE_OLD

if [ "$CLOSE_OLD" == "yes" ]; then
    provider-services tx deployment close --dseq $OLD_DSEQ --from $KEY_NAME -y
    echo "Old deployment closed."
fi

echo ""
echo "=== Migration Complete ==="
echo "Old DSEQ: $OLD_DSEQ (closed)"
echo "New DSEQ: $NEW_DSEQ (active)"
echo "New Provider: $NEW_PROVIDER"
echo ""
echo "⚠️  Restore your backup data to the new deployment."
