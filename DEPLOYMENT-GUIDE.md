# Deployment Guide - Manual Steps via AWS Console

## Prerequisites
- AWS Account with permissions for VPC, RDS, Route53, Lambda, SSM, Transit Gateway
- Access to us-east-1 and us-west-2 regions
- (Optional) AWS CLI configured for command-line deployment

## Phase 1: Network Infrastructure

### Step 1: Deploy Primary VPC (us-east-1)

**Via Console:**
1. Go to CloudFormation console in **us-east-1**
2. Create Stack > Upload template: `1-vpc-tgw-primary.yaml`
3. Stack name: `aurora-failover-vpc-primary`
4. Use default parameters
5. Wait for CREATE_COMPLETE
6. Note outputs: TransitGatewayId, PrivateRouteTableId

**Via CLI:**
```bash
aws cloudformation create-stack \
  --stack-name aurora-failover-vpc-primary \
  --template-body file://minimal-deployment/templates/1-vpc-tgw-primary.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-vpc-primary \
  --region us-east-1

aws cloudformation describe-stacks \
  --stack-name aurora-failover-vpc-primary \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

### Step 2: Deploy Secondary VPC (us-west-2)

**Via Console:**
1. Go to CloudFormation console in **us-west-2**
2. Create Stack > Upload template: `2-vpc-tgw-secondary.yaml`
3. Stack name: `aurora-failover-vpc-secondary`
4. Use default parameters
5. Wait for CREATE_COMPLETE
6. Note outputs: TransitGatewayId, PrivateRouteTableId

**Via CLI:**
```bash
aws cloudformation create-stack \
  --stack-name aurora-failover-vpc-secondary \
  --template-body file://minimal-deployment/templates/2-vpc-tgw-secondary.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2

aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-vpc-secondary \
  --region us-west-2

aws cloudformation describe-stacks \
  --stack-name aurora-failover-vpc-secondary \
  --region us-west-2 \
  --query 'Stacks[0].Outputs'
```

### Step 3: Create Transit Gateway Peering (us-east-1)

**Via Console:**
1. Go to CloudFormation console in **us-east-1**
2. Create Stack > Upload template: `3-tgw-peering.yaml`
3. Stack name: `aurora-failover-tgw-peering`
4. Parameters:
   - PrimaryTGWId: (from Step 1 output)
   - SecondaryTGWId: (from Step 2 output)
   - PrimaryRouteTableId: (from Step 1 output)
   - SecondaryVPCCidr: 10.2.0.0/16
5. Wait for CREATE_COMPLETE

**Via CLI:**
```bash
# Replace with your actual values from Step 1 & 2
PRIMARY_TGW_ID="tgw-xxxxx"
SECONDARY_TGW_ID="tgw-yyyyy"
PRIMARY_RT_ID="rtb-zzzzz"

aws cloudformation create-stack \
  --stack-name aurora-failover-tgw-peering \
  --template-body file://minimal-deployment/templates/3-tgw-peering.yaml \
  --parameters \
    ParameterKey=PrimaryTGWId,ParameterValue=$PRIMARY_TGW_ID \
    ParameterKey=SecondaryTGWId,ParameterValue=$SECONDARY_TGW_ID \
    ParameterKey=PrimaryRouteTableId,ParameterValue=$PRIMARY_RT_ID \
    ParameterKey=SecondaryVPCCidr,ParameterValue=10.2.0.0/16 \
  --region us-east-1

aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-tgw-peering \
  --region us-east-1
```

### Step 4: Accept TGW Peering (us-west-2)
1. Go to VPC console in **us-west-2**
2. Transit Gateway Attachments
3. Find peering attachment with status "pendingAcceptance"
4. Select it > Actions > Accept transit gateway attachment
5. Wait for status to become "available"

### Step 5: Add Route in Secondary Region (us-west-2)

**Via Console:**
1. Go to CloudFormation console in **us-west-2**
2. Create Stack > Upload template: `3b-route-secondary.yaml`
3. Stack name: `aurora-failover-route-secondary`
4. Parameters:
   - RouteTableId: (from Step 2 output)
   - TransitGatewayId: (from Step 2 output)
   - PrimaryVPCCidr: 10.1.0.0/16
5. Wait for CREATE_COMPLETE

**Via CLI:**
```bash
# Replace with your actual values from Step 2
SECONDARY_RT_ID="rtb-aaaaa"
SECONDARY_TGW_ID="tgw-yyyyy"

aws cloudformation create-stack \
  --stack-name aurora-failover-route-secondary \
  --template-body file://minimal-deployment/templates/3b-route-secondary.yaml \
  --parameters \
    ParameterKey=RouteTableId,ParameterValue=$SECONDARY_RT_ID \
    ParameterKey=TransitGatewayId,ParameterValue=$SECONDARY_TGW_ID \
    ParameterKey=PrimaryVPCCidr,ParameterValue=10.1.0.0/16 \
  --region us-west-2

aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-route-secondary \
  --region us-west-2
```

## Phase 2: Aurora Global Database

### Step 6: Deploy Aurora Primary (us-east-1)

**Via Console:**
1. Go to CloudFormation console in **us-east-1**
2. Create Stack > Upload template: `4-aurora-primary.yaml`
3. Stack name: `aurora-failover-db-primary`
4. Parameters:
   - DBUsername: dbadmin
   - DBPassword: (create strong password, save it)
5. Wait for CREATE_COMPLETE (takes ~10 minutes)
6. Note output: DBClusterEndpoint

**Via CLI:**
```bash
DB_PASSWORD="YourStrongPassword123!"

