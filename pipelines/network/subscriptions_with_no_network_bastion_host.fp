locals {
  subscriptions_with_no_network_bastion_host_query = <<-EOQ
    with bastion_hosts as (
      select
        subscription_id,
        _ctx,
        region,
        resource_group,
        count(*) as no_bastion_host
      from
        azure_bastion_host
      group by
        subscription_id,
        _ctx,
        resource_group,
        region
    )
    select
      sub.subscription_id as title,
      sub._ctx ->> 'connection_name' as conn
    from
      azure_subscription as sub
      left join bastion_hosts as i on i.subscription_id = sub.subscription_id
    where
      i.subscription_id is null;
  EOQ
}

variable "subscriptions_with_no_network_bastion_host_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Network"
  }
}

variable "subscriptions_with_no_network_bastion_host_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/Network"
  }
}

trigger "query" "detect_and_correct_subscriptions_with_no_network_bastion_host" {
  title         = "Detect & correct subscriptions with no network bastion host"
  description   = "Detects subscriptions with no network bastion host."
  tags          = local.network_common_tags

  enabled  = var.subscriptions_with_no_network_bastion_host_trigger_enabled
  schedule = var.subscriptions_with_no_network_bastion_host_trigger_schedule
  database = var.database
  sql      = local.subscriptions_with_no_network_bastion_host_query

  capture "insert" {
    pipeline = pipeline.correct_subscriptions_with_no_network_bastion_host
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_subscriptions_with_no_network_bastion_host" {
  title         = "Detect & correct subscriptions with no network bastion host"
  description   = "Detects subscriptions with no network bastion host."
  tags          = local.network_common_tags

  param "database" {
    type        = connection.steampipe
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
    enum        = local.notification_level_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.subscriptions_with_no_network_bastion_host_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_subscriptions_with_no_network_bastion_host
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_subscriptions_with_no_network_bastion_host" {
  title         = "Correct subscriptions with no network bastion host"
  description   = "Send notifications for subscriptions with no network bastion host."
  tags         = merge(local.network_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title           = string
      conn            = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
    enum        = local.notification_level_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} subscription(s) with no network bastion host"
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected subscription ${each.value.title} with no network bastion host."
  }
}
