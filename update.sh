#!/bin/bash

# Quick update script for Chouette Debt Settler
# Use this to update the site after initial deployment

set -e

# Enable alias expansion for 1Password plugin support
shopt -s expand_aliases
source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || true

# Use AWS_COMMAND if set, otherwise use 'aws'
AWS_CMD="${AWS_COMMAND:-aws}"

BUCKET_NAME="settlethechou.com"
DISTRIBUTION_ID="${1}"

if [ -z "$DISTRIBUTION_ID" ]; then
    echo "Usage: ./update.sh [CLOUDFRONT_DISTRIBUTION_ID]"
    echo ""
    echo "Example: ./update.sh E1234ABCD5678"
    echo ""
    echo "To find your distribution ID:"
    echo "  aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,Aliases.Items[0]]' --output table"
    exit 1
fi

echo "Uploading index.html to S3..."
$AWS_CMD s3 cp index.html "s3://${BUCKET_NAME}/" --cache-control "max-age=300"
echo "✓ File uploaded"

echo ""
echo "Invalidating CloudFront cache..."
INVALIDATION_ID=$($AWS_CMD cloudfront create-invalidation \
    --distribution-id "${DISTRIBUTION_ID}" \
    --paths '/*' \
    --query 'Invalidation.Id' \
    --output text)

echo "✓ Invalidation created: ${INVALIDATION_ID}"
echo ""
echo "Changes will be live in 1-5 minutes."
echo "Check status: aws cloudfront get-invalidation --distribution-id ${DISTRIBUTION_ID} --id ${INVALIDATION_ID}"
