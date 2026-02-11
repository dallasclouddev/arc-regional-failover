#!/bin/bash
set -e

echo "Deploying Application Tier - us-east-1..."
aws cloudformation deploy \
  --template-file templates/11-app-tier-primary.yaml \
  --stack-name app-failover-app-primary \
  --region us-east-1 \
  --capabilities CAPABILITY_NAMED_IAM

echo "Deployment complete!"
echo "API Endpoint:"
aws cloudformation describe-stacks \
  --stack-name app-failover-app-primary \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text
