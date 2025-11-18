import os
from flask import Flask, render_template, url_for, request, redirect
from flask_sqlalchemy import SQLAlchemy 
from azure.servicebus import ServiceBusClient
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)
app.config.from_object('config.DevelopmentConfig')

app.secret_key = app.config.get('SECRET_KEY')

# Initialize Service Bus client (will be None if connection string is empty)
service_bus_connection_string = app.config.get('SERVICE_BUS_CONNECTION_STRING')
if service_bus_connection_string:
    try:
        servicebus_client = ServiceBusClient.from_connection_string(service_bus_connection_string)
        queue_client = servicebus_client
    except Exception as e:
        print(f"Warning: Could not initialize Service Bus client: {e}")
        queue_client = None
else:
    print("Warning: SERVICE_BUS_CONNECTION_STRING not configured. Service Bus features will be disabled.")
    queue_client = None

db = SQLAlchemy(app)

from . import routes
