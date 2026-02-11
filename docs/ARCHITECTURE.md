# Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Application                          │
│                    Recovery Controller (ARC)                     │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │  Routing Control │         │  Routing Control │             │
│  │    (Primary)     │         │   (Secondary)    │             │
│  │    State: ON     │         │    State: OFF    │             │
│  └────────┬─────────┘         └─────────┬────────┘             │
│           │                              │                      │
│           │   Safety Rules:              │                      │
│           │   - At least one ON          │                      │
│           │   - At most one ON           │                      │
└───────────┼──────────────────────────────┼──────────────────────┘
            │                              │
            ▼                              ▼
   ┌─────────────────┐           ┌─────────────────┐
   │  Primary Region │           │ Secondary Region│
   │   (us-east-1)   │           │  (us-west-2)    │
   ├─────────────────┤           ├─────────────────┤
   │                 │           │                 │
   │  ┌───────────┐  │           │  ┌───────────┐  │
   │  │   VPC     │  │           │  │   VPC     │  │
   │  │ 10.0.0.0  │  │           │  │ 10.1.0.0  │  │
   │  │   /16     │  │           │  │   /16     │  │
   │  └─────┬─────┘  │           │  └─────┬─────┘  │
   │        │        │           │        │        │
   │  ┌─────▼──────┐ │           │  ┌─────▼──────┐ │
   │  │ Application│ │           │  │ Application│ │
   │  │   Layer    │ │           │  │   Layer    │ │
   │  └─────┬──────┘ │           │  └─────┬──────┘ │
   │        │        │           │        │        │
   │  ┌─────▼──────┐ │  Global   │  ┌─────▼──────┐ │
   │  │   Aurora   │ │  Database │  │   Aurora   │ │
   │  │ PostgreSQL │◄├───Repli───┼─►│ PostgreSQL │ │
   │  │  (Primary) │ │  cation   │  │(Secondary) │ │
   │  │  Cluster   │ │  < 1 sec  │  │  Cluster   │ │
   │  └────────────┘ │           │  └────────────┘ │
   └─────────────────┘           └─────────────────┘
          ACTIVE                      STANDBY
```

## Detailed Component Architecture

### Primary Region (us-east-1)

```
VPC (10.0.0.0/16)
│
├── Availability Zone A
│   ├── Public Subnet (10.0.1.0/24)
│   │   ├── NAT Gateway A
│   │   └── Internet Gateway (shared)
│   └── Private Subnet (10.0.11.0/24)
│       └── Aurora Instance 1 (Writer)
│
└── Availability Zone B
    ├── Public Subnet (10.0.2.0/24)
    │   └── NAT Gateway B
    └── Private Subnet (10.0.12.0/24)
        └── Aurora Instance 2 (Reader)

Security Groups:
├── Application SG (ports 80, 443)
└── Database SG (port 5432, source: App SG)

Aurora Global Database:
├── Primary Cluster (Read/Write)
├── Automated Backups (7 days)
├── Enhanced Monitoring
└── Performance Insights
```

### Secondary Region (us-west-2)

```
VPC (10.1.0.0/16)
│
├── Availability Zone A
│   ├── Public Subnet (10.1.1.0/24)
│   │   ├── NAT Gateway A
│   │   └── Internet Gateway (shared)
│   └── Private Subnet (10.1.11.0/24)
│       └── Aurora Instance 1 (Read-only Replica)
│
└── Availability Zone B
    ├── Public Subnet (10.1.2.0/24)
    │   └── NAT Gateway B
    └── Private Subnet (10.1.12.0/24)
        └── Aurora Instance 2 (Read-only Replica)

Aurora Global Database:
├── Secondary Cluster (Read-only)
├── Asynchronous Replication from Primary
└── Can be promoted to Read/Write
```

### AWS Application Recovery Controller (ARC)

```
ARC Cluster (Multi-Region)
│
├── Control Panel
│   ├── Primary Routing Control
│   │   └── State: On/Off
│   └── Secondary Routing Control
│       └── State: On/Off
│
├── Safety Rules
│   ├── At Least One Rule
│   │   └── Ensures at least 1 region is active
│   └── At Most One Rule
│       └── Ensures only 1 region active (active-passive)
│
└── Readiness Checks
    ├── Primary Cell
    │   └── Database Resource Check
    └── Secondary Cell
        └── Database Resource Check
```

## Data Flow

### Normal Operation (Primary Active)

```
1. Client Request
   ↓
2. Application (Primary Region)
   ↓
3. Check ARC Routing Control → Primary: ON
   ↓
4. Connect to Primary Aurora Cluster
   ↓
5. Read/Write Operations
   ↓
6. Continuous Replication to Secondary
   ↓
