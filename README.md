# Serverless GCP Data Pipeline

A serverless data pipeline built on Google Cloud Platform that fetches data from external APIs, processes it, and stores it in Firestore. All infrastructure is provisioned using Terraform.

## Architecture

The pipeline consists of the following components:

- Cloud Function - Python runtime for data processing
- Firestore - NoSQL database for data storage
- Cloud Monitoring - Logging and alerting
- Cloud Scheduler - Optional periodic execution

## Project Structure
```
serverless-gcp-project/
├── infrastructure/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── function/
│   ├── main.py
│   ├── config.py
│   ├── utils.py
│   └── requirements.txt
└── scripts/
    └── deploy.sh
```

## Installation

### 1. Authenticate with GCP
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 2. Configure Terraform Variables
```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your project ID:
```hcl
project_id = "your-gcp-project-id"
```

### 3. Initialize Terraform
```bash
terraform init
```

## Deployment

### Automated Deployment
```bash
./scripts/deploy.sh
```

### Manual Deployment
```bash
cd infrastructure
terraform plan
terraform apply
```

## Testing

### Invoke the Function
```bash
curl -X POST FUNCTION_URL
```

Get the function URL from Terraform outputs:
```bash
terraform output function_url
```

### View Logs
```bash
gcloud functions logs read data-pipeline-function --region=europe-west1
```

### Verify Data in Firestore

Navigate to the GCP Console and check the `api_data` collection in Firestore.

## Configuration

All configuration variables are defined in `infrastructure/variables.tf`. Default values can be overridden in `terraform.tfvars`.

## Infrastructure Components

### Cloud Function

- Runtime: Python 3.11
- Trigger: HTTP
- Memory: 256 MB
- Timeout: 60 seconds
- Service Account: Dedicated with minimal required permissions

### Firestore

- Type: Native mode
- Location: europe-west
- Collection: api_data

### IAM Roles

The service account has the following roles:

- `roles/datastore.user` - Read/write to Firestore
- `roles/logging.logWriter` - Write logs
- `roles/monitoring.metricWriter` - Write metrics

### Monitoring

- Error rate alerts
- Execution logs
- Custom metrics

## Data Processing Pipeline

1. Fetch data from JSONPlaceholder API
2. Validate required fields
3. Transform and enrich data
4. Store in Firestore with batching
5. Log execution summary

## Error Handling

- Exponential backoff retry logic for API calls
- Rate limit handling
- Data validation before processing
- Batch write failures logged and retried
- Comprehensive error logging

## Cleanup

To destroy all infrastructure:
```bash
cd infrastructure
terraform destroy
```

## Security Considerations

- Service account follows principle of least privilege
- API credentials managed via environment variables
- terraform.tfvars excluded from version control
- Firestore security rules should be configured separately

## Monitoring and Logging

Access logs and metrics through:

- GCP Console - Cloud Functions section
- Cloud Logging
- Cloud Monitoring dashboards

## Development

To modify the function:

1. Update code in `function/` directory
2. Test locally if possible
3. Deploy using Terraform

Terraform will automatically package and upload new code.