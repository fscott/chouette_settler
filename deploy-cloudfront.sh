#!/bin/bash

# CloudFront + Route53 setup for Chouette Debt Settler
# Run this AFTER you have obtained an ACM certificate

set -e

# Enable alias expansion for 1Password plugin support
shopt -s expand_aliases
source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || true

# Use AWS_COMMAND if set, otherwise use 'aws'
AWS_CMD="${AWS_COMMAND:-aws}"

# Configuration
DOMAIN="settlethechou.com"
BUCKET_NAME="settlethechou.com"
REGION="us-east-1"

echo "================================================"
echo "CloudFront Distribution Setup"
echo "================================================"
echo ""

# Get ACM certificate ARN
echo "Looking for ACM certificate for ${DOMAIN}..."
CERT_ARN=$(eval "$AWS_CMD acm list-certificates --region us-east-1 --query \"CertificateSummaryList[?DomainName=='${DOMAIN}'].CertificateArn\" --output text")

if [ -z "$CERT_ARN" ]; then
    echo "Error: No ACM certificate found for ${DOMAIN}"
    echo "Please request and validate a certificate in ACM first."
    echo ""
    echo "To request a certificate:"
    echo "  aws acm request-certificate \\"
    echo "    --domain-name ${DOMAIN} \\"
    echo "    --subject-alternative-names www.${DOMAIN} \\"
    echo "    --validation-method DNS \\"
    echo "    --region us-east-1"
    echo ""
    exit 1
fi

echo "✓ Found certificate: ${CERT_ARN}"

# Create CloudFront distribution config
cat > /tmp/cf-config.json <<EOF
{
    "CallerReference": "chouette-settler-$(date +%s)",
    "Comment": "Chouette Debt Settler",
    "Enabled": true,
    "DefaultRootObject": "index.html",
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "S3-${BUCKET_NAME}",
                "DomainName": "${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com",
                "CustomOriginConfig": {
                    "HTTPPort": 80,
                    "HTTPSPort": 443,
                    "OriginProtocolPolicy": "http-only"
                }
            }
        ]
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3-${BUCKET_NAME}",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"],
            "CachedMethods": {
                "Quantity": 2,
                "Items": ["GET", "HEAD"]
            }
        },
        "Compress": true,
        "ForwardedValues": {
            "QueryString": false,
            "Cookies": {
                "Forward": "none"
            }
        },
        "MinTTL": 0,
        "DefaultTTL": 300,
        "MaxTTL": 31536000
    },
    "Aliases": {
        "Quantity": 2,
        "Items": ["${DOMAIN}", "www.${DOMAIN}"]
    },
    "ViewerCertificate": {
        "ACMCertificateArn": "${CERT_ARN}",
        "SSLSupportMethod": "sni-only",
        "MinimumProtocolVersion": "TLSv1.2_2021"
    }
}
EOF

echo ""
echo "Creating CloudFront distribution..."
DISTRIBUTION_OUTPUT=$(eval "$AWS_CMD cloudfront create-distribution --distribution-config file:///tmp/cf-config.json")
DISTRIBUTION_ID=$(echo "$DISTRIBUTION_OUTPUT" | jq -r '.Distribution.Id')
DISTRIBUTION_DOMAIN=$(echo "$DISTRIBUTION_OUTPUT" | jq -r '.Distribution.DomainName')

echo "✓ CloudFront distribution created"
echo ""
echo "Distribution ID: ${DISTRIBUTION_ID}"
echo "Distribution Domain: ${DISTRIBUTION_DOMAIN}"
echo ""
echo "================================================"
echo "Final Steps:"
echo "================================================"
echo ""
echo "1. Wait for CloudFront distribution to deploy (15-20 minutes)"
echo "   Check status: aws cloudfront get-distribution --id ${DISTRIBUTION_ID}"
echo ""
echo "2. Update DNS records (at your domain registrar or Route53):"
echo "   ${DOMAIN} -> CNAME -> ${DISTRIBUTION_DOMAIN}"
echo "   www.${DOMAIN} -> CNAME -> ${DISTRIBUTION_DOMAIN}"
echo ""
echo "3. Access your site at: https://${DOMAIN}"
echo ""
echo "To update the site in the future, run:"
echo "  aws s3 cp index.html s3://${BUCKET_NAME}/"
echo "  aws cloudfront create-invalidation --distribution-id ${DISTRIBUTION_ID} --paths '/*'"
echo ""
