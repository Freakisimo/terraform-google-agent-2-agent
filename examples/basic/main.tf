provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type        = string
  description = "Your Google Cloud Project ID."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "GCP region."
}

# Import Agent-to-Agent (A2A) Protocol Infrastructure Module
module "a2a_infrastructure" {
  source = "../../"

  project_id = var.project_id
  region     = var.region
  prefix     = "demo-a2a"

  agents = {
    "orchestrator" = {
      image                 = "us-central1-docker.pkg.dev/${var.project_id}/demo-a2a-a2a-agents/orchestrator-agent:latest"
      role_description      = "Main Orchestrator Agent that routes incoming requests"
      allow_unauthenticated = true # Publicly accessible endpoint
      target_agent_invocations = [
        "worker" # Orchestrator is granted IAM permission to invoke the worker agent
      ]
      env_vars = {
        "LOG_LEVEL" = "DEBUG"
      }
    }

    "worker" = {
      image                 = "us-central1-docker.pkg.dev/${var.project_id}/demo-a2a-a2a-agents/worker-agent:latest"
      role_description      = "Specialized worker agent for heavy computational tasks"
      allow_unauthenticated = false # Private: accessible only via authenticated A2A IAM
      cpu                   = "2"
      memory                = "1Gi"
      env_vars = {
        "TASK_TIMEOUT" = "300"
      }
    }
  }

  enable_artifact_registry = true
  enable_pubsub            = false
}

output "orchestrator_url" {
  description = "Invocation URL for the orchestrator agent."
  value       = module.a2a_infrastructure.agent_urls["orchestrator"]
}

output "orchestrator_agent_card" {
  description = "Agent Card URL for agent capability discovery."
  value       = module.a2a_infrastructure.agent_card_urls["orchestrator"]
}

output "artifact_registry_uri" {
  description = "URI of the generated Docker repository."
  value       = module.a2a_infrastructure.artifact_registry_url
}
