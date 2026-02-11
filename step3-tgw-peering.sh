#!/bin/bash
set -e

# Step 3: Create Transit Gateway Peering
PRIMARY_TGW_ID="tgw-05204fce9ffba3f7b"
SECONDARY_TGW_ID="tgw-098bf07e364bdb3ba"
PRIMARY_RT_ID="rtb-0a865f5e7d5f82802"

echo "Creating Transit Gateway Peering..."
aws cloudformation create-stack \
  --stack-name aurora-failover-tgw-peering \
  --template-body file://templates/3-tgw-peering.yaml \
  --parameters \
    ParameterKey=PrimaryTGWId,ParameterValue=$PRIMARY_TGW_ID \
    ParameterKey=SecondaryTGWId,ParameterValue=$SECONDARY_TGW_ID \
    ParameterKey=PrimaryRouteTableId,ParameterValue=$PRIMARY_RT_ID \
    ParameterKey=SecondaryVPCCidr,ParameterValue=10.2.0.0/16 \
  --region us-east-1

echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-tgw-peering \
  --region us-east-1

echo "Step 3 completed successfully!"
echo ""
echo "NEXT STEP: Accept TGW peering in us-west-2 console"
echo "1. Go to VPC console in us-west-2"
echo "2. Transit Gateway Attachments"
echo "3. Find peering attachment with status 'pendingAcceptance'"
echo "4. Select it > Actions > Accept transit gateway attachment"
