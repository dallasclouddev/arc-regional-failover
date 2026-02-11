# End-to-End Regional Failover Testing Guide

## Prerequisites
- All infrastructure deployed (VPC, TGW, Aurora, ARC, Failover Automation)
- Application tier deployed in both regions
- Database table created
- ARC control for us-east-1 is ON

## Step 1: Create Database Table

Connect to Aurora primary and create the items table:

```sql
CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL
);
```

Or use Lambda to create:
```bash
# Get Aurora endpoint
aws rds describe-global-clusters \
  --global-cluster-identifier aurora-global-test \
  --region us-east-1

# Connect via psql or use a Lambda function
```

## Step 2: Test Primary Region (us-east-1)

Get the API endpoint:
```bash
API_EAST=$(aws ssm get-parameter \
  --name /app-failover/api-endpoint-us-east-1 \
  --region us-east-1 \
  --query 'Parameter.Value' \
  --output text)

echo $API_EAST
```

Create an item:
```bash
curl -X POST $API_EAST/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test from us-east-1"}'
```

Get items:
```bash
curl $API_EAST/items | jq
```

Expected response:
```json
{
  "items": [
    {
      "id": 1,
      "name": "Test from us-east-1",
      "created_at": "2024-02-10 12:00:00",
      "served_from": "us-east-1"
    }
  ],
  "region": "us-east-1",
  "database": "aurora-failover-primary.cluster-xxx.us-east-1.rds.amazonaws.com"
}
```

## Step 3: Verify Secondary Region (us-west-2)

```bash
API_WEST=$(aws ssm get-parameter \
  --name /app-failover/api-endpoint-us-west-2 \
  --region us-west-2 \
  --query 'Parameter.Value' \
  --output text)

# Should see same data (replicated from primary)
curl $API_WEST/items | jq
```

Expected: Same items, but `served_from: "us-west-2"` and database shows us-west-2 endpoint (reader)

## Step 4: Trigger Failover

```bash
aws lambda invoke \
  --function-name TriggerFailover \
  --region us-east-1 \
  response.json

cat response.json | jq
```

Monitor progress:
```bash
# Get execution ID from response
EXECUTION_ID=$(cat response.json | jq -r '.body' | jq -r '.executionId')

# Watch status
aws ssm describe-automation-executions \
  --filters Key=ExecutionId,Values=$EXECUTION_ID \
  --region us-east-1
```

## Step 5: Verify Failover Completed

Check ARC controls:
```bash
# us-east-1 should be OFF
# us-west-2 should be ON
```

Check Aurora writer:
```bash
aws rds describe-global-clusters \
  --global-cluster-identifier aurora-global-test \
  --region us-east-1 \
  --query 'GlobalClusters[0].GlobalClusterMembers[?IsWriter==`true`].DBClusterArn'
```

Should show us-west-2 cluster as writer.

## Step 6: Test After Failover

Create item in new active region:
```bash
curl -X POST $API_WEST/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test from us-west-2 after failover"}'
```

Verify from both regions:
```bash
# us-west-2 (now primary)
curl $API_WEST/items | jq

# us-east-1 (now secondary, reading from replica)
curl $API_EAST/items | jq
```

Both should show all items, with replication lag < 1 second.

## Step 7: Test Failback

```bash
aws lambda invoke \
  --function-name TriggerFailover \
  --region us-east-1 \
  response2.json
```

Wait for completion, then verify:
- ARC: us-east-1 ON, us-west-2 OFF
- Aurora: us-east-1 is writer
- API calls work from both regions

## Step 8: Test with Route 53 DNS (Optional)

If you deployed Route 53 DNS:

```bash
# Use custom domain instead of direct API endpoints
curl https://api-failover-test.example.com/items | jq
```

DNS will automatically route to active region based on ARC health checks.

## Troubleshooting

**Lambda can't connect to Aurora:**
- Check security groups allow Lambda → Aurora on port 5432
- Verify Lambda is in correct subnets
- Check Secrets Manager has correct endpoint

**Failover stuck:**
- Check SSM automation execution logs
- Verify Aurora clusters are "available"
- Check ARC endpoint region matching

**Items not replicating:**
- Verify global database replication status
- Check replication lag in CloudWatch metrics
- Ensure both clusters are in global database

## Success Criteria

✅ Create items in us-east-1, visible in both regions
✅ Failover completes in < 2 minutes
✅ After failover, us-west-2 is writer
✅ Create items in us-west-2, visible in both regions
✅ Failback completes successfully
✅ No data loss during failover/failback
✅ Application continues serving requests throughout
