#!/bin/bash

# Check ACM certificate status and show validation records

set -e

# Use AWS_COMMAND if set, otherwise use 'aws'
AWS_CMD="${AWS_COMMAND:-aws}"

DOMAIN="settlethechou.com"

echo "================================================"
echo "ACM Certificate Status Checker"
echo "================================================"
echo ""

# Get all certificates
echo "Looking for certificates for ${DOMAIN}..."
CERT_ARN=$(eval "$AWS_CMD acm list-certificates --region us-east-1 --query \"CertificateSummaryList[?DomainName=='${DOMAIN}'].CertificateArn\" --output text")

if [ -z "$CERT_ARN" ]; then
    echo "❌ No certificate found for ${DOMAIN}"
    echo ""
    echo "To request a certificate, run:"
    echo "  ./deploy-with-1password.sh request-cert"
    exit 1
fi

echo "✓ Certificate found: ${CERT_ARN}"
echo ""

# Get certificate details
CERT_DETAILS=$(eval "$AWS_CMD acm describe-certificate --certificate-arn \"${CERT_ARN}\" --region us-east-1")

STATUS=$(echo "$CERT_DETAILS" | jq -r '.Certificate.Status')
DOMAIN_VALIDATION=$(echo "$CERT_DETAILS" | jq -r '.Certificate.DomainValidationOptions')

echo "Status: ${STATUS}"
echo ""

if [ "$STATUS" == "ISSUED" ]; then
    echo "✅ Certificate is valid and ready to use!"
    echo "You can now run: ./deploy-with-1password.sh cloudfront"
    exit 0
fi

if [ "$STATUS" == "PENDING_VALIDATION" ]; then
    echo "⏳ Certificate is pending validation"
    echo ""
    echo "You need to add the following DNS records to validate your certificate:"
    echo ""
    echo "================================================"
    echo "DNS VALIDATION RECORDS"
    echo "================================================"
    echo ""

    # Show validation records for each domain
    echo "$DOMAIN_VALIDATION" | jq -r '.[] | "Domain: \(.DomainName)\nRecord Type: CNAME\nRecord Name: \(.ResourceRecord.Name)\nRecord Value: \(.ResourceRecord.Value)\n"'

    echo "================================================"
    echo "WHERE TO ADD THESE RECORDS IN ROUTE53:"
    echo "================================================"
    echo ""
    echo "1. Go to AWS Console: https://console.aws.amazon.com/route53/"
    echo "2. Click 'Hosted zones' in the left sidebar"
    echo "3. Find and click on: ${DOMAIN}"
    echo "4. Click 'Create record'"
    echo "5. For each validation record above:"
    echo "   - Record name: Copy the 'Record Name' (without the domain part)"
    echo "   - Record type: CNAME"
    echo "   - Value: Copy the 'Record Value'"
    echo "   - TTL: 300"
    echo "   - Click 'Create records'"
    echo ""
    echo "6. Wait 5-30 minutes for validation to complete"
    echo "7. Run this script again to check status"
    echo ""
    echo "================================================"
    echo "IF YOU DON'T HAVE A ROUTE53 HOSTED ZONE:"
    echo "================================================"
    echo ""
    echo "If ${DOMAIN} is registered elsewhere (GoDaddy, Namecheap, etc):"
    echo "- Go to your domain registrar's DNS settings"
    echo "- Add the CNAME records shown above"
    echo "- Wait for validation"
    echo ""
    exit 0
fi

echo "❓ Certificate status: ${STATUS}"
echo "This is an unexpected status. Check the AWS ACM console."
