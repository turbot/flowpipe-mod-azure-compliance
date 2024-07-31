locals {
  // cis_v210_2_common_tags = merge(local.cis_v210_common_tags, {
  //   cis_section_id = "5"
  // })

  cis_v210_2_control_mapping = {
    cis_v210_2_1_1  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_server, additional_args = {}}
    cis_v210_2_1_2  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_appservice, additional_args = {}}
    cis_v210_2_1_3  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_sqldb, additional_args = {}}
    cis_v210_2_1_4  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_sqlservervm, additional_args = {}}
    cis_v210_2_1_5  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_opensource_relational_db, additional_args = {}}
    cis_v210_2_1_6  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_cosmosdb, additional_args = {}}
    cis_v210_2_1_7  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_storage, additional_args = {}}
    cis_v210_2_1_8  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_containerregistry, additional_args = {}}
    cis_v210_2_1_9  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_keyvault, additional_args = {}}
    cis_v210_2_1_10  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_dns, additional_args = {}}
    cis_v210_2_1_11  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_resource_manager, additional_args = {}}
    cis_v210_2_1_12  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 2.1.12 is a TODO control."}}
    cis_v210_2_1_13  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 2.1.32 is a manual control."}}
    cis_v210_2_1_14  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 2.1.14 is a TODO control."}}
    cis_v210_2_1_15  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 2.1.15 is a manual control."}}
    cis_v210_2_1_16  = {pipeline = pipeline.detect_and_correct_securitycenter_azure_defender_off_for_containerregistry, additional_args = {}}
    cis_v210_2_1_17  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 2.1.17 is a TODO control."}}
    cis_v210_2_1_18  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 2.1.18 is a TODO control."}}
    cis_v210_2_1_19  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 2.1.19 is a TODO control."}}
    cis_v210_2_1_20  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 2.1.20 is a manual control."}}
    cis_v210_2_1_21  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 2.1.21 is a manual control."}}
    cis_v210_2_1_22  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 2.1.22 is a manual control."}}
    cis_v210_2_2_1  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 2.2.1 is a manual control."}}
  }
}

variable "cis_v210_2_enabled_controls" {
  type        = list(string)
  description = "List of CIS v2.1.0 section 2 controls to enable"
  default     = [
    "cis_v210_2_1_1",
    "cis_v210_2_1_2",
    "cis_v210_2_1_3",
    "cis_v210_2_1_4",
    "cis_v210_2_1_5",
    "cis_v210_2_1_6",
    "cis_v210_2_1_7",
    "cis_v210_2_1_8",
    "cis_v210_2_1_9",
    "cis_v210_2_1_10",
    "cis_v210_2_1_11",
    "cis_v210_2_1_12",
    "cis_v210_2_1_13",
    "cis_v210_2_1_14",
    "cis_v210_2_1_15",
    "cis_v210_2_1_16",
    "cis_v210_2_1_17",
    "cis_v210_2_1_18",
    "cis_v210_2_1_19",
    "cis_v210_2_1_20",
    "cis_v210_2_1_21",
    "cis_v210_2_1_22",
    "cis_v210_2_2_1"
  ]
}


pipeline "cis_v210_2" {
  title         = "2 Microsoft Defender"
  documentation = file("./cis_v210/docs/cis_v210_2.md")

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
    subject  = "Request to run CIS v2.1.0 Section 2: Microsoft Defender?"
    prompt   = "Do you wish to run CIS v2.1.0 Section 2: Microsoft Defender?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v210_2" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v3.0.0 Section 2: Microsoft Defender"
  }

  step "pipeline" "cis_v210_2" {
    depends_on = [step.message.cis_v210_2]
    if       = (step.transform.input_value.value == "yes")

    loop {
      until = loop.index >= (length(var.cis_v210_2_enabled_controls)-1)
    }

    pipeline = local.cis_v210_2_control_mapping[var.cis_v210_2_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v210_2_control_mapping[var.cis_v210_2_enabled_controls[loop.index]].additional_args)
  }
}
