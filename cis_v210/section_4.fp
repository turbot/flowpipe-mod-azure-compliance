locals {
  // cis_v210_4_common_tags = merge(local.cis_v210_common_tags, {
  //   cis_section_id = "7"
  // })

  cis_v210_4_control_mapping = {
    cis_v210_4_1_1  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.1.1 is a TODO control."}}
    cis_v210_4_1_2  = {pipeline = pipeline.detect_and_correct_sql_databases_allow_internet_access, additional_args = {}}
    cis_v210_4_1_3  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.1.3 is a TODO control."}}
    cis_v210_4_1_4  =  {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.1.4 is a TODO control."}}
    cis_v210_4_1_5  = {pipeline = pipeline.detect_and_correct_sql_dbs_transparent_data_encryption_disabled, additional_args = {}}
		cis_v210_4_1_6  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.1.6 is a TODO control."}}
		cis_v210_4_3_1  = {pipeline = pipeline.detect_and_correct_postgres_db_servers_ssl_disabled, additional_args = {}}
		cis_v210_4_3_2  = {pipeline = pipeline.detect_and_correct_postgres_db_servers_log_checkpoints_off, additional_args = {}}
		cis_v210_4_3_3  = {pipeline = pipeline.detect_and_correct_postgres_db_servers_log_connections_off, additional_args = {}}
		cis_v210_4_3_4  = {pipeline = pipeline.detect_and_correct_postgres_db_servers_log_disconnections_off, additional_args = {}}
		cis_v210_4_3_5  = {pipeline = pipeline.detect_and_correct_postgres_db_servers_connection_throttling_off, additional_args = {}}
		cis_v210_4_3_6  = {pipeline = pipeline.detect_and_correct_postgres_db_servers_log_retention_days_less_than_3, additional_args = {}}
		cis_v210_4_3_7  = {pipeline = pipeline.detect_and_correct_postgres_db_servers_allow_access_to_azure_services_enabled, additional_args = {}}
		cis_v210_4_3_8  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.3.8 is a TODO control."}}
		cis_v210_4_4_1  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.4.1 is a TODO control."}}
		cis_v210_4_4_2  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.4.1 is a TODO control."}}
		cis_v210_4_4_3  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.4.3 is a manual control."}}
    cis_v210_4_4_4  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.4.4 is a manual control."}}
		cis_v210_4_5_1  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.5.1 is a TODO control."}}
		cis_v210_4_5_2  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.5.2  is a TODO control."}}
    cis_v210_4_5_3  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v2.1.0 4.5.3 is a manual control."}}

  }
}

variable "cis_v210_4_enabled_controls" {
  type        = list(string)
  description = "List of CIS v2.1.0 section 4 controls to enable"
  default     = [
    "cis_v210_4_1_2",
    "cis_v210_4_1_5",
    "cis_v210_4_3_1",
    "cis_v210_4_3_2",
    "cis_v210_4_3_3",
    "cis_v210_4_3_4",
    "cis_v210_4_3_5",
    "cis_v210_4_3_6",
    "cis_v210_4_3_7"
  ]
}

pipeline "cis_v210_4" {
  title         = "4 Database Services"
  documentation = file("./cis_v210/docs/cis_v210_4.md")

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
    subject  = "Request to run CIS v2.1.0 Section 4: Database Services?"
    prompt   = "Do you wish to run CIS v2.1.0 Section 4: Database Services?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v210_4" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v2.1.0 Section 4: Database Services"
  }

  step "pipeline" "cis_v210_4" {
    depends_on = [step.message.cis_v210_4]
    if       = (step.transform.input_value.value == "yes")

    loop {
      until = loop.index >= (length(var.cis_v210_4_enabled_controls)-1)
    }

    pipeline = local.cis_v210_4_control_mapping[var.cis_v210_4_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v210_4_control_mapping[var.cis_v210_4_enabled_controls[loop.index]].additional_args)
  }
}
