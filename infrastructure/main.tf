terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Google Cloud Provider

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Enable Required APIs

resource "google_project_service" "firestore" {
  project = var.project_id
  service = "firestore.googleapis.com"
  
  disable_on_destroy = false
}

resource "google_project_service" "cloudfunctions" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"
  
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
  
  disable_on_destroy = false
}

resource "google_project_service" "logging" {
  project = var.project_id
  service = "logging.googleapis.com"
  
  disable_on_destroy = false
}

resource "google_project_service" "monitoring" {
  project = var.project_id
  service = "monitoring.googleapis.com"
  
  disable_on_destroy = false
}

# Firestore Database

resource "google_firestore_database" "database" {
  project     = var.project_id
  name        = var.firestore_database_name
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"
  
  # Prevent accidental deletion
  deletion_policy = "DELETE"
  
  depends_on = [google_project_service.firestore]
}

# Service Account for Cloud Function

resource "google_service_account" "function_sa" {
  account_id   = "${var.function_name}-sa"
  display_name = "Service Account for ${var.function_name}"
  description  = "Service account used by the data pipeline Cloud Function"
  project      = var.project_id
}


# IAM Roles for Service Account

# Firestore Data User - allows read/write to Firestore
resource "google_project_iam_member" "firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# Cloud Functions Invoker - allows function to be invoked
resource "google_project_iam_member" "function_invoker" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# Logging - allows writing logs
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# Monitoring Metric Writer - allows writing custom metrics
resource "google_project_iam_member" "monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# Cloud Storage Bucket for Function Source Code

resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project_id}-${var.function_name}-source"
  location = var.region
  project  = var.project_id
  
  uniform_bucket_level_access = true
  
  labels = var.labels
  
  # Lifecycle rule to delete old versions
  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }
}

# Archive Function Source Code

data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = "${path.module}/../function"
  output_path = "${path.module}/function-source.zip"
}

# Upload Function Source to Cloud Storage

resource "google_storage_bucket_object" "function_archive" {
  name   = "function-source-${data.archive_file.function_source.output_md5}.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = data.archive_file.function_source.output_path
}

# Cloud Function 

resource "google_cloudfunctions2_function" "data_pipeline" {
  name        = var.function_name
  location    = var.region
  description = var.function_description
  project     = var.project_id
  
  build_config {
    runtime     = var.function_runtime
    entry_point = var.function_entry_point
    
    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_archive.name
      }
    }
  }
  
  service_config {
    max_instance_count = var.function_max_instances
    available_memory   = "${var.function_memory}M"
    timeout_seconds    = var.function_timeout
    
    environment_variables = {
      PROJECT_ID              = var.project_id
      FIRESTORE_DATABASE      = var.firestore_database_name
      FIRESTORE_COLLECTION    = var.firestore_collection_name
      EXTERNAL_API_URL        = var.external_api_url
      API_RETRY_MAX_ATTEMPTS  = var.api_retry_max_attempts
      API_RETRY_DELAY         = var.api_retry_delay
      LOG_LEVEL               = "INFO"
    }
    
    service_account_email = google_service_account.function_sa.email
  }
  
  labels = var.labels
  
  depends_on = [
    google_project_service.cloudfunctions,
    google_project_service.cloudbuild,
    google_project_service.cloudrun,
    google_firestore_database.database
  ]
}

# Allow unauthenticated invocations (for testing)

resource "google_cloud_run_service_iam_member" "invoker" {
  project  = google_cloudfunctions2_function.data_pipeline.project
  location = google_cloudfunctions2_function.data_pipeline.location
  service  = google_cloudfunctions2_function.data_pipeline.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Scheduler (Optional)

resource "google_cloud_scheduler_job" "function_trigger" {
  count = var.enable_scheduler ? 1 : 0
  
  name        = "${var.function_name}-trigger"
  description = "Triggers ${var.function_name} periodically"
  schedule    = var.schedule_cron
  time_zone   = "Europe/Belgrade"
  project     = var.project_id
  region      = var.region
  
  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.data_pipeline.service_config[0].uri
    
    oidc_token {
      service_account_email = google_service_account.function_sa.email
    }
  }
  
  depends_on = [google_cloudfunctions2_function.data_pipeline]
}

# Monitoring Alert Policy (if enabled)

resource "google_monitoring_alert_policy" "function_errors" {
  count = var.enable_monitoring ? 1 : 0
  
  display_name = "${var.function_name} Error Rate Alert"
  combiner     = "OR"
  
  conditions {
    display_name = "Function Error Rate"
    
    condition_threshold {
      filter          = "resource.type = \"cloud_function\" AND resource.labels.function_name = \"${var.function_name}\" AND metric.type = \"cloudfunctions.googleapis.com/function/execution_count\" AND metric.labels.status != \"ok\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  documentation {
    content = "Cloud Function ${var.function_name} is experiencing high error rates."
  }
  
  depends_on = [google_cloudfunctions2_function.data_pipeline]
}

resource "google_project_service" "cloudrun" {
  project = var.project_id
  service = "run.googleapis.com"
  
  disable_on_destroy = false
}