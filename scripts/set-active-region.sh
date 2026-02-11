#!/bin/bash
set -e

# Set Active Region via ARC Routing Control
# Usage: ./set-active-region.sh <primary|secondary> [environment-name]

TARGET_REGION=${1}
ENV_NAME=${2:-arc-demo}
ARC_REGION=${3:-us-west-2}

if [ -z "$TARGET_REGION" ]; then
  echo "Usage: ./set-active-region.sh <primary|secondary> [environment-name] [arc-region]"
  exit 1
fi

echo "========================================="
echo "Setting Active Region to: $TARGET_REGION"
echo "========================================="

# Get routing control ARNs from CloudFormation
PRIMARY_CONTROL_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${ENV_NAME}-arc-cluster \
  --region ${ARC_REGION} \
  --query 'Stacks[0].Outputs[?OutputKey==`PrimaryRoutingControlArn`].OutputValue' \
  --output text)

SECONDARY_CONTROL_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${ENV_NAME}-arc-cluster \
  --region ${ARC_REGION} \
  --query 'Stacks[0].Outputs[?OutputKey==`SecondaryRoutingControlArn`].OutputValue' \
  --output text)

CLUSTER_ENDPOINTS=$(aws cloudformation describe-stacks \
  --stack-name ${ENV_NAME}-arc-cluster \
  --region ${ARC_REGION} \
  --query 'Stacks[0].Outputs[?OutputKey==`ClusterEndpoints`].OutputValue' \
  --output text)

# Get first endpoint
ENDPOINT=$(echo $CLUSTER_ENDPOINTS | cut -d',' -f1)

echo "Using ARC endpoint: $ENDPOINT"

if [ "$TARGET_REGION" == "primary" ]; then
  echo "Activating primary region..."
  
  # Turn ON primary routing control
  aws route53-recovery-cluster update-routing-control-state \
    --routing-control-arn ${PRIMARY_CONTROL_ARN} \
    --routing-control-state On \
    --endpoint-url ${ENDPOINT}
  
  # Turn OFF secondary routing control
  aws route53-recovery-cluster update-routing-control-state \
    --routing-control-arn ${SECONDARY_CONTROL_ARN} \
    --routing-control-state Off \
    --endpoint-url ${ENDPOINT}
  
  echo "✓ Primary region is now ACTIVE"
  
elif [ "$TARGET_REGION" == "secondary" ]; then
  echo "Activating secondary region..."
  
  # Turn OFF primary routing control
  aws route53-recovery-cluster update-routing-control-state \
    --routing-control-arn ${PRIMARY_CONTROL_ARN} \
    --routing-control-state Off \
    --endpoint-url ${ENDPOINT}
  
  # Turn ON secondary routing control
  aws route53-recovery-cluster update-routing-control-state \
    --routing-control-arn ${SECONDARY_CONTROL_ARN} \
    --routing-control-state On \
    --endpoint-url ${ENDPOINT}
  
  echo "✓ Secondary region is now ACTIVE"
  
else
  echo "Invalid region specified. Use 'primary' or 'secondary'"
  exit 1
fi

echo ""
echo "========================================="
echo "Region Switch Complete!"
echo "========================================="
