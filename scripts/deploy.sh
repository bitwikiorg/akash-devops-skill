#!/bin/bash
# Akash Deployment Automation Script
# Usage: ./deploy.sh <sdl-file> [key-name]

set -e

SDL_FILE="${1:-deploy.yaml}"
KEY_NAME="${2:-$AKASH_KEY_NAME}"

if [ -z "$KEY_NAME" ]; then
    echo "Error: No key name specified. Set AKASH_KEY_NAME or pass as argument."
    exit 1
fi

echo "=== Akash Deployment Automation ==="
echo "SDL: $SDL_FILE"
echo "Key: $KEY_NAME"

# Get account address
ACCOUNT_ADDRESS=$(provider-services keys show $KEY_NAME -a)
echo "Account: $ACCOUNT_ADDRESS"

# Check certificate
echo "\n=== Checking Certificate ==="
CERT_EXISTS=$(provider-services query cert list --owner $ACCOUNT_ADDRESS -o json 2>/dev/null | jq -r '.certificates | length' || echo "0")

if [ "$CERT_EXISTS" == "0" ]; then
    echo "Generating and publishing certificate..."
    provider-services tx cert generate client --from $KEY_NAME --override
    provider-services tx cert publish client --from $KEY_NAME -y
else
    echo "Certificate already exists"
fi

# Create deployment
echo "\n=== Creating Deployment ==="
DEPLOY_OUTPUT=$(provider-services tx deployment create $SDL_FILE --from $KEY_NAME -y -o json)
DSEQ=$(echo "$DEPLOY_OUTPUT" | jq -r '.tx_response.events[] | select(.type=="akash.v1.EventDeploymentCreated") | .attributes[] | select(.key=="dseq") | .value' | head -1)

if [ -z "$DSEQ" ] || [ "$DSEQ" == "null" ]; then
    # Alternative extraction method
    DSEQ=$(echo "$DEPLOY_OUTPUT" | grep -oP '"dseq":"\K[^"]+' | head -1)
fi

echo "Deployment Sequence: $DSEQ"

# Wait for bids
echo "\n=== Waiting for Bids ==="
sleep 10

# List bids
echo "\n=== Available Bids ==="
provider-services query market bid list --owner $ACCOUNT_ADDRESS --dseq $DSEQ --state open -o json | \
    jq -r '.bids[] | "Provider: \(.bid.provider_address) | Price: \(.bid.price.amount)uakt"'

# Get best bid (lowest price)
BEST_BID=$(provider-services query market bid list --owner $ACCOUNT_ADDRESS --dseq $DSEQ --state open -o json | \
    jq -r '.bids | sort_by(.bid.price.amount) | .[0]')

PROVIDER_ADDRESS=$(echo "$BEST_BID" | jq -r '.bid.provider_address')
BID_PRICE=$(echo "$BEST_BID" | jq -r '.bid.price.amount')

echo "\n=== Best Bid ==="
echo "Provider: $PROVIDER_ADDRESS"
echo "Price: $BID_PRICE uakt"

# Create lease
echo "\n=== Creating Lease ==="
provider-services tx market lease create \
    --dseq $DSEQ \
    --gseq 1 \
    --oseq 1 \
    --provider $PROVIDER_ADDRESS \
    --from $KEY_NAME -y

# Send manifest
echo "\n=== Sending Manifest ==="
provider-services send-manifest $SDL_FILE \
    --dseq $DSEQ \
    --provider $PROVIDER_ADDRESS \
    --from $KEY_NAME

echo "\n=== Deployment Complete ==="
echo "DSEQ: $DSEQ"
echo "Provider: $PROVIDER_ADDRESS"
echo ""
echo "Save these values for future operations:"
echo "export AKASH_DSEQ=$DSEQ"
echo "export AKASH_PROVIDER=$PROVIDER_ADDRESS"
