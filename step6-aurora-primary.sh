#!/bin/bash
set -e

# Step 6: Deploy Aurora Primary Database
# IMPORTANT: Change the password below!
DB_PASSWORD="ARCtest1"

echo "Deploying Aurora Primary database in us-east-1..."
echo "This will take approximately 10 minutes..."
aws cloudformation create-stack \
  --stack-name aurora-failover-db-primary \
  --template-body file://templates/4-aurora-primary.yaml \
  --parameters \
    ParameterKey=DBUsername,ParameterValue=dbadmin \
    ParameterKey=DBPassword,ParameterValue=$DB_PASSWORD \
  --region us-east-1

echo ""
echo "Waiting for Aurora Primary to be created (this takes ~10 minutes)..."
aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-db-primary \
  --region us-east-1

echo ""
echo "Step 6 completed successfully!"
echo ""
echo "Aurora Primary Database Outputs:"
aws cloudformation describe-stacks \
  --stack-name aurora-failover-db-primary \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'

echo ""
echo "Next: Deploy Aurora Secondary (Step 7)"
