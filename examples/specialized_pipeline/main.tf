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

# Import A2A Module with Specialized Pipeline (Investigator -> Validator -> Compiler/KPIs)
module "a2a_specialized_pipeline" {
  source = "../../"

  project_id = var.project_id
  region     = var.region
  prefix     = "pipeline-a2a"

  agents = {
    # 1. Investigator Agent: Gathers data from sources and invokes the Validator
    "investigator" = {
      image                 = "gcr.io/${var.project_id}/a2a-investigator-agent:latest"
      role_description      = "Investigator Agent: Searches, queries APIs, and extracts relevant information"
      allow_unauthenticated = true # Entrypoint for user requests
      target_agent_invocations = [
        "validator" # Can synchronously invoke the Validator agent
      ]
      config_script = <<EOF
{
  "system_instruction": "You are an Investigator Agent specialized in retrieving financial and technical metrics.",
  "search_depth": "deep",
  "data_sources": ["internal_db", "sec_filings", "web_search"]
}
EOF
      env_vars = {
        "STAGE" = "INVESTIGATION"
      }
    }

    # 2. Validator Agent: Verifies factual accuracy and regulatory compliance
    "validator" = {
      image                 = "gcr.io/${var.project_id}/a2a-validator-agent:latest"
      role_description      = "Validator Agent: Verifies consistency, business rules, and regulatory compliance"
      allow_unauthenticated = false # Private A2A agent
      target_agent_invocations = [
        "compiler" # Can synchronously invoke the Compiler agent
      ]
      config_script = <<EOF
{
  "system_instruction": "You are a Compliance Validator Agent. Verify that reported figures align with auditable standards.",
  "strict_mode": true
}
EOF
      env_vars = {
        "STAGE" = "VALIDATION"
      }
    }

    # 3. Compiler Agent: Synthesizes data into Executive Summaries, KPIs, and Decision Decks
    "compiler" = {
      image                 = "gcr.io/${var.project_id}/a2a-compiler-agent:latest"
      role_description      = "Compiler Agent: Synthesizes validated data into executive summaries, KPIs, and decision boards"
      allow_unauthenticated = false # Private A2A agent
      config_script         = <<EOF
{
  "system_instruction": "You are an Executive Compiler Agent. Transform validated information into a synthesis with key KPIs and recommendations.",
  "output_formats": ["json_kpis", "markdown_summary", "deck_outline"]
}
EOF
      env_vars = {
        "STAGE" = "COMPILATION"
      }
    }
  }

  enable_artifact_registry = true
  enable_pubsub            = true

  # Asynchronous Pub/Sub Event Pipeline between stages
  pubsub_topics = [
    {
      name        = "research-completed"
      subscribers = ["validator"]
    },
    {
      name        = "validation-completed"
      subscribers = ["compiler"]
    }
  ]
}

output "pipeline_entrypoint_url" {
  description = "Invocation URL for the pipeline entrypoint (Investigator Agent)"
  value       = module.a2a_specialized_pipeline.agent_urls["investigator"]
}

output "agent_cards" {
  description = "Agent Card endpoints for A2A capability discovery"
  value       = module.a2a_specialized_pipeline.agent_card_urls
}

output "pubsub_pipeline_topics" {
  description = "Created Pub/Sub topics for asynchronous task pipeline"
  value       = module.a2a_specialized_pipeline.pubsub_topic_ids
}
