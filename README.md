# Minimal Aurora Global Database Failover with ARC

## Overview
Simplified deployment to test Aurora Global Database failover using Route 53 ARC with Transit Gateway.

## What Gets Deployed
1. VPCs in us-east-1 and us-west-2
2. Transit Gateway in each region with cross-region peering
3. Aurora Global Database (PostgreSQL)
4. Route 53 ARC (Cluster + 2 Routing Controls)
5. SSM Document (AuroraGlobalDatabaseFailoverSSMDocument) - Orchestrates:
   - Determine active region by checking ARC routing controls
   - Flip ARC routing controls to switch traffic
   - Failover Aurora Global Database (promote secondary to primary)
   - Update Secrets Manager with new database endpoint
6. Lambda function to trigger the SSM Document

## Route 53 ARC Architecture
Route 53 ARC has two separate APIs:

**Control Plane API (route53-recovery-control-config)**
- Purpose: Manage ARC resources (create clusters, routing controls, safety rules)
- Availability: Only in us-west-2
- Used for: describe_cluster(), create_routing_control(), etc.
- Why limited: Control plane operations are infrequent, so AWS centralizes them

**Data Plane API (route53-recovery-cluster)**
- Purpose: Read/update routing control states during failover
- Availability: 5 regional endpoints (us-east-1, us-west-2, ap-northeast-1, ap-southeast-2, eu-west-1)
- Used for: get_routing_control_state(), update_routing_control_state()
- Why distributed: Failover operations need to be highly available even if one region fails

## Deployment Order (via AWS Console)

### Step 1: Deploy VPC + Transit Gateway (us-east-1)
- Template: `1-vpc-tgw-primary.yaml`
- Region: us-east-1
- Stack Name: `aurora-failover-vpc-primary`

### Step 2: Deploy VPC + Transit Gateway (us-west-2)
- Template: `2-vpc-tgw-secondary.yaml`
- Region: us-west-2
- Stack Name: `aurora-failover-vpc-secondary`

### Step 3: Deploy Transit Gateway Peering (us-east-1)
- Template: `3-tgw-peering.yaml`
- Region: us-east-1
- Stack Name: `aurora-failover-tgw-peering`
- Parameters: Use TGW IDs from Step 1 & 2 outputs

### Step 4: Accept TGW Peering (us-west-2)
- Go to VPC Console > Transit Gateway Attachments
- Accept the peering attachment request

### Step 5: Deploy Aurora Primary (us-east-1)
- Template: `4-aurora-primary.yaml`
- Region: us-east-1
- Stack Name: `aurora-failover-db-primary`

### Step 6: Deploy Aurora Secondary (us-west-2)
- Template: `5-aurora-secondary.yaml`
- Region: us-west-2
- Stack Name: `aurora-failover-db-secondary`

### Step 7: Deploy Route 53 ARC (us-east-1)
- Template: `6-route53-arc.yaml`
- Region: us-east-1
- Stack Name: `aurora-failover-arc`

### Step 8: Deploy Failover Automation (us-east-1)
- Template: `7-failover-automation.yaml`
- Region: us-east-1
- Stack Name: `aurora-failover-automation`

### Step 9: Turn On Primary ARC Control
- Route 53 Console > Application Recovery Controller
- Select "AuroraFailover-ControlPanel"
- Select "AuroraFailover-Region1"
- Change state to "On"

## Test Failover
- Lambda Console > Functions > "TriggerFailover"
- Test > Invoke
- Monitor: Systems Manager > Automation > Executions

## Verify
Check Global Cluster status:
- RDS Console > Databases > Global databases > aurora-global-test
- Verify which cluster is the writer
