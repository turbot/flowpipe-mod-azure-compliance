locals {
  securitycenters_without_notify_alerts_configured_query = <<-EOQ
		with contact_info as (
      select
        count(*) filter (where alert_notifications = 'On') as notification_alert_count,
        subscription_id
      from
        azure_security_center_contact
      group by
        subscription_id
      limit 1
    )
    select
			sub.subscription_id as title,
			sub._ctx ->> 'connection_name' as conn
		from
    	azure_subscription sub
      left join contact_info ci on sub.subscription_id = ci.subscription_id
		where
			not notification_alert_count > 0 or notification_alert_count is null;
  EOQ
}

variable "securitycenters_without_notify_alerts_configured_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/SecurityCenter"
  }
}

variable "securitycenters_without_notify_alerts_configured_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/SecurityCenter"
  }
}

trigger "query" "detect_and_correct_securitycenters_without_notify_alerts_configured" {
  title         = "Detect & correct Security Centers without notify alerts configured"
  description   = "Detect Security Centers without notify alerts configured."
  tags          = local.securitycenter_common_tags

  enabled  = var.securitycenters_without_notify_alerts_configured_trigger_enabled
  schedule = var.securitycenters_without_notify_alerts_configured_trigger_schedule
  database = var.database
  sql      = local.securitycenters_without_notify_alerts_configured_query

  capture "insert" {
    pipeline = pipeline.correct_securitycenters_without_notify_alerts_configured
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_securitycenters_without_notify_alerts_configured" {
  title         = "Detect & correct Security Centers without notify alerts configured"
  description   = "Detect Security Centers without notify alerts configured."
  tags          = local.securitycenter_common_tags

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
    sql      = local.securitycenters_without_notify_alerts_configured_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_securitycenters_without_notify_alerts_configured
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_securitycenters_without_notify_alerts_configured" {
  title         = "Correct Security Centers without notify alerts configured"
  description   = "Send notifications for Security Centers without notify alerts configured."
  tags          = merge(local.securitycenter_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title               = string
      conn                = string
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
    text     = "Detected ${length(param.items)} Subscription(s) Security Center without notify alerts configured."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Subscription ${each.value.title} without Security Center without notify alerts configured."
  }
}
