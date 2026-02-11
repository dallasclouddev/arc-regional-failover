#!/bin/bash
set -e

# Deploy AWS ARC Components
# Usage: ./deploy-arc.sh [arc-region] [environment-name]

ARC_REGION=${1:-us-west-2}
ENV_NAME=${2:-arc-demo}
STACK_NAME_PREFIX="${ENV_NAME}-arc"

echo "========================================="
echo "Deploying AWS ARC Components"
echo "ARC Region: $ARC_REGION"
echo "Environment: $ENV_NAME"
echo "========================================="

# Deploy ARC Cluster and Control Panel
echo ""
echo "Step 1: Deploying ARC Cluster and Control Panel..."
aws cloudformation deploy \
  --template-file cloudformation/arc/arc-cluster.yaml \
  --stack-name ${STACK_NAME_PREFIX}-cluster \
  --parameter-overrides \
    EnvironmentName=${ENV_NAME} \
  --region ${ARC_REGION} \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

echo "✓ ARC Cluster deployed"

# Get cluster ARN and endpoints
CLUSTER_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME_PREFIX}-cluster \
  --region ${ARC_REGION} \
  --query 'Stacks[0].Outputs[?OutputKey==`ClusterArn`].OutputValue' \
  --output text)

CLUSTER_ENDPOINTS=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME_PREFIX}-cluster \
  --region ${ARC_REGION} \
  --query 'Stacks[0].Outputs[?OutputKey==`ClusterEndpoints`].OutputValue' \
  --output text)

PRIMARY_CONTROL_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME_PREFIX}-cluster \
  --region ${ARC_REGION} \
  --query 'Stacks[0].Outputs[?OutputKey==`PrimaryRoutingControlArn`].OutputValue' \
  --output text)

SECONDARY_CONTROL_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME_PREFIX}-cluster \
  --region ${ARC_REGION} \
  --query 'Stacks[0].Outputs[?OutputKey==`SecondaryRoutingControlArn`].OutputValue' \
  --output text)

echo ""
echo "Cluster Endpoints: $CLUSTER_ENDPOINTS"

# Note: Readiness checks require resource ARNs from both regions
echo ""
echo "Note: ARC Readiness checks can be deployed after getting Aurora cluster ARNs from both regions"
echo ""
echo "========================================="
echo "ARC Components Deployment Complete!"
echo "========================================="
echo "Cluster ARN: $CLUSTER_ARN"
echo "Primary Routing Control: $PRIMARY_CONTROL_ARN"
echo "Secondary Routing Control: $SECONDARY_CONTROL_ARN"
echo ""
echo "Next steps:"
echo "  1. Set primary region as active:"
echo "     ./set-active-region.sh primary"
echo "  2. Run sample application"
echo "  3. Test failover:"
echo "     ./failover.sh"
echo "========================================="
