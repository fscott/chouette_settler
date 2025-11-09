#!/bin/bash

# Wrapper script for 1Password AWS plugin users

export AWS_COMMAND="op plugin run -- aws"

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
    *)
        echo "Usage: $0 [s3|cloudfront|update] [args...]"
        echo ""
        echo "Examples:"
        echo "  $0 s3              # Deploy to S3"
        echo "  $0 cloudfront      # Setup CloudFront"
        echo "  $0 update E123...  # Update site"
        exit 1
        ;;
esac
