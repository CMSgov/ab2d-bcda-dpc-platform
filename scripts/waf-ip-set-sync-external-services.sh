#!/bin/bash

set -euo pipefail

IPV4_LIST=$(grep -v '^#' allowed_ips.txt | jq -Rs '{Addresses: split("\n") | map(select(length > 0))}')
IPV4_SET_ID=$(aws wafv2 list-ip-sets --scope REGIONAL --region $AWS_REGION | jq -r '.IPSets[] | select( .Name=="external-services") | .Id')

LOCK_TOKEN=$(aws wafv2 get-ip-set --name external-services --scope REGIONAL --id $IPV4_SET_ID --region us-east-1 | jq '.LockToken')

echo "Beginning 'external services' regional IPv4 set update."

echo "IPV4_SET_ID is ${IPV4_SET_ID}"
echo "App/Env are ${APP} ${ENV}"

SAMPLE_NAME=$(aws ec2 describe-instances | jq -r '.Reservations[0].Instances[].Tags[] | select( .Key=="Name") | .Value')
echo "Sample name is ${SAMPLE_NAME}"

# aws wafv2 update-ip-set \
#   --name external-services \
#   --scope REGIONAL \
#   --id $IPV4_SET_ID \
#   --region us-east-1 \
#   --addresses $IPV4_LIST \
#   --lock-token $LOCK_TOKEN
