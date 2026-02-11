#!/bin/bash

# Deploy EventBridge rule to trigger Aurora failover on ARC control changes
# This enables manual failover from the ARC UI

STACK_NAME="aurora-failover-eventbridge"
REGION="us-east-1"
TEMPLATE_FILE="templates/8-eventbridge-arc-trigger.yaml"

echo "Deploying EventBridge rule for ARC-triggered failover..."
aws cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://${TEMPLATE_FILE} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${REGION}

echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete \
    --stack-name ${STACK_NAME} \
    --region ${REGION}

echo "EventBridge rule deployed successfully!"
echo ""
echo "Now when you manually flip ARC controls in the UI, Aurora will automatically failover."
