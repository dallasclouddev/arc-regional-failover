#!/bin/bash

# Deploy Failover Automation - SSM Document and Lambda

STACK_NAME="aurora-failover-automation"
REGION="us-east-1"
TEMPLATE_FILE="templates/7-failover-automation.yaml"

echo "Deploying failover automation (SSM Document + Lambda)..."
aws cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://${TEMPLATE_FILE} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${REGION}

echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete \
    --stack-name ${STACK_NAME} \
    --region ${REGION}

echo "Failover automation deployed successfully!"
echo ""
echo "Resources created:"
echo "- SSM Document: AuroraGlobalDatabaseFailoverSSMDocument"
echo "- Lambda Function: TriggerFailover"
