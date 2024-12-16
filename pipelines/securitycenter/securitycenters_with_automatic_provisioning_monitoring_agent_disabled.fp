locals {
  securitycenters_with_automatic_provisioning_monitoring_agent_disabled_query = <<-EOQ
    select
      concat(name, ' [', '/', subscription_id, ']') as title,
      _ctx ->> 'connection_name' as conn
    from
      azure_security_center_auto_provisioning
    where
      auto_provision <> 'On'
  EOQ
}

variable "securitycenters_with_automatic_provisioning_monitoring_agent_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/SecurityCenter"
  }
}

variable "securitycenters_with_automatic_provisioning_monitoring_agent_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/SecurityCenter"
  }
}

trigger "query" "detect_and_correct_securitycenters_with_automatic_provisioning_monitoring_agent_disabled" {
  title         = "Detect & correct Security Center auto provisioning settings with automatic provisioning monitoring agent disabled"
  description   = "Detect Security Center auto provisioning settings with automatic provisioning monitoring agent disabled."
  tags          = local.securitycenter_common_tags

  enabled  = var.securitycenters_with_automatic_provisioning_monitoring_agent_disabled_trigger_enabled
  schedule = var.securitycenters_with_automatic_provisioning_monitoring_agent_disabled_trigger_schedule
  database = var.database
  sql      = local.securitycenters_with_automatic_provisioning_monitoring_agent_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_securitycenters_with_automatic_provisioning_monitoring_agent_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_securitycenters_with_automatic_provisioning_monitoring_agent_disabled" {
  title         = "Detect & correct Security Center auto provisioning settings with automatic provisioning monitoring agent disabled"
  description   = "Detect Security Center auto provisioning settings with automatic provisioning monitoring agent disabled."
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
    sql      = local.securitycenters_with_automatic_provisioning_monitoring_agent_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_securitycenters_with_automatic_provisioning_monitoring_agent_disabled
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_securitycenters_with_automatic_provisioning_monitoring_agent_disabled" {
  title         = "Correct Security Center auto provisioning settings with automatic provisioning monitoring agent disabled"
  description   = "Send notifications for Security Center auto provisioning settings with automatic provisioning monitoring agent disabled."
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
    text     = "Detected ${length(param.items)} Security Center auto provisioning setting(s) with automatic provisioning monitoring agent disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Security Center auto provisioning setting ${each.value.title} with automatic provisioning monitoring agent disabled."
  }
}
