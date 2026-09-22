variable "project_id" {
  type        = string
  description = "The GCP Project ID where the A2A infrastructure will be deployed."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The GCP region where Cloud Run and Artifact Registry resources will be created."
}

variable "prefix" {
  type        = string
  default     = "a2a"
  description = "Naming prefix for all resources created by this module."
}

variable "agents" {
  type = map(object({
    image                    = string
    port                     = optional(number, 8080)
    cpu                      = optional(string, "1")
    memory                   = optional(string, "512Mi")
    min_instances            = optional(number, 0)
    max_instances            = optional(number, 10)
    concurrency              = optional(number, 80)
    allow_unauthenticated    = optional(bool, false)
    role_description         = optional(string, "Specialized A2A agent")
    config_script            = optional(string, null)
    env_vars                 = optional(map(string), {})
    secrets                  = optional(map(string), {})
    target_agent_invocations = optional(list(string), [])
  }))
  default     = {}
  description = <<EOF
Map of agent definitions for the A2A protocol.
The key is the unique agent identifier (e.g. "investigator", "validator", "compiler").
Each agent accepts:
  - image: Docker image URI in Artifact Registry / GCR / Docker Hub.
  - port: Port exposed by the container (default 8080).
  - cpu / memory: Resource limits assigned to Cloud Run (e.g. "1", "512Mi").
  - min_instances / max_instances: Autoscaling configuration bounds.
  - allow_unauthenticated: If true, allows public HTTP invocation. If false, requires IAM authentication (A2A standard).
  - role_description: Description or metadata of the agent's specialization.
  - config_script: Startup script, system prompt, or configuration file content (stored in Secret Manager).
  - env_vars: Environment variables injected into the container.
  - secrets: Map of secret key-value pairs injected via Secret Manager.
  - target_agent_invocations: List of other agent names in this map that this agent is explicitly granted IAM permissions to invoke via IAM (roles/run.invoker).
EOF
}

variable "enable_artifact_registry" {
  type        = bool
  default     = true
  description = "Whether to create an Artifact Registry repository for agent container images."
}

variable "artifact_registry_name" {
  type        = string
  default     = "a2a-agents"
  description = "Name of the Artifact Registry repository."
}

variable "enable_pubsub" {
  type        = bool
  default     = false
  description = "Enables asynchronous Pub/Sub messaging infrastructure for inter-agent task pipelines."
}

variable "pubsub_topics" {
  type = list(object({
    name        = string
    subscribers = optional(list(string), [])
  }))
  default     = []
  description = <<EOF
List of Pub/Sub topics and their subscribing agents for asynchronous event pipeline communication.
Example:
  pubsub_topics = [
    {
      name        = "research-completed"
      subscribers = ["validator"]
    }
  ]
EOF
}

variable "labels" {
  type = map(string)
  default = {
    managed_by = "terraform"
    protocol   = "agent-to-agent"
  }
  description = "Common labels applied to supported GCP resources."
}
