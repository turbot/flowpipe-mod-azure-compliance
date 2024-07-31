locals {
  // cis_v210_3_common_tags = merge(local.cis_v210_common_tags, {
  //   cis_section_id = "5"
  // })

  cis_v210_3_control_mapping = {
    cis_v210_3_1  = {pipeline = pipeline.detect_and_correct_storage_account_secure_transfer_required_disabled, additional_args = {}}
    cis_v210_3_2  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 3.2 is a TODO control."}}
    cis_v210_3_3  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 3.3 is a manual control."}}
		cis_v210_3_4  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 3.4 is a manual control."}}
    cis_v210_3_5  = {pipeline = pipeline.detect_and_correct_storage_account_queue_service_logging_disabled, additional_args = {}}
		cis_v210_3_6  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 3.6 is a manual control."}}
    cis_v210_3_7  = {pipeline = pipeline.detect_and_correct_storage_account_if_allow_public_access, additional_args = {}}
    cis_v210_3_8  = {pipeline = pipeline.detect_and_correct_storage_account_default_network_access_rule_allowed, additional_args = {}}
		cis_v210_3_9 = {pipeline = pipeline.detect_and_correct_storage_account_trusted_microsoft_services_disabled, additional_args = {}}
		cis_v210_3_10  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 3.10 is a TODO control."}}
		cis_v210_3_11  = {pipeline = pipeline.detect_and_correct_storage_account_blob_soft_delete_disabled, additional_args = {}}
		cis_v210_3_12  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 3.6 is a manual control."}}
		cis_v210_3_13  = {pipeline = pipeline.detect_and_correct_storage_account_blob_service_logging_disabled, additional_args = {}}
		cis_v210_3_14  = {pipeline = pipeline.detect_and_correct_storage_account_table_service_logging_disabled, additional_args = {}}
		cis_v210_3_15  = {pipeline = pipeline.detect_and_correct_storage_account_no_min_tls_1_2, additional_args = {}}
		cis_v210_3_16  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 3.15 is a TODO control."}}
		cis_v210_3_17  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 3.17 is a TODO control."}}
  }
}

variable "cis_v210_3_enabled_controls" {
  type        = list(string)
  description = "List of CIS v2.1.0 section 2 controls to enable"
  default     = [
    "cis_v210_3_1_1",
    "cis_v210_3_1_2",
    "cis_v210_3_1_3",
    "cis_v210_3_1_4",
    "cis_v210_3_1_5",
    "cis_v210_3_1_6",
    "cis_v210_3_1_7",
    "cis_v210_3_1_8",
    "cis_v210_3_1_9",
    "cis_v210_3_1_10",
    "cis_v210_3_1_11",
    "cis_v210_3_1_12",
    "cis_v210_3_1_13",
    "cis_v210_3_1_14",
    "cis_v210_3_1_15",
    "cis_v210_3_1_16",
    "cis_v210_3_1_17"
  ]
}


pipeline "cis_v210_3" {
  title         = "3 Storage Accounts"
  documentation = file("./cis_v210/docs/cis_v210_3.md")

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
    subject  = "Request to run CIS v3.0.0 Section 3: Storage Accounts?"
    prompt   = "Do you wish to run CIS v3.0.0 Section 3: Storage Accounts?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v210_3" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v3.0.0 Section 3: Storage Accounts"
  }

  step "pipeline" "cis_v210_3" {
    depends_on = [step.message.cis_v210_3]
    if       = (step.transform.input_value.value == "yes")

    loop {
      until = loop.index >= (length(var.cis_v210_3_enabled_controls)-1)
    }

    pipeline = local.cis_v210_3_control_mapping[var.cis_v210_3_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v210_3_control_mapping[var.cis_v210_3_enabled_controls[loop.index]].additional_args)
  }
}
