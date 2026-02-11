#!/bin/bash
set -e

# Step 5: Add Route in Secondary Region
SECONDARY_RT_ID="rtb-0d0d8cf0ad3253388"
SECONDARY_TGW_ID="tgw-098bf07e364bdb3ba"

echo "Adding route in secondary region..."
aws cloudformation create-stack \
  --stack-name aurora-failover-route-secondary \
  --template-body file://templates/3b-route-secondary.yaml \
  --parameters \
    ParameterKey=RouteTableId,ParameterValue=$SECONDARY_RT_ID \
    ParameterKey=TransitGatewayId,ParameterValue=$SECONDARY_TGW_ID \
    ParameterKey=PrimaryVPCCidr,ParameterValue=10.1.0.0/16 \
  --region us-west-2

echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-route-secondary \
  --region us-west-2

echo "Step 5 completed successfully!"
echo ""
echo "Network infrastructure is ready!"
echo "Next: Deploy Aurora databases (Steps 6-7)"
