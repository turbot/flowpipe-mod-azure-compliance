locals {
  subscriptions_without_application_insight_configured_query = <<-EOQ
    with application_insights as (
      select
        subscription_id,
        count(*) as no_application_insight
      from
        azure_application_insight
      group by
        subscription_id
    )
    select
      sub.subscription_id as title,
      sub._ctx ->> 'connection_name' as conn
    from
      azure_subscription sub
      left join application_insights as i on i.subscription_id = sub.subscription_id
    where
      i.subscription_id is null;
  EOQ
}

variable "subscriptions_without_application_insight_configured_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Monitor"
  }
}

variable "subscriptions_without_application_insight_configured_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/Monitor"
  }
}

trigger "query" "detect_and_correct_subscriptions_without_application_insight_configured" {
  title         = "Detect & correct Subscriptions without application insight configured"
  description   = "Detect Subscriptions without application insight configured."
  tags          = local.monitor_common_tags

  enabled  = var.subscriptions_without_application_insight_configured_trigger_enabled
  schedule = var.subscriptions_without_application_insight_configured_trigger_schedule
  database = var.database
  sql      = local.subscriptions_without_application_insight_configured_query

  capture "insert" {
    pipeline = pipeline.correct_subscriptions_without_application_insight_configured
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_subscriptions_without_application_insight_configured" {
  title         = "Detect & correct Subscriptions without application insight configured"
  description   = "Detect Subscriptions without application insight configured."
  tags          = local.monitor_common_tags

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
    sql      = local.subscriptions_without_application_insight_configured_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_subscriptions_without_application_insight_configured
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_subscriptions_without_application_insight_configured" {
  title         = "Correct Subscriptions without application insight configured"
  description   = "Send notifications for Subscriptions without application insight configured."
  tags          = merge(local.monitor_common_tags, { folder = "Internal" })

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
    text     = "Detected ${length(param.items)} Subscription(s) without application insight configured."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Subscription ${each.value.title} without application insight configured."
  }
}