#!/bin/bash -e

## install the runner
## source: https://github.com/philips-labs/terraform-aws-github-runner/blob/e232af5b01f91addf7f143453e72f67a4c35fa36/modules/runners/templates/install-runner.sh

s3_location=${S3_LOCATION_RUNNER_DISTRIBUTION}

if [ -z "$RUNNER_TARBALL_URL" ] && [ -z "$s3_location" ]; then
  echo "Neither RUNNER_TARBALL_URL or s3_location are set"
  exit 1
fi

file_name="actions-runner.tar.gz"

echo "Setting up GH Actions runner tool cache"
# Required for various */setup-* actions to work, location is also know by various environment
# variable names in the actions/runner software : RUNNER_TOOL_CACHE / RUNNER_TOOLSDIRECTORY / AGENT_TOOLSDIRECTORY
# Warning, not all setup actions support the env vars and so this specific path must be created regardless
sudo mkdir -p /opt/hostedtoolcache
sudo chown -R ec2-user:ec2-user /opt/hostedtoolcache

# The IDM server that AB2D needs to access doesn't support TLSv1.2 with EMS
# See https://www.redhat.com/en/blog/tls-extended-master-secret-and-fips-rhel
sudo update-crypto-policies --set FIPS:NO-ENFORCE-EMS

echo "Creating actions-runner directory for the GH Action installation"
sudo mkdir -p /opt/actions-runner
sudo chown -R ec2-user:ec2-user /opt/actions-runner
cd /opt/actions-runner

if [[ -n "$RUNNER_TARBALL_URL" ]]; then
  echo "Downloading the GH Action runner from $RUNNER_TARBALL_URL to $file_name"
  curl -o $file_name -L "$RUNNER_TARBALL_URL"
else
  echo "Retrieving TOKEN from AWS API"
  token=$(curl -sS -f -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 180")

  region=$(curl -sS -f -H "X-aws-ec2-metadata-token: $token" -v http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
  echo "Retrieved REGION from AWS API ($region)"

  echo "Downloading the GH Action runner from s3 bucket $s3_location"
  aws s3 cp "$s3_location" "$file_name" --region "$region"
fi

echo "Un-tar action runner"
tar xzf ./$file_name
echo "Delete tar file"
rm -rf $file_name
