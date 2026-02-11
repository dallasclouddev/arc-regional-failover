#!/bin/bash
set -e

echo "Deploying Application Tier - us-west-2..."
aws cloudformation deploy \
  --template-file templates/12-app-tier-secondary.yaml \
  --stack-name app-failover-app-secondary \
  --region us-west-2 \
  --capabilities CAPABILITY_NAMED_IAM

echo "Deployment complete!"
echo "API Endpoint:"
aws cloudformation describe-stacks \
  --stack-name app-failover-app-secondary \
  --region us-west-2 \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text
