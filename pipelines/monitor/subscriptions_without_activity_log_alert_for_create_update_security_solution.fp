locals {
  subscriptions_without_activity_log_alert_for_create_update_security_solution_query = <<-EOQ
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
          alert.condition -> 'allOf' @> '[{"equals":"Security","field":"category"}]'
          and alert.condition -> 'allOf' @> '[{"field": "operationName", "equals": "Microsoft.Security/securitySolutions/write"}]'
        )
        or (
          alert.condition -> 'allOf' @> '[{"equals":"Security","field":"category"}]'
          and alert.condition -> 'allOf' @> '[{"field": "resourceType", "equals": "microsoft.security/securitysolutions"}]'
          and jsonb_array_length(alert.condition -> 'allOf') = 2
        )
      )
      limit
        1
    ), resource_group as (
      select
        distinct on (s.subscription_id)
        r.name,
        r.subscription_id
      from
        azure_subscription as s
        left join azure_resource_group as r on r.subscription_id = s.subscription_id
      order by
        s.subscription_id, r.name
    )
    select
      sub.subscription_id as title,
      sub._ctx ->> 'connection_name' as conn
    from
      azure_subscription sub
      left join alert_rule a on sub.subscription_id = a.subscription_id
      left join resource_group as r on r.subscription_id = sub.subscription_id
    group by
      sub.subscription_id,
      sub.display_name,
      sub._ctx,
      a.alert_id,
      a.alert_name,
      a.resource_group,
      a.subscription_id,
      a.conn,
      r.name
    having
      not(count(a.subscription_id) > 0);
  EOQ

}

variable "subscriptions_without_activity_log_alert_for_create_update_security_solution_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/Monitor"
  }
}

variable "subscriptions_without_activity_log_alert_for_create_update_security_solution_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/Monitor"
  }
}

trigger "query" "detect_and_correct_subscriptions_without_activity_log_alert_for_create_update_security_solution" {
  title         = "Detect & correct Subscriptions without activity log alert for create and update security solution"
  description   = "Detects Subscriptions without an activity log alert for create and update security solution."
  tags          = local.monitor_common_tags

  enabled  = var.subscriptions_without_activity_log_alert_for_create_update_security_solution_trigger_enabled
  schedule = var.subscriptions_without_activity_log_alert_for_create_update_security_solution_trigger_schedule
  database = var.database
  sql      = local.subscriptions_without_activity_log_alert_for_create_update_security_solution_query

  capture "insert" {
    pipeline = pipeline.correct_subscriptions_without_activity_log_alert_for_create_update_security_solution
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_subscriptions_without_activity_log_alert_for_create_update_security_solution" {
  title         = "Detect & correct Subscriptions without activity log alert for create and update security solution"
  description   = "Detects Subscriptions without an activity log alert for create and update security solution."
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
    sql      = local.subscriptions_without_activity_log_alert_for_create_update_security_solution_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_subscriptions_without_activity_log_alert_for_create_update_security_solution
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_subscriptions_without_activity_log_alert_for_create_update_security_solution" {
  title         = "Correct Subscriptions without activity log alert for create and update security solution"
  description   = "Send notifications for Subscriptions without activity log alert for create and update security solution."
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
    text     = "Detected ${length(param.items)} Subscription(s) without activity log alert for create and update security solution."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected Subscription ${each.value.title} without activity log alert for create and update security solution."
  }
}
