# AWS Health Dashboard Automated Failover (Optional)

## What is AWS Health Dashboard?

AWS Health Dashboard provides alerts when AWS detects issues affecting your resources:
- RDS database failures
- Network connectivity issues
- Hardware problems
- Regional service degradations

**Example Events:**
- "RDS cluster connectivity issue in us-east-1"
- "RDS hardware failure affecting your database"
- "Network connectivity degradation in Availability Zone"

## How Automated Failover Works

```
AWS detects RDS issue in us-east-1
    ↓
AWS Health publishes event
    ↓
EventBridge rule catches event
    ↓
FailoverDecisionFunction evaluates:
  - Is it RDS?
  - Is it in the active region?
  - Is it critical?
    ↓
If YES → Invokes TriggerFailover Lambda
    ↓
Failover starts automatically
```

## Deployment Steps (AFTER Manual Testing)

### Step 1: Test Manual Failover First
Complete all manual failover tests from DEPLOYMENT-GUIDE.md before proceeding.

### Step 2: Deploy Health Trigger (us-east-1)
1. CloudFormation console in **us-east-1**
2. Create Stack > Upload: `8-automated-health-trigger-OPTIONAL.yaml`
3. Stack name: `aurora-failover-health-trigger`
4. Wait for CREATE_COMPLETE

### Step 3: Subscribe to Notifications
1. Go to SNS console in **us-east-1**
2. Topics > AuroraFailoverNotifications
3. Create subscription:
   - Protocol: Email
   - Endpoint: your-email@example.com
4. Confirm subscription via email

### Step 4: Test Decision Logic (Without Failover)
```python
# Manually invoke FailoverDecisionFunction with test event
{
  "detail": {
    "service": "RDS",
    "eventTypeCode": "AWS_RDS_OPERATIONAL_ISSUE",
    "affectedRegion": "us-east-1"
  }
}
```
Check CloudWatch Logs to verify decision logic.

### Step 5: Enable Automated Failover
1. EventBridge console in **us-east-1**
2. Rules > AuroraFailoverHealthTrigger
3. Actions > Enable
4. Confirm

## What Events Trigger Failover?

The template monitors these AWS Health event types:
- `AWS_RDS_OPERATIONAL_ISSUE` - Database operational problems
- `AWS_RDS_HARDWARE_FAILURE` - Hardware failures
- `AWS_RDS_NETWORK_CONNECTIVITY_ISSUE` - Network issues

## Safety Features

1. **Region Check**: Only triggers if event is in the currently active region
2. **Service Filter**: Only RDS events trigger failover
3. **Disabled by Default**: Rule starts disabled for safety
4. **Notifications**: SNS alerts you when failover is triggered
5. **Decision Function**: Evaluates event before triggering

## Testing Automated Failover

AWS doesn't provide a way to simulate Health events, but you can:

1. **Manual Test**: Invoke FailoverDecisionFunction with test event
2. **Monitor Real Events**: Watch AWS Health Dashboard for actual events
3. **Dry Run**: Keep rule disabled and monitor what would trigger

## Customization

### Add More Event Types
Edit EventPattern in template:
```yaml
eventTypeCode:
  - AWS_RDS_OPERATIONAL_ISSUE
  - AWS_RDS_HARDWARE_FAILURE
  - AWS_RDS_NETWORK_CONNECTIVITY_ISSUE
  - AWS_RDS_MAINTENANCE_SCHEDULED  # Add this
```

### Add Approval Step
Modify FailoverDecisionFunction to:
1. Send SNS notification
2. Wait for human approval
3. Then trigger failover

### Add Cooldown Period
Prevent multiple failovers in short time:
```python
# Check DynamoDB for last failover time
# Only failover if > 1 hour since last failover
```

## Disable Automated Failover

1. EventBridge console > Rules
2. AuroraFailoverHealthTrigger > Disable

Or delete the stack entirely.

## Cost

- EventBridge: Free (first 1M events/month)
- Lambda: ~$0.20/month (minimal invocations)
- SNS: $0.50/month (email notifications)

**Total: ~$1/month**

## Monitoring

### CloudWatch Logs
- `/aws/lambda/FailoverDecisionFunction` - Decision logic
- `/aws/lambda/TriggerFailover` - Failover execution

### Metrics to Watch
- Lambda invocations
- Failover execution count
- Health event frequency

## Troubleshooting

**Failover not triggering:**
- Verify EventBridge rule is enabled
- Check Health event matches pattern
- Review FailoverDecisionFunction logs

**False positives:**
- Adjust event type filters
- Add more decision logic
- Implement approval workflow

**Missed events:**
- Check EventBridge rule is in correct region
- Verify Lambda permissions
- Review CloudWatch Logs for errors
