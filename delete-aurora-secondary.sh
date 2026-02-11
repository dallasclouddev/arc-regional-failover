#!/bin/bash

# Delete Aurora Secondary Stack
# This removes the secondary cluster from the global database and deletes the stack

STACK_NAME="aurora-failover-secondary"
REGION="us-west-2"
CLUSTER_ID="aurora-failover-secondary"

echo "Step 1: Removing secondary cluster from global database..."
aws rds remove-from-global-cluster \
    --global-cluster-identifier aurora-global-test \
    --db-cluster-identifier arn:aws:rds:us-west-2:$(aws sts get-caller-identity --query Account --output text):cluster:${CLUSTER_ID} \
    --region ${REGION}

echo "Waiting for cluster to be removed from global database (this may take a few minutes)..."
sleep 60

echo "Step 2: Deleting CloudFormation stack..."
aws cloudformation delete-stack \
    --stack-name ${STACK_NAME} \
    --region ${REGION}

echo "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name ${STACK_NAME} \
    --region ${REGION}

echo "Aurora secondary stack deleted successfully!"
