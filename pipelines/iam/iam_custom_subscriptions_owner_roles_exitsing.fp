locals {
  iam_custom_subscriptions_owner_roles_existing_query = <<-EOQ
    select
      concat(id, ' [', subscription_id, '/', role_name, ']') as title,
      id as id,
      role_name as name,
      subscription_id,
      _ctx ->> 'connection_name' as conn
    from
      azure_role_definition,
      jsonb_array_elements(permissions) as s,
      jsonb_array_elements_text(s -> 'actions') as action
    where
      role_type = 'CustomRole'
      and action in ('*', '*:*');
  EOQ

  iam_custom_subscriptions_owner_roles_existing_enabled_actions_enum = ["skip", "delete_custom_role"]
  iam_custom_subscriptions_owner_roles_existing_default_action_enum = ["notify", "skip", "delete_custom_role"]
}

variable "iam_custom_subscriptions_owner_roles_existing_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_custom_subscriptions_owner_roles_existing_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_custom_subscriptions_owner_roles_existing_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_custom_subscriptions_owner_roles_existing_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_custom_role"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_custom_subscriptions_owner_roles_existing" {
  title         = "Detect & correct custom subscription owner roles existing"
  description   = "Detects custom subscription owner roles that exist and then delete custom subscriptions owner roles."
  tags          = local.iam_common_tags

  enabled  = var.iam_custom_subscriptions_owner_roles_existing_trigger_enabled
  schedule = var.iam_custom_subscriptions_owner_roles_existing_trigger_schedule
  database = var.database
  sql      = local.iam_custom_subscriptions_owner_roles_existing_query

  capture "insert" {
    pipeline = pipeline.correct_iam_custom_subscriptions_owner_roles_existing
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_custom_subscriptions_owner_roles_existing" {
  title         = "Detect & correct custom subscription owner roles existing"
  description   = "Detects custom subscription owner roles that exist and then delete custom subscriptions owner roles."
  tags          = local.iam_common_tags

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
    default     = var.iam_custom_subscriptions_owner_roles_existing_default_action
    enum        = local.iam_custom_subscriptions_owner_roles_existing_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_custom_subscriptions_owner_roles_existing_enabled_actions
    enum        = local.iam_custom_subscriptions_owner_roles_existing_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_custom_subscriptions_owner_roles_existing_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_custom_subscriptions_owner_roles_existing
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

pipeline "correct_iam_custom_subscriptions_owner_roles_existing" {
  title         = "Correct custom subscription owner roles existing"
  description   = "Runs corrective action on a collection of custom subscription owner roles that exist."
  tags          = merge(local.iam_common_tags, { folder = "Internal" })

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
    default     = var.iam_custom_subscriptions_owner_roles_existing_default_action
    enum        = local.iam_custom_subscriptions_owner_roles_existing_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_custom_subscriptions_owner_roles_existing_enabled_actions
    enum        = local.iam_custom_subscriptions_owner_roles_existing_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} custom subscription owner roles."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_custom_subscriptions_owner_role_existing
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

pipeline "correct_one_iam_custom_subscriptions_owner_role_existing" {
  title         = "Correct one custom subscription owner role existing"
  description   = "Runs corrective action on a single custom subscription owner role that exists."
  tags          = merge(local.iam_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the custom subscription owner role."
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
    default     = var.iam_custom_subscriptions_owner_roles_existing_default_action
    enum        = local.iam_custom_subscriptions_owner_roles_existing_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_custom_subscriptions_owner_roles_existing_enabled_actions
    enum        = local.iam_custom_subscriptions_owner_roles_existing_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected custom subscription owner role ${param.title}."
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
            text     = "Skipped custom subscription owner role ${param.title} existing."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_custom_role" = {
          label        = "Delete custom role"
          value        = "delete_custom_role"
          style        = local.style_alert
          pipeline_ref = azure.pipeline.delete_iam_role
          pipeline_args = {
            role_name        = param.name
            subscription_id  = param.subscription_id

            conn             = param.conn
          }
          success_msg = "Deleted custom subscription owner role ${param.title}."
          error_msg   = "Error deleting custom subscription owner role ${param.title}."
        }
      }
    }
  }
}
