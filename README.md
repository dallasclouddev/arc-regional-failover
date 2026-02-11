# AWS ARC Regional Failover with Aurora PostgreSQL

This repository demonstrates how to implement multi-region active-passive failover using AWS Application Recovery Controller (ARC) with Aurora PostgreSQL Global Database.

## Overview

This project provides a complete implementation of a resilient multi-region application architecture using:
- **AWS Application Recovery Controller (ARC)** for coordinated failover
- **Aurora PostgreSQL Global Database** for cross-region data replication
- **CloudFormation** Infrastructure as Code templates
- **Sample Application** to demonstrate failover capabilities

## Architecture

The solution implements an active-passive architecture across two AWS regions:
- **Primary Region**: Serves all application traffic under normal conditions
- **Secondary Region**: Standby region that becomes active during failover

### Key Components

1. **Aurora PostgreSQL Global Database**: Provides low-latency replication across regions with RPO < 1 second
2. **AWS ARC Routing Control**: Manages traffic routing between regions
3. **AWS ARC Readiness Checks**: Monitors resource health across regions
4. **CloudWatch Alarms**: Integrated health monitoring
5. **Application Layer**: Sample Python application demonstrating database connectivity

## Repository Structure

```
.
├── cloudformation/           # CloudFormation templates
│   ├── infrastructure/      # VPC, Aurora, networking
│   └── arc/                 # ARC cluster, routing controls, health checks
├── app/                     # Sample application
│   ├── python/             # Python application code
│   └── config/             # Configuration files
├── scripts/                # Deployment and utility scripts
└── docs/                   # Additional documentation
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Two AWS regions selected (e.g., us-east-1 and us-west-2)
- Sufficient permissions to create VPC, Aurora, ARC resources
- Python 3.8+ (for running the sample application)

## Quick Start

### 1. Deploy Infrastructure

```bash
# Deploy to primary region
./scripts/deploy-primary.sh us-east-1

# Deploy to secondary region
./scripts/deploy-secondary.sh us-west-2
```

### 2. Deploy ARC Components

```bash
# Deploy ARC cluster and routing controls
./scripts/deploy-arc.sh us-west-2
```

### 3. Run Sample Application

```bash
cd app/python
pip install -r requirements.txt
python app.py
```

### 4. Test Failover

```bash
# Initiate failover to secondary region
./scripts/failover.sh
```

## Deployment Guide

Detailed deployment instructions can be found in [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

## Failover Testing

See [docs/TESTING.md](docs/TESTING.md) for comprehensive failover testing procedures.

## Architecture Diagrams

Architecture diagrams are available in the `docs/diagrams/` directory.

## Cost Considerations

This demo creates AWS resources that incur costs:
- Aurora Global Database
- ARC cluster and routing controls
- VPC and networking resources
- CloudWatch alarms

Estimated monthly cost: $200-500 depending on usage and data transfer.

## Cleanup

To remove all resources:

```bash
./scripts/cleanup.sh
```

## Contributing

Contributions are welcome! Please submit pull requests or open issues for improvements.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Additional Resources

- [AWS Application Recovery Controller Documentation](https://docs.aws.amazon.com/r53recovery/latest/dg/what-is-route53-recovery.html)
- [Aurora Global Database Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html)
- [Multi-Region Architecture Best Practices](https://aws.amazon.com/blogs/architecture/)
