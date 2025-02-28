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
    "description": "Deploy MSSQL with SSM Automation",
    "assumeRole": "{{AutomationAssumeRole}}",
    "parameters": {
      "ThirdAZ": {
        "default": "no",
        "description": "Enable a 3 AZ deployment, the 3rd AZ can either be used just for the witness, or can be a full SQL cluster node.",
        "type": "String"
      },
      "SQLLicenseProvided": {
        "default": "yes",
        "description": "License SQL Server from AWS Marketplace",
        "type": "String"
      },
      "FSXFileSystemID": {
        "default": "fs-076b4b274a4586c2b",
        "description": "ID of the FSX File System to be used as a cluster witness",
        "type": "String"
      },
      "SQLServerVersion": {
        "default": "2016",
        "description": "Version of SQL Server to install on Failover Cluster Nodes",
        "type": "String"
      },
      "SQLSecrets": {
        "default": "arn:aws:secretsmanager:us-west-2:944706592399:secret:kk-secret-manager-rIELpH",
        "description": "AWS Secrets Parameter Name that has Password and User namer for the SQL Service Account.",
        "type": "String"
      },
      "SQL2017Media": {
        "default": "https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/Install-SQLEE.ps1",
        "description": "SQL Server 2017 installation media location",
        "type": "String"
      },
      "DomainDNSName": {
        "default": "kk.com",
        "description": "Fully qualified domain name (FQDN) of the forest root domain e.g. example.com",
        "type": "String"
      },
      "DomainDNSServer1": {
        "default": "10.49.68.29",
        "description": "DNS Server 1 for the domain",
        "type": "String"
      },
      "DomainDNSServer2": {
        "default": "10.49.69.57",
        "description": "DNS Server 2 for the domain",
        "type": "String"
      },
      "WSFCNode2PrivateIP3": {
        "default": "10.49.69.61",
        "description": "Third private IP for Availability Group Listener on first WSFC Node",
        "type": "String"
      },
      "WSFCNode2NetBIOSName": {
        "default": "sql-dev-2",
        "description": "NetBIOS name of the second WSFC Node (up to 15 characters)",
        "type": "String"
      },
      "AvailabiltyGroupName": {
        "default": "av-gp1",
        "description": "NetBIOS name of the Availablity Group (up to 15 characters)",
        "type": "String"
      },
      "AvailabiltyGroupListenerName": {
        "default": "av-li1",
        "description": "NetBIOS name of the Availablity Group (up to 15 characters)",
        "type": "String"
      },
      "QSS3KeyPrefix": {
        "default": "",
        "description": "S3 key prefix for the Quick Start assets. Quick Start key prefix can include numbers, lowercase letters, uppercase letters, hyphens (-), and forward slash (/).",
        "type": "String"
      },
      "ManagedAD": {
        "default": "Yes",
        "description": "Active Directory being Managed by AWS",
        "type": "String"
      },
      "WSFCNode1NetBIOSName": {
        "default": "sql-dev-1",
        "description": "NetBIOS name of the first WSFC Node (up to 15 characters)",
        "type": "String"
      },
      "ClusterName": {
        "default": "sqcls12",
        "description": "NetBIOS name of the Cluster (up to 15 characters)",
        "type": "String"
      },
      "WitnessType": {
        "default": "Windoes file share",
        "description": "Failover cluster witness type",
        "type": "String"
      },
      "WSFCNode1PrivateIP1": {
        "default": "10.49.69.5",
        "description": "Secondary private IP for WSFC cluster on first WSFC Node",
        "type": "String"
      },
      "WSFCNode1PrivateIP2": {
        "default": "10.49.69.15",
        "description": "Secondary private IP for WSFC cluster on first WSFC Node",
        "type": "String"
      },
      "WSFCNode1PrivateIP3": {
        "default": "10.49.69.30",
        "description": "Third private IP for Availability Group Listener on first WSFC Node",
        "type": "String"
      },
      "AutomationAssumeRole": {
        "default": "",
        "description": "(Optional) The ARN of the role that allows Automation to perform the actions on your behalf.",
        "type": "String"
      },
      "QSS3BucketName": {
        "default": "www.kh-static-pri.net",
        "description": "S3 bucket name for the Quick Start assets. Quick Start bucket name can include numbers, lowercase letters, uppercase letters, and hyphens (-). It cannot start or end with a hyphen (-).",
        "type": "String"
      },
      "DomainNetBIOSName": {
        "default": "kk",
        "description": "NetBIOS name of the domain (up to 15 characters) for users of earlier versions of Windows e.g. EXAMPLE",
        "type": "String"
      },
      "DomainJoinOU": {
        "default": "computers",
        "description": "OU the domain",
        "type": "String"
      },
      "SQL2019Media": {
        "default": "https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/Install-SQLEE.ps1",
        "description": "SQL Server 2019 installation media location",
        "type": "String"
      },
      "WSFCNode2PrivateIP1": {
        "default": "10.49.69.36",
        "description": "Secondary private IP for WSFC cluster on first WSFC Node",
        "type": "String"
      },
      "SQL2016Media": {
        "default": "https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/Install-SQLEE.ps1",
        "description": "SQL Server 2016 installation media location",
        "type": "String"
      },
     
      "WSFCNode2PrivateIP2": {
        "default": "10.49.69.54",
        "description": "Secondary private IP for WSFC cluster on first WSFC Node",
        "type": "String"
      },
      "AdminSecrets": {
        "default": "arn:aws:secretsmanager:us-west-2:944706592399:secret:kk-secret-manager-rIELpH",
        "description": "AWS Secrets Parameter Name that has Password and User name for a domain administrator.",
        "type": "String"
      },
      "SQLAdminGroup": {
        "default": "sql-admin",
        "description": "The AD group name for the sql administrators to be added to sys admin role",
        "type": "String"
      },
      "StackName": {
        "default": "skah",
        "description": "Stack Name Input for cfn resource signal",
        "type": "String"
      },
      "CloudwatchLogGroup": {
        "default": "quickstart",
        "description": "Stack Name Input for cfn resource signal",
        "type": "String"
      }
    },
    "mainSteps": [
      {
        "outputs": [
          {
            "Type": "String",
            "Name": "InstanceId",
            "Selector": "$.Reservations[0].Instances[0].InstanceId"
          }
        ],
        "inputs": {
          "Filters": [
            {
              "Values": [
                "{{WSFCNode1NetBIOSName}}"
              ],
              "Name": "tag:Name"
            },
            {
              "Values": [
                "running"
              ],
              "Name": "instance-state-name"
            }
          ],
          "Service": "ec2",
          "Api": "DescribeInstances"
        },
        "name": "wsfcNode1InstanceId",
        "action": "aws:executeAwsApi",
        "onFailure": "step:sleepend"
      },
      {
        "outputs": [
          {
            "Type": "String",
            "Name": "InstanceId",
            "Selector": "$.Reservations[0].Instances[0].InstanceId"
          }
        ],
        "inputs": {
          "Filters": [
            {
              "Values": [
                "{{WSFCNode2NetBIOSName}}"
              ],
              "Name": "tag:Name"
            },  
            {
              "Values": [
                "running"
              ],
              "Name": "instance-state-name"
            }
          ],
          "Service": "ec2",
          "Api": "DescribeInstances"
        },
        "name": "wsfcNode2InstanceId",
        "action": "aws:executeAwsApi",
        "onFailure": "step:sleepend"
      },
      {
        "outputs": [
          {
            "Type": "StringList",
            "Name": "InstanceIds",
            "Selector": "$.Reservations..Instances..InstanceId"
          }
        ],
        "inputs": {
          "Filters": [
            {
              "Values": [
                "{{WSFCNode1NetBIOSName}}",
                "{{WSFCNode2NetBIOSName}}"
              ],
              "Name": "tag:Name"
            },
   
            {
              "Values": [
                "running"
              ],
              "Name": "instance-state-name"
            }
          ],
          "Service": "ec2",
          "Api": "DescribeInstances"
        },
        "name": "wsfcfInstanceIds",
        "action": "aws:executeAwsApi",
        "onFailure": "step:sleepend"
      },
      {
        "inputs": {
          "Parameters": {
            "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/install-sql-modules.ps1\"}",
            "sourceType": "S3",
            "commandLine": "./install-sql-modules.ps1"
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcfInstanceIds.InstanceIds}}"
          ],
          "DocumentName": "AWS-RunRemoteScript"
        },
        "name": "wsfcfInstallDscModules",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
       {
        "inputs": {
        "Parameters": {
          "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/adduser.ps1\"}",
          "sourceType": "S3",
          "commandLine": "./adduser.ps1 -SQLSecrets {{SQLSecrets}}"
        },
        "CloudWatchOutputConfig": {
          "CloudWatchOutputEnabled": "true",
          "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
        },
        "InstanceIds": [
          "{{wsfcfInstanceIds.InstanceIds}}"
        ],
        "DocumentName": "AWS-RunRemoteScript"
      },
      "name": "addsqluser",
      "action": "aws:runCommand",
      "onFailure": "Abort"
      },
      {
        "inputs": {
        "Parameters": {
          "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/addadminuser.ps1\"}",
          "sourceType": "S3",
          "commandLine": "./addadminuser.ps1 -AdminSecrets {{AdminSecrets}}"
        },
        "CloudWatchOutputConfig": {
          "CloudWatchOutputEnabled": "true",
          "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
        },
        "InstanceIds": [
          "{{wsfcfInstanceIds.InstanceIds}}"
        ],
        "DocumentName": "AWS-RunRemoteScript"
      },
      "name": "addadminuser",
      "action": "aws:runCommand",
      "onFailure": "Abort"
      },
       {
        "inputs": {
        "Parameters": {
          "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/updatednsip.ps1\"}",
          "sourceType": "S3",
          "commandLine": "./updatednsip.ps1 -DomainDNSServer1 {{DomainDNSServer1}} -DomainDNSServer2 {{DomainDNSServer2}}"
        },
        "CloudWatchOutputConfig": {
          "CloudWatchOutputEnabled": "true",
          "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
        },
        "InstanceIds": [
          "{{wsfcfInstanceIds.InstanceIds}}"
        ],
        "DocumentName": "AWS-RunRemoteScript"
      },
      "name": "updatednsip",
      "action": "aws:runCommand",
      "onFailure": "Abort"
      },
      {
        "inputs": {
          "Parameters": {
            "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/LCM-Config.ps1\"}",
            "sourceType": "S3",
            "commandLine": "./LCM-Config.ps1"
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcfInstanceIds.InstanceIds}}"
          ],
          "DocumentName": "AWS-RunRemoteScript"
        },
        "name": "wsfcfLCMConfig",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
      {
        "inputs": {
          "Parameters": {
            "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/DomainJoin.ps1\"}",
            "sourceType": "S3",
            "commandLine": "./DomainJoin.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}} -OU {{DomainJoinOU}}"
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcfInstanceIds.InstanceIds}}"
          ],
          "DocumentName": "AWS-RunRemoteScript"
        },
        "name": "wsfcfDomainJoin",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
      {
        "inputs": {
          "Parameters": {
            "commands": [
              "function DscStatusCheck () {\n    $LCMState = (Get-DscLocalConfigurationManager).LCMState\n    if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {\n        'returning 3010, should continue after reboot'\n        exit 3010\n    } else {\n      'Completed'\n    }\n}\n\nStart-DscConfiguration 'C:\\AWSQuickstart\\DomainJoin' -Wait -Verbose -Force\n\nDscStatusCheck\n"
            ]
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcfInstanceIds.InstanceIds}}"
          ],
          "DocumentName": "AWS-RunPowerShellScript"
        },
        "name": "wsfcfDomainConfig",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
      
      {
        "inputs": {
          "Parameters": {
            "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/Initialize-GPT.ps1\"}",
            "sourceType": "S3",
            "commandLine": "./Initialize-GPT.ps1"
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcfInstanceIds.InstanceIds}}"
          ],
          "DocumentName": "AWS-RunRemoteScript"
        },
        "name": "wsfcnodefInitializeDisk",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
     
      
      {
        "inputs": {
          "Parameters": {
            "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/Node1Config.ps1\"}",
            "sourceType": "S3",
            "commandLine": "./Node1Config.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -WSFCNode1PrivateIP2 {{WSFCNode1PrivateIP2}} -ClusterName {{ClusterName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -FSXFileSystemID {{FSXFileSystemID}}"
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode1InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunRemoteScript"
        },
        "name": "Node1fMof",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend",
        "nextStep": "Node1wConfig"
      },
      {
        "inputs": {
          "Parameters": {
            "commands": [
              "function DscStatusCheck () {\n    $LCMState = (Get-DscLocalConfigurationManager).LCMState\n    if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {\n        'returning 3010, should continue after reboot'\n        exit 3010\n    } else {\n      'Completed'\n    }\n}\n\nStart-DscConfiguration 'C:\\AWSQuickstart\\WSFCNode1Config' -Wait -Verbose -Force\n\nDscStatusCheck\n"
            ]
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode1InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunPowerShellScript"
        },
        "name": "Node1wConfig",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
      {
        "inputs": {
          "Parameters": {
            "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/AdditionalNodeConfig.ps1\"}",
            "sourceType": "S3",
            "commandLine": "./AdditionalNodeConfig.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -WSFCNodePrivateIP2 {{WSFCNode2PrivateIP2}} -ClusterName {{ClusterName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}}"
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode2InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunRemoteScript"
        },
        "name": "Node2Mof",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
      {
        "inputs": {
          "Parameters": {
            "commands": [
              "function DscStatusCheck () {\n    $LCMState = (Get-DscLocalConfigurationManager).LCMState\n    if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {\n        'returning 3010, should continue after reboot'\n        exit 3010\n    } else {\n      'Completed'\n    }\n}\n\nStart-DscConfiguration 'C:\\AWSQuickstart\\AdditionalWSFCNode' -Wait -Verbose -Force\n\nDscStatusCheck\n"
            ]
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode2InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunPowerShellScript"
        },
        "name": "Node2Config",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
      {
        "inputs": {
          "Choices": [
            {
              "StringEquals": "no",
              "Variable": "{{SQLLicenseProvided}}",
              "NextStep": "2NodeDownloadSQL"
            },
            {
              "StringEquals": "yes",
              "Variable": "{{SQLLicenseProvided}}",
              "NextStep": "2NodeReconfigureSQL"
            }
          ]
        },
        "name": "SqlInstallBranch",
        "action": "aws:branch"
      },
      {
        "inputs": {
          "Parameters": {
            "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/DownloadSQLEE.ps1\"}",
            "sourceType": "S3",
            "commandLine": "./DownloadSQLEE.ps1 -SQLServerVersion {{SQLServerVersion}} -SQL2016Media {{SQL2016Media}} -SQL2017Media {{SQL2017Media}} -SQL2019Media {{SQL2019Media}}"
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode1InstanceId.InstanceId}}",
            "{{wsfcNode2InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunRemoteScript"
        },
        "name": "2NodeDownloadSQL",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
      
      
      {
        "inputs": {
          "Parameters": {
            "commands": [
              "$ssms = \"C:\\SQLMedia\\SSMS-Setup-ENU.exe\"\n$ssmsargs = \"/quiet /norestart\"\nStart-Process $ssms $ssmsargs -Wait -ErrorAction Stop\n"
            ]
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode1InstanceId.InstanceId}}",
            "{{wsfcNode2InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunPowerShellScript"
        },
        "name": "2NodeInstallSSMS",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend",
        "nextStep": "CreateAGBranch"
      },
      {
        "inputs": {
          "Parameters": {
            "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/Reconfigure-SQL-DSC.ps1\"}",
            "sourceType": "S3",
            "commandLine": "./Reconfigure-SQL-DSC.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}}"
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode1InstanceId.InstanceId}}",
            "{{wsfcNode2InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunRemoteScript"
        },
        "name": "2NodeReconfigureSQL",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend",
        "nextStep": "CreateAGBranch"
      },
      {
        "inputs": {
          "Choices": [
            {
              "And": [
                {
                  "Not": {
                    "StringEquals": "yes",
                    "Variable": "{{ManagedAD}}"
                  }
                },
                {
                  "Not": {
                    "StringEquals": "full",
                    "Variable": "{{ThirdAZ}}"
                  }
                }
              ],
              "NextStep": "2NodeNoMadPrimaryCreateAG"
            },
            {
              "And": [
                {
                  "StringEquals": "yes",
                  "Variable": "{{ManagedAD}}"
                },
                {
                  "Not": {
                    "StringEquals": "full",
                    "Variable": "{{ThirdAZ}}"
                  }
                }
              ],
              "NextStep": "2NodeMadPrimaryCreateAG"
            }
          ]
        },
        "name": "CreateAGBranch",
        "action": "aws:branch"
      },
      {
        "inputs": {
          "Parameters": {
            "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/CreateAGNode1.ps1\"}",
            "sourceType": "S3",
            "commandLine": "./CreateAGNode1.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -ClusterName {{ClusterName}} -AvailabiltyGroupName {{AvailabiltyGroupName}} -AvailabiltyGroupListenerName {{AvailabiltyGroupListenerName}} -WSFCNode1NetBIOSName {{WSFCNode1NetBIOSName}} -WSFCNode2NetBIOSName {{WSFCNode2NetBIOSName}} -AGListener1PrivateIP1 {{WSFCNode1PrivateIP3}} -AGListener1PrivateIP2 {{WSFCNode2PrivateIP3}}"
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode1InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunRemoteScript"
        },
        "name": "2NodeNoMadPrimaryCreateAG",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
      
      {
        "inputs": {
          "Parameters": {
            "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/CreateAGNode1.ps1\"}",
            "sourceType": "S3",
            "commandLine": "./CreateAGNode1.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -ClusterName {{ClusterName}} -AvailabiltyGroupName {{AvailabiltyGroupName}} -AvailabiltyGroupListenerName {{AvailabiltyGroupListenerName}} -WSFCNode1NetBIOSName {{WSFCNode1NetBIOSName}} -WSFCNode2NetBIOSName {{WSFCNode2NetBIOSName}} -AGListener1PrivateIP1 {{WSFCNode1PrivateIP3}} -AGListener1PrivateIP2 {{WSFCNode2PrivateIP3}} -ManagedAD 'Yes'"
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode1InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunRemoteScript"
        },
        "name": "2NodeMadPrimaryCreateAG",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
      {
        "inputs": {
          "Parameters": {
            "commands": [
              "function DscStatusCheck () {\n    $LCMState = (Get-DscLocalConfigurationManager).LCMState\n    if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {\n        'returning 3010, should continue after reboot'\n        exit 3010\n    } else {\n      'Completed'\n    }\n}\n\nStart-DscConfiguration 'C:\\AWSQuickstart\\AddAG' -Wait -Verbose -Force\n\nDscStatusCheck\n"
            ]
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode1InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunPowerShellScript"
        },
        "name": "2NodeMadPrimaryCreateAGConfig",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend",
        "nextStep": "2NodeAdditionalCreateAG"
      },
      {
        "inputs": {
          "Parameters": {
            "sourceInfo": "{\"path\": \"https://www.kh-static-pri.net.s3.us-west-2.amazonaws.com/AdditionalNodeCreateAG.ps1\"}",
            "sourceType": "S3",
            "commandLine": "./AdditionalNodeCreateAG.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -ClusterName {{ClusterName}} -AvailabiltyGroupName {{AvailabiltyGroupName}} -PrimaryNetBIOSName {{WSFCNode1NetBIOSName}}"
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode2InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunRemoteScript"
        },
        "name": "2NodeAdditionalCreateAG",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend"
      },
      {
        "inputs": {
          "Parameters": {
            "commands": [
              "function DscStatusCheck () {\n    $LCMState = (Get-DscLocalConfigurationManager).LCMState\n    if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {\n        'returning 3010, should continue after reboot'\n        exit 3010\n    } else {\n      'Completed'\n    }\n}\n\nStart-DscConfiguration 'C:\\AWSQuickstart\\AddAG' -Wait -Verbose -Force\n\nDscStatusCheck\n"
            ]
          },
          "CloudWatchOutputConfig": {
            "CloudWatchOutputEnabled": "true",
            "CloudWatchLogGroupName": "{{CloudwatchLogGroup}}"
          },
          "InstanceIds": [
            "{{wsfcNode2InstanceId.InstanceId}}"
          ],
          "DocumentName": "AWS-RunPowerShellScript"
        },
        "name": "2NodeAdditionalCreateAGConfig",
        "action": "aws:runCommand",
        "onFailure": "step:sleepend",
        "nextStep": "CFNSignalEnd"
      },
      {
        "inputs": {
          "Choices": [
            {
              "Not": {
                "StringEquals": "",
                "Variable": "{{StackName}}"
              },
              "NextStep": "sleepend"
            },
            {
              "StringEquals": "",
              "Variable": "{{StackName}}",
              "NextStep": "sleepend"
            }
          ]
        },
        "name": "CFNSignalEnd",
        "action": "aws:branch"
      },
      {
        "inputs": {
          "Duration": "PT1S"
        },
        "name": "sleepend",
        "action": "aws:sleep",
        "isEnd": true
      }
    ]
}
DOC
}

resource "aws_iam_role" "wsfc_role" {
  name = "${var.prefix}-mssql-ssm-automation-role"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AdministratorAccess"
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
