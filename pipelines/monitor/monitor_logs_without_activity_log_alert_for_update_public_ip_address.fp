locals {
  monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_query = <<-EOQ
    with alert_rule as (
      select
        alert.id as alert_id,
        alert.name as alert_name,
        alert.enabled,
        alert.location,
        alert.subscription_id,
        alert.resource_group,
        alert._ctx ->> 'connection_name' as cred,
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
					and alert.condition -> 'allOf' @> '[{"field": "operationName", "equals": "Microsoft.Network/publicIPAddresses/write"}]'
				)
				or (
					alert.condition -> 'allOf' @> '[{"equals":"Administrative","field":"category"}]'
					and alert.condition -> 'allOf' @> '[{"field": "resourceType", "equals": "microsoft.network/publicipaddresses"}]'
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
        left join azure_resource_group AS r ON r.subscription_id = s.subscription_id
      order by
        s.subscription_id, r.name
    )
    select
      sub.subscription_id as title,
      sub.subscription_id,
      sub._ctx ->> 'connection_name' as cred,
      concat('/subscriptions/', sub.subscription_id) as scope,
      r.name as resource_group
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
      a.cred,
      r.name
    having
      not(count(a.subscription_id) > 0);
  EOQ
}

trigger "query" "detect_and_correct_monitor_logs_without_activity_log_alert_for_create_update_public_ip_address" {
  title         = "Detect & correct Monitor Logs without activity log alert for create update public IP address"
  description   = "Detects Monitor Logs without an activity log alert for create update public IP address and runs your chosen action."
  tags          = merge(local.monitor_common_tags, { class = "security" })

  enabled  = var.monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_trigger_enabled
  schedule = var.monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_trigger_schedule
  database = var.database
  sql      = local.monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_query

  capture "insert" {
    pipeline = pipeline.correct_monitor_logs_without_activity_log_alert_for_create_update_public_ip_address
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_monitor_logs_without_activity_log_alert_for_create_update_public_ip_address" {
  title         = "Detect & correct Monitor Logs without activity log alert for create update public IP address"
  description   = "Detects Monitor Logs without an activity log alert for create update public IP address and runs your chosen action."
  tags          = merge(local.monitor_common_tags, { class = "security", type = "featured" })

  param "database" {
    type        = string
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_monitor_logs_without_activity_log_alert_for_create_update_public_ip_address
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_monitor_logs_without_activity_log_alert_for_create_update_public_ip_address" {
  title         = "Correct Monitor Logs without activity log alert for create update public IP address"
  description   = "Runs corrective action on a collection of Monitor Logs without activity log alert for create update public IP address."
  tags          = merge(local.monitor_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
      resource_group  = string
      scope           = string
      subscription_id = string
      cred            = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Monitor Logs without activity log alert for create update public IP address."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_monitor_logs_without_activity_log_alert_for_create_update_public_ip_address
    args = {
      title              = each.value.title
      subscription_id    = each.value.subscription_id
      resource_group     = each.value.resource_group
      scope              = each.value.scope
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_monitor_logs_without_activity_log_alert_for_create_update_public_ip_address" {
  title         = "Correct one Monitor Log without activity log alert for create update public IP address"
  description   = "Runs corrective action on a single Monitor Log without activity log alert for create update public IP address."
  tags          = merge(local.monitor_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

  param "scope" {
    type        = string
    description = local.description_resource_group
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Monitor Log ${param.title} without activity log alert for create update public IP address."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped subscription ${param.title} without activity log alert for create update public IP address."
          }
          success_msg = ""
          error_msg   = ""
        },
        "create_update_public_ip_address_activity_log_alert" = {
          label        = "Create Update Public IP Address Activity Log Alert"
          value        = "create_update_public_ip_address_activity_log_alert"
          style        = local.style_alert
          pipeline_ref = pipeline.create_activity_log_alert_for_create_update_public_ip_address
          pipeline_args = {
            resource_group    = param.resource_group
            subscription_id   = param.subscription_id
            alert_name        = "alertCreateUpdatePublicIPAddress"
            level             = "verbose"
            scope             = param.scope
            action_group_name = "actionGroupCreateUpdatePublicIPAddres"
            cred              = param.cred
          }
          success_msg = "Created create and update Public IP Address activity log alert for subscription ${param.title}."
          error_msg   = "Error creating create and update Public IP Address activity log alert for subscription ${param.title}."
        }
      }
    }
  }
}

variable "monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "monitor_logs_without_activity_log_alert_for_create_update_public_ip_address_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "create_update_public_ip_address_activity_log_alert"]
}


pipeline "create_activity_log_alert_for_create_update_public_ip_address" {
  title       = "Create Activity log alert for create update public IP address"
  description = "Create an Azure Monitor activity log alert for create update public IP address."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

  param "alert_name" {
    type        = string
    description = "The name of the activity log alert."
    default     = "alertCreateUpdatePublicIPAddress"
  }

  param "level" {
    type        = string
    description = "The alert level (verbose, information, warning, error, critical)."
    default     = "verbose"
  }

  param "action_group_name" {
    type        = string
    description = "The name of the action group."
    default     = "actionGroupCreateUpdatePublicIPAddres"
  }

  param "scope" {
    type        = string
    description = "The scope of the alert (e.g., /subscriptions/<subscription ID>)."
  }

  step "container" "create_action_group" {
    image = "ghcr.io/turbot/flowpipe-image-azure-cli"
    cmd   = [
      "monitor", "action-group", "create",
      "--action-group-name", param.action_group_name,
      "--resource-group", param.resource_group,
      "--subscription", param.subscription_id,
      "--output", "json"
    ]

    env = credential.azure[param.cred].env
  }

  step "container" "create_activity_log_alert" {
    depends_on = [step.container.create_action_group]
    image = "ghcr.io/turbot/flowpipe-image-azure-cli"
    cmd   = [
      "monitor", "activity-log", "alert", "create",
      "--resource-group", param.resource_group,
      "--condition", "category=Administrative and operationName=Microsoft.Network/publicIPAddresses/write and level=verbose",
      "--scope", param.scope,
      "--name", param.alert_name,
      "--subscription", param.subscription_id,
      "--action-group", jsondecode(step.container.create_action_group.stdout).id
    ]

    env = credential.azure[param.cred].env
  }

  output "action_group_id" {
    description = "The ID of the created action group."
    value       = jsondecode(step.container.create_action_group.stdout).id
  }

}