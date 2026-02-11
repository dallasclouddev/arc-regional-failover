#!/bin/bash
set -e

# Cleanup All Resources
# Usage: ./cleanup.sh [environment-name] [primary-region] [secondary-region] [arc-region]

ENV_NAME=${1:-arc-demo}
PRIMARY_REGION=${2:-us-east-1}
SECONDARY_REGION=${3:-us-west-2}
ARC_REGION=${4:-us-west-2}

echo "========================================="
echo "Cleaning Up All Resources"
echo "Environment: $ENV_NAME"
echo "========================================="
echo ""
echo "WARNING: This will delete all resources!"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

# Delete ARC resources
echo ""
echo "Deleting ARC resources..."
aws cloudformation delete-stack \
  --stack-name ${ENV_NAME}-arc-cluster \
  --region ${ARC_REGION} || true

echo "Waiting for ARC stack deletion..."
aws cloudformation wait stack-delete-complete \
  --stack-name ${ENV_NAME}-arc-cluster \
  --region ${ARC_REGION} || true

# Delete secondary region resources
echo ""
echo "Deleting secondary region resources..."
aws cloudformation delete-stack \
  --stack-name ${ENV_NAME}-secondary-aurora \
  --region ${SECONDARY_REGION} || true

echo "Waiting for secondary Aurora stack deletion..."
aws cloudformation wait stack-delete-complete \
  --stack-name ${ENV_NAME}-secondary-aurora \
  --region ${SECONDARY_REGION} || true

aws cloudformation delete-stack \
  --stack-name ${ENV_NAME}-secondary-vpc \
  --region ${SECONDARY_REGION} || true

echo "Waiting for secondary VPC stack deletion..."
aws cloudformation wait stack-delete-complete \
  --stack-name ${ENV_NAME}-secondary-vpc \
  --region ${SECONDARY_REGION} || true

# Delete primary region resources
echo ""
echo "Deleting primary region resources..."
aws cloudformation delete-stack \
  --stack-name ${ENV_NAME}-primary-aurora \
  --region ${PRIMARY_REGION} || true

echo "Waiting for primary Aurora stack deletion..."
aws cloudformation wait stack-delete-complete \
  --stack-name ${ENV_NAME}-primary-aurora \
  --region ${PRIMARY_REGION} || true

aws cloudformation delete-stack \
  --stack-name ${ENV_NAME}-primary-vpc \
  --region ${PRIMARY_REGION} || true

echo "Waiting for primary VPC stack deletion..."
aws cloudformation wait stack-delete-complete \
  --stack-name ${ENV_NAME}-primary-vpc \
  --region ${PRIMARY_REGION} || true

echo ""
echo "========================================="
echo "Cleanup Complete!"
echo "========================================="
echo "All resources have been deleted."
