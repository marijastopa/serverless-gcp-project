"""
Utility functions for the data pipeline
Includes retry logic, data validation, and health checks
"""

import time
import logging
from typing import Any, Dict, List, Optional, Callable
from datetime import datetime
import requests
from google.cloud import firestore


logger = logging.getLogger(__name__)


def retry_with_backoff(
    func: Callable,
    max_attempts: int = 3,
    initial_delay: int = 2,
    backoff_factor: float = 2.0,
    exceptions: tuple = (Exception,)
) -> Any:
    delay = initial_delay
    last_exception = None
    
    for attempt in range(1, max_attempts + 1):
        try:
            logger.info(f"Attempt {attempt}/{max_attempts}")
            result = func()
            logger.info(f"Success on attempt {attempt}")
            return result
            
        except exceptions as e:
            last_exception = e
            logger.warning(f"Attempt {attempt} failed: {str(e)}")
            
            if attempt < max_attempts:
                logger.info(f"Retrying in {delay} seconds...")
                time.sleep(delay)
                delay *= backoff_factor
            else:
                logger.error(f"All {max_attempts} attempts failed")
    
    raise last_exception


def validate_post_data(data: Dict[str, Any]) -> bool:
    required_fields = ['userId', 'id', 'title', 'body']
    
    # Check if all required fields exist
    for field in required_fields:
        if field not in data:
            logger.warning(f"Missing required field: {field}")
            return False
    
    # Validate field types
    if not isinstance(data.get('userId'), int):
        logger.warning(f"Invalid userId type: {type(data.get('userId'))}")
        return False
    
    if not isinstance(data.get('id'), int):
        logger.warning(f"Invalid id type: {type(data.get('id'))}")
        return False
    
    if not isinstance(data.get('title'), str) or not data.get('title').strip():
        logger.warning(f"Invalid or empty title")
        return False
    
    if not isinstance(data.get('body'), str) or not data.get('body').strip():
        logger.warning(f"Invalid or empty body")
        return False
    
    return True


def transform_post_data(data: Dict[str, Any]) -> Dict[str, Any]:
    transformed = {
        'user_id': data['userId'],
        'post_id': data['id'],
        'title': data['title'].strip(),
        'body': data['body'].strip(),
        'title_length': len(data['title'].strip()),
        'body_length': len(data['body'].strip()),
        'word_count': len(data['body'].strip().split()),
        'fetched_at': firestore.SERVER_TIMESTAMP,
        'processed_at': datetime.utcnow().isoformat(),
        'source': 'jsonplaceholder',
        'status': 'processed'
    }
    
    return transformed


def check_firestore_health(db: firestore.Client) -> bool:
    try:
        # Try to read from a health check collection
        health_ref = db.collection('_health_check').document('status')
        health_ref.set({
            'last_check': firestore.SERVER_TIMESTAMP,
            'status': 'healthy'
        })
        
        # Verify we can read it back
        doc = health_ref.get()
        if doc.exists:
            logger.info("Firestore health check passed")
            return True
        else:
            logger.error("Firestore health check failed: document not found")
            return False
            
    except Exception as e:
        logger.error(f"Firestore health check failed: {str(e)}")
        return False


def handle_rate_limit(response: requests.Response) -> None:
    if response.status_code == 429:
        retry_after = response.headers.get('Retry-After', '60')
        logger.warning(f"Rate limited. Retry after {retry_after} seconds")
        raise Exception(f"Rate limited. Retry after {retry_after} seconds")
    
    response.raise_for_status()


def batch_write_to_firestore(
    db: firestore.Client,
    collection_name: str,
    items: List[Dict[str, Any]],
    batch_size: int = 5
) -> int:
    total_written = 0
    
    for i in range(0, len(items), batch_size):
        batch = db.batch()
        batch_items = items[i:i + batch_size]
        
        for item in batch_items:
            doc_id = f"post_{item['post_id']}"
            doc_ref = db.collection(collection_name).document(doc_id)
            batch.set(doc_ref, item)
        
        try:
            batch.commit()
            total_written += len(batch_items)
            logger.info(f"Batch write successful: {len(batch_items)} items")
        except Exception as e:
            logger.error(f"Batch write failed: {str(e)}")
            raise
    
    return total_written


def get_execution_summary(
    total_fetched: int,
    total_processed: int,
    total_stored: int,
    errors: List[str],
    start_time: datetime
) -> Dict[str, Any]:
    end_time = datetime.utcnow()
    duration = (end_time - start_time).total_seconds()
    
    return {
        'execution_time': duration,
        'start_time': start_time.isoformat(),
        'end_time': end_time.isoformat(),
        'items_fetched': total_fetched,
        'items_processed': total_processed,
        'items_stored': total_stored,
        'success_rate': (total_stored / total_fetched * 100) if total_fetched > 0 else 0,
        'errors_count': len(errors),
        'errors': errors[:10],  # Limit to first 10 errors
        'status': 'success' if total_stored > 0 and len(errors) == 0 else 'partial' if total_stored > 0 else 'failed'
    }