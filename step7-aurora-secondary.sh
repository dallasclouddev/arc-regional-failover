#!/bin/bash
set -e

# Step 7: Deploy Aurora Secondary Database
echo "Deploying Aurora Secondary database in us-west-2..."
echo "This will take approximately 10 minutes..."
aws cloudformation create-stack \
  --stack-name aurora-failover-db-secondary \
  --template-body file://templates/5-aurora-secondary.yaml \
  --parameters \
    ParameterKey=GlobalClusterIdentifier,ParameterValue=aurora-global-test \
  --region us-west-2

echo ""
echo "Waiting for Aurora Secondary to be created (this takes ~10 minutes)..."
aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-db-secondary \
  --region us-west-2

echo ""
echo "Step 7 completed successfully!"
echo ""
echo "Aurora Secondary Database Outputs:"
aws cloudformation describe-stacks \
  --stack-name aurora-failover-db-secondary \
  --region us-west-2 \
  --query 'Stacks[0].Outputs'

echo ""
echo "Aurora Global Database is ready!"
echo "Next: Deploy Route 53 ARC (Step 9)"
