resource "cloudflare_workers_domain" "project_domain" {
  account_id = var.cloudflare_account_id
  hostname   = "${var.project_name}.${var.environment}.${var.domain}"
  service    = "${var.project_name}-${var.environment}"
  zone_id    = var.cloudflare_zone_id

  depends_on = [cloudflare_workers_script.project_script]
}

resource "cloudflare_workers_route" "project_route" {
  zone_id     = var.cloudflare_zone_id
  pattern     = "${var.project_name}.${var.environment}.${var.domain}/*"
  script_name = cloudflare_workers_script.project_script.name
}

resource "null_resource" "project_id" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/get_project_id.sh"
    environment = {
       project = "pulsedb-${var.environment}"
    }
  }
}

data "local_file" "load_project_id" {
    filename = "${path.module}/project_id"
  depends_on = [ null_resource.project_id ]
}

resource "cloudflare_workers_script" "project_script" {
  account_id         = var.cloudflare_account_id
  name               = "${var.project_name}-${var.environment}"
  content            = file("${path.module}/dist/index.mjs")
  compatibility_date = "2023-08-28"
  module             = true

  plain_text_binding {
    name = "CORS_DOMAINS"
    text = var.ALLOWED_HOSTS
  }

  plain_text_binding {
    name = "ENVIRONMENT"
    text = var.environment
  }

  plain_text_binding {
    name = "GCP_LOGGING_PROJECT_ID"
    text = var.GCP_LOGGING_PROJECT_ID
  }

  plain_text_binding {
    name = "LOG_NAME"
    text = "${var.project_name}_${var.environment}_worker_log"
  }

  r2_bucket_binding {
    name        = "SCHEMAS_BUCKET"
    bucket_name = "schemas-pulsedb-${var.environment}"
  }

  plain_text_binding {
    name = "PULSE_DATASET"
    text = "pulsedb_dataset"
  }

  plain_text_binding {
    name = "PULSE_DATABASE_PROJECT_ID"
    text = data.local_file.load_project_id.content
  }

  plain_text_binding {
    name = "VERSION"
    text = var.VERSION
  }

  secret_text_binding {
    name = "GCP_LOGGING_CREDENTIALS"
    text = var.GCP_LOGGING_CREDENTIALS
  }

  secret_text_binding {
    name = "GCP_BIGQUERY_CREDENTIALS"
    text = var.GCP_BIGQUERY_CREDENTIALS
  }

  secret_text_binding {
    name = "GCP_USERINFO_CREDENTIALS"
    text = var.GCP_USERINFO_CREDENTIALS
  }

  secret_text_binding {
    name = "GLOBAL_SHARED_SECRET"
    text = var.GLOBAL_SHARED_SECRET
  }

  depends_on = [ data.local_file.load_project_id ]
}
