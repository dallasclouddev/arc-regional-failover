# Deployment Guide

This guide provides step-by-step instructions for deploying the multi-region AWS ARC failover demonstration.

## Prerequisites

Before starting, ensure you have:

1. **AWS CLI** installed and configured
   ```bash
   aws --version
   aws configure
   ```

2. **Sufficient AWS Permissions** to create:
   - VPC and networking resources
   - RDS Aurora clusters
   - Route53 Recovery Controller resources
   - CloudWatch alarms
   - IAM roles
   - Secrets Manager secrets

3. **Two AWS Regions** selected for deployment (e.g., us-east-1 and us-west-2)

4. **Python 3.8+** (for running the sample application)

## Architecture Overview

The deployment creates:
- **Primary Region**: Active Aurora cluster with read/write capability
- **Secondary Region**: Standby Aurora cluster with read-only replica
- **AWS ARC**: Routing controls for coordinated failover
- **Monitoring**: CloudWatch alarms and ARC readiness checks

## Deployment Steps

### Step 1: Clone the Repository

```bash
git clone https://github.com/dallasclouddev/arc-regional-failover.git
cd arc-regional-failover
```

### Step 2: Deploy Primary Region

Choose your primary region (e.g., us-east-1):

```bash
./scripts/deploy-primary.sh us-east-1
```

This script will:
1. Create VPC with public and private subnets
2. Deploy NAT gateways and routing tables
3. Create security groups
4. Deploy Aurora PostgreSQL Global Database
5. Set up enhanced monitoring
6. Create database credentials in Secrets Manager

**Important**: Save the database password and Global Cluster ID displayed at the end!

Expected deployment time: 15-20 minutes

### Step 3: Deploy Secondary Region

Using the Global Cluster ID from Step 2, deploy the secondary region:

```bash
./scripts/deploy-secondary.sh us-west-2 <GLOBAL-CLUSTER-ID>
```

Replace `<GLOBAL-CLUSTER-ID>` with the ID from Step 2.

This script will:
1. Create VPC infrastructure in secondary region
2. Deploy Aurora secondary cluster attached to global database
3. Configure cross-region replication

Expected deployment time: 15-20 minutes

### Step 4: Deploy AWS ARC Components

Deploy the Application Recovery Controller:

```bash
./scripts/deploy-arc.sh us-west-2
```

This script will:
1. Create ARC cluster with regional endpoints
2. Set up control panel
3. Create routing controls for both regions
4. Configure safety rules (at least one region must be active)

Expected deployment time: 5-10 minutes

### Step 5: Set Initial Active Region

Activate the primary region:

```bash
./scripts/set-active-region.sh primary
```

This sets the primary region as the active region for traffic.

### Step 6: Verify Deployment

Check that all resources are created:

```bash
# Check primary region stacks
aws cloudformation list-stacks --region us-east-1 \
  --stack-status-filter CREATE_COMPLETE

# Check secondary region stacks
aws cloudformation list-stacks --region us-west-2 \
  --stack-status-filter CREATE_COMPLETE

# Check ARC routing control state
aws route53-recovery-cluster get-routing-control-state \
  --routing-control-arn <PRIMARY-CONTROL-ARN> \
  --endpoint-url <CLUSTER-ENDPOINT>
```

## Post-Deployment Configuration

### Configure Application

1. Copy the example configuration:
   ```bash
   cd app/config
   cp .env.example .env
   ```

2. Edit `.env` with your actual values:
   ```bash
   DB_SECRET_NAME=arc-demo/database/credentials
   AWS_REGION=us-east-1
   ROUTING_CONTROL_ARN=<your-routing-control-arn>
   CLUSTER_ENDPOINTS=<your-cluster-endpoints>
   ```

### Install Application Dependencies

```bash
cd app/python
pip install -r requirements.txt
```

### Run the Application

```bash
python app.py
```

The application will:
- Connect to the active Aurora cluster
- Initialize the database schema
- Perform periodic health checks
- Log activity to the database

## Testing Failover

See [TESTING.md](TESTING.md) for detailed failover testing procedures.

## Troubleshooting

### Stack Creation Fails

If a CloudFormation stack fails to create:

1. Check the CloudFormation console for error details
2. Review CloudFormation events:
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name <stack-name> \
     --region <region>
   ```
3. Common issues:
   - Insufficient permissions
   - Resource limits exceeded
   - Invalid parameter values

### Database Connection Fails

1. Verify security group rules allow traffic from application
2. Check that database is in available state:
   ```bash
   aws rds describe-db-clusters \
     --db-cluster-identifier arc-demo-primary-cluster \
     --region us-east-1
   ```
3. Verify credentials in Secrets Manager

### ARC Routing Control Issues

1. Ensure safety rules are satisfied (at least one region must be ON)
2. Use correct cluster endpoint URL
3. Check IAM permissions for Route53 Recovery Controller

## Cost Optimization

To reduce costs during testing:

1. Use smaller instance types (db.r5.large instead of db.r5.xlarge)
2. Delete resources when not in use:
   ```bash
   ./scripts/cleanup.sh
   ```
3. Consider using Aurora Serverless v2 for variable workloads

## Next Steps

- Review [TESTING.md](TESTING.md) for failover testing
- Explore CloudWatch metrics and alarms
- Integrate with your existing applications
- Set up SNS notifications for alarms

## Support

For issues or questions:
- Open an issue on GitHub
- Review AWS documentation for ARC and Aurora
- Check AWS Support if you have a support plan
