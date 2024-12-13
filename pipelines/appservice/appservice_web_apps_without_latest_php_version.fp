locals {
  appservice_web_apps_without_latest_php_version_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', resource_group, ']') as title,
      id as id,
      name,
      resource_group,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_app_service_web_app
    where
      exists (
        select
        from
          unnest(regexp_split_to_array(kind, ',')) elem
        where
          elem like 'app%'
      )
      and exists (
        select
        from
          unnest(regexp_split_to_array(kind, ',')) elem
        where
          elem = 'linux'
      )
      and configuration -> 'properties' ->> 'linuxFxVersion' like 'PHP%'
      and configuration -> 'properties' ->> 'linuxFxVersion' <> 'PHP|8.3';
  EOQ

  appservice_web_apps_without_latest_php_version_enabled_actions_enum = ["skip", "enable_latest_php_version"]
  appservice_web_apps_without_latest_php_version_default_action_enum  = ["notify", "skip", "enable_latest_php_version"]
}

variable "appservice_web_apps_without_latest_php_version_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/AppService"
  }
}

variable "appservice_web_apps_without_latest_php_version_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/AppService"
  }
}

variable "appservice_web_apps_without_latest_php_version_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/AppService"
  }
}

variable "appservice_web_apps_without_latest_php_version_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_latest_php_version"]

  tags = {
    folder = "Advanced/AppService"
  }
}

variable "appservice_web_apps_without_latest_php_version_linux_fx_version" {
  type        = string
  description = "The linux fx version for App Service web app."
  default     = "PHP|8.3"

  tags = {
    folder = "Advanced/AppService"
  }
}

trigger "query" "detect_and_correct_appservice_web_apps_without_latest_php_version" {
  title         = "Detect & correct App Service web apps without the latest PHP version"
  description   = "Detect App Services web apps without the latest PHP version and then enable latest PHP version."
  tags          = local.appservice_common_tags

  enabled  = var.appservice_web_apps_without_latest_php_version_trigger_enabled
  schedule = var.appservice_web_apps_without_latest_php_version_trigger_schedule
  database = var.database
  sql      = local.appservice_web_apps_without_latest_php_version_query

  capture "insert" {
    pipeline = pipeline.correct_appservice_web_apps_without_latest_php_version
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_appservice_web_apps_without_latest_php_version" {
  title         = "Detect & correct App Service web apps without the latest PHP version"
  description   = "Detect App Services web apps without the latest PHP version and then enable latest PHP version."
  tags          = local.appservice_common_tags

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

  param "linux_fx_version" {
    type        = string
    description = "The linux fx version for App Service web app."
    default     = var.appservice_web_apps_without_latest_php_version_linux_fx_version
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.appservice_web_apps_without_latest_php_version_default_action
    enum        = local.appservice_web_apps_without_latest_php_version_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_web_apps_without_latest_php_version_enabled_actions
    enum        = local.appservice_web_apps_without_latest_php_version_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.appservice_web_apps_without_latest_php_version_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_appservice_web_apps_without_latest_php_version
    args = {
      items              = step.query.detect.rows
	    linux_fx_version   = param.linux_fx_version
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_appservice_web_apps_without_latest_php_version" {
  title         = "Correct App Services web apps without the latest PHP version"
  description   = "Enable latest PHP version for App Services web apps without the latest PHP version."
  tags          = merge(local.appservice_common_tags, { folder = "Internal" })

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

  param "linux_fx_version" {
    type        = string
    description = "The linux fx version for App Service web app."
    default     = var.appservice_web_apps_without_latest_php_version_linux_fx_version
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
    default     = var.appservice_web_apps_without_latest_php_version_default_action
    enum        = local.appservice_web_apps_without_latest_php_version_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_web_apps_without_latest_php_version_enabled_actions
    enum        = local.appservice_web_apps_without_latest_php_version_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} App Services web app(s) without the latest PHP version."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_appservice_web_app_without_latest_php_version
    args = {
      title              = each.value.title
      name               = each.value.name
      resource_group     = each.value.resource_group
      subscription_id    = each.value.subscription_id
      conn               = connection.azure[each.value.conn]
	    linux_fx_version   = param.linux_fx_version
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_appservice_web_app_without_latest_php_version" {
  title         = "Correct App Services web app without the latest PHP version"
  description   = "Enable latest PHP version for a App Services web app without the latest PHP version."
  tags          = merge(local.appservice_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the App Service web app."
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
    type        = connection.azure
    description = local.description_connection
  }

  param "linux_fx_version" {
    type        = string
    description = "The linux fx version for App Service web app."
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
    default     = var.appservice_web_apps_without_latest_php_version_default_action
    enum        = local.appservice_web_apps_without_latest_php_version_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.appservice_web_apps_without_latest_php_version_enabled_actions
    enum        = local.appservice_web_apps_without_latest_php_version_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected App Service web app ${param.title} without the latest PHP version."
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
        "enable_latest_php_version" = {
          label        = "Enable latest PHP version"
          value        = "enable_latest_php_version"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.set_config_appservice_webapp
          pipeline_args = {
            resource_group   = param.resource_group
            subscription_id  = param.subscription_id
            app_name         = param.name
            conn             = param.conn
					  linux_fx_version = param.linux_fx_version
          }
          success_msg = "Enabled latest PHP version for App Service web app ${param.title}."
          error_msg   = "Error enabling latest PHP version for App Service web app ${param.title}."
        }
      }
    }
  }
}

