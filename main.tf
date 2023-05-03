data "aws_caller_identity" "current" {}

# Get current region
data "aws_region" "current" {}

# Available AZ
data "aws_availability_zones" "available" {}

resource "aws_cloudwatch_log_group" "mssql-ssm-automation-cloudwatch-logs" {
  name                    = "${var.prefix}-mssql-ssm-automation"
  kms_key_id              = var.cloudwatch_kms_key_id
  retention_in_days       = var.cloudwatch_retention_in_days

  tags = var.tags
}


resource "aws_iam_role" "ssm_automation_role" {
  name = "${var.prefix}-qs-ssm-automation-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "s3_policy" {
  name = "${var.prefix}-mssql-s3-policy"
  role = aws_iam_role.ssm_automation_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
            "arn:aws:s3:::${var.qs_s3_bucket_name}/*",
            "arn:aws:s3:::${var.qs_s3_bucket_name}"
            ]
      },
    ]
  })
}

resource "aws_iam_role_policy" "ssm_automation_execution" {
  name = "${var.prefix}-mssql-ssm-AutomationExecution-policy"
  role = aws_iam_role.ssm_automation_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ssm:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "ssm_automation_custom_s3_policy" {
  name = "${var.prefix}-mssql-ssm-custom-s3-policy"
  role = aws_iam_role.ssm_automation_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = [
            "arn:aws:s3:::aws-ssm-${data.aws_region.current.name}/*",
            "arn:aws:s3:::aws-windows-downloads-${data.aws_region.current.name}/*",
            "arn:aws:s3:::amazon-ssm-${data.aws_region.current.name}/*",
            "arn:aws:s3:::amazon-ssm-packages-${data.aws_region.current.name}/*",
            "arn:aws:s3:::${data.aws_region.current.name}-birdwatcher-prod/*",
            "arn:aws:s3:::patch-baseline-snapshot-${data.aws_region.current.name}/*"
            ]
      },
    ]
  })
}

