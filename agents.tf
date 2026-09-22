# Dedicated Service Account per A2A Agent
resource "google_service_account" "agent_sa" {
  for_each = var.agents

  project      = var.project_id
  account_id   = "${var.prefix}-${each.key}-sa"
  display_name = "Service Account for A2A Agent: ${each.key}"
}

# Flatten Inter-Agent Invocation Matrix for IAM Bindings
locals {
  agent_invocation_pairs = flatten([
    for source_name, source_agent in var.agents : [
      for target_name in source_agent.target_agent_invocations : {
        source_agent = source_name
        target_agent = target_name
        key          = "${source_name}-invokes-${target_name}"
      }
      if contains(keys(var.agents), target_name)
    ]
  ])
  agent_invocation_map = {
    for pair in local.agent_invocation_pairs : pair.key => pair
  }
}

# Cloud Run v2 Services per Agent
resource "google_cloud_run_v2_service" "agent_service" {
  for_each = var.agents

  project  = var.project_id
  location = var.region
  name     = "${var.prefix}-${each.key}"
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.agent_sa[each.key].email

    scaling {
      min_instance_count = each.value.min_instances
      max_instance_count = each.value.max_instances
    }

    containers {
      image = each.value.image

      ports {
        container_port = each.value.port
      }

      resources {
        limits = {
          cpu    = each.value.cpu
          memory = each.value.memory
        }
      }

      # Standard A2A protocol environment variables
      env {
        name  = "A2A_AGENT_NAME"
        value = each.key
      }

      env {
        name  = "A2A_ROLE_DESCRIPTION"
        value = each.value.role_description
      }

      env {
        name  = "A2A_WELL_KNOWN_URI"
        value = "/.well-known/agent.json"
      }

      # Custom user environment variables
      dynamic "env" {
        for_each = each.value.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Dynamic injection of downstream target agent URLs (for chained workflows)
      dynamic "env" {
        for_each = toset(each.value.target_agent_invocations)
        content {
          name  = "A2A_TARGET_${upper(replace(env.value, "-", "_"))}_URL"
          value = contains(keys(google_cloud_run_v2_service.agent_service), env.value) ? google_cloud_run_v2_service.agent_service[env.value].uri : ""
        }
      }

      # Injection of configuration script secret (if provided)
      dynamic "env" {
        for_each = each.value.config_script != null ? [1] : []
        content {
          name = "A2A_CONFIG_SCRIPT"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.config_scripts[each.key].secret_id
              version = "latest"
            }
          }
        }
      }

      # Injection of additional key-value secrets
      dynamic "env" {
        for_each = each.value.secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.agent_kv_secrets["${each.key}-${env.key}"].secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  labels = merge(var.labels, {
    agent = each.key
  })

  depends_on = [
    google_project_service.required_services
  ]
}

# IAM Invocation Permissions: Unauthenticated Public Invocation (if allow_unauthenticated = true)
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  for_each = {
    for k, v in var.agents : k => v
    if v.allow_unauthenticated
  }

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.agent_service[each.key].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# IAM Invocation Permissions: Authenticated Inter-Agent Invocation (based on `target_agent_invocations`)
resource "google_cloud_run_v2_service_iam_member" "inter_agent_invoker" {
  for_each = local.agent_invocation_map

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.agent_service[each.value.target_agent].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.agent_sa[each.value.source_agent].email}"
}
