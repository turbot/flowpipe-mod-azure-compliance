locals {
  appservice_web_apps_register_with_active_directory_disabled_query = <<-EOQ
    select
      concat(app.id, ' [', app.subscription_id, '/', app.resource_group, ']') as title,
      app.id as id,
      app.name,
      app.resource_group,
      app.subscription_id,
      app._ctx ->> 'connection_name' as conn
    from
      azure_app_service_web_app as app,
      azure_subscription as sub
    where
      sub.subscription_id = app.subscription_id
      and identity = '{}';
  EOQ

  appservice_web_apps_register_with_active_directory_disabled_enabled_actions_enum = ["skip", "register_active_directory"]
  appservice_web_apps_register_with_active_directory_disabled_default_action_enum = ["notify", "skip", "register_active_directory"]
}

variable "appservice_web_apps_register_with_active_directory_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "appservice_web_apps_register_with_active_directory_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "appservice_web_apps_register_with_active_directory_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "appservice_web_apps_register_with_active_directory_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "register_active_directory"]
}

trigger "query" "detect_and_correct_appservice_web_apps_register_with_active_directory_disabled" {
  title         = "Detect & correct App Service web apps register with Active Directory disabled"
  description   = "Detects App Service web apps register with Active Directory disabled and then register with Active Directory."

  enabled  = var.appservice_web_apps_register_with_active_directory_disabled_trigger_enabled
  schedule = var.appservice_web_apps_register_with_active_directory_disabled_trigger_schedule
  database = var.database
  sql      = local.appservice_web_apps_register_with_active_directory_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_appservice_web_apps_register_with_active_directory_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_appservice_web_apps_register_with_active_directory_disabled" {
  title         = "Detect & correct App Service web apps register with Active Directory disabled"
  description   = "Detects App Service web apps register with Active Directory disabled and then register with Active Directory."

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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.appservice_web_apps_register_with_active_directory_disabled_default_action
    enum        = local.appservice_web_apps_register_with_active_directory_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_web_apps_register_with_active_directory_disabled_enabled_actions
    enum        = local.appservice_web_apps_register_with_active_directory_disabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.appservice_web_apps_register_with_active_directory_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_appservice_web_apps_register_with_active_directory_disabled
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

pipeline "correct_appservice_web_apps_register_with_active_directory_disabled" {
  title         = "Correct App Services not registered with Active Directory"
  description   = "Runs corrective action on a collection of App Services not registered with Active Directory."

  param "items" {
    type = list(object({
      id              = string
      title           = string
      name            = string
      resource_group  = string
      subscription_id = string
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.appservice_web_apps_register_with_active_directory_disabled_default_action
    enum        = local.appservice_web_apps_register_with_active_directory_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_web_apps_register_with_active_directory_disabled_enabled_actions
    enum        = local.appservice_web_apps_register_with_active_directory_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} App Services not registered with Active Directory."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_appservice_web_apps_register_with_active_directory_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
      resource_group     = each.value.resource_group
      subscription_id    = each.value.subscription_id
      conn               = connection.azure[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_appservice_web_apps_register_with_active_directory_disabled" {
  title         = "Correct one App Service not registered with Active Directory"
  description   = "Runs corrective action on a single App Service not registered with Active Directory."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the App Service."
  }

  param "resource_group" {
    type        = string
    description = local.description_resource_group
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "conn" {
    type        = string
    description = local.description_connection
    default     = "default"
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.appservice_web_apps_register_with_active_directory_disabled_default_action
    enum        = local.appservice_web_apps_register_with_active_directory_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_web_apps_register_with_active_directory_disabled_enabled_actions
    enum        = local.appservice_web_apps_register_with_active_directory_disabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected App Service web app ${param.title} unregistered with Active Directory."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = detect_correct.pipeline.optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_info
            text     = "Skipped App Service web app ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "register_active_directory" = {
          label        = "Register Active Directory"
          value        = "register_active_directory"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.assign_appservice_webapp_identity
          pipeline_args = {
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            app_name        = param.name
            conn            = param.conn
          }
          success_msg = "Registered Active Directory for App Service web app ${param.title}."
          error_msg   = "Error registering Active Directory for App Service web app ${param.title}."
        }
      }
    }
  }
}

