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

// Common Texts
locals {
  description_resource         = "The name of the resource"
  description_database         = "Database connection string."
  description_approvers        = "List of notifiers to be used for obtaining action/approval decisions."
  description_credential       = "Name of the credential to be used for any authenticated actions."
  description_resource_group   = "Azure Resource Group. Examples: my-rg, my-rg-123."
	description_subscription_id  = "Azure Subscription Id. Examples: d46d7416-f95f-4771-bbb5-529d4c766."
  description_title            = "Title of the resource, to be used as a display name."
  description_max_concurrency  = "The maximum concurrency to use for responding to detection items."
  description_notifier         = "The name of the notifier to use for sending notification messages."
  description_notifier_level   = "The verbosity level of notification messages to send. Valid options are 'verbose', 'info', 'error'."
  description_default_action   = "The default action to use for the detected item, used if no input is provided."
  description_enabled_actions  = "The list of enabled actions to provide to approvers for selection."
  description_trigger_enabled  = "If true, the trigger is enabled."
  description_trigger_schedule = "The schedule on which to run the trigger if enabled."
  description_items            = "A collection of detected resources to run corrective actions against."
}

// Pipeline References
locals {
  pipeline_optional_message                                     = detect_correct.pipeline.optional_message
	azure_pipeline_set_postgres_server_configuration              = azure.pipeline.set_postgres_server_configuration
  azure_pipeline_update_postgres_server_ssl_enforcement         = azure.pipeline.update_postgres_server_ssl_enforcement
  azure_pipeline_create_security_pricing                        = azure.pipeline.create_security_pricing
  azure_pipeline_update_storage_account_public_network_access   = azure.pipeline.update_storage_account_public_network_access
  azure_pipeline_update_storage_account_minimum_tls             = azure.pipeline.update_storage_account_minimum_tls
  azure_pipeline_update_storage_account_blob_service_properties = azure.pipeline.update_storage_account_blob_service_properties
  azure_pipeline_update_storage_account_bypass_azure_services   = azure.pipeline.update_storage_account_bypass_azure_services
  azure_pipeline_update_storage_account_https_only              = azure.pipeline.update_storage_account_https_only
  azure_pipeline_update_storage_account_logging                 = azure.pipeline.update_storage_account_logging
  azure_pipeline_update_storage_account_default_action          = azure.pipeline.update_storage_account_default_action
  azure_pipeline_update_appservice_webapp_auth                  = azure.pipeline.update_appservice_webapp_auth
  azure_pipeline_set_config_appservice_webapp                   = azure.pipeline.set_config_appservice_webapp
  azure_pipeline_update_appservice_webapp                       = azure.pipeline.update_appservice_webapp
  azure_pipeline_assign_appservice_webapp_identity              = azure.pipeline.assign_appservice_webapp_identity
  azure_pipeline_delete_sql_server_firewall_rule                = azure.pipeline.delete_sql_server_firewall_rule
  azure_pipeline_set_sql_db_tde                                 = azure.pipeline.set_sql_db_tde
  azure_pipeline_update_azure_key_vault_purge_protection        = azure.pipeline.update_azure_key_vault_purge_protection
}