resource "aws_ssm_document" "aws_quickstart_mssql" {
  name                = "${var.prefix}-aws-quickstart-mssql"
  document_type       = "Automation"
  document_format     = "YAML"
content = <<DOC
{
  "schemaVersion": "0.3",
  "description": "Updates AMI with Linux distribution packages and Amazon software. For details,see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/sysman-ami-walkthrough.html",
  "assumeRole": "{{AutomationAssumeRole}}",
  "parameters": {
    "SourceAmiId": {
      "type": "String",
      "description": "(Required) The source Amazon Machine Image ID."
    },
    "SourceAmiParameterName": {
      "type": "String",
      "description": "(Required) The Parameter Store key where the AMI id is stored."
    },
    "SSMAmiLambdaFunctionName": {
      "type": "String",
      "description": "(Required) The Lambda function name that should be triggered at the end of the build."
    },
    "InstanceIamRole": {
      "type": "String",
      "description": "(Required) The name of the role that enables Systems Manager (SSM) to manage the instance.",
      "default": "ManagedInstanceProfile"
    },
    "AutomationAssumeRole": {
      "type": "String",
      "description": "(Required) The ARN of the role that allows Automation to perform the actions on your behalf.",
      "default": "arn:aws:iam::{{global:ACCOUNT_ID}}:role/AutomationServiceRole"
    },
    "TargetAmiName": {
      "type": "String",
      "description": "(Optional) The name of the new AMI that will be created. Default is a system-generated string including the source AMI id, and the creation time and date.",
      "default": "UpdateLinuxAmi_from_{{SourceAmiId}}_on_{{global:DATE_TIME}}"
    },
    "InstanceType": {
      "type": "String",
      "description": "(Optional) Type of instance to launch as the workspace host. Instance types vary by region. Default is t2.micro.",
      "default": "t2.micro"
    },
    "PreUpdateScript": {
      "type": "String",
      "description": "(Optional) URL of a script to run before updates are applied. Default (\"none\") is to not run a script.",
      "default": "none"
    },
    "PostUpdateScript": {
      "type": "String",
      "description": "(Optional) URL of a script to run after package updates are applied. Default (\"none\") is to not run a script.",
      "default": "none"
    },
    "IncludePackages": {
      "type": "String",
      "description": "(Optional) Only update these named packages. By default (\"all\"), all available updates are applied.",
      "default": "all"
    },
    "ExcludePackages": {
      "type": "String",
      "description": "(Optional) Names of packages to hold back from updates, under all conditions. By default (\"none\"), no package is excluded.",
      "default": "none"
    },
    "SSMAutomationUpdateAsg": {
      "type": "String",
      "description": "Lambda function name that updates the ASGs",
      "default": ""
    },
    "targetASG": {
      "type": "String",
      "description": "(Optional) Autoscaling group ARN to update to use the new AMI created",
      "default": ""
    },
    "ApprovalNotificationArn": {
      "type": "String",
      "description": "(Optional) ARN of an SNS topic which to watch for approval requests",
      "default": ""
    }
  },
  "mainSteps": [
    {
      "name": "launchInstance",
      "action": "aws:runInstances",
      "maxAttempts": 3,
      "timeoutSeconds": 1200,
      "onFailure": "Abort",
      "inputs": {
        "ImageId": "{{SourceAmiId}}",
        "InstanceType": "{{InstanceType}}",
        "UserData": "IyEvYmluL2Jhc2gNCg0KZnVuY3Rpb24gZ2V0X2NvbnRlbnRzKCkgew0KICAgIGlmIFsgLXggIiQod2hpY2ggY3VybCkiIF07IHRoZW4NCiAgICAgICAgY3VybCAtcyAtZiAiJDEiDQogICAgZWxpZiBbIC14ICIkKHdoaWNoIHdnZXQpIiBdOyB0aGVuDQogICAgICAgIHdnZXQgIiQxIiAtTyAtDQogICAgZWxzZQ0KICAgICAgICBkaWUgIk5vIGRvd25sb2FkIHV0aWxpdHkgKGN1cmwsIHdnZXQpIg0KICAgIGZpDQp9DQoNCnJlYWRvbmx5IElERU5USVRZX1VSTD0iaHR0cDovLzE2OS4yNTQuMTY5LjI1NC8yMDE2LTA2LTMwL2R5bmFtaWMvaW5zdGFuY2UtaWRlbnRpdHkvZG9jdW1lbnQvIg0KcmVhZG9ubHkgVFJVRV9SRUdJT049JChnZXRfY29udGVudHMgIiRJREVOVElUWV9VUkwiIHwgYXdrIC1GXCIgJy9yZWdpb24vIHsgcHJpbnQgJDQgfScpDQpyZWFkb25seSBERUZBVUxUX1JFR0lPTj0idXMtZWFzdC0xIg0KcmVhZG9ubHkgUkVHSU9OPSIke1RSVUVfUkVHSU9OOi0kREVGQVVMVF9SRUdJT059Ig0KDQpyZWFkb25seSBTQ1JJUFRfTkFNRT0iYXdzLWluc3RhbGwtc3NtLWFnZW50Ig0KIFNDUklQVF9VUkw9Imh0dHBzOi8vYXdzLXNzbS1kb3dubG9hZHMtJFJFR0lPTi5zMy5hbWF6b25hd3MuY29tL3NjcmlwdHMvJFNDUklQVF9OQU1FIg0KDQppZiBbICIkUkVHSU9OIiA9ICJjbi1ub3J0aC0xIiBdOyB0aGVuDQogIFNDUklQVF9VUkw9Imh0dHBzOi8vYXdzLXNzbS1kb3dubG9hZHMtJFJFR0lPTi5zMy5jbi1ub3J0aC0xLmFtYXpvbmF3cy5jb20uY24vc2NyaXB0cy8kU0NSSVBUX05BTUUiDQpmaQ0KDQppZiBbICIkUkVHSU9OIiA9ICJ1cy1nb3Ytd2VzdC0xIiBdOyB0aGVuDQogIFNDUklQVF9VUkw9Imh0dHBzOi8vYXdzLXNzbS1kb3dubG9hZHMtJFJFR0lPTi5zMy11cy1nb3Ytd2VzdC0xLmFtYXpvbmF3cy5jb20vc2NyaXB0cy8kU0NSSVBUX05BTUUiDQpmaQ0KDQpjZCAvdG1wDQpGSUxFX1NJWkU9MA0KTUFYX1JFVFJZX0NPVU5UPTMNClJFVFJZX0NPVU5UPTANCg0Kd2hpbGUgWyAkUkVUUllfQ09VTlQgLWx0ICRNQVhfUkVUUllfQ09VTlQgXSA7IGRvDQogIGVjaG8gQVdTLVVwZGF0ZUxpbnV4QW1pOiBEb3dubG9hZGluZyBzY3JpcHQgZnJvbSAkU0NSSVBUX1VSTA0KICBnZXRfY29udGVudHMgIiRTQ1JJUFRfVVJMIiA+ICIkU0NSSVBUX05BTUUiDQogIEZJTEVfU0laRT0kKGR1IC1rIC90bXAvJFNDUklQVF9OQU1FIHwgY3V0IC1mMSkNCiAgZWNobyBBV1MtVXBkYXRlTGludXhBbWk6IEZpbmlzaGVkIGRvd25sb2FkaW5nIHNjcmlwdCwgc2l6ZTogJEZJTEVfU0laRQ0KICBpZiBbICRGSUxFX1NJWkUgLWd0IDAgXTsgdGhlbg0KICAgIGJyZWFrDQogIGVsc2UNCiAgICBpZiBbWyAkUkVUUllfQ09VTlQgLWx0IE1BWF9SRVRSWV9DT1VOVCBdXTsgdGhlbg0KICAgICAgUkVUUllfQ09VTlQ9JCgoUkVUUllfQ09VTlQrMSkpOw0KICAgICAgZWNobyBBV1MtVXBkYXRlTGludXhBbWk6IEZpbGVTaXplIGlzIDAsIHJldHJ5Q291bnQ6ICRSRVRSWV9DT1VOVA0KICAgIGZpDQogIGZpIA0KZG9uZQ0KDQppZiBbICRGSUxFX1NJWkUgLWd0IDAgXTsgdGhlbg0KICBjaG1vZCAreCAiJFNDUklQVF9OQU1FIg0KICBlY2hvIEFXUy1VcGRhdGVMaW51eEFtaTogUnVubmluZyBVcGRhdGVTU01BZ2VudCBzY3JpcHQgbm93IC4uLi4NCiAgLi8iJFNDUklQVF9OQU1FIiAtLXJlZ2lvbiAiJFJFR0lPTiINCmVsc2UNCiAgZWNobyBBV1MtVXBkYXRlTGludXhBbWk6IFVuYWJsZSB0byBkb3dubG9hZCBzY3JpcHQsIHF1aXR0aW5nIC4uLi4NCmZp",
        "MinInstanceCount": 1,
        "MaxInstanceCount": 1,
        "IamInstanceProfileName": "{{InstanceIamRole}}"
      }
    },
    {
      "name": "updateOSSoftware",
      "action": "aws:runCommand",
      "maxAttempts": 3,
      "timeoutSeconds": 3600,
      "onFailure": "Abort",
      "inputs": {
        "DocumentName": "AWS-RunShellScript",
        "InstanceIds": [
          "{{launchInstance.InstanceIds}}"
        ],
        "Parameters": {
          "commands": [
            "set -e",
            "[ -x \"$(which wget)\" ] && get_contents='wget $1 -O -'",
            "[ -x \"$(which curl)\" ] && get_contents='curl -s -f $1'",
            "eval $get_contents https://aws-ssm-downloads-{{global:REGION}}.s3.amazonaws.com/scripts/aws-update-linux-instance > /tmp/aws-update-linux-instance",
            "chmod +x /tmp/aws-update-linux-instance",
            "/tmp/aws-update-linux-instance --pre-update-script '{{PreUpdateScript}}' --post-update-script '{{PostUpdateScript}}' --include-packages '{{IncludePackages}}' --exclude-packages '{{ExcludePackages}}' 2>&1 | tee /tmp/aws-update-linux-instance.log"
          ]
        }
      }
    },
    {
      "name": "stopInstance",
      "action": "aws:changeInstanceState",
      "maxAttempts": 3,
      "timeoutSeconds": 1200,
      "onFailure": "Abort",
      "inputs": {
        "InstanceIds": [
          "{{launchInstance.InstanceIds}}"
        ],
        "DesiredState": "stopped"
      }
    },
    {
      "name": "createImage",
      "action": "aws:createImage",
      "maxAttempts": 3,
      "onFailure": "Abort",
      "inputs": {
        "InstanceId": "{{launchInstance.InstanceIds}}",
        "ImageName": "{{TargetAmiName}}",
        "NoReboot": true,
        "ImageDescription": "AMI Generated by EC2 Automation on {{global:DATE_TIME}} from {{SourceAmiId}}"
      }
    },
    {
      "name": "terminateInstance",
      "action": "aws:changeInstanceState",
      "maxAttempts": 3,
      "onFailure": "Continue",
      "inputs": {
        "InstanceIds": [
          "{{launchInstance.InstanceIds}}"
        ],
        "DesiredState": "terminated"
      }
    },
    {
         "name":"updateSsmParam",
         "action":"aws:invokeLambdaFunction",
         "timeoutSeconds":1200,
         "maxAttempts":1,
         "onFailure":"Abort",
         "inputs":{
            "FunctionName":"{{SSMAmiLambdaFunctionName}}",
            "Payload":"{\"parameterName\":\"{{SourceAmiParameterName}}\", \"parameterValue\":\"{{createImage.ImageId}}\"}"
         }
      }
      ${local.approval_request},
      {
         "name":"updateASG",
         "action":"aws:invokeLambdaFunction",
         "timeoutSeconds":1200,
         "maxAttempts":1,
         "onFailure":"Abort",
         "inputs": {
            "FunctionName": "{{SSMAutomationUpdateAsg}}",
            "Payload": "{\"targetASG\":\"{{targetASG}}\", \"newAmiID\":\"{{createImage.ImageId}}\"}"
         }
      }
  ],
  "outputs": [
    "createImage.ImageId"
  ]
}
DOC
}

