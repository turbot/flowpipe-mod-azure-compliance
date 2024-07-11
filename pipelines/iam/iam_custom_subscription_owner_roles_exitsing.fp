locals {
  iam_custom_subscription_owner_roles_existing_query = <<-EOQ
    select
      concat(id, ' [', role_name, '/', subscription_id, ']') as title,
      id as id,
      role_name as name,
      subscription_id,
      _ctx ->> 'connection_name' as cred
    from
			azure_role_definition,
			jsonb_array_elements(permissions) as s,
			jsonb_array_elements_text(s -> 'actions') as action
		where
			role_type = 'CustomRole'
			and action in ('*', '*:*');
  EOQ
}

trigger "query" "detect_and_correct_iam_custom_subscription_owner_roles_existing" {
  title         = "Detect & correct custom subscription owner roles existing"
  description   = "Detects custom subscription owner roles that exist and runs your chosen action."
  tags          = merge(local.iam_common_tags, { class = "security" })

  enabled  = var.iam_custom_subscription_owner_roles_existing_trigger_enabled
  schedule = var.iam_custom_subscription_owner_roles_existing_trigger_schedule
  database = var.database
  sql      = local.iam_custom_subscription_owner_roles_existing_query

  capture "insert" {
    pipeline = pipeline.correct_iam_custom_subscription_owner_roles_existing
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_custom_subscription_owner_roles_existing" {
  title         = "Detect & correct custom subscription owner roles existing"
  description   = "Detects custom subscription owner roles that exist and runs your chosen action."
  tags          = merge(local.iam_common_tags, { class = "security", type = "featured" })

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
    default     = var.iam_custom_subscription_owner_roles_existing_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_custom_subscription_owner_roles_existing_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_custom_subscription_owner_roles_existing_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_custom_subscription_owner_roles_existing
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

pipeline "correct_iam_custom_subscription_owner_roles_existing" {
  title         = "Correct custom subscription owner roles existing"
  description   = "Runs corrective action on a collection of custom subscription owner roles that exist."
  tags          = merge(local.iam_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      id              = string
      title           = string
      name            = string
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
    default     = var.iam_custom_subscription_owner_roles_existing_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_custom_subscription_owner_roles_existing_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} custom subscription owner roles existing."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_custom_subscription_owner_role_existing
    args = {
      title              = each.value.title
      name               = each.value.name
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

pipeline "correct_one_iam_custom_subscription_owner_role_existing" {
  title         = "Correct one custom subscription owner role existing"
  description   = "Runs corrective action on a single custom subscription owner role that exists."
  tags          = merge(local.iam_common_tags, { class = "security" })

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
    default     = var.iam_custom_subscription_owner_roles_existing_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_custom_subscription_owner_roles_existing_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected custom subscription owner role ${param.title} existing."
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
            text     = "Skipped custom subscription owner role ${param.title} existing."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_custom_role" = {
          label        = "Delete Custom Role"
          value        = "delete_custom_role"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_delete_iam_role
          pipeline_args = {
            role_name        = param.name
            subscription_id  = param.subscription_id

            cred             = param.cred
          }
          success_msg = "Deleted custom subscription owner role ${param.title}."
          error_msg   = "Error deleting custom subscription owner role ${param.title}."
        }
      }
    }
  }
}

variable "iam_custom_subscription_owner_roles_existing_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_custom_subscription_owner_roles_existing_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "iam_custom_subscription_owner_roles_existing_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "iam_custom_subscription_owner_roles_existing_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_custom_role"]
}
