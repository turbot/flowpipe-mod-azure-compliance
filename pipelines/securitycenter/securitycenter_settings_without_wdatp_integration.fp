locals {
  securitycenter_settings_without_wdatp_integration_query = <<-EOQ
    select
			concat(sc_sett.id, ' [', sc_sett.subscription_id, ']') as title,
      sc_sett.subscription_id,
			sc_sett._ctx ->> 'connection_name' as conn,
      enabled
    from
      azure_security_center_setting sc_sett
      right join azure_subscription sub on sc_sett.subscription_id = sub.subscription_id
    where
      name = 'WDATP'
			and (not enabled or enabled is null);
  EOQ
}

variable "securitycenter_settings_without_wdatp_integration_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/SecurityCenter"
  }
}

variable "securitycenter_settings_without_wdatp_integration_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/SecurityCenter"
  }
}

trigger "query" "detect_and_correct_securitycenter_settings_without_wdatp_integration" {
  title         = "Detect & correct Security Center settings without WDATP integration"
  description   = "Detect Security Center settings without WDATP integration."
  tags          = local.securitycenter_common_tags

  enabled  = var.securitycenter_settings_without_wdatp_integration_trigger_enabled
  schedule = var.securitycenter_settings_without_wdatp_integration_trigger_schedule
  database = var.database
  sql      = local.securitycenter_settings_without_wdatp_integration_query

  capture "insert" {
    pipeline = pipeline.correct_securitycenter_settings_without_wdatp_integration
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_securitycenter_settings_without_wdatp_integration" {
  title         = "Detect & correct Security Center settings without WDATP integration"
  description   = "Detect Security Center settings without WDATP integration."
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
    sql      = local.securitycenter_settings_without_wdatp_integration_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_securitycenter_settings_without_wdatp_integration
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_securitycenter_settings_without_wdatp_integration" {
  title         = "Correct Security Center settings without WDATP integration"
  description   = "Send notifications for Security Center settings without WDATP integration."
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
    text     = "Detected ${length(param.items)} Security Center settings without WDATP integration."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Security Center setting ${each.value.title} without WDATP integration."
  }
}
