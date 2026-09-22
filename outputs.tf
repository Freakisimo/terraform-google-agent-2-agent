output "agent_urls" {
  description = "Map of agent names to their Cloud Run invocation URIs."
  value = {
    for k, v in google_cloud_run_v2_service.agent_service : k => v.uri
  }
}

output "agent_card_urls" {
  description = "Map of Agent Card discovery URLs (/.well-known/agent.json) per agent following the A2A spec."
  value = {
    for k, v in google_cloud_run_v2_service.agent_service : k => "${v.uri}/.well-known/agent.json"
  }
}

output "agent_service_accounts" {
  description = "Map of dedicated Service Accounts generated per agent."
  value = {
    for k, v in google_service_account.agent_sa : k => v.email
  }
}

output "artifact_registry_url" {
  description = "URI of the Artifact Registry repository for pulling and pushing agent container images."
  value       = var.enable_artifact_registry ? "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.a2a_repo[0].repository_id}" : null
}

output "pubsub_topic_ids" {
  description = "IDs of created Pub/Sub topics for asynchronous messaging."
  value = var.enable_pubsub ? {
    for k, v in google_pubsub_topic.topics : k => v.id
  } : {}
}
