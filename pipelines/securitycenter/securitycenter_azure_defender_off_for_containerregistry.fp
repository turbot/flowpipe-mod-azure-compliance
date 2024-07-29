locals {
  securitycenter_azure_defender_off_for_containerregistry_query = <<-EOQ
    select
      concat(sc.id, ' [', '/', sc.subscription_id, ']') as title,
      sc.id as id,
      sc.name,
      sc.subscription_id,
      sc._ctx ->> 'connection_name' as cred
    from
      azure_security_center_subscription_pricing as sc,
      azure_subscription as sub
    where
      sc.pricing_tier != 'Standard'
      and sc.name = 'ContainerRegistry'
      and sub.subscription_id = sc.subscription_id;
  EOQ
}

trigger "query" "detect_and_correct_securitycenter_azure_defender_off_for_containerregistry" {
  title         = "Detect & correct Security Center Azure Defender off for Container Registries"
  description   = "Detects Security Center Azure Defender turned off for Container Registries and runs your chosen action."
  // tags          = merge(local.securitycenter_common_tags, { class = "unused" })

  enabled  = var.securitycenter_azure_defender_off_for_containerregistry_trigger_enabled
  schedule = var.securitycenter_azure_defender_off_for_containerregistry_trigger_schedule
  database = var.database
  sql      = local.securitycenter_azure_defender_off_for_containerregistry_query

  capture "insert" {
    pipeline = pipeline.correct_securitycenter_azure_defender_off_for_containerregistry
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_securitycenter_azure_defender_off_for_containerregistry" {
  title         = "Detect & correct Security Center Azure Defender off for Container Registries"
  description   = "Detects Security Center Azure Defender turned off for Container Registries and runs your chosen action."
  // tags          = merge(local.securitycenter_common_tags, { class = "unused", type = "featured" })

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
    default     = var.securitycenter_azure_defender_off_for_containerregistry_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.securitycenter_azure_defender_off_for_containerregistry_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.securitycenter_azure_defender_off_for_containerregistry_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_securitycenter_azure_defender_off_for_containerregistry
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

pipeline "correct_securitycenter_azure_defender_off_for_containerregistry" {
  title         = "Correct Security Center Azure Defender off for Container Registries"
  description   = "Runs corrective action on a collection of subscription with Security Center Azure Defender turned off for Container Registries."
  //  tags          = merge(local.securitycenter_common_tags, { class = "unused" })

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
    default     = var.securitycenter_azure_defender_off_for_containerregistry_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.securitycenter_azure_defender_off_for_containerregistry_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected Security Center Azure Defender turned off for Container Registries."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_securitycenter_azure_defender_off_for_containerregistry
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


pipeline "correct_one_securitycenter_azure_defender_off_for_containerregistry" {
  title         = "Correct one subscription with Security Center Azure Defender turned off for Container Registries"
  description   = "Runs corrective action on a subscription with Security Center Azure Defender turned off for Container Registries."
  // tags          = merge(local.securitycenter_common_tags, { class = "unused" })

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
    default     = var.securitycenter_azure_defender_off_for_containerregistry_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.securitycenter_azure_defender_off_for_containerregistry_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Security Center Azure Defender turned off for Container Registries."
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
            text     = "Skipped Security Center Azure Defender turned off for Container Registries."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_containerregistry_azure_defender" = {
          label        = "Enable Container Registries Azure Defender"
          value        = "enable_containerregistry_azure_defender"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_create_security_pricing
          pipeline_args = {
            resource_type     = "ContainerRegistry"
            subscription_id   = param.subscription_id
            cred              = param.cred
            tier              = "Standard"
          }
          success_msg = "Enabled Security Center Azure Defender for Container Registries."
          error_msg   = "Error enabling Security Center Azure Defender for Container Registries ."
        }
      }
    }
  }
}

variable "securitycenter_azure_defender_off_for_containerregistry_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "securitycenter_azure_defender_off_for_containerregistry_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "securitycenter_azure_defender_off_for_containerregistry_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "enable_containerregistry_azure_defender"
}

variable "securitycenter_azure_defender_off_for_containerregistry_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_containerregistry_azure_defender"]
}
