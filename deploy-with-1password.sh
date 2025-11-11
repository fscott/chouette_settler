#!/bin/bash

# Wrapper script for 1Password AWS plugin users

# Use full path to op command
export AWS_COMMAND="/opt/homebrew/bin/op plugin run -- aws"

echo "Using 1Password AWS plugin..."
echo ""

# Run the requested script
case "$1" in
    "s3"|"deploy")
        ./deploy.sh
        ;;
    "cloudfront"|"cf")
        ./deploy-cloudfront.sh
        ;;
    "update")
        shift
        ./update.sh "$@"
        ;;
    "check-cert"|"cert")
        ./check-certificate.sh
        ;;
    *)
        echo "Usage: $0 [s3|cloudfront|update|check-cert] [args...]"
        echo ""
        echo "Examples:"
        echo "  $0 s3              # Deploy to S3"
        echo "  $0 check-cert      # Check certificate status and show validation records"
        echo "  $0 cloudfront      # Setup CloudFront (after cert is validated)"
        echo "  $0 update E123...  # Update site"
        exit 1
        ;;
esac
