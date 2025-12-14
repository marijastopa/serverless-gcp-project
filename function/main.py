"""
Cloud Function for Data Pipeline
Fetches data from JSONPlaceholder API, processes it, and stores in Firestore
"""

import logging
import sys
from datetime import datetime
from typing import Dict, Any, List
import requests
from google.cloud import firestore
from google.cloud import logging as cloud_logging

from config import Config
from utils import (
    retry_with_backoff,
    validate_post_data,
    transform_post_data,
    check_firestore_health,
    handle_rate_limit,
    batch_write_to_firestore,
    get_execution_summary
)


# Initialize Cloud Logging
logging_client = cloud_logging.Client()
logging_client.setup_logging()

# Configure logger
logger = logging.getLogger(__name__)
logger.setLevel(getattr(logging, Config.LOG_LEVEL))


def fetch_data_from_api() -> List[Dict[str, Any]]:
    url = f"{Config.EXTERNAL_API_URL}{Config.API_ENDPOINT}"
    logger.info(f"Fetching data from: {url}")
    
    def make_request():
        response = requests.get(
            url,
            timeout=Config.API_TIMEOUT,
            headers={'User-Agent': 'GCP-Cloud-Function-Data-Pipeline/1.0'}
        )
        handle_rate_limit(response)
        return response.json()
    
    # Fetch with retry logic
    data = retry_with_backoff(
        func=make_request,
        max_attempts=Config.API_RETRY_MAX_ATTEMPTS,
        initial_delay=Config.API_RETRY_DELAY,
        backoff_factor=Config.API_RETRY_BACKOFF,
        exceptions=(requests.RequestException, Exception)
    )
    
    logger.info(f"Successfully fetched {len(data)} items from API")
    return data


def process_data(raw_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    processed_items = []
    errors = []
    
    # Limit number of items to process
    items_to_process = raw_data[:Config.MAX_ITEMS_TO_PROCESS]
    logger.info(f"Processing {len(items_to_process)} items")
    
    for idx, item in enumerate(items_to_process, 1):
        try:
            # Validate data
            if not validate_post_data(item):
                errors.append(f"Item {idx}: Validation failed")
                logger.warning(f"Skipping item {idx}: validation failed")
                continue
            
            # Transform data
            transformed = transform_post_data(item)
            processed_items.append(transformed)
            logger.debug(f"Item {idx}: Processed successfully")
            
        except Exception as e:
            error_msg = f"Item {idx}: Processing error - {str(e)}"
            errors.append(error_msg)
            logger.error(error_msg)
    
    logger.info(f"Processed {len(processed_items)} items successfully, {len(errors)} errors")
    
    if errors:
        logger.warning(f"Processing errors: {errors}")
    
    return processed_items


def store_data_in_firestore(db: firestore.Client, items: List[Dict[str, Any]]) -> int:
    if not items:
        logger.warning("No items to store in Firestore")
        return 0
    
    logger.info(f"Storing {len(items)} items in Firestore collection: {Config.FIRESTORE_COLLECTION}")
    
    try:
        # Batch write to Firestore
        stored_count = batch_write_to_firestore(
            db=db,
            collection_name=Config.FIRESTORE_COLLECTION,
            items=items,
            batch_size=Config.BATCH_SIZE
        )
        
        logger.info(f"Successfully stored {stored_count} items in Firestore")
        return stored_count
        
    except Exception as e:
        logger.error(f"Failed to store data in Firestore: {str(e)}")
        raise


def initialize_firestore() -> firestore.Client:
    try:
        logger.info(f"Initializing Firestore client for project: {Config.PROJECT_ID}")
        db = firestore.Client(
            project=Config.PROJECT_ID,
            database=Config.FIRESTORE_DATABASE
        )
        
        # Perform health check
        if not check_firestore_health(db):
            raise Exception("Firestore health check failed")
        
        logger.info("Firestore client initialized successfully")
        return db
        
    except Exception as e:
        logger.error(f"Failed to initialize Firestore: {str(e)}")
        raise


def main(request) -> tuple:
    start_time = datetime.utcnow()
    errors = []
    
    try:
        # Log function invocation
        logger.info("=" * 80)
        logger.info("Cloud Function execution started")
        logger.info(f"Configuration: {Config.to_dict()}")
        
        # Validate configuration
        Config.validate()
        
        # Initialize Firestore
        db = initialize_firestore()
        
        # Step 1: Fetch data from API
        logger.info("Step 1: Fetching data from external API")
        raw_data = fetch_data_from_api()
        
        # Step 2: Process data
        logger.info("Step 2: Processing and validating data")
        processed_data = process_data(raw_data)
        
        # Step 3: Store data in Firestore
        logger.info("Step 3: Storing data in Firestore")
        stored_count = store_data_in_firestore(db, processed_data)
        
        # Generate execution summary
        summary = get_execution_summary(
            total_fetched=len(raw_data),
            total_processed=len(processed_data),
            total_stored=stored_count,
            errors=errors,
            start_time=start_time
        )
        
        logger.info("Cloud Function execution completed successfully")
        logger.info(f"Execution summary: {summary}")
        logger.info("=" * 80)
        
        return (summary, 200)
        
    except Exception as e:
        error_msg = f"Cloud Function execution failed: {str(e)}"
        logger.error(error_msg, exc_info=True)
        
        summary = {
            'status': 'failed',
            'error': str(e),
            'execution_time': (datetime.utcnow() - start_time).total_seconds(),
            'timestamp': datetime.utcnow().isoformat()
        }
        
        logger.info("=" * 80)
        return (summary, 500)


# Health check endpoint
def health_check(request) -> tuple:
    try:
        # Check Firestore connection
        db = initialize_firestore()
        firestore_healthy = check_firestore_health(db)
        
        health_status = {
            'status': 'healthy' if firestore_healthy else 'unhealthy',
            'firestore': 'connected' if firestore_healthy else 'disconnected',
            'timestamp': datetime.utcnow().isoformat(),
            'version': '1.0.0'
        }
        
        status_code = 200 if firestore_healthy else 503
        return (health_status, status_code)
        
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return ({'status': 'unhealthy', 'error': str(e)}, 503)