aws cloudformation create-stack \
  --stack-name aurora-failover-db-primary \
  --template-body file://minimal-deployment/templates/4-aurora-primary.yaml \
  --parameters \
    ParameterKey=DBUsername,ParameterValue=dbadmin \
    ParameterKey=DBPassword,ParameterValue=$DB_PASSWORD \
  --region us-east-1

aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-db-primary \
  --region us-east-1

aws cloudformation describe-stacks \
  --stack-name aurora-failover-db-primary \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

### Step 7: Deploy Aurora Secondary (us-west-2)

**Via Console:**
1. Go to CloudFormation console in **us-west-2**
2. Create Stack > Upload template: `5-aurora-secondary.yaml`
3. Stack name: `aurora-failover-db-secondary`
4. Parameters:
   - GlobalClusterIdentifier: aurora-global-test
5. Wait for CREATE_COMPLETE (takes ~10 minutes)
6. Note output: DBClusterEndpoint

**Via CLI:**
```bash
aws cloudformation create-stack \
  --stack-name aurora-failover-db-secondary \
  --template-body file://minimal-deployment/templates/5-aurora-secondary.yaml \
  --parameters \
    ParameterKey=GlobalClusterIdentifier,ParameterValue=aurora-global-test \
  --region us-west-2

aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-db-secondary \
  --region us-west-2

aws cloudformation describe-stacks \
  --stack-name aurora-failover-db-secondary \
  --region us-west-2 \
  --query 'Stacks[0].Outputs'
```

### Step 8: Verify Global Database
1. Go to RDS console in **us-east-1**
2. Global databases > aurora-global-test
3. Verify:
   - Primary cluster: aurora-failover-primary (Writer)
   - Secondary cluster: aurora-failover-secondary (Reader)

## Phase 3: Route 53 ARC

### Step 9: Deploy Route 53 ARC (us-east-1)

**Via Console:**
1. Go to CloudFormation console in **us-east-1**
2. Create Stack > Upload template: `6-route53-arc.yaml`
3. Stack name: `aurora-failover-arc`
4. Wait for CREATE_COMPLETE (takes ~5 minutes)

**Via CLI:**
```bash
aws cloudformation create-stack \
  --stack-name aurora-failover-arc \
  --template-body file://minimal-deployment/templates/6-route53-arc.yaml \
  --region us-east-1

aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-arc \
  --region us-east-1
```

### Step 10: Turn On Primary ARC Control
1. Go to Route 53 console > Application Recovery Controller
2. Select "AuroraFailover-ControlPanel"
3. Select "AuroraFailover-Region1"
4. Click "Change routing control states"
5. Set state to "On"
6. Click "Change traffic routing"

## Phase 4: Failover Automation

### Step 11: Deploy Failover Automation (us-east-1)

**Via Console:**
1. Go to CloudFormation console in **us-east-1**
2. Create Stack > Upload template: `7-failover-automation.yaml`
3. Stack name: `aurora-failover-automation`
4. Check "I acknowledge that AWS CloudFormation might create IAM resources"
5. Wait for CREATE_COMPLETE

**Via CLI:**
```bash
aws cloudformation create-stack \
  --stack-name aurora-failover-automation \
  --template-body file://minimal-deployment/templates/7-failover-automation.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

aws cloudformation wait stack-create-complete \
  --stack-name aurora-failover-automation \
  --region us-east-1
```

## Testing Failover

### Step 12: Trigger Failover

**Via Console:**
1. Go to Lambda console in **us-east-1**
2. Functions > TriggerFailover
3. Test tab > Create test event (use default)
4. Click "Test"

**Via CLI:**
```bash
aws lambda invoke \
  --function-name TriggerFailover \
  --region us-east-1 \
  response.json

cat response.json
```

### Step 13: Monitor Execution
1. Go to Systems Manager console in **us-east-1**
2. Automation > Executions
3. Find "AuroraFailoverRunbook" execution
4. Monitor steps (takes ~5-10 minutes):
   - DetermineActiveRegion
   - FlipARCControls
   - FailoverAurora
   - UpdateSecret

### Step 14: Verify Failover
1. Go to RDS console in **us-east-1**
2. Global databases > aurora-global-test
3. Verify roles swapped:
   - Primary cluster: aurora-failover-primary (Reader)
   - Secondary cluster: aurora-failover-secondary (Writer)

4. Go to Route 53 console > Application Recovery Controller
5. Verify ARC controls flipped:
   - AuroraFailover-Region1: Off
   - AuroraFailover-Region2: On

6. Go to Secrets Manager in **us-east-1**
7. View secret: aurora-failover-db-secret
8. Verify "host" field now points to us-west-2 endpoint

## Failback

To failback to primary region:
1. Invoke Lambda function again
2. Process repeats in reverse

## Cleanup

Delete stacks in reverse order:
1. aurora-failover-automation (us-east-1)
2. aurora-failover-arc (us-east-1)
3. aurora-failover-db-secondary (us-west-2)
4. aurora-failover-db-primary (us-east-1)
5. aurora-failover-route-secondary (us-west-2)
6. aurora-failover-tgw-peering (us-east-1)
7. aurora-failover-vpc-secondary (us-west-2)
8. aurora-failover-vpc-primary (us-east-1)

## Troubleshooting

**TGW Peering not working:**
- Verify peering attachment is "available" in both regions
- Check route tables have routes to remote CIDR blocks

**Aurora failover fails:**
- Verify global database status is "available"
- Check IAM role has RDS permissions

**ARC controls not flipping:**
- Verify ARC cluster endpoints are accessible
- Check IAM role has route53-recovery-cluster permissions

**Secret not updating:**
- Verify Lambda has secretsmanager permissions
- Check secret exists in us-east-1
