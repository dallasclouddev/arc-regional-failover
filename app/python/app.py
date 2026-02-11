"""
Multi-Region Application with Aurora PostgreSQL
Demonstrates AWS ARC regional failover capabilities
"""

import os
import sys
import json
import time
import psycopg2
import boto3
from datetime import datetime
from typing import Dict, Optional

class DatabaseConnection:
    """Manages database connections with failover support"""
    
    def __init__(self, secret_name: str, region: str):
        self.secret_name = secret_name
        self.region = region
        self.connection = None
        self.credentials = None
        
    def get_credentials(self) -> Dict:
        """Retrieve database credentials from Secrets Manager"""
        if self.credentials:
            return self.credentials
            
        try:
            client = boto3.client('secretsmanager', region_name=self.region)
            response = client.get_secret_value(SecretId=self.secret_name)
            self.credentials = json.loads(response['SecretString'])
            return self.credentials
        except Exception as e:
            print(f"Error retrieving credentials: {e}")
            raise
    
    def connect(self) -> bool:
        """Establish database connection"""
        try:
            creds = self.get_credentials()
            self.connection = psycopg2.connect(
                host=creds['host'],
                port=creds['port'],
                database=creds['dbname'],
                user=creds['username'],
                password=creds['password'],
                connect_timeout=5
            )
            print(f"✓ Connected to database at {creds['host']}")
            return True
        except Exception as e:
            print(f"✗ Connection failed: {e}")
            return False
    
    def disconnect(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            self.connection = None
    
    def execute_query(self, query: str) -> Optional[list]:
        """Execute SQL query and return results"""
        if not self.connection:
            print("No active connection")
            return None
            
        try:
            cursor = self.connection.cursor()
            cursor.execute(query)
            
            if query.strip().upper().startswith('SELECT'):
                results = cursor.fetchall()
                cursor.close()
                return results
            else:
                self.connection.commit()
                cursor.close()
                return []
        except Exception as e:
            print(f"Query execution error: {e}")
            self.connection.rollback()
            return None


class ARCRoutingControl:
    """Manages AWS ARC routing control state"""
    
    def __init__(self, cluster_endpoints: list):
        self.cluster_endpoints = cluster_endpoints
        self.client = boto3.client(
            'route53-recovery-cluster',
            endpoint_url=cluster_endpoints[0]
        )
    
    def get_routing_control_state(self, control_arn: str) -> str:
        """Get current state of routing control"""
        try:
            response = self.client.get_routing_control_state(
                RoutingControlArn=control_arn
            )
            return response['RoutingControlState']
        except Exception as e:
            print(f"Error getting routing control state: {e}")
            return "UNKNOWN"
    
    def update_routing_control_state(self, control_arn: str, state: str) -> bool:
        """Update routing control state (On/Off)"""
        try:
            self.client.update_routing_control_state(
                RoutingControlArn=control_arn,
                RoutingControlState=state
            )
            print(f"✓ Updated routing control to {state}")
            return True
        except Exception as e:
            print(f"✗ Failed to update routing control: {e}")
            return False


def initialize_database(db: DatabaseConnection):
    """Initialize database schema and sample data"""
    print("\nInitializing database...")
    
    # Create sample table
    create_table = """
    CREATE TABLE IF NOT EXISTS health_check (
        id SERIAL PRIMARY KEY,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        region VARCHAR(50),
        status VARCHAR(20),
        message TEXT
    );
    """
    
    db.execute_query(create_table)
    
    # Insert initial record
    insert_data = """
    INSERT INTO health_check (region, status, message)
    VALUES ('primary', 'healthy', 'Initial setup complete');
    """
    
    db.execute_query(insert_data)
    print("✓ Database initialized")


def perform_health_check(db: DatabaseConnection, region: str):
    """Perform health check and log to database"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    # Insert health check record
    query = f"""
    INSERT INTO health_check (region, status, message)
    VALUES ('{region}', 'healthy', 'Health check at {timestamp}');
    """
    
    result = db.execute_query(query)
    
    if result is not None:
        print(f"✓ Health check logged for {region}")
        
        # Query recent health checks
        recent_checks = db.execute_query(
            "SELECT timestamp, region, status FROM health_check ORDER BY timestamp DESC LIMIT 5;"
        )
        
        if recent_checks:
            print("\nRecent health checks:")
            for check in recent_checks:
                print(f"  {check[0]} | {check[1]} | {check[2]}")
    else:
        print(f"✗ Health check failed for {region}")


def main():
    """Main application entry point"""
    print("=" * 60)
    print("AWS ARC Multi-Region Application Demo")
    print("=" * 60)
    
    # Configuration (would typically come from environment or config file)
    config = {
        'secret_name': os.getenv('DB_SECRET_NAME', 'arc-demo/database/credentials'),
        'region': os.getenv('AWS_REGION', 'us-east-1'),
        'routing_control_arn': os.getenv('ROUTING_CONTROL_ARN', ''),
        'cluster_endpoints': os.getenv('CLUSTER_ENDPOINTS', '').split(',')
    }
    
    # Initialize database connection
    db = DatabaseConnection(config['secret_name'], config['region'])
    
    if not db.connect():
        print("Failed to connect to database. Exiting.")
        sys.exit(1)
    
    try:
        # Initialize database if needed
        initialize_database(db)
        
        # Continuous health check loop
        print("\nStarting health check loop (Ctrl+C to stop)...")
        while True:
            perform_health_check(db, config['region'])
            time.sleep(30)  # Check every 30 seconds
            
    except KeyboardInterrupt:
        print("\n\nShutting down gracefully...")
    except Exception as e:
        print(f"\nError: {e}")
    finally:
        db.disconnect()
        print("✓ Disconnected from database")


if __name__ == '__main__':
    main()
