#!/bin/bash
set -e

# Deploy Secondary Region Infrastructure
# Usage: ./deploy-secondary.sh <region> <global-cluster-id> [environment-name]

REGION=${1}
GLOBAL_CLUSTER_ID=${2}
ENV_NAME=${3:-arc-demo}
STACK_NAME_PREFIX="${ENV_NAME}-secondary"

if [ -z "$REGION" ] || [ -z "$GLOBAL_CLUSTER_ID" ]; then
  echo "Usage: ./deploy-secondary.sh <region> <global-cluster-id> [environment-name]"
  echo "Example: ./deploy-secondary.sh us-west-2 arc-demo-global-cluster arc-demo"
  exit 1
fi

echo "==========================================="
echo "Deploying Secondary Region Infrastructure"
echo "Region: $REGION"
echo "Global Cluster: $GLOBAL_CLUSTER_ID"
echo "Environment: $ENV_NAME"
echo "==========================================="

# Deploy VPC and Networking
echo ""
echo "Step 1: Deploying VPC and Networking..."
aws cloudformation deploy \
  --template-file cloudformation/infrastructure/vpc-networking.yaml \
  --stack-name ${STACK_NAME_PREFIX}-vpc \
  --parameter-overrides \
    EnvironmentName=${ENV_NAME} \
    VpcCIDR=10.1.0.0/16 \
    PublicSubnet1CIDR=10.1.1.0/24 \
    PublicSubnet2CIDR=10.1.2.0/24 \
    PrivateSubnet1CIDR=10.1.11.0/24 \
    PrivateSubnet2CIDR=10.1.12.0/24 \
  --region ${REGION} \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

echo "✓ VPC and Networking deployed"

# Deploy Aurora PostgreSQL Secondary Cluster
echo ""
echo "Step 2: Deploying Aurora PostgreSQL Secondary Cluster..."
aws cloudformation deploy \
  --template-file cloudformation/infrastructure/aurora-secondary.yaml \
  --stack-name ${STACK_NAME_PREFIX}-aurora \
  --parameter-overrides \
    EnvironmentName=${ENV_NAME} \
    GlobalClusterIdentifier=${GLOBAL_CLUSTER_ID} \
  --region ${REGION} \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

echo "✓ Aurora PostgreSQL Secondary Cluster deployed"

# Get outputs
echo ""
echo "Retrieving stack outputs..."
DB_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME_PREFIX}-aurora \
  --region ${REGION} \
  --query 'Stacks[0].Outputs[?OutputKey==`DBClusterEndpoint`].OutputValue' \
  --output text)

echo ""
echo "==========================================="
echo "Secondary Region Deployment Complete!"
echo "==========================================="
echo "Database Endpoint: $DB_ENDPOINT"
echo ""
echo "Next steps:"
echo "  1. Deploy ARC components: ./deploy-arc.sh"
echo "==========================================="
