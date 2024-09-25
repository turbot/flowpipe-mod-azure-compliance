locals {
  securitycenters_with_azure_defender_for_keyvault_disabled_query = <<-EOQ
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
      and sc.name = 'KeyVaults'
      and sub.subscription_id = sc.subscription_id;
  EOQ
}

variable "securitycenters_with_azure_defender_for_keyvault_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "securitycenters_with_azure_defender_for_keyvault_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "securitycenters_with_azure_defender_for_keyvault_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "securitycenters_with_azure_defender_for_keyvault_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_key_vault_azure_defender"]
}

trigger "query" "detect_and_correct_securitycenters_with_azure_defender_for_keyvault_disabled" {
  title         = "Detect & correct Security Centers with Azure Defender disabled for Key Vault"
  description   = "Detect Security Centers with Azure Defender disabled for Key Vault and then enable Azure Defender for Key Vault."
  // tags          = merge(local.securitycenter_common_tags, { class = "unused" })

  enabled  = var.securitycenters_with_azure_defender_for_keyvault_disabled_trigger_enabled
  schedule = var.securitycenters_with_azure_defender_for_keyvault_disabled_trigger_schedule
  database = var.database
  sql      = local.securitycenters_with_azure_defender_for_keyvault_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_securitycenters_with_azure_defender_for_keyvault_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_securitycenters_with_azure_defender_for_keyvault_disabled" {
  title         = "Detect & correct Security Centers with Azure Defender disabled for Key Vault"
  description   = "Detect Security Centers with Azure Defender disabled for Key Vault and then enable Azure Defender for Key Vault."
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
    default     = var.securitycenters_with_azure_defender_for_keyvault_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.securitycenters_with_azure_defender_for_keyvault_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.securitycenters_with_azure_defender_for_keyvault_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_securitycenters_with_azure_defender_for_keyvault_disabled
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

pipeline "correct_securitycenters_with_azure_defender_for_keyvault_disabled" {
  title         = "Correct Security Centers with Azure Defender disabled for Key Vault"
  description   = "Enable Azure Defender for Key Vault in Security Centers with Azure Defender disabled for Key Vault."
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
    default     = var.securitycenters_with_azure_defender_for_keyvault_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.securitycenters_with_azure_defender_for_keyvault_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Security Center(s) with Azure Defender disabled for Key Vault."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_securitycenter_with_azure_defender_for_keyvault_disabled
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

pipeline "correct_one_securitycenter_with_azure_defender_for_keyvault_disabled" {
  title         = "Correct Security Center with Azure Defender disabled for Key Vault"
  description   = "Enable Azure Defender for Key Vault in Security Center with Azure Defender disabled for Key Vault."
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
    default     = var.securitycenters_with_azure_defender_for_keyvault_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.securitycenters_with_azure_defender_for_keyvault_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Security Center ${param.title} with Azure Defender disabled for Key Vault."
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
            text     = "Skipped Security Center ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_key_vault_azure_defender" = {
          label        = "Enable Key Vault Azure Defender"
          value        = "enable_key_vault_azure_defender"
          style        = local.style_alert
          pipeline_ref = local.azure_pipeline_create_security_pricing
          pipeline_args = {
            resource_type     = "KeyVaults"
            subscription_id   = param.subscription_id
            cred              = param.cred
            tier              = "Standard"
          }
          success_msg = "Enabled Azure Defender for Key Vault in Security Center ${param.title}."
          error_msg   = "Error enabling Azure Defender for Key Vault in Security Center ${param.title}."
        }
      }
    }
  }
}

