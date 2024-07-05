locals {
  monitor_log_without_activity_log_alert_for_delete_security_solution_query = <<-EOQ
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
						alert.condition -> 'allOf' @> '[{"equals":"Security","field":"category"}]'
						and alert.condition -> 'allOf' @> '[{"field": "operationName", "equals": "Microsoft.Security/securitySolutions/delete"}]'
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

trigger "query" "detect_and_correct_monitor_log_without_activity_log_alert_for_delete_security_solution" {
  title         = "Detect & correct Monitor Logs without activity log alert for delete security solution"
  description   = "Detects Monitor Logs without an activity log alert for delete security solution and runs your chosen action."
  // documentation = file("./monitor/docs/detect_and_correct_monitor_log_without_activity_log_alert_for_delete_security_solution_trigger.md")
  tags          = merge(local.monitor_common_tags, { class = "security" })

  enabled  = var.monitor_log_without_activity_log_alert_for_delete_security_solution_trigger_enabled
  schedule = var.monitor_log_without_activity_log_alert_for_delete_security_solution_trigger_schedule
  database = var.database
  sql      = local.monitor_log_without_activity_log_alert_for_delete_security_solution_query

  capture "insert" {
    pipeline = pipeline.correct_monitor_log_without_activity_log_alert_for_delete_security_solution
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_monitor_log_without_activity_log_alert_for_delete_security_solution" {
  title         = "Detect & correct Monitor Logs without activity log alert for delete security solution"
  description   = "Detects Monitor Logs without an activity log alert for delete security solution and runs your chosen action."
  // documentation = file("./monitor/docs/detect_and_correct_monitor_log_without_activity_log_alert_for_delete_security_solution.md")
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
    default     = var.monitor_log_without_activity_log_alert_for_delete_security_solution_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_log_without_activity_log_alert_for_delete_security_solution_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.monitor_log_without_activity_log_alert_for_delete_security_solution_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_monitor_log_without_activity_log_alert_for_delete_security_solution
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

pipeline "correct_monitor_log_without_activity_log_alert_for_delete_security_solution" {
  title         = "Correct Monitor Logs without activity log alert for delete security solution"
  description   = "Runs corrective action on a collection of Monitor Logs without activity log alert for delete security solution."
  // documentation = file("./monitor/docs/correct_monitor_log_without_activity_log_alert_for_delete_security_solution.md")
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
    default     = var.monitor_log_without_activity_log_alert_for_delete_security_solution_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_log_without_activity_log_alert_for_delete_security_solution_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Monitor Logs without activity log alert for delete security solution."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_monitor_log_without_activity_log_alert_for_delete_security_solution
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

pipeline "correct_one_monitor_log_without_activity_log_alert_for_delete_security_solution" {
  title         = "Correct one Monitor Log without activity log alert for delete security solution"
  description   = "Runs corrective action on a single Monitor Log without activity log alert for delete security solution."
  // documentation = file("./monitor/docs/correct_one_monitor_log_without_activity_log_alert_for_delete_security_solution.md")
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
    default     = var.monitor_log_without_activity_log_alert_for_delete_security_solution_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.monitor_log_without_activity_log_alert_for_delete_security_solution_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Monitor Log ${param.title} without activity log alert for delete security solution."
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
            text     = "Skipped subscription ${param.title} without activity log alert for delete security solution."
          }
          success_msg = ""
          error_msg   = ""
        },
        "create_delete_security_solution_activity_log_alert" = {
          label        = "Create delete security solution Activity Log Alert"
          value        = "create_delete_security_solution_activity_log_alert"
          style        = local.style_alert
          pipeline_ref = pipeline.create_activity_log_alert_for_delete_security_solution
          pipeline_args = {
            resource_group    = param.resource_group
            subscription_id   = param.subscription_id
            alert_name        = "alertDeleteSecuritySolution"
            level             = "verbose"
            scope             = param.scope
            action_group_name = "actionGroupDeleteSecuritySolution"
            cred              = param.cred
          }
          success_msg = "Created delete security solution activity log alert for subscription ${param.title}."
          error_msg   = "Error creating delete security solution activity log alert for subscription ${param.title}."
        }
      }
    }
  }
}

variable "monitor_log_without_activity_log_alert_for_delete_security_solution_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "monitor_log_without_activity_log_alert_for_delete_security_solution_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "monitor_log_without_activity_log_alert_for_delete_security_solution_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "monitor_log_without_activity_log_alert_for_delete_security_solution_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "create_delete_security_solution_activity_log_alert"]
}


pipeline "create_activity_log_alert_for_delete_security_solution" {
  title       = "Create Activity Log Alert for delete security solution"
  description = "Create an Azure Monitor activity log alert for delete security solution."

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
    default     = "alertDeleteSecuritySolution"
  }

  param "level" {
    type        = string
    description = "The alert level (verbose, information, warning, error, critical)."
    default     = "verbose"
  }

  param "action_group_name" {
    type        = string
    description = "The name of the action group."
    default     = "actionGroupDeleteSecuritySolution"
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
      "--condition", "category=Administrative and operationName=Microsoft.Security/securitySolutions/delete and level=verbose",
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