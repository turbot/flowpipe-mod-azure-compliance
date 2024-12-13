locals {
  subscriptions_diagnostic_setting_without_capturing_proper_categories_query = <<-EOQ
    with enabled_settings as (
      select
        name,
        id,
        _ctx,
        resource_group,
        subscription_id,
        count(*) filter (where l ->> 'enabled' = 'true'
          and l ->> 'category' in ('Administrative', 'Security', 'Alert', 'Policy')
        ) as valid_category_count,
        string_agg(l ->> 'category', ', ') filter (where l ->> 'enabled' = 'true'
          and l ->> 'category' in ('Administrative', 'Security', 'Alert', 'Policy')
        ) as valid_categories
      from
        azure_diagnostic_setting,
        jsonb_array_elements(logs) as l
      group by
        name,
        id,
        _ctx,
        resource_group,
        subscription_id
    ), enabled_settings_count as (
      select
        subscription_id,
        count(*) as enabled_setting_counts
      from
        enabled_settings
      where
        valid_category_count = 4
      group by
        subscription_id
    )
    select
      distinct sub.subscription_id as title,
      sub._ctx ->> 'connection_name' as conn
    from
      azure_subscription sub
      left join enabled_settings_count as i on i.subscription_id = sub.subscription_id
    where
      enabled_setting_counts = 0 or enabled_setting_counts is null;
  EOQ
}

variable "subscriptions_diagnostic_setting_without_capturing_proper_categories_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Monitor"
  }
}

variable "subscriptions_diagnostic_setting_without_capturing_proper_categories_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/Monitor"
  }
}

trigger "query" "detect_and_correct_subscriptions_diagnostic_setting_without_capturing_proper_categories" {
  title         = "Detect & correct Subscriptions diagnostic settings without capturing proper categories"
  description   = "Detect Subscriptions diagnostic settings without capturing proper categories"
  tags          = local.monitor_common_tags

  enabled  = var.subscriptions_diagnostic_setting_without_capturing_proper_categories_trigger_enabled
  schedule = var.subscriptions_diagnostic_setting_without_capturing_proper_categories_trigger_schedule
  database = var.database
  sql      = local.subscriptions_diagnostic_setting_without_capturing_proper_categories_query

  capture "insert" {
    pipeline = pipeline.correct_subscriptions_diagnostic_setting_without_capturing_proper_categories
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_subscriptions_diagnostic_setting_without_capturing_proper_categories" {
  title         = "Detect & correct Subscriptions diagnostic settings without capturing proper categories"
  description   = "Detect Subscriptions diagnostic settings without capturing proper categories."
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
    sql      = local.subscriptions_diagnostic_setting_without_capturing_proper_categories_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_subscriptions_diagnostic_setting_without_capturing_proper_categories
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_subscriptions_diagnostic_setting_without_capturing_proper_categories" {
  title         = "Correct Subscriptions diagnostic settings without capturing proper categories"
  description   = "Send notifications for Subscriptions diagnostic settings without capturing proper categories."
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
    text     = "Detected ${length(param.items)} Subscription(s) diagnostic settings without capturing proper categories."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Subscription ${each.value.title} diagnostic settings without capturing proper categories."
  }
}