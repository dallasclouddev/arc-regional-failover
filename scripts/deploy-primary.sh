#!/bin/bash
set -e

# Deploy Primary Region Infrastructure
# Usage: ./deploy-primary.sh <region> [environment-name]

REGION=${1:-us-east-1}
ENV_NAME=${2:-arc-demo}
STACK_NAME_PREFIX="${ENV_NAME}-primary"

echo "========================================="
echo "Deploying Primary Region Infrastructure"
echo "Region: $REGION"
echo "Environment: $ENV_NAME"
echo "========================================="

# Deploy VPC and Networking
echo ""
echo "Step 1: Deploying VPC and Networking..."
aws cloudformation deploy \
  --template-file cloudformation/infrastructure/vpc-networking.yaml \
  --stack-name ${STACK_NAME_PREFIX}-vpc \
  --parameter-overrides \
    EnvironmentName=${ENV_NAME} \
  --region ${REGION} \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

echo "✓ VPC and Networking deployed"

# Get database password (or generate one)
DB_PASSWORD=${DB_PASSWORD:-$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)}
echo ""
echo "Database password: $DB_PASSWORD"
echo "IMPORTANT: Save this password securely!"

# Deploy Aurora PostgreSQL
echo ""
echo "Step 2: Deploying Aurora PostgreSQL Global Database..."
aws cloudformation deploy \
  --template-file cloudformation/infrastructure/aurora-primary.yaml \
  --stack-name ${STACK_NAME_PREFIX}-aurora \
  --parameter-overrides \
    EnvironmentName=${ENV_NAME} \
    DBPassword=${DB_PASSWORD} \
  --region ${REGION} \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

echo "✓ Aurora PostgreSQL deployed"

# Get outputs
echo ""
echo "Retrieving stack outputs..."
GLOBAL_CLUSTER_ID=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME_PREFIX}-aurora \
  --region ${REGION} \
  --query 'Stacks[0].Outputs[?OutputKey==`GlobalClusterIdentifier`].OutputValue' \
  --output text)

DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME_PREFIX}-aurora \
  --region ${REGION} \
  --query 'Stacks[0].Outputs[?OutputKey==`DBClusterEndpoint`].OutputValue' \
  --output text)

echo ""
echo "========================================="
echo "Primary Region Deployment Complete!"
echo "========================================="
echo "Global Cluster ID: $GLOBAL_CLUSTER_ID"
echo "Database Endpoint: $DB_ENDPOINT"
echo ""
echo "Save these values for secondary region deployment:"
echo "  GLOBAL_CLUSTER_ID=$GLOBAL_CLUSTER_ID"
echo ""
echo "Next steps:"
echo "  1. Deploy secondary region: ./deploy-secondary.sh <region> $GLOBAL_CLUSTER_ID"
echo "  2. Deploy ARC components: ./deploy-arc.sh"
echo "========================================="
