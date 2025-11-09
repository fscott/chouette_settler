#!/bin/bash

# Deployment script for Chouette Debt Settler
# Deploys to S3 + CloudFront with custom domain

set -e

# Configuration
DOMAIN="settlethechou.com"
BUCKET_NAME="settlethechou.com"
REGION="us-east-1"  # Must be us-east-1 for CloudFront ACM certificates
STACK_NAME="chouette-settler"

echo "================================================"
echo "Chouette Debt Settler Deployment"
echo "================================================"
echo ""
echo "Domain: ${DOMAIN}"
echo "Bucket: ${BUCKET_NAME}"
echo "Region: ${REGION}"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

echo "Step 1: Creating S3 bucket..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb "s3://${BUCKET_NAME}" --region "${REGION}"
    echo "✓ Bucket created"
else
    echo "✓ Bucket already exists"
fi

echo ""
echo "Step 2: Uploading files to S3..."
aws s3 sync . "s3://${BUCKET_NAME}" \
    --exclude "*" \
    --include "index.html" \
    --cache-control "max-age=300" \
    --region "${REGION}"
echo "✓ Files uploaded"

echo ""
echo "Step 3: Configuring S3 bucket for website hosting..."
aws s3 website "s3://${BUCKET_NAME}" \
    --index-document index.html \
    --error-document index.html

# Create bucket policy
cat > /tmp/bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy \
    --bucket "${BUCKET_NAME}" \
    --policy file:///tmp/bucket-policy.json

echo "✓ Bucket configured for static website hosting"

echo ""
echo "================================================"
echo "S3 Setup Complete!"
echo "================================================"
echo ""
echo "Website URL: http://${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com"
echo ""
echo "================================================"
echo "Next Steps for Custom Domain with HTTPS:"
echo "================================================"
echo ""
echo "1. Request SSL Certificate (ACM):"
echo "   - Go to AWS Certificate Manager (ACM) in us-east-1 region"
echo "   - Request a certificate for: ${DOMAIN} and www.${DOMAIN}"
echo "   - Validate via DNS (add CNAME records to your domain)"
echo "   - Wait for certificate to be issued (can take up to 30 minutes)"
echo ""
echo "2. Create CloudFront Distribution:"
echo "   - Origin: ${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com"
echo "   - Alternate domain names (CNAMEs): ${DOMAIN}, www.${DOMAIN}"
echo "   - SSL Certificate: Select your ACM certificate"
echo "   - Default root object: index.html"
echo ""
echo "3. Update DNS:"
echo "   - Create CNAME record: ${DOMAIN} -> [CloudFront distribution domain]"
echo "   - Create CNAME record: www.${DOMAIN} -> [CloudFront distribution domain]"
echo ""
echo "Or run: ./deploy-cloudfront.sh (after certificate is issued)"
echo ""
