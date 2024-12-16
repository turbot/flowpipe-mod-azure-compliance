locals {
  securitycenters_with_azure_defender_for_container_disabled_query = <<-EOQ
    select
      concat(sc.id, ' [', '/', sc.subscription_id, ']') as title,
      sc.id as id,
      sc.name,
      sc.subscription_id,
      sc._ctx ->> 'connection_name' as conn
    from
      azure_security_center_subscription_pricing as sc,
      azure_subscription as sub
    where
      sc.pricing_tier != 'Standard'
      and sc.name = 'Containers'
      and sub.subscription_id = sc.subscription_id;
  EOQ

  securitycenters_with_azure_defender_for_container_disabled_enabled_actions_enum = ["skip", "enable_container_azure_defender"]
  securitycenters_with_azure_defender_for_container_disabled_default_action_enum = ["notify", "skip", "enable_container_azure_defender"]
}

variable "securitycenters_with_azure_defender_for_container_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/SecurityCenter"
  }
}

variable "securitycenters_with_azure_defender_for_container_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/SecurityCenter"
  }
}

variable "securitycenters_with_azure_defender_for_container_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/SecurityCenter"
  }
}

variable "securitycenters_with_azure_defender_for_container_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_container_azure_defender"]

  tags = {
    folder = "Advanced/SecurityCenter"
  }
}

trigger "query" "detect_and_correct_securitycenters_with_azure_defender_for_container_disabled" {
  title         = "Detect & correct Security Centers with azure defender disabled for Container"
  description   = "Detect Security Centers with azure defender disabled for Container and then enable azure defender for Container."
   tags          = local.securitycenter_common_tags

  enabled  = var.securitycenters_with_azure_defender_for_container_disabled_trigger_enabled
  schedule = var.securitycenters_with_azure_defender_for_container_disabled_trigger_schedule
  database = var.database
  sql      = local.securitycenters_with_azure_defender_for_container_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_securitycenters_with_azure_defender_for_container_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_securitycenters_with_azure_defender_for_container_disabled" {
  title         = "Detect & correct Security Centers with azure defender disabled for Container"
  description   = "Detect Security Centers with azure defender disabled for Container and then enable azure defender for Container."
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.securitycenters_with_azure_defender_for_container_disabled_default_action
    enum        = local.securitycenters_with_azure_defender_for_container_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.securitycenters_with_azure_defender_for_container_disabled_enabled_actions
    enum        = local.securitycenters_with_azure_defender_for_container_disabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.securitycenters_with_azure_defender_for_container_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_securitycenters_with_azure_defender_for_container_disabled
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

pipeline "correct_securitycenters_with_azure_defender_for_container_disabled" {
  title         = "Correct Security Centers with azure defender disabled for Container"
  description   = "Enable azure defender for Container in Security Centers with azure defender disabled for Container."
  tags          = merge(local.securitycenter_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
      name            = string
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
    default     = var.securitycenters_with_azure_defender_for_container_disabled_default_action
    enum        = local.securitycenters_with_azure_defender_for_container_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.securitycenters_with_azure_defender_for_container_disabled_enabled_actions
    enum        = local.securitycenters_with_azure_defender_for_container_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Security Center(s) with azure defender disabled for Container."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_securitycenter_with_azure_defender_for_containers_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
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

pipeline "correct_one_securitycenter_with_azure_defender_for_containers_disabled" {
  title         = "Correct Security Center with azure defender disabled for Container"
  description   = "Enable azure defender for Container in Security Center with azure defender disabled for Container."
  tags          = merge(local.securitycenter_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the security center subscription pricing."
  }

  param "subscription_id" {
    type        = string
    description = local.description_subscription_id
  }

  param "conn" {
    type        = connection.azure
    description = local.description_connection
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
    default     = var.securitycenters_with_azure_defender_for_container_disabled_default_action
    enum        = local.securitycenters_with_azure_defender_for_container_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.securitycenters_with_azure_defender_for_container_disabled_enabled_actions
    enum        = local.securitycenters_with_azure_defender_for_container_disabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Security Center ${param.title} with azure defender disabled for Container."
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
            text     = "Skipped Security Center ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_container_azure_defender" = {
          label        = "Enable Container azure defender"
          value        = "enable_container_azure_defender"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.create_security_pricing
          pipeline_args = {
            resource_type     = "Container"
            subscription_id   = param.subscription_id
            conn              = param.conn
            tier              = "Standard"
          }
          success_msg = "Enabled azure defender for Container in Security Center ${param.title}."
          error_msg   = "Error enabling azure defender for Container in Security Center ${param.title}."
        }
      }
    }
  }
}

