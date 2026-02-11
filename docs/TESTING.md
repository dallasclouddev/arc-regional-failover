# Failover Testing Guide

This guide describes how to test and validate the regional failover capabilities of your AWS ARC deployment.

## Overview

The testing process validates:
1. Normal operation in primary region
2. Coordinated failover to secondary region
3. Application continuity during failover
4. Failback to primary region

## Prerequisites

- Completed deployment of all infrastructure (see [DEPLOYMENT.md](DEPLOYMENT.md))
- Sample application running and connected to database
- Access to AWS Console and CLI
- Understanding of Aurora Global Database replication

## Test Scenarios

### Test 1: Verify Normal Operation

**Objective**: Confirm the system is working correctly in the primary region.

1. Check routing control state:
   ```bash
   aws route53-recovery-cluster get-routing-control-state \
     --routing-control-arn <PRIMARY-CONTROL-ARN> \
     --endpoint-url <CLUSTER-ENDPOINT>
   ```
   
   Expected: `RoutingControlState: On`

2. Verify database connectivity:
   ```bash
   cd app/python
   python app.py
   ```
   
   Expected: Application connects successfully and logs health checks

3. Check Aurora replication lag:
   ```bash
   aws rds describe-db-clusters \
     --db-cluster-identifier arc-demo-secondary-cluster \
     --region us-west-2 \
     --query 'DBClusters[0].ReplicationSourceIdentifier'
   ```
   
   Expected: Shows primary cluster as replication source

### Test 2: Planned Failover to Secondary Region

**Objective**: Perform a controlled failover to the secondary region.

1. **Pre-failover checks**:
   ```bash
   # Note current database endpoint
   echo "Current primary endpoint:"
   aws rds describe-db-clusters \
     --db-cluster-identifier arc-demo-primary-cluster \
     --region us-east-1 \
     --query 'DBClusters[0].Endpoint' \
     --output text
   
   # Check replication lag
   aws rds describe-global-clusters \
     --global-cluster-identifier arc-demo-global-cluster \
     --region us-east-1
   ```

2. **Initiate failover**:
   ```bash
   ./scripts/failover.sh
   ```
   
   Or manually:
   ```bash
   ./scripts/set-active-region.sh secondary
   ```

3. **Monitor failover progress**:
   - Watch routing control state changes
   - Monitor application logs for connection updates
   - Check Aurora Global Database promotion status
   
   Expected duration: 30-60 seconds for routing control, 1-2 minutes for Aurora

4. **Promote secondary Aurora cluster** (if testing full DR):
   ```bash
   aws rds remove-from-global-cluster \
     --db-cluster-identifier arc-demo-secondary-cluster \
     --global-cluster-identifier arc-demo-global-cluster \
     --region us-west-2
   ```
   
   Note: This breaks the global database and makes secondary independent

5. **Verify failover**:
   ```bash
   # Check secondary routing control is ON
   aws route53-recovery-cluster get-routing-control-state \
     --routing-control-arn <SECONDARY-CONTROL-ARN> \
     --endpoint-url <CLUSTER-ENDPOINT>
   
   # Verify application reconnected
   # Check application logs or database
   ```

### Test 3: Application Behavior During Failover

**Objective**: Verify application handles failover gracefully.

1. **Start continuous health checks**:
   ```bash
   cd app/python
   python app.py
   ```

2. **In another terminal, trigger failover**:
   ```bash
   ./scripts/failover.sh
   ```

3. **Observe application behavior**:
   - Connection errors during transition (expected)
   - Automatic reconnection to new endpoint
   - Continued health check logging
   - Total downtime: typically < 1 minute

4. **Query database to verify continuity**:
   ```sql
   SELECT COUNT(*), MIN(timestamp), MAX(timestamp) 
   FROM health_check 
   WHERE timestamp > NOW() - INTERVAL '10 minutes';
   ```

### Test 4: Failback to Primary Region

**Objective**: Return traffic to the primary region.

1. **Verify secondary region is stable**:
   ```bash
   # Check application is running
   # Verify no errors in CloudWatch Logs
   ```

2. **Initiate failback**:
   ```bash
   ./scripts/set-active-region.sh primary
   ```