resource "aws_iam_role" "wsfc_role" {
  name = "${var.prefix}-mssql-ssm-automation-role"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  ]
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "wsfc_s3_policy" {
  name = "${var.prefix}-wsfc-s3-policy"
  role = aws_iam_role.wsfc_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
            "arn:aws:s3:::${var.qs_s3_bucket_name}/*",
            "arn:aws:s3:::${var.qs_s3_bucket_name}"
            ]
      },
    ]
  })
}

resource "aws_iam_role_policy" "qs_mssql_ssm_execution" {
  name = "${var.prefix}-qs-mssql-policy"
  role = aws_iam_role.wsfc_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = [
          "${var.admin_secrets_arn}",
          "${var.sql_secrets_arn}"
        ]
      },
      {
        Action = [
          "ssm:StartAutomationExecution"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "wsfc_custom_s3_policy" {
  name = "${var.prefix}-wsfc-custom-s3-policy"
  role = aws_iam_role.wsfc_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = [
            "arn:aws:s3:::aws-ssm-${data.aws_region.current.name}/*",
            "arn:aws:s3:::aws-windows-downloads-${data.aws_region.current.name}/*",
            "arn:aws:s3:::amazon-ssm-${data.aws_region.current.name}/*",
            "arn:aws:s3:::amazon-ssm-packages-${data.aws_region.current.name}/*",
            "arn:aws:s3:::${data.aws_region.current.name}-birdwatcher-prod/*",
            "arn:aws:s3:::patch-baseline-snapshot-${data.aws_region.current.name}/*"
            ]
      },
    ]
  })
}

resource "aws_iam_role_policy" "wsfc_fsx_policy" {
  name = "${var.prefix}-wsfc-fsx-policy"
  role = aws_iam_role.wsfc_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "fsx:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "wsfc_ssm_passrole_policy" {
  name = "${var.prefix}-wsfc-ssm-passrole-policy"
  role = aws_iam_role.wsfc_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iam:PassRole"
        ]
        Effect   = "Allow"
        Resource = "${aws_iam_role.ssm_automation_role.arn}"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "wsfc_role" {
  name = "${var.prefix}-wsfc-role"
  role = aws_iam_role.wsfc_role.name
}
