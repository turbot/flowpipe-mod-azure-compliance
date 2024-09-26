locals {
  appservice_web_apps_not_using_https_query = <<-EOQ
    select
      concat(app.id, ' [', app.subscription_id, '/', app.resource_group, ']') as title,
      app.id as id,
      app.name,
      app.resource_group,
      app.subscription_id,
      app._ctx ->> 'connection_name' as cred
    from
      azure_app_service_web_app as app,
      azure_subscription as sub
    where
      sub.subscription_id = app.subscription_id
      and not https_only;
  EOQ
}

variable "appservice_web_apps_not_using_https_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "appservice_web_apps_not_using_https_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "appservice_web_apps_not_using_https_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "appservice_web_apps_not_using_https_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_https"]
}

trigger "query" "detect_and_correct_appservice_web_apps_not_using_https" {
  title         = "Detect & correct App Service web apps not using HTTPS"
  description   = "Detects App Services not using HTTPS and then enable HTTPS."

  enabled  = var.appservice_web_apps_not_using_https_trigger_enabled
  schedule = var.appservice_web_apps_not_using_https_trigger_schedule
  database = var.database
  sql      = local.appservice_web_apps_not_using_https_query

  capture "insert" {
    pipeline = pipeline.correct_appservice_web_apps_not_using_https
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_appservice_web_apps_not_using_https" {
  title         = "Detect & correct App Service web apps not using HTTPS"
  description   = "Detects App Service web apps not using HTTPS and then enable HTTPS."

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
    default     = var.appservice_web_apps_not_using_https_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_web_apps_not_using_https_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.appservice_web_apps_not_using_https_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_appservice_web_apps_not_using_https
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

pipeline "correct_appservice_web_apps_not_using_https" {
  title         = "Correct App Service web apps not using HTTPS"
  description   = "Enable HTTPS for App Service web apps not using HTTPS."

  param "items" {
    type = list(object({
      id              = string
      title           = string
      name            = string
      resource_group  = string
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
    default     = var.appservice_web_apps_not_using_https_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_web_apps_not_using_https_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} App Service web app(s) not using HTTPS."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_appservice_web_app_not_using_https
    args = {
      title              = each.value.title
      name               = each.value.name
      resource_group     = each.value.resource_group
      subscription_id    = each.value.subscription_id
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_appservice_web_app_not_using_https" {
  title         = "Correct App Service web app not using HTTPS"
  description   = "Enable HTTPS for a App Service web app not using HTTPS."

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
    default     = var.appservice_web_apps_not_using_https_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_web_apps_not_using_https_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected App Service web app ${param.title} not using HTTPS."
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
            text     = "Skipped App Service web app ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_https" = {
          label        = "Enable HTTPS"
          value        = "enable_https"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_update_appservice_webapp
          pipeline_args = {
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            app_name        = param.name
            cred            = param.cred
            https_only      = true
          }
          success_msg = "Enabled HTTPS for App Service web app ${param.title}."
          error_msg   = "Error enabling HTTPS for App Service web app ${param.title}."
        }
      }
    }
  }
}

