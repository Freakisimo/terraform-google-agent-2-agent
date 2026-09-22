# Google Agent-to-Agent (A2A) Protocol Infrastructure - Terraform Module

This Terraform module provisions end-to-end infrastructure on Google Cloud Platform (GCP) for deploying multi-agent AI systems built on Google's **Agent-to-Agent (A2A) Protocol**.

It allows you to deploy containerized autonomous agent architectures (Cloud Run v2), manage inter-agent synchronous security & invocation policies via IAM (OAuth2/OIDC), securely inject system prompts & runtime configs using Secret Manager, and enable event-driven asynchronous pipelines with Google Cloud Pub/Sub.

---

## 🏗️ Architecture & A2A Communication Flow

```
                                    +-------------------------------------------------+
                                    |         Google Cloud Project (GCP)              |
                                    |                                                 |
                                    |  +-------------------------------------------+  |
  [ Client / User / API Gateway ]    |  Artifact Registry Repository             |  |
                 |                  |  (A2A Agent Docker Container Images)         |  |
                 | (HTTPS/OIDC)     +-------------------------------------------+  |
                 v                                                                    |
  +-------------------------------+         (Synchronous HTTPS/JSON-RPC IAM OIDC)      |
  |  Agent 1: Investigator        | ------------------------------------------+       |
  |  (Cloud Run v2)               |                                           |       |
  |  - Secret Manager Config      |                                           v       |
  |  - Agent Card URI Exposed     |                           +-------------------------------+
  +-------------------------------+                           |  Agent 2: Validator           |
                 |                                            |  (Cloud Run v2)               |
                 | (Async Pub/Sub Event:                      |  - Secret Manager Config      |
                 |  "research-completed")                     |  - Agent Card URI Exposed     |
                 v                                            +-------------------------------+
  +-------------------------------+                                           |
  |  Pub/Sub Topic & Subscription |                                           | (IAM OIDC)
  +-------------------------------+                                           v
                 |                                            +-------------------------------+
                 +------------------------------------------> |  Agent 3: Compiler            |
                                                              |  (Cloud Run v2)               |
                                                              |  - Generates Summary / KPIs   |
                                                              +-------------------------------+
```

---

## ✨ Features

- 🤖 **Dynamic Agent Provisioning:** Deploys any number of specialized agents declared in a clean, declarative Terraform map.
- 🔒 **Least-Privilege Security (IAM):** Generates dedicated Service Accounts per agent and enforces `roles/run.invoker` permissions strictly between authorized agents (`target_agent_invocations`).
- 📜 **Prompt & Script Injection:** Automatically stores setup scripts or system prompts in **Secret Manager** and mounts them securely into container environments.
- 📦 **Integrated Artifact Registry:** Creates a private Docker repository optimized for hosting agent images.
- ⚡ **Asynchronous Event Pipelines (Pub/Sub):** Connects agents using Pub/Sub topics and Push subscriptions routed to agent endpoints.
- 🌐 **Standard A2A Agent Card:** Automatically defines and exposes the discovery URI `A2A_WELL_KNOWN_URI` (`/.well-known/agent.json`) and target URLs (`A2A_TARGET_<NAME>_URL`).

---

## 🚀 Usage Examples

### 1. Basic Usage (Orchestrator + Worker)

```hcl
module "a2a" {
  source  = "Freakisimo/agent-2-agent/google"
  version = "~> 1.0.0"

  project_id = "my-gcp-project-id"
  region     = "us-central1"
  prefix     = "my-system"

  agents = {
    "orchestrator" = {
      image                 = "us-central1-docker.pkg.dev/my-gcp-project-id/my-system-a2a-agents/orchestrator:latest"
      role_description      = "Main Orchestrator Agent that routes requests"
      allow_unauthenticated = true
      target_agent_invocations = ["worker"]
    }

    "worker" = {
      image                 = "us-central1-docker.pkg.dev/my-gcp-project-id/my-system-a2a-agents/worker:latest"
      role_description      = "Specialized worker agent"
      allow_unauthenticated = false
      cpu                   = "2"
      memory                = "1Gi"
    }
  }
}
```

### 2. Specialized Multi-Agent Pipeline (Investigator ➔ Validator ➔ Compiler/KPIs)

Check out the full runnable example in [`examples/specialized_pipeline/main.tf`](file:///home/arkade/Documents/github/agent-2-agent/examples/specialized_pipeline/main.tf).

---

## 📋 Inputs

| Name | Description | Type | Default | Required |
| :--- | :--- | :--- | :--- | :---: |
| `project_id` | GCP Project ID | `string` | N/A | **Yes** |
| `region` | GCP region for resource deployment | `string` | `"us-central1"` | No |
| `prefix` | Resource naming prefix | `string` | `"a2a"` | No |
| `agents` | Map of A2A agent definitions | `map(object)` | `{}` | No |
| `enable_artifact_registry` | Create Artifact Registry repository | `bool` | `true` | No |
| `artifact_registry_name` | Name of the Artifact Registry repository | `string` | `"a2a-agents"` | No |
| `enable_pubsub` | Enable asynchronous Pub/Sub event bus | `bool` | `false` | No |
| `pubsub_topics` | List of Pub/Sub topics and subscribers | `list(object)` | `[]` | No |
| `labels` | Labels applied to GCP resources | `map(string)` | `{ managed_by = "terraform" }` | No |

---

## 📤 Outputs

| Name | Description |
| :--- | :--- |
| `agent_urls` | Map of agent names to their Cloud Run invocation URIs. |
| `agent_card_urls` | URLs of Agent Card specifications (`/.well-known/agent.json`) per agent. |
| `agent_service_accounts` | Dedicated Service Account emails generated per agent. |
| `artifact_registry_url` | URI of the Artifact Registry Docker repository. |
| `pubsub_topic_ids` | IDs of created Pub/Sub topics. |

---

## 📄 License

Apache License 2.0. See [LICENSE](LICENSE) for full details.
