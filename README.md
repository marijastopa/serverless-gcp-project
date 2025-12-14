# Serverless GCP Data Pipeline

A serverless data pipeline on Google Cloud Platform that fetches data from external APIs, processes it, and stores it in Firestore. Complete infrastructure provisioned as code using Terraform.

## Overview

This project implements an automated data pipeline that:
- Fetches data from JSONPlaceholder REST API
- Validates and transforms the data
- Stores processed records in Firestore
- Monitors execution and logs all operations
- Handles errors with exponential backoff retry logic

## Architecture
```
External API (JSONPlaceholder)
          ↓
    Cloud Function (Python 3.11)
          ↓
    Data Processing & Validation
          ↓
    Firestore (NoSQL Database)
          ↓
    Cloud Monitoring & Logging
```

## Technology Stack

- **Infrastructure**: Terraform 
- **Runtime**: Python 3.11
- **Cloud Platform**: Google Cloud Platform
- **Database**: Firestore (Native mode)
- **Compute**: Cloud Functions 
- **Monitoring**: Cloud Monitoring & Cloud Logging
- **Region**: europe-west1 (Belgium)

## Project Structure
```
serverless-gcp-project/
├── infrastructure/          # Terraform configuration
│   ├── main.tf             # GCP resources definition
│   ├── variables.tf        # Configuration variables
│   ├── outputs.tf          # Deployment outputs
│   └── terraform.tfvars    # Project-specific values (gitignored)
├── function/               # Cloud Function source code
│   ├── main.py            # Main function logic
│   ├── config.py          # Configuration management
│   ├── utils.py           # Helper functions
│   └── requirements.txt   # Python dependencies
├── scripts/
│   └── deploy.sh          # Deployment automation script
└── README.md
```

## Installation

### 1. Clone Repository
```bash
git clone git@github.com:YOUR_USERNAME/serverless-gcp-project.git
cd serverless-gcp-project
```

### 2. Install Dependencies
```bash
# Install Terraform
brew install terraform

# Install Google Cloud SDK
brew install --cask google-cloud-sdk

# Authenticate
gcloud auth login
gcloud auth application-default login
```

### 3. Configure GCP Project
```bash
# Set your project ID
gcloud config set project YOUR_PROJECT_ID

# Create terraform.tfvars
cd infrastructure
cat > terraform.tfvars << EOF
project_id = "YOUR_PROJECT_ID"
EOF
```

## Deployment

### Automated Deployment
```bash
./scripts/deploy.sh
```

### Manual Deployment
```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

Deployment takes approximately 3-5 minutes and creates:
- Firestore database
- Cloud Function with service account
- IAM roles and permissions
- Cloud Storage bucket
- Monitoring alert policy
- Required API enablements

## Testing

### Invoke Function
```bash
curl -X POST https://data-pipeline-function-4j5meez7dq-ew.a.run.app
```

Expected response:
```json
{
  "status": "success",
  "execution_time": 2.27,
  "items_fetched": 100,
  "items_processed": 10,
  "items_stored": 10,
  "success_rate": 10.0,
  "errors_count": 0
}
```

### View Logs
```bash
gcloud functions logs read data-pipeline-function --region=europe-west1 --limit=50
```

### Verify Data in Firestore

Navigate to GCP Console:
```
Firestore → Database (default) → api_data collection
```

You should see 10 documents (post_1 through post_10) with fields:
- body, title (original content)
- body_length, title_length, word_count (metadata)
- user_id, post_id (identifiers)
- fetched_at, processed_at (timestamps)
- source, status (tracking fields)

## Configuration

All configuration is managed through Terraform variables in `infrastructure/variables.tf`.

## Infrastructure Components

### Firestore Database
- **Type**: Native mode
- **Location**: eur3 (Belgium and Netherlands)
- **Collection**: api_data
- **Access**: Service account with datastore.user role

### Cloud Function
- **Runtime**: Python 3.11
- **Memory**: 256 MB
- **Timeout**: 60 seconds
- **Concurrency**: Max 10 instances
- **Trigger**: HTTP (unauthenticated for testing)

### Service Account
Dedicated service account with minimal required permissions:
- roles/datastore.user
- roles/cloudfunctions.invoker
- roles/logging.logWriter
- roles/monitoring.metricWriter

### Monitoring
- Error rate alert policy (threshold: 5 errors/minute)
- Automatic logging to Cloud Logging
- Execution metrics tracked in Cloud Monitoring

## Data Processing Pipeline

1. **Fetch**: HTTP GET request to external API with retry logic
2. **Validate**: Check required fields and data types
3. **Transform**: Add metadata (word count, lengths, timestamps)
4. **Store**: Batch write to Firestore (batches of 5 documents)
5. **Log**: Record execution summary and statistics

## Error Handling

- **Retry Logic**: Exponential backoff (3 attempts, 2-second initial delay)
- **Rate Limiting**: HTTP 429 detection and handling
- **Validation**: Pre-storage data validation
- **Health Checks**: Firestore connectivity verification
- **Comprehensive Logging**: All errors captured with context

## Monitoring and Observability

### Logs
Access function logs via:
- GCP Console: Cloud Functions → Logs tab
- CLI: `gcloud functions logs read data-pipeline-function`

### Metrics
Monitor via GCP Console:
- Cloud Functions → Metrics tab
- Cloud Monitoring → Dashboards

### Alerts
Alert policy triggers when error rate exceeds 5 errors per minute.

## Security

- Service account follows principle of least privilege
- IAM roles scoped to minimum required permissions
- terraform.tfvars excluded from version control
- No hardcoded credentials in source code
- Environment variables for configuration

## Cleanup

To remove all infrastructure:
```bash
cd infrastructure
terraform destroy
```

This will delete:
- Cloud Function
- Firestore database (including all data)
- Service account
- Storage bucket
- Monitoring policies
