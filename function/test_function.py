#!/usr/bin/env python3
"""
Test script to simulate Azure Function Service Bus trigger locally
"""
import sys
import os

# Add function directory to path
sys.path.insert(0, '/workspaces/nd081-c3-Migrating-Non-Native-Cloud-Applications-project-starter/function')

# Set environment variables
os.environ['POSTGRES_URL'] = 'techconf-db-xizeh6mypik36.postgres.database.azure.com'
os.environ['POSTGRES_USER'] = 'techconfadmin'
os.environ['POSTGRES_PW'] = 'SecurePass123!'
os.environ['POSTGRES_DB'] = 'techconfdb'
os.environ['ADMIN_EMAIL_ADDRESS'] = 'info@techconf.com'
os.environ['SENDGRID_API_KEY'] = 'YOUR_SENDGRID_API_KEY'

# Mock Azure Functions ServiceBusMessage
class MockServiceBusMessage:
    def __init__(self, notification_id):
        self.notification_id = notification_id
    
    def get_body(self):
        return str(self.notification_id).encode('utf-8')

# Import the function
from __init__ import main

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Test Azure Function locally')
    parser.add_argument('notification_id', type=int, help='Notification ID to process')
    args = parser.parse_args()
    
    print(f"Testing function with notification ID: {args.notification_id}")
    print("-" * 60)
    
    # Create mock message
    mock_msg = MockServiceBusMessage(args.notification_id)
    
    # Call the function
    try:
        main(mock_msg)
        print("-" * 60)
        print("✅ Function executed successfully!")
    except Exception as e:
        print("-" * 60)
        print(f"❌ Function failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
