# Provider Selection Guide

## Key Criteria

### 1. Reliability
- Check uptime history
- Look for audited providers
- Review community feedback

### 2. Location
- Choose based on user geography
- Consider compliance requirements (GDPR, etc.)
- Network latency considerations

### 3. Features
- Persistent storage support
- GPU availability
- IP lease capability

### 4. Pricing
- Balance cost vs reliability
- Very low prices may indicate issues

## Querying Providers

```bash
# List all providers
provider-services query provider list -o json | jq '.[]'

# Get specific provider details
provider-services query provider get $PROVIDER -o json

# Console API (more details)
curl -s https://console-api.akash.network/v1/providers | \
  jq '.[] | {address, uptime, leaseCount, isOnline}'

# Filter by attributes
curl -s https://console-api.akash.network/v1/providers | \
  jq '.[] | select(.attributes[]?.value == "us-west")'
```

## Recommended Providers

Look for providers with:
- Uptime > 95%
- Audited status
- Reasonable pricing
- Active lease count

## Provider Attributes

| Attribute | Values | Use Case |
|-----------|--------|----------|
| region | us-west, us-east, eu-west, asia-east | Geographic placement |
| tier | community, enterprise | Quality level |
| host | akash | Provider type |
| feat-persistent-storage | true | Storage capability |
| feat-endpoint-ip | true | IP lease capability |
