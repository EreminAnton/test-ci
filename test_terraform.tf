
data "aws_ssoadmin_instances" "this" {}

# You will have to create /sso-elevator/slack-signing-secret AWS SSM Parameter
# and store Slack app signing secret there, if you have not created app yet then
# you can leave a dummy value there and update it after Slack app is ready
data "aws_ssm_parameter" "sso_elevator_slack_signing_secret" {
  name = "/sso-elevator/slack-signing-secret"
}

# You will have to create /sso-elevator/slack-bot-token AWS SSM Parameter
# and store Slack bot token there, if you have not created app yet then
# you can leave a dummy value there and update it after Slack app is ready
data "aws_ssm_parameter" "sso_elevator_slack_bot_token" {
  name = "/sso-elevator/slack-bot-token"
}

module "aws_sso_elevator" {
  source                           = "github.com/fivexl/terraform-aws-sso-elevator.git?ref=v1.0.0"
  aws_sns_topic_subscription_email = "email@gmail.com"

  slack_signing_secret                           = data.aws_ssm_parameter.sso_elevator_slack_signing_secret.value
  slack_bot_token                                = data.aws_ssm_parameter.sso_elevator_slack_bot_token.value
  slack_channel_id                               = "***********"
  schedule_expression                            = "cron(0 23 * * ? *)" # revoke access schedule expression
  schedule_expression_for_check_on_inconsistency = "rate(1 hour)"
  build_in_docker                                = true
  revoker_post_update_to_slack                   = true

  sso_instance_arn = one(data.aws_ssoadmin_instances.this.arns)

  # If you wish to use your own S3 bucket for audit_entry logs, 
  # specify its name here:
  s3_name_of_the_existing_bucket = "your-s3-bucket-name"

  # If you do not provide a value for s3_name_of_the_existing_bucket, 
  # the module will create a new bucket with the default name 'sso-elevator-audit-entry':
  s3_bucket_name_for_audit_entry = "fivexl-sso-elevator"

  # The default partition prefix is "logs/":
  s3_bucket_partition_prefix = "some_prefix/"

  # MFA delete setting for the S3 bucket:
  s3_mfa_delete = false

  # Object lock setting for the S3 bucket:
  s3_object_lock = true

  # The default object lock configuration is as follows:
  # {
  #  rule = {
  #   default_retention = {
  #      mode  = "GOVERNANCE"
  #      years = 2
  #    }
  #  }
  #}
  # You can specify a different configuration here:
  s3_object_lock_configuration = {
    rule = {
      default_retention = {
        mode  = "GOVERNANCE"
        years = 1
      }
    }
  }

  # Here, you can specify the target_bucket and prefix for access logs of the sso_elevator bucket.
  # If s3_logging is not specified, logs will not be written:
  s3_logging = {
    target_bucket = "some_access_logging_bucket"
    target_prefix = "some_prefix_for_access_logs"
  }

  config = [
    # This could be a config for dev/stage account where developers can self-serve
    # permissions
    # Allows Bob and Alice to approve requests for all
    # PermissionSets in accounts dev_account_id and stage_account_id as
    # well as approve its own requests
    # You have to specify at AllowSelfApproval: true or specify two approvers
    # so you do not lock out approver
    {
      "ResourceType" : "Account",
      "Resource" : ["dev_account_id", "stage_account_id"],
      "PermissionSet" : "*",
      "Approvers" : ["bob@corp.com", "alice@corp.com"],
      "AllowSelfApproval" : true,
    },
    # This could be an option for a financial person
    # allows self approval for Billing PermissionSet
    # for account_id for user finances@corp.com
    {
      "ResourceType" : "Account",
      "Resource" : "account_id",
      "PermissionSet" : "Billing",
      "Approvers" : "finances@corp.com",
      "AllowSelfApproval" : true,
    },
    # Your typical CTO - can approve all accounts and all permissions
    # as well as his/hers own requests to avoid lock out
    # Careful withi Resource * since it will cause revocation of all
    # non-module-created user-level permission set assignments in all
    # accounts, add this one later when you are done with single account
    # testing
    {
      "ResourceType" : "Account",
      "Resource" : "*",
      "PermissionSet" : "*",
      "Approvers" : "cto@corp.com",
      "AllowSelfApproval" : true,
    },
    # Read only config for production accounts so developers
    # can check prod when needed
    {
      "ResourceType" : "Account",
      "Resource" : ["prod_account_id", "prod_account_id2"],
      "PermissionSet" : "ReadOnly",
      "AllowSelfApproval" : true,
    },
    # Prod access
    {
      "ResourceType" : "Account",
      "Resource" : ["prod_account_id", "prod_account_id2"],
      "PermissionSet" : "AdministratorAccess",
      "Approvers" : ["manager@corp.com", "ciso@corp.com"],
      "ApprovalIsNotRequired" : false,
      "AllowSelfApproval" : false,
    },
    # example of list being used for permissions sets
    {
      "ResourceType" : "Account",
      "Resource" : "account_id",
      "PermissionSet" : ["ReadOnlyPlus", "AdministratorAccess"],
      "Approvers" : ["ciso@corp.com"],
      "AllowSelfApproval" : true,
    },

  ]
}

output "aws_sso_elevator_lambda_function_url" {
  value = module.aws_sso_elevator.lambda_function_url
}