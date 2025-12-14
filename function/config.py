"""
Configuration module for Cloud Function
Loads environment variables and provides configuration settings
"""

import os
from typing import Dict, Any

class Config:
    """Configuration class for the data pipeline function"""
    
    # GCP Project Configuration
    PROJECT_ID: str = os.environ.get('PROJECT_ID', '')
    FIRESTORE_DATABASE: str = os.environ.get('FIRESTORE_DATABASE', '(default)')
    FIRESTORE_COLLECTION: str = os.environ.get('FIRESTORE_COLLECTION', 'api_data')
    
    # External API Configuration
    EXTERNAL_API_URL: str = os.environ.get('EXTERNAL_API_URL', 'https://jsonplaceholder.typicode.com')
    API_ENDPOINT: str = '/posts'  # JSONPlaceholder posts endpoint
    
    # Retry Configuration
    API_RETRY_MAX_ATTEMPTS: int = int(os.environ.get('API_RETRY_MAX_ATTEMPTS', '3'))
    API_RETRY_DELAY: int = int(os.environ.get('API_RETRY_DELAY', '2'))
    API_RETRY_BACKOFF: float = 2.0  # Exponential backoff multiplier
    
    # Timeout Configuration
    API_TIMEOUT: int = 30  # seconds
    
    # Logging Configuration
    LOG_LEVEL: str = os.environ.get('LOG_LEVEL', 'INFO')
    
    # Data Processing Configuration
    MAX_ITEMS_TO_PROCESS: int = 10  # Limit number of items to process per run
    BATCH_SIZE: int = 5  # Firestore batch write size
    
    @classmethod
    def validate(cls) -> bool:
        """Validate that required configuration is present"""
        required_fields = ['PROJECT_ID']
        
        for field in required_fields:
            value = getattr(cls, field, None)
            if not value:
                raise ValueError(f"Missing required configuration: {field}")
        
        return True
    
    @classmethod
    def to_dict(cls) -> Dict[str, Any]:
        """Convert configuration to dictionary for logging"""
        return {
            'project_id': cls.PROJECT_ID,
            'firestore_database': cls.FIRESTORE_DATABASE,
            'firestore_collection': cls.FIRESTORE_COLLECTION,
            'api_url': cls.EXTERNAL_API_URL,
            'api_endpoint': cls.API_ENDPOINT,
            'retry_max_attempts': cls.API_RETRY_MAX_ATTEMPTS,
            'retry_delay': cls.API_RETRY_DELAY,
            'log_level': cls.LOG_LEVEL,
        }