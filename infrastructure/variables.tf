variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "europe-west1" 
}

variable "zone" {
  description = "GCP zone for resources"
  type        = string
  default     = "europe-west1-b"
}

# Firestore Database Variables

variable "firestore_database_name" {
  description = "Firestore database name"
  type        = string
  default     = "(default)"
}

variable "firestore_location" {
  description = "Firestore database location"
  type        = string
  default     = "europe-west"
}

variable "firestore_collection_name" {
  description = "Main Firestore collection for storing API data"
  type        = string
  default     = "api_data"
}

# Cloud Function Variables

variable "function_name" {
  description = "Name of the Cloud Function"
  type        = string
  default     = "data-pipeline-function"
}

variable "function_description" {
  description = "Description of the Cloud Function"
  type        = string
  default     = "Fetches data from JSONPlaceholder API and stores in Firestore"
}

variable "function_runtime" {
  description = "Runtime for Cloud Function"
  type        = string
  default     = "python311"
}

variable "function_entry_point" {
  description = "Entry point function name"
  type        = string
  default     = "main"
}

variable "function_timeout" {
  description = "Function timeout in seconds"
  type        = number
  default     = 60
}

variable "function_memory" {
  description = "Memory allocation for function in MB"
  type        = number
  default     = 256
}

variable "function_max_instances" {
  description = "Maximum number of function instances"
  type        = number
  default     = 10
}

# External API Variables

variable "external_api_url" {
  description = "External API base URL"
  type        = string
  default     = "https://jsonplaceholder.typicode.com"
}

variable "api_retry_max_attempts" {
  description = "Maximum retry attempts for API calls"
  type        = number
  default     = 3
}

variable "api_retry_delay" {
  description = "Delay between retries in seconds"
  type        = number
  default     = 2
}

# Cloud Scheduler (Optional)

variable "enable_scheduler" {
  description = "Enable Cloud Scheduler for periodic function execution"
  type        = bool
  default     = false
}

variable "schedule_cron" {
  description = "Cron expression for function schedule"
  type        = string
  default     = "0 */6 * * *"  
}

# Monitoring & Logging Variables

variable "enable_monitoring" {
  description = "Enable Cloud Monitoring alerts"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "alert_email" {
  description = "Email for monitoring alerts (optional)"
  type        = string
  default     = ""
}

# Labels & Tags

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    environment = "production"
    project     = "serverless-data-pipeline"
    managed_by  = "terraform"
  }
}