locals {
  appservice_webapp_register_with_active_directory_disabled_query = <<-EOQ
    select
      concat(app.id, ' [', app.resource_group, '/', app.subscription_id, ']') as title,
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
      and identity = '{}';
  EOQ
}

trigger "query" "detect_and_correct_appservice_webapp_register_with_active_directory_disabled" {
  title         = "Detect & correct App Services not registered with Active Directory"
  description   = "Detects App Services not registered with Active Directory and runs your chosen action."
  // documentation = file("./appservice/docs/detect_and_correct_appservice_webapp_register_with_active_directory_disabled_trigger.md")
  tags          = merge(local.appservice_common_tags, { class = "unused" })

  enabled  = var.appservice_webapp_register_with_active_directory_disabled_trigger_enabled
  schedule = var.appservice_webapp_register_with_active_directory_disabled_trigger_schedule
  database = var.database
  sql      = local.appservice_webapp_register_with_active_directory_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_appservice_webapp_register_with_active_directory_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_appservice_webapp_register_with_active_directory_disabled" {
  title         = "Detect & correct App Services not registered with Active Directory"
  description   = "Detects App Services not registered with Active Directory and runs your chosen action."
  // documentation = file("./appservice/docs/detect_and_correct_appservice_webapp_register_with_active_directory_disabled.md")
  tags          = merge(local.appservice_common_tags, { class = "unused", type = "featured" })

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
    default     = var.appservice_webapp_register_with_active_directory_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_webapp_register_with_active_directory_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.appservice_webapp_register_with_active_directory_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_appservice_webapp_register_with_active_directory_disabled
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

pipeline "correct_appservice_webapp_register_with_active_directory_disabled" {
  title         = "Correct App Services not registered with Active Directory"
  description   = "Runs corrective action on a collection of App Services not registered with Active Directory."
  // documentation = file("./appservice/docs/correct_appservice_webapp_register_with_active_directory_disabled.md")
  tags          = merge(local.appservice_common_tags, { class = "unused" })

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
    default     = var.appservice_webapp_register_with_active_directory_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_webapp_register_with_active_directory_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} App Services not registered with Active Directory."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_appservice_webapp_register_with_active_directory_disabled
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

pipeline "correct_one_appservice_webapp_register_with_active_directory_disabled" {
  title         = "Correct one App Service not registered with Active Directory"
  description   = "Runs corrective action on a single App Service not registered with Active Directory."
  // documentation = file("./appservice/docs/correct_one_appservice_webapp_register_with_active_directory_disabled.md")
  tags          = merge(local.appservice_common_tags, { class = "unused" })

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
    default     = var.appservice_webapp_register_with_active_directory_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_webapp_register_with_active_directory_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected App Service ${param.title} not registered with Active Directory."
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
            text     = "Skipped App Service ${param.title} not registered with Active Directory."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_active_directory" = {
          label        = "Enable Active Directory"
          value        = "enable_active_directory"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_assign_appservice_webapp_identity
          pipeline_args = {
            resource_group  = param.resource_group
            subscription_id = param.subscription_id
            app_name        = param.name
            cred            = param.cred
          }
          success_msg = "Enabled Active Directory for App Service ${param.title}."
          error_msg   = "Error enabling Active Directory for App Service ${param.title}."
        }
      }
    }
  }
}

variable "appservice_webapp_register_with_active_directory_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "appservice_webapp_register_with_active_directory_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "appservice_webapp_register_with_active_directory_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "appservice_webapp_register_with_active_directory_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_active_directory"]
}
