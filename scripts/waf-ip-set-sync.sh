#!/bin/bash

set -euo pipefail

echo "Generating IP set"

IPV4_LIST=$(grep -v '^#' temp/ip-sets/ab2d/allowed_ips.txt | jq -Rs '{Addresses: split("\n") | map(select(length > 0))}' | jq -rc .Addresses)

echo "Fetching IP set IDs"

{
  read -r IPV4_SET_ID
  read -r IPV6_SET_ID
} < <(aws wafv2 list-ip-sets --scope REGIONAL | jq -r '.IPSets[] | select( .Name | contains("api-customers")) | .Id')

echo "Updating IPv4 set"

LOCK_TOKEN=$(aws wafv2 get-ip-set --name $APP-$ENV-api-customers --scope REGIONAL --id $IPV4_SET_ID --region us-east-1 | jq -r '.LockToken')

aws wafv2 update-ip-set \
  --name $APP-$ENV-api-customers \
  --scope REGIONAL \
  --id $IPV4_SET_ID \
  --region us-east-1 \
  --addresses $IPV4_LIST \
  --lock-token $LOCK_TOKEN \
  > /dev/null 2>&1
