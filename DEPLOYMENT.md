# Deployment Guide: Chouette Debt Settler

This guide will help you deploy the Chouette Debt Settler application to AWS with a custom domain (settlethechou.com) and HTTPS.

## Prerequisites

- AWS Account
- AWS CLI installed and configured (`aws configure`)
- Domain name: `settlethechou.com` (registered with any registrar)
- `jq` installed (for CloudFront script): `sudo apt-get install jq` or `brew install jq`

### Using 1Password AWS Plugin

If you use the 1Password plugin for AWS, use the wrapper script instead:

```bash
# For 1Password users - use this instead of the regular scripts
./deploy-with-1password.sh s3           # Deploy to S3
./deploy-with-1password.sh cloudfront   # Setup CloudFront
./deploy-with-1password.sh update E123  # Update site
```

Or set the AWS_COMMAND environment variable:

```bash
export AWS_COMMAND="op plugin run -- aws"
./deploy.sh
./deploy-cloudfront.sh
```

## Architecture

The deployment uses:
- **S3**: Hosts the static HTML file
- **CloudFront**: CDN for fast global delivery and HTTPS
- **ACM**: SSL/TLS certificate for HTTPS
- **Route53** (optional): DNS management

## Deployment Steps

### Option 1: Automated Deployment (Recommended)

#### Step 1: Deploy to S3

```bash
chmod +x deploy.sh
./deploy.sh
```

This will:
- Create an S3 bucket named `settlethechou.com`
- Upload `index.html`
- Configure the bucket for static website hosting
- Set public read permissions

Your site will be accessible at:
`http://settlethechou.com.s3-website-us-east-1.amazonaws.com`

#### Step 2: Request SSL Certificate

**Important:** ACM certificates for CloudFront must be in the `us-east-1` region.

```bash
aws acm request-certificate \
  --domain-name settlethechou.com \
  --subject-alternative-names www.settlethechou.com \
  --validation-method DNS \
  --region us-east-1
```

Or use the AWS Console:
1. Go to AWS Certificate Manager in **us-east-1** region
2. Click "Request a certificate"
3. Enter domain names: `settlethechou.com` and `www.settlethechou.com`
4. Choose DNS validation
5. Follow the instructions to add CNAME records to your domain's DNS
6. Wait for validation (typically 5-30 minutes)

#### Step 3: Deploy CloudFront Distribution

After your certificate shows "Issued" status:

```bash
chmod +x deploy-cloudfront.sh
./deploy-cloudfront.sh
```

This will:
- Create a CloudFront distribution
- Configure it with your domain and SSL certificate
- Output the CloudFront domain name

Wait 15-20 minutes for the distribution to deploy.

#### Step 4: Update DNS Records

Add these CNAME records at your domain registrar (or Route53):

```
Type    Name                    Value
CNAME   settlethechou.com       d1234abcd.cloudfront.net
CNAME   www.settlethechou.com   d1234abcd.cloudfront.net
```

Replace `d1234abcd.cloudfront.net` with your actual CloudFront domain from the script output.

**Note:** If using the root domain (settlethechou.com) as a CNAME, some registrars don't support this. In that case, either:
- Use Route53 with an ALIAS record (recommended)
- Use only www.settlethechou.com

#### Step 5: Access Your Site

After DNS propagation (5-60 minutes):
- https://settlethechou.com
- https://www.settlethechou.com

---

### Option 2: Manual Deployment via AWS Console

<details>
<summary>Click to expand manual steps</summary>

#### 1. Create S3 Bucket
1. Go to S3 Console
2. Create bucket named `settlethechou.com`
3. Uncheck "Block all public access"
4. Enable static website hosting (Properties tab)
5. Set index document to `index.html`

#### 2. Upload File
1. Upload `index.html` to the bucket
2. Make it public

#### 3. Add Bucket Policy
Go to Permissions > Bucket Policy and add:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::settlethechou.com/*"
        }
    ]
}
```

#### 4. Request ACM Certificate
1. Go to Certificate Manager (us-east-1 region)
2. Request certificate for `settlethechou.com` and `www.settlethechou.com`
3. Validate via DNS

#### 5. Create CloudFront Distribution
1. Go to CloudFront
2. Create distribution
3. Origin domain: `settlethechou.com.s3-website-us-east-1.amazonaws.com`
4. Origin protocol: HTTP only
5. Viewer protocol policy: Redirect HTTP to HTTPS
6. Alternate domain names: `settlethechou.com`, `www.settlethechou.com`
7. SSL certificate: Select your ACM certificate
8. Default root object: `index.html`

#### 6. Update DNS
Add CNAME records pointing to your CloudFront domain.

</details>

---

## Updating the Site

After initial deployment, update with:

```bash
# Upload new version
aws s3 cp index.html s3://settlethechou.com/

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id E1234ABCD5678 \
  --paths '/*'
```

Replace `E1234ABCD5678` with your actual distribution ID.

---

## Using Route53 for DNS (Optional)

If you want to manage DNS with AWS:

```bash
# Create hosted zone
aws route53 create-hosted-zone --name settlethechou.com --caller-reference $(date +%s)

# Get the CloudFront distribution domain
CLOUDFRONT_DOMAIN="d1234abcd.cloudfront.net"
HOSTED_ZONE_ID="Z2FDTNDATAQYW2"  # CloudFront hosted zone ID

# Create ALIAS record for root domain
# (Create a JSON file with the record set, then use route53 change-resource-record-sets)
```

Update your domain registrar's nameservers to point to the Route53 nameservers.

---

## Costs

Estimated AWS costs for low traffic:
- **S3**: ~$0.023 per GB stored + $0.09 per GB transferred
- **CloudFront**: First 1TB free (12 months), then ~$0.085 per GB
- **Route53**: $0.50 per hosted zone per month (if used)
- **ACM Certificate**: FREE

For a single HTML file with minimal traffic: **~$0-2 per month**

---

## Troubleshooting

### Certificate Validation Stuck
- Ensure CNAME records are added correctly to your domain's DNS
- Check the certificate status in ACM console
- DNS propagation can take up to 30 minutes

### CloudFront Shows "Access Denied"
- Verify S3 bucket policy allows public access
- Check CloudFront origin is using HTTP (not HTTPS) for S3 website endpoint
- Ensure origin domain is `bucket-name.s3-website-region.amazonaws.com` not `bucket-name.s3.amazonaws.com`

### DNS Not Resolving
- Wait for DNS propagation (can take up to 48 hours, typically 5-60 minutes)
- Verify CNAME records are correct
- Use `dig settlethechou.com` or `nslookup settlethechou.com` to check

### CloudFront Distribution Taking Long Time
- Initial deployment typically takes 15-20 minutes
- Check status: `aws cloudfront get-distribution --id YOUR_DIST_ID`

---

## Security Notes

- The S3 bucket is public (required for static hosting)
- All files are served via HTTPS through CloudFront
- No sensitive data or backend required
- Consider enabling CloudFront WAF for additional protection (optional)

---

## Alternative: Quick Test with S3 Only

For quick testing without HTTPS/custom domain:

```bash
./deploy.sh
# Access at: http://settlethechou.com.s3-website-us-east-1.amazonaws.com
```
