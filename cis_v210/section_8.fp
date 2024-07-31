locals {
  // cis_v210_8_common_tags = merge(local.cis_v210_common_tags, {
  //   cis_section_id = "8"
  // })

  cis_v210_8_control_mapping = {
    cis_v210_8_1  = {pipeline = pipeline.detect_and_correct_keyvault_with_rbac_key_expiration_not_set, additional_args = {}}
    cis_v210_8_2  = {pipeline = pipeline.detect_and_correct_keyvault_with_non_rbac_key_expiration_not_set, additional_args = {}}
    cis_v210_8_3  = {pipeline = pipeline.detect_and_correct_keyvault_with_rbac_secret_expiration_not_set, additional_args = {}}
    cis_v210_8_4  = {pipeline = pipeline.detect_and_correct_keyvault_with_non_rbac_secret_expiration_not_set, additional_args = {}}
    cis_v210_8_5  = {pipeline = pipeline.detect_and_correct_keyvault_vault_non_recoverable, additional_args = {}}
		cis_v210_8_6  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 8.6 is a manual control."}}
		cis_v210_8_7  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 8.7 is a manual control."}}
    cis_v210_8_8  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 8.8 is a manual control."}}
  }
}

variable "cis_v210_8_enabled_controls" {
  type        = list(string)
  description = "List of CIS v2.1.0 section 8 controls to enable"
  default     = [
    "cis_v210_8_1",
    "cis_v210_8_2",
    "cis_v210_8_3",
    "cis_v210_8_4",
    "cis_v210_8_5",
    "cis_v210_8_6",
    "cis_v210_8_7",
    "cis_v210_8_8"
  ]
}


pipeline "cis_v210_8" {
  title         = "8 Key Vault"
  documentation = file("./cis_v210/docs/cis_v210_8.md")

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

  step "input" "should_run" {
    if       = (length(param.approvers) > 0)
    notifier = notifier[param.notifier]
    type     = "button"
    subject  = "Request to run CIS v2.1.0 Section 8: Key Vault?"
    prompt   = "Do you wish to run CIS v2.1.0 Section 8: Key Vault?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v210_8" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v2.1.0 Section 8: Key Vault"
  }

  step "pipeline" "cis_v210_8" {
    depends_on = [step.message.cis_v210_8]
    if       = (step.transform.input_value.value == "yes")

    loop {
      until = loop.index >= (length(var.cis_v210_8_enabled_controls)-1)
    }

    pipeline = local.cis_v210_8_control_mapping[var.cis_v210_8_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v210_8_control_mapping[var.cis_v210_8_enabled_controls[loop.index]].additional_args)
  }
}
