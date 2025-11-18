import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

app_dir = os.path.abspath(os.path.dirname(__file__))

class BaseConfig:
    DEBUG = True
    
    # Database Configuration - Use environment variables
    POSTGRES_URL = os.getenv('POSTGRES_URL', 'localhost')
    POSTGRES_USER = os.getenv('POSTGRES_USER', 'postgres')
    POSTGRES_PW = os.getenv('POSTGRES_PW', '')
    POSTGRES_DB = os.getenv('POSTGRES_DB', 'techconfdb')
    
    DB_URL = 'postgresql://{user}:{pw}@{url}/{db}'.format(
        user=POSTGRES_USER,
        pw=POSTGRES_PW,
        url=POSTGRES_URL,
        db=POSTGRES_DB
    )
    SQLALCHEMY_DATABASE_URI = os.getenv('SQLALCHEMY_DATABASE_URI') or DB_URL
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    CONFERENCE_ID = 1
    SECRET_KEY = os.getenv('SECRET_KEY', 'LWd2tzlprdGHCIPHTd4tp5SBFgDszm')
    
    # Azure Service Bus Configuration
    SERVICE_BUS_CONNECTION_STRING = os.getenv('SERVICE_BUS_CONNECTION_STRING', '')
    SERVICE_BUS_QUEUE_NAME = os.getenv('SERVICE_BUS_QUEUE_NAME', 'notificationqueue')
    
    # Email Configuration
    ADMIN_EMAIL_ADDRESS = os.getenv('ADMIN_EMAIL_ADDRESS', 'info@techconf.com')
    SENDGRID_API_KEY = os.getenv('SENDGRID_API_KEY', 'YOUR_SENDGRID_API_KEY')

class DevelopmentConfig(BaseConfig):
    DEBUG = True


class ProductionConfig(BaseConfig):
    DEBUG = False