// Tags
locals {
  azure_compliance_common_tags = {
    category = "Compliance"
    plugin   = "azure"
    service  = "Azure"
  }
}

// Consts
locals {
  level_verbose = "verbose"
  level_info    = "info"
  level_error   = "error"
  style_ok      = "ok"
  style_info    = "info"
  style_alert   = "alert"
}

locals {
  notification_level_enum = ["verbose", "info", "error"]
}

// Common Texts
locals {
  description_resource         = "The name of the resource"
  description_database         = "Database connection string."
  description_approvers        = "List of notifiers to be used for obtaining action/approval decisions."
  description_connection       = "Name of the connection to be used for any authenticated actions."
  description_resource_group   = "Azure Resource Group. Examples: my-rg, my-rg-123."
  description_subscription_id  = "Azure Subscription Id. Examples: d46d7416-f95f-4771-bbb5-529d4c766."
  description_title            = "Title of the resource, to be used as a display name."
  description_max_concurrency  = "The maximum concurrency to use for responding to detection items."
  description_notifier         = "The name of the notifier to use for sending notification messages."
  description_notifier_level   = "The verbosity level of notification messages to send. Valid options are 'verbose', 'info', 'error'."
  description_default_action   = "The default action to use when there are no approvers."
  description_enabled_actions  = "The list of enabled actions to provide to approvers for selection."
  description_trigger_enabled  = "If true, the trigger is enabled."
  description_trigger_schedule = "If the trigger is enabled, run it on this schedule."
  description_items            = "A collection of detected resources to run corrective actions against."
}

