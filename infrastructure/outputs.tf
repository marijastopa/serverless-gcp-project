# Firestore Outputs

output "firestore_database_name" {
  description = "Name of the Firestore database"
  value       = google_firestore_database.database.name
}

output "firestore_location" {
  description = "Location of the Firestore database"
  value       = google_firestore_database.database.location_id
}

output "firestore_collection_name" {
  description = "Main Firestore collection name"
  value       = var.firestore_collection_name
}

# Cloud Function Outputs

output "function_name" {
  description = "Name of the Cloud Function"
  value       = google_cloudfunctions2_function.data_pipeline.name
}

output "function_url" {
  description = "HTTP URL of the Cloud Function"
  value       = google_cloudfunctions2_function.data_pipeline.service_config[0].uri
}

output "function_region" {
  description = "Region where the function is deployed"
  value       = google_cloudfunctions2_function.data_pipeline.location
}

output "function_runtime" {
  description = "Runtime environment of the function"
  value       = google_cloudfunctions2_function.data_pipeline.build_config[0].runtime
}

# Service Account Outputs

output "service_account_email" {
  description = "Email of the service account used by the function"
  value       = google_service_account.function_sa.email
}

output "service_account_name" {
  description = "Name of the service account"
  value       = google_service_account.function_sa.name
}

# Storage Outputs

output "function_bucket_name" {
  description = "Name of the Cloud Storage bucket for function source"
  value       = google_storage_bucket.function_bucket.name
}

output "function_bucket_url" {
  description = "URL of the Cloud Storage bucket"
  value       = google_storage_bucket.function_bucket.url
}

# Scheduler Outputs (if enabled)

output "scheduler_job_name" {
  description = "Name of the Cloud Scheduler job (if enabled)"
  value       = var.enable_scheduler ? google_cloud_scheduler_job.function_trigger[0].name : "Not enabled"
}

output "scheduler_cron" {
  description = "Cron schedule for the function (if enabled)"
  value       = var.enable_scheduler ? var.schedule_cron : "Not enabled"
}

# Monitoring Outputs

output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = var.enable_monitoring
}

output "alert_policy_name" {
  description = "Name of the monitoring alert policy (if enabled)"
  value       = var.enable_monitoring ? google_monitoring_alert_policy.function_errors[0].display_name : "Not enabled"
}

# Project Information

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}