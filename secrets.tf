# Secret Manager for Per-Agent Configuration Scripts / System Prompts
resource "google_secret_manager_secret" "config_scripts" {
  for_each = {
    for k, v in var.agents : k => v
    if v.config_script != null
  }

  project   = var.project_id
  secret_id = "${var.prefix}-${each.key}-config-script"

  replication {
    auto {}
  }

  labels = merge(var.labels, {
    agent = each.key
    type  = "config-script"
  })

  depends_on = [google_project_service.required_services]
}

resource "google_secret_manager_secret_version" "config_scripts" {
  for_each = {
    for k, v in var.agents : k => v
    if v.config_script != null
  }

  secret      = google_secret_manager_secret.config_scripts[each.key].id
  secret_data = each.value.config_script
}

# IAM permissions for each Agent Service Account to read its configuration script
resource "google_secret_manager_secret_iam_member" "agent_config_access" {
  for_each = {
    for k, v in var.agents : k => v
    if v.config_script != null
  }

  project   = var.project_id
  secret_id = google_secret_manager_secret.config_scripts[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.agent_sa[each.key].email}"
}

# Secret Manager for Additional Key-Value Secrets Defined in `secrets` Map
locals {
  agent_secrets_list = flatten([
    for agent_name, agent in var.agents : [
      for secret_key, secret_val in agent.secrets : {
        agent_name = agent_name
        secret_key = secret_key
        secret_val = secret_val
        id         = "${agent_name}-${secret_key}"
      }
    ]
  ])
  agent_secrets_map = {
    for item in local.agent_secrets_list : item.id => item
  }
}

resource "google_secret_manager_secret" "agent_kv_secrets" {
  for_each = local.agent_secrets_map

  project   = var.project_id
  secret_id = "${var.prefix}-${each.value.agent_name}-${each.value.secret_key}"

  replication {
    auto {}
  }

  labels = merge(var.labels, {
    agent = each.value.agent_name
  })

  depends_on = [google_project_service.required_services]
}

resource "google_secret_manager_secret_version" "agent_kv_secrets" {
  for_each = local.agent_secrets_map

  secret      = google_secret_manager_secret.agent_kv_secrets[each.key].id
  secret_data = each.value.secret_val
}

resource "google_secret_manager_secret_iam_member" "agent_kv_secret_access" {
  for_each = local.agent_secrets_map

  project   = var.project_id
  secret_id = google_secret_manager_secret.agent_kv_secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.agent_sa[each.value.agent_name].email}"
}
