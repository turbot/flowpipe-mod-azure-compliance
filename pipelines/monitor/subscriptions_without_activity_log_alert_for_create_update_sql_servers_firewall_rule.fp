locals {
  subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule_query = <<-EOQ
    with alert_rule as (
      select
        alert.id as alert_id,
        alert.name as alert_name,
        alert.enabled,
        alert.location,
        alert.subscription_id,
        alert.resource_group,
        alert._ctx ->> 'connection_name' as conn,
        jsonb_array_length(alert.condition -> 'allOf')
      from
        azure_log_alert as alert,
        jsonb_array_elements_text(scopes) as sc
      where
        alert.location = 'Global'
        and alert.enabled
        and sc = '/subscriptions/' || alert.subscription_id
        and (
        (
          alert.condition -> 'allOf' @> '[{"equals":"Administrative","field":"category"}]'
          and alert.condition -> 'allOf' @> '[{"field": "operationName", "equals": "Microsoft.Sql/servers/firewallRules/write"}]'
        )
        or (
          alert.condition -> 'allOf' @> '[{"equals":"Administrative","field":"category"}]'
          and alert.condition -> 'allOf' @> '[{"field": "resourceType", "equals": "microsoft.sql/servers/firewallrules"}]'
          and jsonb_array_length(alert.condition -> 'allOf') = 2
        )
      )
      limit
        1
    )
    select
      sub.subscription_id as title,
      sub._ctx ->> 'connection_name' as conn
    from
      azure_subscription sub
      left join alert_rule a on sub.subscription_id = a.subscription_id
    group by
      sub.subscription_id,
      sub.display_name,
      sub._ctx,
      a.alert_id,
      a.alert_name,
      a.resource_group,
      a.subscription_id,
      a.conn
    having
      not(count(a.subscription_id) > 0);
  EOQ

}

variable "subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/Monitor"
  }
}

variable "subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/Monitor"
  }
}

trigger "query" "detect_and_correct_subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule" {
  title         = "Detect & correct Subscriptions without activity log alert for create and update SQL servers firewall rule"
  description   = "Detect subscriptions without an activity log alert for create and update SQL servers firewall rule."
  tags          = local.monitor_common_tags

  enabled  = var.subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule_trigger_enabled
  schedule = var.subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule_trigger_schedule
  database = var.database
  sql      = local.subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule_query

  capture "insert" {
    pipeline = pipeline.correct_subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule" {
  title         = "Detect & correct Subscriptions without activity log alert for create and update SQL servers firewall rule"
  description   = "Detect subscriptions without an activity log alert for create and update SQL servers firewall rule."
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
    sql      = local.subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_subscriptions_without_activity_log_alert_for_create_update_sql_servers_firewall_rule" {
  title         = "Correct Subscriptions without activity log alert for create and update SQL servers firewall rule"
  description   = "Send notifications for subscriptions without activity log alert for create and update SQL servers firewall rule."
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
    text     = "Detected ${length(param.items)} subscription(s) without activity log alert for create and update SQL servers firewall rule."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected subscription ${each.value.title} without activity log alert for create and update SQL servers firewall rule."
  }
}