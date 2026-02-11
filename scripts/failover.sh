#!/bin/bash
set -e

# Perform Regional Failover
# Usage: ./failover.sh [environment-name]

ENV_NAME=${1:-arc-demo}
ARC_REGION=${2:-us-west-2}

echo "========================================="
echo "Initiating Regional Failover"
echo "Environment: $ENV_NAME"
echo "========================================="

# Get current routing control states
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

ENDPOINT=$(echo $CLUSTER_ENDPOINTS | cut -d',' -f1)

echo "Checking current routing control states..."
PRIMARY_STATE=$(aws route53-recovery-cluster get-routing-control-state \
  --routing-control-arn ${PRIMARY_CONTROL_ARN} \
  --endpoint-url ${ENDPOINT} \
  --query 'RoutingControlState' \
  --output text)

echo "Primary region state: $PRIMARY_STATE"

# Determine target region based on current state
if [ "$PRIMARY_STATE" == "On" ]; then
  echo ""
  echo "Failing over from PRIMARY to SECONDARY..."
  TARGET="secondary"
else
  echo ""
  echo "Failing over from SECONDARY to PRIMARY..."
  TARGET="primary"
fi

# Perform the failover
./scripts/set-active-region.sh $TARGET $ENV_NAME $ARC_REGION

echo ""
echo "========================================="
echo "Failover Complete!"
echo "Active region is now: $TARGET"
echo "========================================="
echo ""
echo "Verify the failover:"
echo "  1. Check application connectivity"
echo "  2. Monitor CloudWatch metrics"
echo "  3. Review ARC readiness status"
echo "========================================="