3. **Verify failback**:
   ```bash
   # Check primary routing control is ON
   aws route53-recovery-cluster get-routing-control-state \
     --routing-control-arn <PRIMARY-CONTROL-ARN> \
     --endpoint-url <CLUSTER-ENDPOINT>
   ```

### Test 5: Safety Rule Validation

**Objective**: Verify safety rules prevent invalid states.

1. **Attempt to turn OFF all routing controls**:
   ```bash
   # This should fail due to safety rule
   aws route53-recovery-cluster update-routing-control-state \
     --routing-control-arn <PRIMARY-CONTROL-ARN> \
     --routing-control-state Off \
     --endpoint-url <CLUSTER-ENDPOINT>
   ```
   
   Expected: Error message about safety rule violation

2. **Attempt to turn ON both routing controls**:
   ```bash
   # This should fail for active-passive configuration
   aws route53-recovery-cluster update-routing-control-state \
     --routing-control-arn <SECONDARY-CONTROL-ARN> \
     --routing-control-state On \
     --endpoint-url <CLUSTER-ENDPOINT>
   ```
   
   Expected: Error if safety rule configured for active-passive

## Monitoring During Tests

### CloudWatch Metrics to Monitor

1. **Aurora Metrics**:
   - `CPUUtilization`
   - `DatabaseConnections`
   - `AuroraGlobalDBReplicationLag`
   - `Deadlocks`

2. **ARC Metrics**:
   - `ReadinessCheckStatus`
   - Routing control state changes

### CloudWatch Logs

Check logs for:
- Application connection errors
- Database query errors
- Failover timing

```bash
aws logs tail /aws/rds/cluster/arc-demo-primary-cluster/postgresql \
  --follow \
  --region us-east-1
```

## Measuring Failover Performance

### Key Metrics

1. **Detection Time**: Time to detect primary region failure
2. **Decision Time**: Time to decide on failover
3. **Execution Time**: Time to execute routing control change
4. **Recovery Time**: Time for application to reconnect
5. **Total RTO**: End-to-end recovery time objective

### Sample Test Results

| Metric | Target | Typical |
|--------|--------|---------|
| Routing Control Update | < 5s | 2-3s |
| Aurora Promotion | < 60s | 30-45s |
| Application Reconnect | < 30s | 10-15s |
| Total RTO | < 120s | 60-90s |
| RPO (Data Loss) | < 1s | < 1s |

## Troubleshooting Test Failures

### Failover Doesn't Complete

1. Check safety rules aren't blocking the change
2. Verify IAM permissions for ARC operations
3. Ensure cluster endpoints are accessible
4. Review CloudFormation stack outputs for correct ARNs

### Application Doesn't Reconnect

1. Verify application configuration points to correct endpoint
2. Check security groups allow connectivity
3. Review application error logs
4. Confirm database credentials are valid

### High Replication Lag

1. Check network connectivity between regions
2. Review write load on primary cluster
3. Verify secondary instance is sized appropriately
4. Monitor Aurora Global Database metrics

## Best Practices

1. **Regular Testing**: Test failover monthly to ensure procedures work
2. **Document Results**: Keep a log of test results and issues
3. **Automate Testing**: Create automated test scripts
4. **Monitor Continuously**: Set up alarms for key metrics
5. **Practice Runbooks**: Ensure team is familiar with procedures

## Advanced Testing

### Chaos Engineering

1. **Simulate region failure**:
   - Disconnect network connectivity
   - Shut down Aurora instances
   - Trigger CloudWatch alarms

2. **Load testing during failover**:
   - Use tools like JMeter or Locust
   - Measure impact on active users
   - Validate connection pooling behavior

3. **Test partial failures**:
   - Single AZ failure
   - Database instance failure
   - Network partition

## Cleanup After Testing

If performing destructive tests that broke global database:

1. Recreate global database cluster
2. Re-establish replication
3. Verify data consistency
4. Reset routing controls to primary

Or perform full cleanup:

```bash
./scripts/cleanup.sh
```

## Next Steps

- Integrate failover into production runbooks
- Set up automated failover triggers
- Create dashboards for monitoring
- Train operations team on procedures
