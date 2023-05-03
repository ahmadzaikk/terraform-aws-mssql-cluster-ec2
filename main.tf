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
   schemaVersion: "0.3"
        description: Deploy MSSQL with SSM Automation
        # Role that is utilized to perform the steps within the Automation Document.
        assumeRole: "{{AutomationAssumeRole}}"
        # Gathering parameters needed to configure DCs in the Quick Start
        parameters:
          SQLServerVersion:
            default: "2017"
            description: "Version of SQL Server to install on Failover Cluster Nodes"
            type: "String"
          SQLLicenseProvided:
            default: "yes"
            description: "License SQL Server from AWS Marketplace"
            type: "String"
          SQL2016Media:
            description: "SQL Server 2016 installation media location"
            type: "String"
          SQL2017Media:
            description: "SQL Server 2017 installation media location"
            type: "String"
          SQL2019Media:
            description: "SQL Server 2019 installation media location"
            type: "String"
          URLSuffix:
            description: "AWS URL suffix"
            type: "String"
          WSFCNode1NetBIOSName:
            default: "WSFCNode1"
            description: "NetBIOS name of the first WSFC Node (up to 15 characters)"
            type: "String"
          WSFCNode1PrivateIP2:
            default: "10.0.0.101"
            description: "Secondary private IP for WSFC cluster on first WSFC Node"
            type: "String"
          WSFCNode1PrivateIP3:
            default: "10.0.0.102"
            description: "Third private IP for Availability Group Listener on first WSFC Node"
            type: "String"
          WSFCNode2NetBIOSName:
            default: "WSFCNode2"
            description: "NetBIOS name of the second WSFC Node (up to 15 characters)"
            type: "String"
          WSFCNode2PrivateIP2:
            default: "10.0.32.101"
            description: "Secondary private IP for WSFC cluster on first WSFC Node"
            type: "String"
          WSFCNode2PrivateIP3:
            default: "10.0.32.102"
            description: "Third private IP for Availability Group Listener on first WSFC Node"
            type: "String"
          FSXFileSystemID:
            default: ""
            description: "ID of the FSX File System to be used as a cluster witness"
            type: "String"
          WSFCNode3NetBIOSName:
            default: "WSFCNode3"
            description: "NetBIOS name of the third WSFC Node (up to 15 characters)"
            type: "String"
          WSFCNode3PrivateIP2:
            default: "10.0.64.101"
            description: "Fixed private IP for the first Active Directory server located in Availability Zone 1"
            type: "String"
          WSFCNode3PrivateIP3:
            default: "10.0.64.102"
            description: "Third private IP for Availability Group Listener on first WSFC Node"
            type: "String"
          WSFCFileServerNetBIOSName:
            default: "WSFCFileServer"
            description: "NetBIOS name of the WSFCFileServer (up to 15 characters)"
            type: "String"
          ClusterName:
            default: "WSFCCluster1"
            description: "NetBIOS name of the Cluster (up to 15 characters)"
            type: "String"
          AvailabiltyGroupName:
            default: "SQLAG1"
            description: "NetBIOS name of the Availablity Group (up to 15 characters)"
            type: "String"
          ThirdAZ: 
            default: "no"
            description: "Enable a 3 AZ deployment, the 3rd AZ can either be used just for the witness, or can be a full SQL cluster node."
            type: "String"
          DomainDNSName: 
            default: "example.com"
            description: "Fully qualified domain name (FQDN) of the forest root domain e.g. example.com"
            type: "String"
          DomainNetBIOSName: 
            default: "example"
            description: "NetBIOS name of the domain (up to 15 characters) for users of earlier versions of Windows e.g. EXAMPLE"
            type: "String"
          ManagedAD:
            default: "No"
            description: "Active Directory being Managed by AWS"
            type: "String"
          AdminSecrets:
            description: "AWS Secrets Parameter Name that has Password and User name for a domain administrator."
            type: "String"
          SQLSecrets:
            description: "AWS Secrets Parameter Name that has Password and User namer for the SQL Service Account."
            type: "String"
          QSS3BucketName:
            default: "aws-quickstart"
            description: "S3 bucket name for the Quick Start assets. Quick Start bucket name can include numbers, lowercase letters, uppercase letters, and hyphens (-). It cannot start or end with a hyphen (-)."
            type: "String"
          QSS3KeyPrefix:
            default: "quickstart-microsoft-sql/"
            description: "S3 key prefix for the Quick Start assets. Quick Start key prefix can include numbers, lowercase letters, uppercase letters, hyphens (-), and forward slash (/)."
            type: "String"
          StackName:
            default: ""
            description: "Stack Name Input for cfn resource signal"
            type: "String"
          AutomationAssumeRole:
            default: ""
            description: "(Optional) The ARN of the role that allows Automation to perform the actions on your behalf."
            type: "String"
          WitnessType:
            default: "Windoes file share"
            description: "Failover cluster witness type"
            type: "String"
        mainSteps:
        - name: "wsfcNode1InstanceId"
          action: aws:executeAwsApi
          onFailure: "step:signalfailure"
          inputs:
            Service: ec2
            Api: DescribeInstances
            Filters:  
            - Name: "tag:Name"
              Values: ["{{WSFCNode1NetBIOSName}}"]
            - Name: "tag:aws:cloudformation:stack-name"
              Values: ["{{StackName}}"]
            - Name: "instance-state-name"
              Values: [ "running" ]
          outputs:
          - Name: InstanceId
            Selector: "$.Reservations[0].Instances[0].InstanceId"
            Type: String
        - name: "wsfcNode2InstanceId"
          action: aws:executeAwsApi
          onFailure: "step:signalfailure"
          inputs:
            Service: ec2
            Api: DescribeInstances
            Filters:  
            - Name: "tag:Name"
              Values: ["{{WSFCNode2NetBIOSName}}"]
            - Name: "tag:aws:cloudformation:stack-name"
              Values: ["{{StackName}}"]
            - Name: "instance-state-name"
              Values: [ "running" ]
          outputs:
          - Name: InstanceId
            Selector: "$.Reservations[0].Instances[0].InstanceId"
            Type: String
        - name: InstanceIdBranch
          action: aws:branch
          inputs:
            Choices:
            - Or:
              - Variable: "{{ThirdAZ}}"
                StringEquals: "no"
              - Variable: "{{ThirdAZ}}"
                StringEquals: "witness"
              NextStep: FSxBranch
            - Variable: "{{ThirdAZ}}"
              StringEquals: "full"
              NextStep: wsfcNode3InstanceId
        - name: "wsfcNode3InstanceId"
          action: aws:executeAwsApi
          onFailure: "step:signalfailure"
          inputs:
            Service: ec2
            Api: DescribeInstances
            Filters:  
            - Name: "tag:Name"
              Values: ["{{WSFCNode3NetBIOSName}}"]
            - Name: "tag:aws:cloudformation:stack-name"
              Values: ["{{StackName}}"]
            - Name: "instance-state-name"
              Values: [ "running" ]
          outputs:
          - Name: InstanceId
            Selector: "$.Reservations[0].Instances[0].InstanceId"
            Type: "String"
        - name: "wsfcnInstanceIds"
          action: aws:executeAwsApi
          onFailure: "step:signalfailure"
          inputs:
            Service: ec2
            Api: DescribeInstances
            Filters:  
            - Name: "tag:Name"
              Values: [ "{{WSFCNode1NetBIOSName}}","{{WSFCNode2NetBIOSName}}", "{{WSFCNode3NetBIOSName}}"]
            - Name: "tag:aws:cloudformation:stack-name"
              Values: ["{{StackName}}"]
            - Name: "instance-state-name"
              Values: [ "running" ]
          outputs:
          - Name: InstanceIds
            Selector: "$.Reservations..Instances..InstanceId"
            Type: "StringList"
        - name: "wsfcnInstallDscModules"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
            - "{{wsfcnInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo:
                !Sub
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/install-sql-modules.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./install-sql-modules.ps1"
        - name: "wsfcnInitializeDisk"
          action: "aws:runCommand"
          onFailure: "step:signalfailure" 
          inputs:
            DocumentName: AWS-RunRemoteScript
            InstanceIds: 
              - "{{wsfcnInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
            Parameters:
              sourceType: "S3"
              sourceInfo:
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/Initialize-GPT.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./Initialize-GPT.ps1"
        - name: "wsfcnLCMConfig"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
            - "{{wsfcnInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/LCM-Config.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./LCM-Config.ps1"
        - name: "wsfcnDomainJoin"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcnInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/DomainJoin.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./DomainJoin.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}}"
        - name: "wsfcnDomainConfig"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcnInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\DomainJoin' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: "Node1nMof"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          #nextStep: 
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/Node1Config.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./Node1Config.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -WSFCNode1PrivateIP2 {{WSFCNode1PrivateIP2}} -ClusterName {{ClusterName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}}"
        - name: "Node1nConfig"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          nextStep: "Node2Mof"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\WSFCNode1Config' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: FSxBranch
          action: aws:branch
          inputs:
            Choices:
            - Variable: "{{WitnessType}}"
              StringEquals: "Windows file share"
              NextStep: wsfcFileServerInstanceId
            - Variable: "{{WitnessType}}"
              StringEquals: "FSx"
              NextStep: wsfcfInstanceIds
        - name: "wsfcFileServerInstanceId"
          action: aws:executeAwsApi
          onFailure: "step:signalfailure"
          inputs:
            Service: ec2
            Api: DescribeInstances
            Filters:  
            - Name: "tag:Name"
              Values: ["{{WSFCFileServerNetBIOSName}}"]
            - Name: "tag:aws:cloudformation:stack-name"
              Values: ["{{StackName}}"]
            - Name: "instance-state-name"
              Values: [ "running" ]
          outputs:
          - Name: InstanceId
            Selector: "$.Reservations[0].Instances[0].InstanceId"
            Type: "String"
        - name: "wsfcwInstanceIds"
          action: aws:executeAwsApi
          onFailure: "step:signalfailure"
          inputs:
            Service: ec2
            Api: DescribeInstances
            Filters:  
            - Name: "tag:Name"
              Values: [ "{{WSFCNode1NetBIOSName}}","{{WSFCNode2NetBIOSName}}", "{{WSFCFileServerNetBIOSName}}"]
            - Name: "tag:aws:cloudformation:stack-name"
              Values: ["{{StackName}}"]
            - Name: "instance-state-name"
              Values: [ "running" ]
          outputs:
          - Name: InstanceIds
            Selector: "$.Reservations..Instances..InstanceId"
            Type: "StringList"
        - name: "wsfcwInstallDscModules"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
            - "{{wsfcwInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/install-sql-modules.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./install-sql-modules.ps1"
        - name: "wsfcnodewInitializeDisk"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunRemoteScript
            InstanceIds: 
              - "{{wsfcNode1InstanceId.InstanceId}}"
              - "{{wsfcNode2InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/Initialize-GPT.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./Initialize-GPT.ps1"
        - name: "wsfcwLCMConfig"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
            - "{{wsfcwInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/LCM-Config.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./LCM-Config.ps1"
        - name: "wsfcwDomainJoin"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcwInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/DomainJoin.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./DomainJoin.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}}"
        - name: "wsfcwDomainConfig"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcwInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\DomainJoin' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: "wsfcFileServerConfig"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcFileServerInstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/WSFCFileShare.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./WSFCFileShare.ps1"
        - name: "Node1wMof"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          nextStep: Node1wConfig
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/Node1Config.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./Node1Config.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -WSFCNode1PrivateIP2 {{WSFCNode1PrivateIP2}} -ClusterName {{ClusterName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -FileServerNetBIOSName {{WSFCFileServerNetBIOSName}}"
        - name: "wsfcfInstanceIds"
          action: aws:executeAwsApi
          onFailure: "step:signalfailure"
          inputs:
            Service: ec2
            Api: DescribeInstances
            Filters:  
            - Name: "tag:Name"
              Values: [ "{{WSFCNode1NetBIOSName}}","{{WSFCNode2NetBIOSName}}"]
            - Name: "tag:aws:cloudformation:stack-name"
              Values: ["{{StackName}}"]
            - Name: "instance-state-name"
              Values: [ "running" ]
          outputs:
          - Name: InstanceIds
            Selector: "$.Reservations..Instances..InstanceId"
            Type: "StringList"
        - name: "wsfcfInstallDscModules"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
            - "{{wsfcfInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/install-sql-modules.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./install-sql-modules.ps1"
        - name: "wsfcnodefInitializeDisk"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunRemoteScript
            InstanceIds: 
            - "{{wsfcfInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/Initialize-GPT.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./Initialize-GPT.ps1"
        - name: "wsfcfLCMConfig"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
            - "{{wsfcfInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/LCM-Config.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./LCM-Config.ps1"
        - name: "wsfcfDomainJoin"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
            - "{{wsfcfInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/DomainJoin.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./DomainJoin.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}}"
        - name: "wsfcfDomainConfig"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
            - "{{wsfcfInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\DomainJoin' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: "Node1fMof"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          nextStep: Node1wConfig
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/Node1Config.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./Node1Config.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -WSFCNode1PrivateIP2 {{WSFCNode1PrivateIP2}} -ClusterName {{ClusterName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -FSXFileSystemID {{FSXFileSystemID}}"
        - name: "Node1wConfig"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\WSFCNode1Config' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: "Node2Mof"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode2InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/AdditionalNodeConfig.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./AdditionalNodeConfig.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -WSFCNodePrivateIP2 {{WSFCNode2PrivateIP2}} -ClusterName {{ClusterName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}}"
        - name: "Node2Config"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode2InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\AdditionalWSFCNode' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: 3AZFullBranch
          action: aws:branch
          inputs:
            Choices:
            - Or:
              - Variable: "{{ThirdAZ}}"
                StringEquals: "no"
              - Variable: "{{ThirdAZ}}"
                StringEquals: "witness"
              NextStep: SqlInstallBranch
            - Variable: "{{ThirdAZ}}"
              StringEquals: "full"
              NextStep: Node3Mof
        - name: "Node3Mof"
          action: "aws:runCommand"
          onFailure: "step:signalfailure" 
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode3InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/AdditionalNodeConfig.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./AdditionalNodeConfig.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -WSFCNodePrivateIP2 {{WSFCNode3PrivateIP2}} -ClusterName {{ClusterName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}}"
        - name: "Node3Config"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode3InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\AdditionalWSFCNode' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: SqlInstallBranch
          action: aws:branch
          inputs:
            Choices:
            - Variable: "{{SQLLicenseProvided}}"
              StringEquals: "no"
              NextStep: NodesSqlInstallBranch
            - Variable: "{{SQLLicenseProvided}}"
              StringEquals: "yes"
              NextStep: NodesReconfigureSQLBranch
        - name: NodesSqlInstallBranch
          action: aws:branch
          inputs:
            Choices:
            - Or:
              - Variable: "{{ThirdAZ}}"
                StringEquals: "no"
              - Variable: "{{ThirdAZ}}"
                StringEquals: "witness"
              NextStep: 2NodeDownloadSQL
            - Variable: "{{ThirdAZ}}"
              StringEquals: "full"
              NextStep: 3NodeDownloadSQL
        - name: "2NodeDownloadSQL"
          action: "aws:runCommand"
          onFailure: "step:signalfailure" 
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode1InstanceId.InstanceId}}"
              - "{{wsfcNode2InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/DownloadSQLEE.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./DownloadSQLEE.ps1 -SQLServerVersion {{SQLServerVersion}} -SQL2016Media {{SQL2016Media}} -SQL2017Media {{SQL2017Media}} -SQL2019Media {{SQL2019Media}}"
        - name: "2NodeSQLInstallMOF"
          action: "aws:runCommand"
          onFailure: "step:signalfailure" 
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode1InstanceId.InstanceId}}"
              - "{{wsfcNode2InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/Install-SQLEE.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./Install-SQLEE.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}} -SQLServerVersion {{SQLServerVersion}} -SQLSecret {{SQLSecrets}}"
        - name: "2NodeSQLInstall"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode1InstanceId.InstanceId}}"
              - "{{wsfcNode2InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\SQLInstall' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: "2NodeInstallSSMS"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          nextStep: "CreateAGBranch"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode1InstanceId.InstanceId}}"
              - "{{wsfcNode2InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |
                   $ssms = "C:\SQLMedia\SSMS-Setup-ENU.exe"
                   $ssmsargs = "/quiet /norestart"
                   Start-Process $ssms $ssmsargs -Wait -ErrorAction Stop
        - name: "3NodeDownloadSQL"
          action: "aws:runCommand"
          onFailure: "step:signalfailure" 
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcnInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/DownloadSQLEE.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./DownloadSQLEE.ps1 -SQLServerVersion {{SQLServerVersion}} -SQL2016Media {{SQL2016Media}} -SQL2017Media {{SQL2017Media}} -SQL2019Media {{SQL2019Media}}"
        - name: "3NodeSQLInstallMOF"
          action: "aws:runCommand"
          onFailure: "step:signalfailure" 
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcnInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/Install-SQLEE.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./Install-SQLEE.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}} -SQLServerVersion {{SQLServerVersion}} -SQLSecret {{SQLSecrets}}"
        - name: "3NodeSQLInstall"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcnInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\SQLInstall' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: "3NodeInstallSSMS"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          nextStep: "CreateAGBranch"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcnInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |
                   $ssms = "C:\sqlinstall\SSMS-Setup-ENU.exe"
                   $ssmsargs = "/quiet /norestart"
                   Start-Process $ssms $ssmsargs -Wait -ErrorAction Stop
        - name: NodesReconfigureSQLBranch
          action: aws:branch
          inputs:
            Choices:
            - Or:
              - Variable: "{{ThirdAZ}}"
                StringEquals: "no"
              - Variable: "{{ThirdAZ}}"
                StringEquals: "witness"
              NextStep: 2NodeReconfigureSQL
            - Variable: "{{ThirdAZ}}"
              StringEquals: "full"
              NextStep: 3NodeReconfigureSQL
        - name: "2NodeReconfigureSQL"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          nextStep: "CreateAGBranch" 
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode1InstanceId.InstanceId}}"
              - "{{wsfcNode2InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/Reconfigure-SQL-DSC.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./Reconfigure-SQL-DSC.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}}"
        - name: "3NodeReconfigureSQL"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          nextStep: "CreateAGBranch" 
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcnInstanceIds.InstanceIds}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/Reconfigure-SQL-DSC.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./Reconfigure-SQL-DSC.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}}"
        - name: CreateAGBranch
          action: aws:branch
          inputs:
            Choices:
            - And:
              - Not:
                  Variable: "{{ManagedAD}}"
                  StringEquals: "yes"
              - Not:
                  Variable: "{{ThirdAZ}}"
                  StringEquals: "full"
              NextStep: 2NodeNoMadPrimaryCreateAG
            - And:
              - Variable: "{{ManagedAD}}"
                StringEquals: "yes"
              - Not:
                  Variable: "{{ThirdAZ}}"
                  StringEquals: "full"
              NextStep: 2NodeMadPrimaryCreateAG
            - And:
              - Not:
                  Variable: "{{ManagedAD}}"
                  StringEquals: "yes"
              - Variable: "{{ThirdAZ}}"
                StringEquals: "full"
              NextStep: 3NodeNoMadPrimaryCreateAG
            - And:
              - Variable: "{{ManagedAD}}"
                StringEquals: "yes"
              - Variable: "{{ThirdAZ}}"
                StringEquals: "full"
              NextStep: 3NodeMadPrimaryCreateAG
        - name: "2NodeNoMadPrimaryCreateAG"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/CreateAGNode1.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./CreateAGNode1.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -ClusterName {{ClusterName}} -AvailabiltyGroupName {{AvailabiltyGroupName}} -WSFCNode1NetBIOSName {{WSFCNode1NetBIOSName}} -WSFCNode2NetBIOSName {{WSFCNode2NetBIOSName}} -AGListener1PrivateIP1 {{WSFCNode1PrivateIP3}} -AGListener1PrivateIP2 {{WSFCNode2PrivateIP3}}"
        - name: "2NodeNoMadPrimaryCreateAGConfig"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          nextStep: "AdditionalCreateAGBranch"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\AddAG' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: "2NodeMadPrimaryCreateAG"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/CreateAGNode1.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./CreateAGNode1.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -ClusterName {{ClusterName}} -AvailabiltyGroupName {{AvailabiltyGroupName}} -WSFCNode1NetBIOSName {{WSFCNode1NetBIOSName}} -WSFCNode2NetBIOSName {{WSFCNode2NetBIOSName}} -AGListener1PrivateIP1 {{WSFCNode1PrivateIP3}} -AGListener1PrivateIP2 {{WSFCNode2PrivateIP3}} -ManagedAD 'Yes'"
        - name: "2NodeMadPrimaryCreateAGConfig"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          nextStep: "AdditionalCreateAGBranch"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\AddAG' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: "3NodeNoMadPrimaryCreateAG"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/CreateAGNode1.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./CreateAGNode1.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -ClusterName {{ClusterName}} -AvailabiltyGroupName {{AvailabiltyGroupName}} -WSFCNode1NetBIOSName {{WSFCNode1NetBIOSName}} -WSFCNode2NetBIOSName {{WSFCNode2NetBIOSName}} -AGListener1PrivateIP1 {{WSFCNode1PrivateIP3}} -AGListener1PrivateIP2 {{WSFCNode2PrivateIP3}} -WSFCNode3NetBIOSName {{WSFCNode3NetBIOSName}} -AGListener1PrivateIP3 {{WSFCNode3PrivateIP3}}"
        - name: "3NodeNoMadPrimaryCreateAGConfig"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          nextStep: "AdditionalCreateAGBranch"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\AddAG' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: "3NodeMadPrimaryCreateAG"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/CreateAGNode1.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./CreateAGNode1.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -DomainDNSName {{DomainDNSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -ClusterName {{ClusterName}} -AvailabiltyGroupName {{AvailabiltyGroupName}} -WSFCNode1NetBIOSName {{WSFCNode1NetBIOSName}} -WSFCNode2NetBIOSName {{WSFCNode2NetBIOSName}} -AGListener1PrivateIP1 {{WSFCNode1PrivateIP3}} -AGListener1PrivateIP2 {{WSFCNode2PrivateIP3}} -WSFCNode3NetBIOSName {{WSFCNode3NetBIOSName}} -AGListener1PrivateIP3 {{WSFCNode3PrivateIP3}} -ManagedAD 'Yes'"
        - name: "3NodeMadPrimaryCreateAGConfig"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode1InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\AddAG' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: AdditionalCreateAGBranch
          action: aws:branch
          inputs:
            Choices:
            - Or:
              - Variable: "{{ThirdAZ}}"
                StringEquals: "no"
              - Variable: "{{ThirdAZ}}"
                StringEquals: "witness"
              NextStep: 2NodeAdditionalCreateAG
            - Variable: "{{ThirdAZ}}"
              StringEquals: "full"
              NextStep: 3NodeAdditionalCreateAG
        - name: "2NodeAdditionalCreateAG"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode2InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/AdditionalNodeCreateAG.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./AdditionalNodeCreateAG.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -ClusterName {{ClusterName}} -AvailabiltyGroupName {{AvailabiltyGroupName}} -PrimaryNetBIOSName {{WSFCNode1NetBIOSName}}"
        - name: "2NodeAdditionalCreateAGConfig"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          nextStep: "CFNSignalEnd"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode2InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\AddAG' -Wait -Verbose -Force
        
                   DscStatusCheck
        - name: "3NodeAdditionalCreateAG"
          action: "aws:runCommand"
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: "AWS-RunRemoteScript"
            InstanceIds:
              - "{{wsfcNode2InstanceId.InstanceId}}"
              - "{{wsfcNode3InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              sourceType: "S3"
              sourceInfo: 
                !Sub 
                  - '{"path": "https://${S3Bucket}.s3.${S3Region}.{{URLSuffix}}/{{QSS3KeyPrefix}}scripts/AdditionalNodeCreateAG.ps1"}'
                  - S3Bucket: !If 
                      - UsingDefaultBucket
                      - !Sub '${QSS3BucketName}-${AWS::Region}'
                      - !Ref QSS3BucketName
                    S3Region: !If 
                      - UsingDefaultBucket
                      - !Ref AWS::Region
                      - !Ref QSS3BucketRegion
              commandLine: "./AdditionalNodeCreateAG.ps1 -DomainNetBIOSName {{DomainNetBIOSName}} -AdminSecret {{AdminSecrets}} -SQLSecret {{SQLSecrets}} -ClusterName {{ClusterName}} -AvailabiltyGroupName {{AvailabiltyGroupName}} -PrimaryNetBIOSName {{WSFCNode1NetBIOSName}}"
        - name: "3NodeAdditionalCreateAGConfig"
          action: aws:runCommand
          onFailure: "step:signalfailure"
          inputs:
            DocumentName: AWS-RunPowerShellScript
            InstanceIds: 
              - "{{wsfcNode2InstanceId.InstanceId}}"
              - "{{wsfcNode3InstanceId.InstanceId}}"
            CloudWatchOutputConfig:
              CloudWatchOutputEnabled: "true"
              CloudWatchLogGroupName: !Sub '/aws/Quick_Start/${AWS::StackName}'
            Parameters:
              commands: 
                - |     
                   function DscStatusCheck () {
                       $LCMState = (Get-DscLocalConfigurationManager).LCMState
                       if ($LCMState -eq 'PendingConfiguration' -Or $LCMState -eq 'PendingReboot') {
                           'returning 3010, should continue after reboot'
                           exit 3010
                       } else {
                         'Completed'
                       }
                   }
                   
                   Start-DscConfiguration 'C:\AWSQuickstart\AddAG' -Wait -Verbose -Force
        
                   DscStatusCheck
        # Determines if CFN Needs to be Signaled or if Work flow should just end
        - name: CFNSignalEnd
          action: aws:branch
          inputs:
            Choices:
            - NextStep: signalsuccess
              Not: 
                Variable: "{{StackName}}"
                StringEquals: ""
            - NextStep: sleepend
              Variable: "{{StackName}}"
              StringEquals: ""
        # If all steps complete successfully signals CFN of Success
        - name: "signalsuccess"
          action: "aws:executeAwsApi"
          isEnd: True
          inputs:
            Service: cloudformation
            Api: SignalResource
            LogicalResourceId: "SSMWaitCondition"
            StackName: "{{StackName}}"
            Status: SUCCESS
            UniqueId: "{{wsfcNode2InstanceId.InstanceId}}"
        # If CFN Signl Not Needed this sleep ends work flow
        - name: "sleepend"
          action: "aws:sleep"
          isEnd: True
          inputs:
            Duration: PT1S
        # If any steps fails signals CFN of Failure
        - name: "signalfailure"
          action: "aws:executeAwsApi"
          inputs:
            Service: cloudformation
            Api: SignalResource
            LogicalResourceId: "SSMWaitCondition"
            StackName: "{{StackName}}"
            Status: FAILURE
            UniqueId: "{{wsfcNode2InstanceId.InstanceId}}"
  MSSQLSSMPassRolePolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: MSSQL-SSM-PassRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Action:
              - iam:PassRole
            Resource: !Sub 'arn:${AWS::Partition}:iam::${AWS::AccountId}:role/${AWSQuickstartMSSQLRole}'
      Roles:
        - !Ref 'AWSQuickstartMSSQLRole'
  WSFCRole:
    Type: AWS::IAM::Role
    Metadata:
      cfn-lint:
        config:
          ignore_checks:
            - EIAMPolicyActionWildcard
            - EIAMPolicyWildcardResource
    Properties:
      Policies:
        - PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Action:
                  - s3:GetObject
                  - s3:GetBucketLocation
                  - s3:ListBucket
                Resource:
                  - !Sub ['arn:${AWS::Partition}:s3:::${S3Bucket}/${QSS3KeyPrefix}*', S3Bucket: !If [UsingDefaultBucket, !Sub '${QSS3BucketName}-${AWS::Region}', !Ref QSS3BucketName]]
                  - !Sub ['arn:${AWS::Partition}:s3:::${S3Bucket}', S3Bucket: !If [UsingDefaultBucket, !Sub '${QSS3BucketName}-${AWS::Region}', !Ref QSS3BucketName]]
                Effect: Allow
          PolicyName: aws-quick-start-s3-policy
        - PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Action:
                  - s3:GetObject
                Resource: 
                  - !Sub 'arn:${AWS::Partition}:s3:::aws-ssm-${AWS::Region}/*'
                  - !Sub 'arn:${AWS::Partition}:s3:::aws-windows-downloads-${AWS::Region}/*'
                  - !Sub 'arn:${AWS::Partition}:s3:::amazon-ssm-${AWS::Region}/*'
                  - !Sub 'arn:${AWS::Partition}:s3:::amazon-ssm-packages-${AWS::Region}/*'
                  - !Sub 'arn:${AWS::Partition}:s3:::${AWS::Region}-birdwatcher-prod/*'
                  - !Sub 'arn:${AWS::Partition}:s3:::patch-baseline-snapshot-${AWS::Region}/*'
                Effect: Allow
          PolicyName: ssm-custom-s3-policy
        - PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - secretsmanager:GetSecretValue
                  - secretsmanager:DescribeSecret
                Resource: 
                  - !Ref 'SQLSecrets'
                  - !Ref 'ADAdminSecrets'
              - Effect: Allow
                Action:
                  - ssm:StartAutomationExecution
                Resource: '*'
          PolicyName: QS-MSSQL-SSM
        - PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action: fsx:*
                Resource: '*'
          PolicyName: QS-MSSQL-FSX
        - PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - iam:PassRole
                Resource: !Sub 'arn:${AWS::Partition}:iam::${AWS::AccountId}:role/${AWSQuickstartMSSQLRole}'
          PolicyName: QS-MSSQL-SSM-PassRole
      Path: /
      ManagedPolicyArns:
        - !Sub 'arn:${AWS::Partition}:iam::aws:policy/AmazonSSMManagedInstanceCore'
        - !Sub 'arn:${AWS::Partition}:iam::aws:policy/CloudWatchAgentServerPolicy'
        - !Sub 'arn:${AWS::Partition}:iam::aws:policy/AmazonEC2ReadOnlyAccess'
      AssumeRolePolicyDocument:
        Statement:
          - Action:
              - sts:AssumeRole
            Principal:
              Service:
                - ec2.amazonaws.com
                - ssm.amazonaws.com
            Effect: Allow
        Version: '2012-10-17'
  WSFCProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref 'WSFCRole'
      Path: /
  WSFCFileServer:
    Type: AWS::EC2::Instance
    Condition: IsTwoNode
    Properties:
      ImageId: !Ref WS2019FULLBASE
      IamInstanceProfile: !Ref 'WSFCProfile'
      InstanceType: !Ref 'WSFCFileServerInstanceType'
      NetworkInterfaces:
        - DeleteOnTermination: true
          DeviceIndex: '0'
          SubnetId: !If
            - ThirdAzIsWitness
            - !Ref 'PrivateSubnet3ID'
            - !Ref 'PrivateSubnet1ID'
          PrivateIpAddresses:
            - Primary: true
              PrivateIpAddress: !Ref 'WSFCFileServerPrivateIP'
          GroupSet:
            - !Ref 'DomainMemberSGID'
            - !Ref 'WSFCSecurityGroup'
            - !Ref 'WSFCClientSecurityGroup'
      Tags:
        - Key: Name
          Value: !Ref 'WSFCFileServerNetBIOSName'
      BlockDeviceMappings:
        - DeviceName: /dev/sda1
          Ebs:
            VolumeSize: 100
            VolumeType: gp2
            Encrypted: true
      KeyName: !Ref 'KeyPairName'
  WSFCNode1:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: !If
        - SQLBakedInAMI
        - !If
            - 'SQLVersion2016'
            - !Ref WS2019FULLSQL2016ENT
            - !If
              - 'SQLVersion2017'
              - !Ref WS2019FULLSQL2017ENT
              - !Ref WS2019FULLSQL2019ENT
        - !Ref WS2019FULLBASE
      IamInstanceProfile: !Ref 'WSFCProfile'
      InstanceType: !Ref 'WSFCNode1InstanceType'
      EbsOptimized: true
      NetworkInterfaces:
        - DeleteOnTermination: true
          DeviceIndex: '0'
          SubnetId: !Ref 'PrivateSubnet1ID'
          PrivateIpAddresses:
            - Primary: true
              PrivateIpAddress: !Ref 'WSFCNode1PrivateIP1'
            - Primary: false
              PrivateIpAddress: !Ref 'WSFCNode1PrivateIP2'
            - Primary: false
              PrivateIpAddress: !Ref 'WSFCNode1PrivateIP3'
          GroupSet:
            - !Ref 'DomainMemberSGID'
            - !Ref 'WSFCSecurityGroup'
            - !Ref 'WSFCClientSecurityGroup'
      Tags:
        - Key: Name
          Value: !Ref 'WSFCNode1NetBIOSName'
      BlockDeviceMappings:
        - DeviceName: /dev/sda1
          Ebs:
            VolumeSize: 100
            VolumeType: gp2
            Encrypted: true
        - DeviceName: /dev/xvdca
          VirtualName: ephemeral0
      KeyName: !Ref 'KeyPairName'
  WSFCNode3:
    Type: AWS::EC2::Instance
    Condition: ThirdAzIsFullNode
    Properties:
      ImageId: !If
        - SQLBakedInAMI
        - !If
            - 'SQLVersion2016'
            - !Ref WS2019FULLSQL2016ENT
            - !If
              - 'SQLVersion2017'
              - !Ref WS2019FULLSQL2017ENT
              - !Ref WS2019FULLSQL2019ENT
        - !Ref WS2019FULLBASE
      IamInstanceProfile: !Ref 'WSFCProfile'
      InstanceType: !Ref 'WSFCNode3InstanceType'
      EbsOptimized: true
      NetworkInterfaces:
        - DeleteOnTermination: true
          DeviceIndex: '0'
          SubnetId: !Ref 'PrivateSubnet3ID'
          PrivateIpAddresses:
            - Primary: true
              PrivateIpAddress: !Ref 'WSFCNode3PrivateIP1'
            - Primary: false
              PrivateIpAddress: !Ref 'WSFCNode3PrivateIP2'
            - Primary: false
              PrivateIpAddress: !Ref 'WSFCNode3PrivateIP3'
          GroupSet:
            - !Ref 'DomainMemberSGID'
            - !Ref 'WSFCSecurityGroup'
            - !Ref 'WSFCClientSecurityGroup'
      Tags:
        - Key: Name
          Value: !Ref 'WSFCNode3NetBIOSName'
      BlockDeviceMappings:
        - DeviceName: /dev/sda1
          Ebs:
            VolumeSize: 100
            VolumeType: gp2
            Encrypted: true
        - DeviceName: /dev/xvdca
          VirtualName: ephemeral0
      KeyName: !Ref 'KeyPairName'
  WSFCNode2:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: !If
        - SQLBakedInAMI
        - !If
            - 'SQLVersion2016'
            - !Ref WS2019FULLSQL2016ENT
            - !If
              - 'SQLVersion2017'
              - !Ref WS2019FULLSQL2017ENT
              - !Ref WS2019FULLSQL2019ENT
        - !Ref WS2019FULLBASE
      IamInstanceProfile: !Ref 'WSFCProfile'
      InstanceType: !Ref 'WSFCNode2InstanceType'
      EbsOptimized: true
      NetworkInterfaces:
        - DeleteOnTermination: true
          DeviceIndex: '0'
          SubnetId: !Ref 'PrivateSubnet2ID'
          PrivateIpAddresses:
            - Primary: true
              PrivateIpAddress: !Ref 'WSFCNode2PrivateIP1'
            - Primary: false
              PrivateIpAddress: !Ref 'WSFCNode2PrivateIP2'
            - Primary: false
              PrivateIpAddress: !Ref 'WSFCNode2PrivateIP3'
          GroupSet:
            - !Ref 'DomainMemberSGID'
            - !Ref 'WSFCSecurityGroup'
            - !Ref 'WSFCClientSecurityGroup'
      Tags:
        - Key: Name
          Value: !Ref 'WSFCNode2NetBIOSName'
      BlockDeviceMappings:
        - DeviceName: /dev/sda1
          Ebs:
            VolumeSize: 100
            VolumeType: gp2
            Encrypted: true
        - DeviceName: /dev/xvdca
          VirtualName: ephemeral0
      KeyName: !Ref 'KeyPairName'
      UserData: !Base64
        Fn::Join:
          - ''
          - - "<powershell>\n"
            - 'Start-SSMAutomationExecution -DocumentName '
            - !Sub '"${AWSQuickstartMSSQL}"'
            - ' -Parameter @{"SQLServerVersion"='
            - !Sub '"${SQLServerVersion}"'
            - ';"SQLLicenseProvided"='
            - !Sub '"${SQLLicenseProvided}"'
            - ';"WSFCNode1NetBIOSName"='
            - !Sub '"${WSFCNode1NetBIOSName}"'
            - ';"WSFCNode1PrivateIP2"='
            - !Sub '"${WSFCNode1PrivateIP2}"'
            - ';"WSFCNode1PrivateIP3"='
            - !Sub '"${WSFCNode1PrivateIP3}"'
            - ';"WSFCNode2NetBIOSName"='
            - !Sub '"${WSFCNode2NetBIOSName}"'
            - ';"WSFCNode2PrivateIP2"='
            - !Sub '"${WSFCNode2PrivateIP2}"'
            - ';"WSFCNode2PrivateIP3"='
            - !Sub '"${WSFCNode2PrivateIP3}"'
            - ';"WSFCNode3NetBIOSName"='
            - !Sub '"${WSFCNode3NetBIOSName}"'
            - ';"WSFCNode3PrivateIP2"='
            - !Sub '"${WSFCNode3PrivateIP2}"'
            - ';"WSFCNode3PrivateIP3"='
            - !Sub '"${WSFCNode3PrivateIP3}"'
            - ';"WSFCFileServerNetBIOSName"='
            - !Sub '"${WSFCFileServerNetBIOSName}"'
            - ';"FSXFileSystemID"='
            - !If
                - FSxWitness
                - !Sub '"${FSXFileSystem}"'
                - '"none"'
            - ';"ClusterName"='
            - !Sub '"${ClusterName}"'
            - ';"AvailabiltyGroupName"='
            - !Sub '"${AvailabiltyGroupName}"'
            - ';"ThirdAZ"='
            - !Sub '"${ThirdAZ}"'
            - ';"DomainDNSName"='
            - !Sub '"${DomainDNSName}"'
            - ';"DomainNetBIOSName"='
            - !Sub '"${DomainNetBIOSName}"'
            - ';"ManagedAD"="'
            - !If
                - UseAWSDirectoryServiceEE
                - "yes"
                - "no"
            - '";"AdminSecrets"='
            - !Sub '"${ADAdminSecrets}"'
            - ';"SQLSecrets"='
            - !Sub '"${SQLSecrets}"'
            - ';"QSS3BucketName"='
            - !Sub '"${QSS3BucketName}"'
            - ';"QSS3KeyPrefix"='
            - !Sub '"${QSS3KeyPrefix}"'
            - ';"SQL2016Media"='
            - !Sub '"${SQL2016Media}"'
            - ';"SQL2017Media"='
            - !Sub '"${SQL2017Media}"'
            - ';"SQL2019Media"='
            - !Sub '"${SQL2019Media}"'
            - ';"StackName"='
            - !Sub '"${AWS::StackName}"'
            - ';"WitnessType"='
            - !Sub '"${WitnessType}"'
            - ';"URLSuffix"='
            - !Sub '"${AWS::URLSuffix}"'
            - ';"AutomationAssumeRole"='
            - !Sub '"arn:${AWS::Partition}:iam::${AWS::AccountId}:role/${AWSQuickstartMSSQLRole}"'
            - '}'
            - "\n"
            - "</powershell>\n"
  WSFCNode1Volume1:
    Type: AWS::EC2::Volume
    Properties:
      Size: !Ref 'Volume1Size'
      VolumeType: !Ref 'Volume1Type'
      Encrypted: true
      AvailabilityZone: !GetAtt 'WSFCNode1.AvailabilityZone'
      Iops: !If
        - Vol1IsIo1
        - !Ref 'Volume1Iops'
        - !Ref 'AWS::NoValue'
  WSFCNode1Volume2:
    Type: AWS::EC2::Volume
    Properties:
      Size: !Ref 'Volume2Size'
      VolumeType: !Ref 'Volume2Type'
      Encrypted: true
      AvailabilityZone: !GetAtt 'WSFCNode1.AvailabilityZone'
      Iops: !If
        - Vol2IsIo1
        - !Ref 'Volume2Iops'
        - !Ref 'AWS::NoValue'
  WSFCNode1Volume3:
    Type: AWS::EC2::Volume
    Properties:
      Size: !Ref 'Volume3Size'
      VolumeType: !Ref 'Volume3Type'
      Encrypted: true
      AvailabilityZone: !GetAtt 'WSFCNode1.AvailabilityZone'
      Iops: !If
        - Vol3IsIo1
        - !Ref 'Volume3Iops'
        - !Ref 'AWS::NoValue'
  WSFCNode2Volume1:
    Type: AWS::EC2::Volume
    Properties:
      Size: !Ref 'Volume1Size'
      VolumeType: !Ref 'Volume1Type'
      Encrypted: true
      AvailabilityZone: !GetAtt 'WSFCNode2.AvailabilityZone'
      Iops: !If
        - Vol1IsIo1
        - !Ref 'Volume1Iops'
        - !Ref 'AWS::NoValue'
  WSFCNode2Volume2:
    Type: AWS::EC2::Volume
    Properties:
      Size: !Ref 'Volume2Size'
      VolumeType: !Ref 'Volume2Type'
      Encrypted: true
      AvailabilityZone: !GetAtt 'WSFCNode2.AvailabilityZone'
      Iops: !If
        - Vol2IsIo1
        - !Ref 'Volume2Iops'
        - !Ref 'AWS::NoValue'
  WSFCNode2Volume3:
    Type: AWS::EC2::Volume
    Properties:
      Size: !Ref 'Volume3Size'
      VolumeType: !Ref 'Volume3Type'
      Encrypted: true
      AvailabilityZone: !GetAtt 'WSFCNode2.AvailabilityZone'
      Iops: !If
        - Vol3IsIo1
        - !Ref 'Volume3Iops'
        - !Ref 'AWS::NoValue'
  WSFCNode3Volume1:
    Type: AWS::EC2::Volume
    Condition: ThirdAzIsFullNode
    Properties:
      Size: !Ref 'Volume1Size'
      VolumeType: !Ref 'Volume1Type'
      Encrypted: true
      AvailabilityZone: !GetAtt 'WSFCNode3.AvailabilityZone'
      Iops: !If
        - Vol1IsIo1
        - !Ref 'Volume1Iops'
        - !Ref 'AWS::NoValue'
  WSFCNode3Volume2:
    Type: AWS::EC2::Volume
    Condition: ThirdAzIsFullNode
    Properties:
      Size: !Ref 'Volume2Size'
      VolumeType: !Ref 'Volume2Type'
      Encrypted: true
      AvailabilityZone: !GetAtt 'WSFCNode3.AvailabilityZone'
      Iops: !If
        - Vol2IsIo1
        - !Ref 'Volume2Iops'
        - !Ref 'AWS::NoValue'
  WSFCNode3Volume3:
    Type: AWS::EC2::Volume
    Condition: ThirdAzIsFullNode
    Properties:
      Size: !Ref 'Volume3Size'
      VolumeType: !Ref 'Volume3Type'
      Encrypted: true
      AvailabilityZone: !GetAtt 'WSFCNode3.AvailabilityZone'
      Iops: !If
        - Vol3IsIo1
        - !Ref 'Volume3Iops'
        - !Ref 'AWS::NoValue'
  WSFCNode1Volume1Attachment:
    Type: AWS::EC2::VolumeAttachment
    Properties:
      Device: /dev/xvdb
      InstanceId: !Ref 'WSFCNode1'
      VolumeId: !Ref 'WSFCNode1Volume1'
  WSFCNode1Volume2Attachment:
    Type: AWS::EC2::VolumeAttachment
    Properties:
      Device: /dev/xvdc
      InstanceId: !Ref 'WSFCNode1'
      VolumeId: !Ref 'WSFCNode1Volume2'
  WSFCNode1Volume3Attachment:
    Type: AWS::EC2::VolumeAttachment
    Properties:
      Device: /dev/xvdd
      InstanceId: !Ref 'WSFCNode1'
      VolumeId: !Ref 'WSFCNode1Volume3'
  WSFCNode2Volume1Attachment:
    Type: AWS::EC2::VolumeAttachment
    Properties:
      Device: /dev/xvdb
      InstanceId: !Ref 'WSFCNode2'
      VolumeId: !Ref 'WSFCNode2Volume1'
  WSFCNode2Volume2Attachment:
    Type: AWS::EC2::VolumeAttachment
    Properties:
      Device: /dev/xvdc
      InstanceId: !Ref 'WSFCNode2'
      VolumeId: !Ref 'WSFCNode2Volume2'
  WSFCNode2Volume3Attachment:
    Type: AWS::EC2::VolumeAttachment
    Properties:
      Device: /dev/xvdd
      InstanceId: !Ref 'WSFCNode2'
      VolumeId: !Ref 'WSFCNode2Volume3'
  WSFCNode3Volume1Attachment:
    Type: AWS::EC2::VolumeAttachment
    Condition: ThirdAzIsFullNode
    Properties:
      Device: /dev/xvdb
      InstanceId: !Ref 'WSFCNode3'
      VolumeId: !Ref 'WSFCNode3Volume1'
  WSFCNode3Volume2Attachment:
    Type: AWS::EC2::VolumeAttachment
    Condition: ThirdAzIsFullNode
    Properties:
      Device: /dev/xvdc
      InstanceId: !Ref 'WSFCNode3'
      VolumeId: !Ref 'WSFCNode3Volume2'
  WSFCNode3Volume3Attachment:
    Type: AWS::EC2::VolumeAttachment
    Condition: ThirdAzIsFullNode
    Properties:
      Device: /dev/xvdd
      InstanceId: !Ref 'WSFCNode3'
      VolumeId: !Ref 'WSFCNode3Volume3'
  SSMWaitHandle: 
    Type: AWS::CloudFormation::WaitConditionHandle
  SSMWaitCondition: 
    Type: AWS::CloudFormation::WaitCondition
    CreationPolicy:
      ResourceSignal:
        Timeout: PT180M
        Count: 1
    DependsOn: "WSFCNode2"
    Properties: 
      Handle: 
        Ref: "SSMWaitHandle"
      Timeout: "9000"
      Count: 1
  WSFCSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Enable the WSFC and SQL AlwaysOn Availability Group communications
      VpcId: !Ref 'VPCID'
  WSFCSecurityGroupIngressIcmp:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: icmp
      FromPort: -1
      ToPort: -1
  WSFCSecurityGroupIngressTcp135:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: tcp
      FromPort: 135
      ToPort: 135
  WSFCSecurityGroupIngressTcp137:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: tcp
      FromPort: 137
      ToPort: 137
  WSFCSecurityGroupIngressTcp445:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: tcp
      FromPort: 445
      ToPort: 445
  WSFCSecurityGroupIngressTcp1433:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: tcp
      FromPort: 1433
      ToPort: 1434
  WSFCSecurityGroupIngressTcp3343:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: tcp
      FromPort: 3343
      ToPort: 3343
  WSFCSecurityGroupIngressTcp5022:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: tcp
      FromPort: 5022
      ToPort: 5022
  WSFCSecurityGroupIngressTcp5985:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: tcp
      FromPort: 5985
      ToPort: 5985
  WSFCSecurityGroupIngressUdp137:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: udp
      FromPort: 137
      ToPort: 137
  WSFCSecurityGroupIngressUdp3343:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: udp
      FromPort: 3343
      ToPort: 3343
  WSFCSecurityGroupIngressUdp1434:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: udp
      FromPort: 1434
      ToPort: 1434
  WSFCSecurityGroupIngressUdpHighPorts:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: udp
      FromPort: 49152
      ToPort: 65535
  WSFCSecurityGroupIngressTcpHighPorts:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref 'WSFCSecurityGroup'
      SourceSecurityGroupId: !Ref 'WSFCSecurityGroup'
      IpProtocol: tcp
      FromPort: 49152
      ToPort: 65535
  SQLServerAccessSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      VpcId: !Ref 'VPCID'
      GroupDescription: Allows access to SQL Servers
  WSFCClientSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: SQL Client access ports
      VpcId: !Ref 'VPCID'
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 1433
          ToPort: 1433
          SourceSecurityGroupId: !Ref 'SQLServerAccessSecurityGroup'
  FSxSG:
    Type: AWS::EC2::SecurityGroup
    Condition: FSxWitness
    Properties: 
      GroupDescription: FSx share
      VpcId: !Ref VPCID
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 5985
          ToPort: 5985
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: tcp
          FromPort: 53
          ToPort: 53
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: tcp
          FromPort: 53
          ToPort: 53
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: udp
          FromPort: 53
          ToPort: 53
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: tcp
          FromPort: 49152
          ToPort: 65535
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: udp
          FromPort: 49152
          ToPort: 65535
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: tcp
          FromPort: 88
          ToPort: 88
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: udp
          FromPort: 88
          ToPort: 88
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: tcp
          FromPort: 445
          ToPort: 445
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: udp
          FromPort: 445
          ToPort: 445
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: tcp
          FromPort: 389
          ToPort: 389
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: udp
          FromPort: 389
          ToPort: 389
          SourceSecurityGroupId: !Ref DomainMemberSGID
        - IpProtocol: tcp
          FromPort: 636
          ToPort: 636
          SourceSecurityGroupId: !Ref DomainMemberSGID
  FSXFileSystem:
    Type: 'AWS::FSx::FileSystem'
    Condition: FSxWitness
    Properties:
      FileSystemType: WINDOWS
      StorageCapacity: 32
      StorageType: SSD
      SubnetIds:
        - !Ref PrivateSubnet1ID
        - !Ref PrivateSubnet2ID
      SecurityGroupIds:
        - !Ref FSxSG
      Tags:
        - Key: Name
          Value: windows
      WindowsConfiguration:
        ThroughputCapacity: 8
        WeeklyMaintenanceStartTime: '4:16:30'
        DailyAutomaticBackupStartTime: '01:00'
        AutomaticBackupRetentionDays: 30
        CopyTagsToBackups: false
        DeploymentType: 'MULTI_AZ_1'
        PreferredSubnetId: !Ref PrivateSubnet1ID
        SelfManagedActiveDirectoryConfiguration:
          DnsIps:
            - !Ref ADServer1PrivateIP
            - !Ref ADServer2PrivateIP
          DomainName: !Ref DomainDNSName
          UserName: !Ref DomainAdminUser
          Password: !Ref DomainAdminPassword
  AppInsightsForSQLHA:
    Condition: EnableAppInsightForSQLHA
    Type: AWS::ApplicationInsights::Application
    Properties:
      ResourceGroupName: !Ref 'ResourceGroupName'
      AutoConfigurationEnabled: false
      CustomComponents:
        - ComponentName: !Sub 'SQLHAClusterInstances-${ApplicationName}'
          ResourceList:
            - !Sub 'arn:${AWS::Partition}:ec2:${AWS::Region}:${AWS::AccountId}:instance/${WSFCNode1}'
            - !Sub 'arn:${AWS::Partition}:ec2:${AWS::Region}:${AWS::AccountId}:instance/${WSFCNode2}'
            - !If
              - ThirdAzIsFullNode
              - !Sub 'arn:${AWS::Partition}:ec2:${AWS::Region}:${AWS::AccountId}:instance/${WSFCNode3}'
              - !Ref 'AWS::NoValue'

      ComponentMonitoringSettings:
        - ComponentName: !Sub 'SQLHAClusterInstances-${ApplicationName}'
          Tier: SQL_SERVER_ALWAYSON_AVAILABILITY_GROUP
          ComponentConfigurationMode: DEFAULT_WITH_OVERWRITE
          DefaultOverwriteComponentConfiguration:
            SubComponentTypeConfigurations:
              - SubComponentType: AWS::EC2::Instance
                SubComponentConfigurationDetails:
                  Logs:
                    - LogGroupName: !Sub 'SQL_SERVER-${ResourceGroupName}'
                      LogType: SQL_SERVER
                      LogPath: C:\Program Files\Microsoft SQL Server\MSSQL**.MSSQLSERVER\MSSQL\Log\ERRORLOG
Outputs:
  WSFCNode1NetBIOSName:
    Value: !Ref 'WSFCNode1NetBIOSName'
    Description: NetBIOS name of the 1st WSFC Node
  WSFCNode2NetBIOSName:
    Value: !Ref 'WSFCNode2NetBIOSName'
    Description: NetBIOS name of the 2nd WSFC Node
  WSFCNode3NetBIOSName:
    Condition: ThirdAzIsFullNode
    Value: !Ref 'WSFCNode3NetBIOSName'
    Description: NetBIOS name of the 3rd WSFC Node
  SQLServerAccessSecurityGroupID:
    Value: !Ref 'SQLServerAccessSecurityGroup'
    Description: Add instances that require access to SQL to this Security Group
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