7. Response to Client
```

### Failover Sequence

```
1. Trigger Event
   ├── Manual failover command
   ├── Health check failure
   └── Regional outage
   ↓
2. Update ARC Routing Controls
   ├── Primary: ON → OFF
   └── Secondary: OFF → ON
   ↓
3. Application Detects Change
   ↓
4. Promote Secondary Aurora (if needed)
   └── Remove from Global Cluster
   └── Convert to standalone cluster
   ↓
5. Application Reconnects
   └── Connect to Secondary Cluster
   ↓
6. Resume Operations
   └── Secondary now handles R/W
```

## Network Architecture

### Cross-Region Connectivity

```
Primary Region               Secondary Region
   VPC A                         VPC B
     │                             │
     ├── Private Subnet            ├── Private Subnet
     │   └── Aurora Primary        │   └── Aurora Secondary
     │                             │
     └── PrivateLink               └── PrivateLink
         (Aurora Replication)
              │                    │
              └────────┬───────────┘
                       │
              AWS Global Network
              (Encrypted Replication)
```

## Security Architecture

### Identity and Access

```
IAM Roles & Policies
│
├── Application Role
│   ├── Read Secrets Manager
│   ├── Connect to RDS
│   └── Query ARC Routing Controls
│
├── ARC Management Role
│   ├── Update Routing Controls
│   ├── View Readiness Checks
│   └── Manage Safety Rules
│
└── Monitoring Role
    ├── Enhanced RDS Monitoring
    └── CloudWatch Logs
```

### Data Encryption

```
┌─────────────────────────────────┐
│      Data at Rest               │
├─────────────────────────────────┤
│ • Aurora encrypted with KMS     │
│ • Secrets Manager encrypted     │
│ • Backup encrypted              │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│      Data in Transit            │
├─────────────────────────────────┤
│ • TLS for app → database        │
│ • SSL for replication           │
│ • HTTPS for ARC API calls       │
└─────────────────────────────────┘
```

## Monitoring Architecture

```
CloudWatch
│
├── Metrics
│   ├── Aurora Metrics
│   │   ├── CPU Utilization
│   │   ├── Database Connections
│   │   ├── Replication Lag
│   │   └── Storage Used
│   │
│   ├── ARC Metrics
│   │   ├── Routing Control State
│   │   └── Readiness Status
│   │
│   └── Application Metrics
│       ├── Request Count
│       ├── Error Rate
│       └── Latency
│
├── Alarms
│   ├── High CPU (>80%)
│   ├── High Connections
│   ├── Replication Lag (>1s)
│   └── Readiness Not Ready
│
└── Logs
    ├── Aurora PostgreSQL Logs
    ├── Application Logs
    └── ARC State Changes
```

## Capacity Planning

### Aurora Sizing

| Component | Primary | Secondary |
|-----------|---------|-----------|
| Instance Class | db.r5.large | db.r5.large |
| Instance Count | 2 (1 writer, 1 reader) | 2 (readers) |
| Storage | Auto-scaling up to 128TB | Same as primary |
| IOPS | Auto-scaling | Auto-scaling |

### Cost Estimation

| Service | Monthly Cost (Estimate) |
|---------|-------------------------|
| Aurora Primary Instances (2x db.r5.large) | $200 |
| Aurora Secondary Instances (2x db.r5.large) | $200 |
| Aurora Storage (100GB) | $10 |
| Aurora I/O | $20-50 |
| Data Transfer (cross-region) | $20-100 |
| ARC Cluster | $90 |
| ARC Routing Controls | $10 |
| VPC (NAT Gateways, etc.) | $90 |
| **Total** | **~$640-740/month** |

## Disaster Recovery Metrics

### Recovery Objectives

| Metric | Target | Actual |
|--------|--------|--------|
| RTO (Recovery Time Objective) | < 2 minutes | ~1 minute |
| RPO (Recovery Point Objective) | < 1 second | < 1 second |
| Failover Decision Time | < 30 seconds | 10-20 seconds |
| Application Reconnect | < 30 seconds | 10-15 seconds |

## Scalability Considerations

### Horizontal Scaling

- Add read replicas in each region for read scaling
- Distribute read traffic across replicas
- Use connection pooling for efficient connection management

### Vertical Scaling

- Upgrade instance classes for more CPU/memory
- Minimal downtime during instance modification
- Can be done independently per region

### Geographic Expansion

To add more regions:

1. Deploy VPC and Aurora secondary cluster
2. Add to Aurora Global Database
3. Create new ARC routing control
4. Update safety rules for N regions

## References

- [AWS ARC Documentation](https://docs.aws.amazon.com/r53recovery/)
- [Aurora Global Database](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html)
- [Multi-Region Architecture Patterns](https://aws.amazon.com/solutions/implementations/multi-region-application-architecture/)
