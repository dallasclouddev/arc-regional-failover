#!/bin/bash

# Deploy Route 53 Application Recovery Controller
# ARC is deployed in us-east-1 (global service with regional endpoint)

STACK_NAME="aurora-failover-arc"
REGION="us-east-1"
TEMPLATE_FILE="templates/6-route53-arc.yaml"

echo "Deploying Route 53 ARC cluster with control panel and routing controls..."
aws cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://${TEMPLATE_FILE} \
    --region ${REGION}

echo "Waiting for stack creation to complete (this may take 5-10 minutes)..."
aws cloudformation wait stack-create-complete \
    --stack-name ${STACK_NAME} \
    --region ${REGION}

echo "Route 53 ARC deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Manually turn ON the us-east-1 routing control in the Route 53 ARC console"
echo "2. Keep the us-west-2 routing control OFF"
