# Pub/Sub Messaging Infrastructure for Asynchronous Inter-Agent Pipelines
locals {
  pubsub_topics_map = var.enable_pubsub ? {
    for topic in var.pubsub_topics : topic.name => topic
  } : {}

  pubsub_subscribers_list = var.enable_pubsub ? flatten([
    for topic in var.pubsub_topics : [
      for sub in topic.subscribers : {
        topic_name = topic.name
        agent_name = sub
        id         = "${topic.name}-${sub}"
      }
      if contains(keys(var.agents), sub)
    ]
  ]) : []

  pubsub_subscribers_map = {
    for item in local.pubsub_subscribers_list : item.id => item
  }
}

# Pub/Sub Topics
resource "google_pubsub_topic" "topics" {
  for_each = local.pubsub_topics_map

  project = var.project_id
  name    = "${var.prefix}-${each.key}"

  labels = merge(var.labels, {
    pipeline = "a2a-workflow"
  })

  depends_on = [google_project_service.required_services]
}

# Pub/Sub Subscriptions per Subscriber Agent
resource "google_pubsub_subscription" "subscriptions" {
  for_each = local.pubsub_subscribers_map

  project = var.project_id
  name    = "${var.prefix}-${each.value.topic_name}-sub-${each.value.agent_name}"
  topic   = google_pubsub_topic.topics[each.value.topic_name].id

  ack_deadline_seconds = 60

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.agent_service[each.value.agent_name].uri}/a2a/events"

    oidc_token {
      service_account_email = google_service_account.agent_sa[each.value.agent_name].email
    }
  }

  labels = merge(var.labels, {
    subscriber = each.value.agent_name
  })
}

# IAM Permission for Subscriber Agents to receive Push events from Pub/Sub
resource "google_pubsub_subscription_iam_member" "subscriber_access" {
  for_each = local.pubsub_subscribers_map

  project      = var.project_id
  subscription = google_pubsub_subscription.subscriptions[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.agent_sa[each.value.agent_name].email}"
}

# IAM Permission for Agent Service Accounts to publish events if Pub/Sub is enabled
resource "google_pubsub_topic_iam_member" "publisher_access" {
  for_each = var.enable_pubsub ? var.agents : {}

  project = var.project_id
  topic   = google_pubsub_topic.topics[keys(local.pubsub_topics_map)[0]].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.agent_sa[each.key].email}"
}
