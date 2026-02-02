# AWS Landing Zone - 12-Day Hands-On Lab Guide 🏗️

> A practical lab guide to master AWS Landing Zone architecture, Control Tower, and multi-account management through daily hands-on exercises.

---

## 📋 Table of Contents

- [Lab Setup](#lab-setup)
- [Day 1: AWS Organizations Fundamentals](#day-1-aws-organizations-fundamentals)
- [Day 2: Control Tower Setup](#day-2-control-tower-setup)
- [Day 3: Account Factory & Vending](#day-3-account-factory--vending)
- [Day 4: Networking Architecture](#day-4-networking-architecture)
- [Day 5: Security Baseline](#day-5-security-baseline)
- [Day 6: Guardrails & Policies](#day-6-guardrails--policies)
- [Day 7: Logging & Monitoring](#day-7-logging--monitoring)
- [Day 8: Identity & Access Management](#day-8-identity--access-management)
- [Day 9: Cost Management](#day-9-cost-management)
- [Day 10: Compliance & Governance](#day-10-compliance--governance)
- [Day 11: Disaster Recovery](#day-11-disaster-recovery)
- [Day 12: Advanced Scenarios](#day-12-advanced-scenarios)
- [Deep Interview Questions](#deep-interview-questions)

**Total Time:** ~20 hours (practice at your own pace)

---

## Lab Setup

### Prerequisites

- AWS Account with admin access (root account)
- Credit card for AWS billing (free tier available)
- AWS CLI installed and configured
- Terraform or CloudFormation knowledge
- Basic understanding of AWS services

### Initial Setup

#### Step 1: Prepare Management Account

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region: us-east-1
# Default output format: json

# Verify access
aws sts get-caller-identity
```

#### Step 2: Enable Required Services

```bash
# Enable Organizations (if not already)
aws organizations enable-all-features

# Enable trusted access for required services
aws organizations enable-aws-service-access \
  --service-principal cloudtrail.amazonaws.com

aws organizations enable-aws-service-access \
  --service-principal config.amazonaws.com

aws organizations enable-aws-service-access \
  --service-principal sso.amazonaws.com
```

#### Step 3: Budget Warning (Important!)

```bash
# Create budget alert to avoid surprise charges
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json

# budget.json:
cat > budget.json <<EOF
{
  "BudgetName": "LandingZoneLab",
  "BudgetLimit": {
    "Amount": "50",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
EOF
```

---

## Day 1: AWS Organizations Fundamentals

**Learning Objectives:**
- Understand AWS Organizations architecture
- Create Organization Units (OUs)
- Implement basic SCPs
- Understand account hierarchy

### Exercise 1.1: Create AWS Organization

```bash
# Create organization (if not exists)
aws organizations create-organization \
  --feature-set ALL

# Describe organization
aws organizations describe-organization

# Key fields to note:
# - MasterAccountId
# - FeatureSet (should be ALL)
# - AvailablePolicyTypes
```

### Exercise 1.2: Create Organizational Structure

**Recommended OU Structure:**
```
Root
├── Security
│   ├── Log Archive
│   └── Security Tooling
├── Infrastructure
│   ├── Network
│   └── Shared Services
├── Sandbox
├── Workloads
│   ├── Production
│   ├── Staging
│   └── Development
└── Suspended
```

**Create OUs:**
```bash
# Get root ID
ROOT_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text)

# Create Security OU
SECURITY_OU=$(aws organizations create-organizational-unit \
  --parent-id $ROOT_ID \
  --name Security \
  --query 'OrganizationalUnit.Id' \
  --output text)

# Create Infrastructure OU
INFRA_OU=$(aws organizations create-organizational-unit \
  --parent-id $ROOT_ID \
  --name Infrastructure \
  --query 'OrganizationalUnit.Id' \
  --output text)

# Create Workloads OU
WORKLOADS_OU=$(aws organizations create-organizational-unit \
  --parent-id $ROOT_ID \
  --name Workloads \
  --query 'OrganizationalUnit.Id' \
  --output text)

# Create nested OUs under Workloads
PROD_OU=$(aws organizations create-organizational-unit \
  --parent-id $WORKLOADS_OU \
  --name Production \
  --query 'OrganizationalUnit.Id' \
  --output text)

DEV_OU=$(aws organizations create-organizational-unit \
  --parent-id $WORKLOADS_OU \
  --name Development \
  --query 'OrganizationalUnit.Id' \
  --output text)

# List all OUs
aws organizations list-organizational-units-for-parent \
  --parent-id $ROOT_ID
```

### Exercise 1.3: Service Control Policies (SCPs)

**Create Baseline SCP - Deny Region Restriction:**
```bash
# Create deny-non-approved-regions SCP
cat > deny-regions-scp.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllOutsideApprovedRegions",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "us-east-1",
            "us-west-2",
            "eu-west-1"
          ]
        },
        "ArnNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::*:role/AWSControlTowerExecution"
          ]
        }
      }
    }
  ]
}
EOF

# Create policy
REGION_POLICY=$(aws organizations create-policy \
  --content file://deny-regions-scp.json \
  --description "Restrict services to approved regions" \
  --name DenyNonApprovedRegions \
  --type SERVICE_CONTROL_POLICY \
  --query 'Policy.PolicySummary.Id' \
  --output text)

# Attach to Workloads OU
aws organizations attach-policy \
  --policy-id $REGION_POLICY \
  --target-id $WORKLOADS_OU
```

**Create Security Baseline SCP:**
```bash
cat > security-baseline-scp.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLeavingOrganization",
      "Effect": "Deny",
      "Action": "organizations:LeaveOrganization",
      "Resource": "*"
    },
    {
      "Sid": "DenyRootAccountUsage",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:root"
        }
      }
    },
    {
      "Sid": "DenyCloudTrailDisable",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:DeleteTrail",
        "cloudtrail:StopLogging",
        "cloudtrail:UpdateTrail"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyConfigDisable",
      "Effect": "Deny",
      "Action": [
        "config:DeleteConfigRule",
        "config:DeleteConfigurationRecorder",
        "config:DeleteDeliveryChannel",
        "config:StopConfigurationRecorder"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws organizations create-policy \
  --content file://security-baseline-scp.json \
  --description "Security baseline requirements" \
  --name SecurityBaseline \
  --type SERVICE_CONTROL_POLICY

# Attach to root (applies to all accounts)
aws organizations attach-policy \
  --policy-id $(aws organizations list-policies \
    --filter SERVICE_CONTROL_POLICY \
    --query "Policies[?Name=='SecurityBaseline'].Id" \
    --output text) \
  --target-id $ROOT_ID
```

### Exercise 1.4: Validate SCPs

```bash
# List all policies
aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY

# Describe specific policy
aws organizations describe-policy \
  --policy-id $REGION_POLICY

# List targets (OUs/accounts) for policy
aws organizations list-targets-for-policy \
  --policy-id $REGION_POLICY

# Check effective policies for an OU
aws organizations list-policies-for-target \
  --target-id $WORKLOADS_OU \
  --filter SERVICE_CONTROL_POLICY
```

**📝 Daily Summary:**
- Draw your organization structure
- Document all SCPs and their purpose
- Understand SCP inheritance (policies flow down)
- Note: SCPs never grant permissions, only restrict

---

## Day 2: Control Tower Setup

**Learning Objectives:**
- Set up AWS Control Tower
- Understand Control Tower architecture
- Configure landing zone
- Explore AWS SSO integration

### Exercise 2.1: Pre-Flight Checks

```bash
# Verify prerequisites
# 1. Management account has no existing Config/CloudTrail in home region
# 2. No existing Organizations setup that conflicts
# 3. Sufficient service limits

# Check existing CloudTrail
aws cloudtrail describe-trails

# Check existing Config
aws configservice describe-configuration-recorders

# Check Organizations
aws organizations describe-organization
```

### Exercise 2.2: Launch Control Tower

**Via Console (Recommended for first time):**

1. Navigate to AWS Control Tower console
2. Click "Set up landing zone"
3. Configure:
   - **Home Region:** us-east-1 (recommended)
   - **Region deny settings:** Select allowed regions
   - **Log Archive account:** (auto-created)
   - **Audit account:** (auto-created)
   - **Additional OUs:** Keep defaults for now

4. Review pricing (estimated $5-10/month)
5. Click "Set up landing zone"
6. **Wait 45-60 minutes** for setup

**What Control Tower Creates:**
- Two mandatory accounts:
  - **Log Archive:** Centralized logging
  - **Audit (Security):** Security/compliance tools
- Core OUs:
  - **Security OU:** Contains Log Archive & Audit
  - **Sandbox OU:** For experimentation
- Guardrails (Detective & Preventive)
- AWS SSO configured
- CloudTrail organization trail
- AWS Config in all accounts

### Exercise 2.3: Explore Control Tower Dashboard

```bash
# View Control Tower setup (after completion)
# Console: AWS Control Tower > Dashboard

# Key metrics to check:
# - Number of OUs
# - Number of accounts
# - Enabled guardrails
# - Drift status (should be "No drift detected")

# Via CLI - check Organizations structure
aws organizations list-accounts

# View Control Tower created OUs
aws organizations list-organizational-units-for-parent \
  --parent-id $ROOT_ID
```

### Exercise 2.4: Configure AWS SSO

```bash
# AWS SSO is automatically configured by Control Tower

# Access SSO portal URL
# Console: AWS SSO > Settings > User portal URL
# Example: https://d-xxxxxxxxxx.awsapps.com/start

# Create SSO admin user
# Console: AWS SSO > Users > Add user
# - Username: admin@example.com
# - Email: (your email)
# - First/Last name

# Create permission sets
# Console: AWS SSO > AWS accounts > Permission sets > Create permission set
# - Use AdministratorAccess for now (refine later)
```

### Exercise 2.5: Account Factory Configuration

```bash
# View Account Factory settings
# Console: Control Tower > Account factory

# Configure Account Factory
# Set up parameters:
# - Account email format
# - Organizational unit options
# - VPC configuration (we'll use Transit Gateway later)
# - Region settings
```

**📝 Daily Summary:**
- Control Tower creates 2 mandatory accounts (Log Archive, Audit)
- Sets up AWS SSO for centralized access
- Deploys detective and preventive guardrails
- Account Factory ready for provisioning
- Document your SSO portal URL

---

## Day 3: Account Factory & Vending

**Learning Objectives:**
- Provision accounts using Account Factory
- Understand account baseline
- Automate account vending
- Configure account templates

### Exercise 3.1: Provision First Account (Manual)

**Via Console:**
```
1. Control Tower > Account factory > Enroll account
2. Fill in:
   - Account email: dev-account-001@example.com
   - Display name: Development-001
   - AWS SSO email: admin@example.com
   - Organizational unit: Development (under Workloads)
3. Click "Enroll account"
4. Wait 20-30 minutes
```

**What Gets Created:**
- New AWS account
- VPC with subnets (if enabled)
- CloudTrail enabled
- AWS Config enabled
- SCPs applied from parent OU
- SSO access configured

### Exercise 3.2: Provision Account via Service Catalog

```bash
# Account Factory uses Service Catalog under the hood

# List Service Catalog products
aws servicecatalog search-products \
  --filters FullTextSearch="AWS Control Tower Account Factory"

# Get product ID
PRODUCT_ID=$(aws servicecatalog search-products \
  --filters FullTextSearch="AWS Control Tower Account Factory" \
  --query 'ProductViewSummaries[0].ProductId' \
  --output text)

# List provisioning artifacts (versions)
aws servicecatalog list-provisioning-artifacts \
  --product-id $PRODUCT_ID

# Get artifact ID (latest version)
ARTIFACT_ID=$(aws servicecatalog list-provisioning-artifacts \
  --product-id $PRODUCT_ID \
  --query 'ProvisioningArtifactDetails[0].Id' \
  --output text)

# Provision account via Service Catalog
cat > account-params.json <<EOF
[
  {
    "Key": "AccountEmail",
    "Value": "staging-account-001@example.com"
  },
  {
    "Key": "AccountName",
    "Value": "Staging-001"
  },
  {
    "Key": "ManagedOrganizationalUnit",
    "Value": "Staging"
  },
  {
    "Key": "SSOUserEmail",
    "Value": "admin@example.com"
  },
  {
    "Key": "SSOUserFirstName",
    "Value": "Admin"
  },
  {
    "Key": "SSOUserLastName",
    "Value": "User"
  }
]
EOF

aws servicecatalog provision-product \
  --product-id $PRODUCT_ID \
  --provisioning-artifact-id $ARTIFACT_ID \
  --provisioned-product-name "Staging-001" \
  --provisioning-parameters file://account-params.json
```

### Exercise 3.3: Automate with Terraform

**Create Terraform for Account Vending:**
```hcl
# account-factory.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Data source for Service Catalog product
data "aws_servicecatalog_product" "account_factory" {
  name = "AWS Control Tower Account Factory"
}

# Provision new account
resource "aws_servicecatalog_provisioned_product" "dev_account" {
  name                       = "Development-002"
  product_id                 = data.aws_servicecatalog_product.account_factory.id
  provisioning_artifact_name = "AWS Control Tower Account Factory"

  provisioning_parameters {
    key   = "AccountEmail"
    value = "dev-account-002@example.com"
  }

  provisioning_parameters {
    key   = "AccountName"
    value = "Development-002"
  }

  provisioning_parameters {
    key   = "ManagedOrganizationalUnit"
    value = "Development"
  }

  provisioning_parameters {
    key   = "SSOUserEmail"
    value = "admin@example.com"
  }

  provisioning_parameters {
    key   = "SSOUserFirstName"
    value = "Admin"
  }

  provisioning_parameters {
    key   = "SSOUserLastName"
    value = "User"
  }

  tags = {
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

output "account_id" {
  value = aws_servicecatalog_provisioned_product.dev_account.outputs["AccountId"]
}
```

**Deploy:**
```bash
terraform init
terraform plan
terraform apply
```

### Exercise 3.4: Account Baseline Customization

**Create Customization Package:**
```bash
# Account customizations allow you to run scripts/deploy resources
# when new accounts are created

# Create customization structure
mkdir -p customizations/{policies,templates,manifest}

# Create manifest file
cat > customizations/manifest.yaml <<EOF
region: us-east-1
version: 2021-03-15

resources:
  - name: BaselineIAMRoles
    resource_file: templates/iam-roles.yaml
    deploy_method: stack_set
    deployment_targets:
      organizational_units:
        - Development
        - Staging
        - Production
    regions:
      - us-east-1

  - name: BaselineSecurityGroup
    resource_file: templates/security-groups.yaml
    deploy_method: stack_set
    deployment_targets:
      organizational_units:
        - Development
        - Staging
        - Production
    regions:
      - us-east-1
      - us-west-2
EOF

# Create IAM roles template
cat > customizations/templates/iam-roles.yaml <<EOF
AWSTemplateFormatVersion: '2010-09-09'
Description: Baseline IAM roles for all accounts

Resources:
  ReadOnlyRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: ReadOnlyAccess
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/ReadOnlyAccess

  PowerUserRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: PowerUserAccess
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/PowerUserAccess
EOF
```

### Exercise 3.5: Validate Account Creation

```bash
# List all accounts
aws organizations list-accounts

# Describe specific account
aws organizations describe-account \
  --account-id <new-account-id>

# Check account in Control Tower
# Console: Control Tower > Organization > View OUs
# Verify account appears in correct OU

# Test SSO access
# 1. Go to SSO portal
# 2. Sign in with admin user
# 3. Should see new account in list
# 4. Click account > Management console
```

**📝 Daily Summary:**
- Account Factory creates standardized accounts
- Provisioning takes 20-30 minutes
- Can automate with Terraform/Service Catalog API
- All accounts get baseline (CloudTrail, Config, SCPs)
- Document account naming convention

---

## Day 4: Networking Architecture

**Learning Objectives:**
- Design hub-and-spoke network
- Configure Transit Gateway
- Set up VPC sharing
- Implement network segmentation

### Exercise 4.1: Network Design

**Recommended Architecture:**
```
Transit Gateway (Network Account)
├── Shared Services VPC (10.0.0.0/16)
│   ├── Active Directory
│   ├── DNS
│   └── NAT Gateways
├── Production VPC (10.1.0.0/16)
├── Staging VPC (10.2.0.0/16)
├── Development VPC (10.3.0.0/16)
└── Security VPC (10.10.0.0/16)
    ├── Firewall
    └── Inspection
```

### Exercise 4.2: Create Network Account

```bash
# Provision Network account via Account Factory
# (Use process from Day 3)
# Account email: network-account@example.com
# OU: Infrastructure

# Note the account ID for later
NETWORK_ACCOUNT_ID=<network-account-id>
```

### Exercise 4.3: Deploy Transit Gateway

**Via CloudFormation:**
```yaml
# transit-gateway.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: Transit Gateway for Landing Zone

Parameters:
  AmazonSideAsn:
    Type: Number
    Default: 64512
    Description: ASN for Transit Gateway

Resources:
  TransitGateway:
    Type: AWS::EC2::TransitGateway
    Properties:
      AmazonSideAsn: !Ref AmazonSideAsn
      Description: Landing Zone Transit Gateway
      DefaultRouteTableAssociation: disable
      DefaultRouteTablePropagation: disable
      DnsSupport: enable
      VpnEcnSupport: enable
      Tags:
        - Key: Name
          Value: LandingZone-TGW

  # Route Tables
  SharedServicesRouteTable:
    Type: AWS::EC2::TransitGatewayRouteTable
    Properties:
      TransitGatewayId: !Ref TransitGateway
      Tags:
        - Key: Name
          Value: Shared-Services-RT

  ProductionRouteTable:
    Type: AWS::EC2::TransitGatewayRouteTable
    Properties:
      TransitGatewayId: !Ref TransitGateway
      Tags:
        - Key: Name
          Value: Production-RT

  NonProductionRouteTable:
    Type: AWS::EC2::TransitGatewayRouteTable
    Properties:
      TransitGatewayId: !Ref TransitGateway
      Tags:
        - Key: Name
          Value: NonProduction-RT

  # Resource Share for RAM
  TransitGatewayShare:
    Type: AWS::RAM::ResourceShare
    Properties:
      Name: TransitGateway-Share
      ResourceArns:
        - !Sub 'arn:aws:ec2:${AWS::Region}:${AWS::AccountId}:transit-gateway/${TransitGateway}'
      Principals:
        - !Sub 'arn:aws:organizations::${AWS::AccountId}:organization/${OrganizationId}'

Outputs:
  TransitGatewayId:
    Value: !Ref TransitGateway
    Export:
      Name: LandingZone-TGW-ID

  SharedServicesRouteTableId:
    Value: !Ref SharedServicesRouteTable
    Export:
      Name: SharedServices-RT-ID
```

**Deploy:**
```bash
# Switch to Network account
aws sts assume-role \
  --role-arn arn:aws:iam::$NETWORK_ACCOUNT_ID:role/AWSControlTowerExecution \
  --role-session-name network-setup

# Deploy Transit Gateway
aws cloudformation create-stack \
  --stack-name LandingZone-TransitGateway \
  --template-body file://transit-gateway.yaml \
  --capabilities CAPABILITY_IAM

# Wait for completion
aws cloudformation wait stack-create-complete \
  --stack-name LandingZone-TransitGateway
```

### Exercise 4.4: Share Transit Gateway with Organization

```bash
# Enable RAM sharing in Organizations (management account)
aws ram enable-sharing-with-aws-organization

# Get Transit Gateway ARN
TGW_ID=$(aws cloudformation describe-stacks \
  --stack-name LandingZone-TransitGateway \
  --query 'Stacks[0].Outputs[?OutputKey==`TransitGatewayId`].OutputValue' \
  --output text)

TGW_ARN="arn:aws:ec2:us-east-1:$NETWORK_ACCOUNT_ID:transit-gateway/$TGW_ID"

# Create RAM resource share
aws ram create-resource-share \
  --name "TransitGateway-OrgShare" \
  --resource-arns $TGW_ARN \
  --principals "arn:aws:organizations::$MANAGEMENT_ACCOUNT_ID:organization/$ORG_ID"

# In spoke accounts, accept the share
aws ram get-resource-share-invitations

aws ram accept-resource-share-invitation \
  --resource-share-invitation-arn <invitation-arn>
```

### Exercise 4.5: Create VPC with Transit Gateway Attachment

**Spoke VPC Template:**
```yaml
# spoke-vpc.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: Spoke VPC attached to Transit Gateway

Parameters:
  VpcCidr:
    Type: String
    Default: 10.1.0.0/16
  
  TransitGatewayId:
    Type: String
    Description: Transit Gateway ID from Network account

  Environment:
    Type: String
    AllowedValues:
      - Production
      - Staging
      - Development

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCidr
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-VPC'

  # Private Subnets (for workloads)
  PrivateSubnetA:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: !Select [0, !Cidr [!Ref VpcCidr, 6, 8]]
      AvailabilityZone: !Select [0, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-Private-A'

  PrivateSubnetB:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: !Select [1, !Cidr [!Ref VpcCidr, 6, 8]]
      AvailabilityZone: !Select [1, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-Private-B'

  # Transit Gateway Subnets
  TGWSubnetA:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: !Select [4, !Cidr [!Ref VpcCidr, 6, 8]]
      AvailabilityZone: !Select [0, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-TGW-A'

  TGWSubnetB:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: !Select [5, !Cidr [!Ref VpcCidr, 6, 8]]
      AvailabilityZone: !Select [1, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-TGW-B'

  # Transit Gateway Attachment
  TransitGatewayAttachment:
    Type: AWS::EC2::TransitGatewayAttachment
    Properties:
      TransitGatewayId: !Ref TransitGatewayId
      VpcId: !Ref VPC
      SubnetIds:
        - !Ref TGWSubnetA
        - !Ref TGWSubnetB
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-TGW-Attachment'

  # Route Tables
  PrivateRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${Environment}-Private-RT'

  # Route to Transit Gateway
  RouteToTGW:
    Type: AWS::EC2::Route
    DependsOn: TransitGatewayAttachment
    Properties:
      RouteTableId: !Ref PrivateRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      TransitGatewayId: !Ref TransitGatewayId

  # Associate subnets with route table
  PrivateSubnetAAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnetA
      RouteTableId: !Ref PrivateRouteTable

  PrivateSubnetBAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnetB
      RouteTableId: !Ref PrivateRouteTable

Outputs:
  VpcId:
    Value: !Ref VPC
  TransitGatewayAttachmentId:
    Value: !Ref TransitGatewayAttachment
```

**Deploy in Production Account:**
```bash
# Switch to Production account
aws sts assume-role \
  --role-arn arn:aws:iam::$PROD_ACCOUNT_ID:role/AWSControlTowerExecution \
  --role-session-name vpc-setup

# Deploy VPC
aws cloudformation create-stack \
  --stack-name Production-VPC \
  --template-body file://spoke-vpc.yaml \
  --parameters \
    ParameterKey=VpcCidr,ParameterValue=10.1.0.0/16 \
    ParameterKey=TransitGatewayId,ParameterValue=$TGW_ID \
    ParameterKey=Environment,ParameterValue=Production
```

### Exercise 4.6: Configure Transit Gateway Routing

```bash
# Back in Network account

# Get attachment IDs
PROD_ATTACHMENT=$(aws ec2 describe-transit-gateway-attachments \
  --filters "Name=resource-id,Values=$PROD_VPC_ID" \
  --query 'TransitGatewayAttachments[0].TransitGatewayAttachmentId' \
  --output text)

# Associate Production VPC with Production Route Table
aws ec2 associate-transit-gateway-route-table \
  --transit-gateway-route-table-id $PROD_RT_ID \
  --transit-gateway-attachment-id $PROD_ATTACHMENT

# Add route to Shared Services
aws ec2 create-transit-gateway-route \
  --transit-gateway-route-table-id $PROD_RT_ID \
  --destination-cidr-block 10.0.0.0/16 \
  --transit-gateway-attachment-id $SHARED_SERVICES_ATTACHMENT
```

**📝 Daily Summary:**
- Transit Gateway enables hub-and-spoke architecture
- Network account centralizes network resources
- RAM shares TGW across organization
- Route tables control traffic flow
- Document CIDR allocations

---

## Day 5: Security Baseline

**Learning Objectives:**
- Enable Security Hub
- Configure GuardDuty
- Set up AWS Config rules
- Enable Macie for data protection

### Exercise 5.1: Enable Security Hub

**Centralized Security Account Setup:**
```bash
# In Security (Audit) account

# Enable Security Hub
aws securityhub enable-security-hub

# Enable security standards
aws securityhub batch-enable-standards \
  --standards-subscription-requests \
    StandardsArn="arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0" \
    StandardsArn="arn:aws:securityhub:us-east-1::standards/cis-aws-foundations-benchmark/v/1.2.0"

# Enable Security Hub for organization (management account)
aws securityhub create-members \
  --account-details AccountId=$PROD_ACCOUNT_ID,Email=prod@example.com \
                    AccountId=$DEV_ACCOUNT_ID,Email=dev@example.com
```

**Via CloudFormation StackSet (All Accounts):**
```yaml
# security-hub-enable.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: Enable Security Hub in member accounts

Resources:
  SecurityHub:
    Type: AWS::SecurityHub::Hub
    Properties:
      Tags:
        ManagedBy: LandingZone

  CISStandard:
    Type: AWS::SecurityHub::Standard
    Properties:
      StandardsArn: !Sub 'arn:aws:securityhub:${AWS::Region}::standards/cis-aws-foundations-benchmark/v/1.2.0'

  AWSFoundationalStandard:
    Type: AWS::SecurityHub::Standard
    Properties:
      StandardsArn: !Sub 'arn:aws:securityhub:${AWS::Region}::standards/aws-foundational-security-best-practices/v/1.0.0'
```

```bash
# Deploy via StackSet to all accounts
aws cloudformation create-stack-set \
  --stack-set-name SecurityHub-Enable \
  --template-body file://security-hub-enable.yaml \
  --capabilities CAPABILITY_IAM \
  --permission-model SERVICE_MANAGED \
  --auto-deployment Enabled=true,RetainStacksOnAccountRemoval=false

# Add stack instances for all OUs
aws cloudformation create-stack-instances \
  --stack-set-name SecurityHub-Enable \
  --deployment-targets OrganizationalUnitIds=$WORKLOADS_OU \
  --regions us-east-1
```

### Exercise 5.2: Enable GuardDuty

```bash
# In Security account - enable as delegated admin
aws guardduty enable-organization-admin-account \
  --admin-account-id $AUDIT_ACCOUNT_ID

# In Audit account - enable GuardDuty
DETECTOR_ID=$(aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES \
  --query 'DetectorId' \
  --output text)

# Enable for organization
aws guardduty create-members \
  --detector-id $DETECTOR_ID \
  --account-details \
    AccountId=$PROD_ACCOUNT_ID,Email=prod@example.com \
    AccountId=$DEV_ACCOUNT_ID,Email=dev@example.com

# Auto-enable for new accounts
aws guardduty update-organization-configuration \
  --detector-id $DETECTOR_ID \
  --auto-enable
```

### Exercise 5.3: AWS Config Conformance Packs

```bash
# Deploy conformance pack across organization
cat > cis-conformance-pack.yaml <<'EOF'
Resources:
  CISConformancePack:
    Type: AWS::Config::ConformancePack
    Properties:
      ConformancePackName: cis-aws-foundations-benchmark
      DeliveryS3Bucket: !Ref ConfigBucket
      TemplateS3Uri: s3://aws-config-conformance-packs-us-east-1/cis-aws-foundations-benchmark-conformance-pack.yaml

  ConfigBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub 'config-conformance-${AWS::AccountId}'
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
EOF

aws cloudformation create-stack-set \
  --stack-set-name Config-CIS-Pack \
  --template-body file://cis-conformance-pack.yaml \
  --capabilities CAPABILITY_IAM
```

### Exercise 5.4: Enable Amazon Macie

```bash
# In Security account
aws macie2 enable-macie

# Enable for organization
aws macie2 enable-organization-admin-account \
  --admin-account-id $AUDIT_ACCOUNT_ID

# Create classification job for S3 buckets
cat > macie-job.json <<'EOF'
{
  "clientToken": "discovery-job-1",
  "jobType": "ONE_TIME",
  "name": "S3-Sensitive-Data-Discovery",
  "s3JobDefinition": {
    "bucketDefinitions": [
      {
        "accountId": "123456789012",
        "buckets": ["*"]
      }
    ]
  },
  "managedDataIdentifierIds": [
    "SSN",
    "CREDIT_CARD",
    "AWS_CREDENTIALS"
  ]
}
EOF

aws macie2 create-classification-job \
  --cli-input-json file://macie-job.json
```

### Exercise 5.5: Centralized Logging

```bash
# S3 bucket for centralized logs (in Log Archive account)
cat > central-logging-bucket.yaml <<'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  LogBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub 'landing-zone-logs-${AWS::AccountId}'
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
      VersioningConfiguration:
        Status: Enabled
      LifecycleConfiguration:
        Rules:
          - Id: TransitionToIA
            Status: Enabled
            Transitions:
              - TransitionInDays: 90
                StorageClass: STANDARD_IA
          - Id: TransitionToGlacier
            Status: Enabled
            Transitions:
              - TransitionInDays: 365
                StorageClass: GLACIER
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

  LogBucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref LogBucket
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Sid: AWSCloudTrailAclCheck
            Effect: Allow
            Principal:
              Service: cloudtrail.amazonaws.com
            Action: 's3:GetBucketAcl'
            Resource: !GetAtt LogBucket.Arn
          - Sid: AWSCloudTrailWrite
            Effect: Allow
            Principal:
              Service: cloudtrail.amazonaws.com
            Action: 's3:PutObject'
            Resource: !Sub '${LogBucket.Arn}/*'
            Condition:
              StringEquals:
                's3:x-amz-acl': 'bucket-owner-full-control'
          - Sid: AWSConfigBucketPermissionsCheck
            Effect: Allow
            Principal:
              Service: config.amazonaws.com
            Action: 's3:GetBucketAcl'
            Resource: !GetAtt LogBucket.Arn
          - Sid: AWSConfigBucketExistenceCheck
            Effect: Allow
            Principal:
              Service: config.amazonaws.com
            Action: 's3:ListBucket'
            Resource: !GetAtt LogBucket.Arn
          - Sid: AWSConfigWrite
            Effect: Allow
            Principal:
              Service: config.amazonaws.com
            Action: 's3:PutObject'
            Resource: !Sub '${LogBucket.Arn}/*'

Outputs:
  LogBucketName:
    Value: !Ref LogBucket
    Export:
      Name: Central-Log-Bucket
EOF
```

**📝 Daily Summary:**
- Security Hub provides centralized security view
- GuardDuty detects threats
- Config tracks compliance
- Macie discovers sensitive data
- All logs flow to Log Archive account

---

## Day 6: Guardrails & Policies

**Learning Objectives:**
- Understand preventive vs detective guardrails
- Implement custom guardrails
- Create tag policies
- Enforce compliance

### Exercise 6.1: Review Control Tower Guardrails

```bash
# List enabled guardrails
# Console: Control Tower > Guardrails

# Key mandatory guardrails:
# - Disallow changes to CloudTrail
# - Disallow deletion of log archive
# - Detect CloudTrail disabled
# - Detect root account usage

# Check guardrail compliance
# Console: Control Tower > Guardrails > Select guardrail
# View: Enabled status, Enforcement status, Accounts in violation
```

### Exercise 6.2: Enable Strongly Recommended Guardrails

```bash
# Enable via Console:
# Control Tower > Guardrails > Select guardrail > Enable

# Recommended to enable:
# - Detect Whether MFA for Root is Enabled
# - Detect Whether Public Read Access to S3 Buckets is Allowed
# - Detect Whether Public Write Access to S3 Buckets is Allowed
# - Detect Whether Encryption is Enabled for EBS Volumes
# - Detect Whether Amazon RDS Snapshots are Public

# Via AWS SDK (example)
aws controltower enable-control \
  --control-identifier "arn:aws:controltower:us-east-1::control/AWS-GR_MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS" \
  --target-identifier "arn:aws:organizations::$ACCOUNT_ID:ou/o-xxxxx/ou-xxxxx"
```

### Exercise 6.3: Create Custom Guardrail (SCP-based)

**Prevent Creation of Default VPCs:**
```bash
cat > prevent-default-vpc-scp.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PreventDefaultVPCCreation",
      "Effect": "Deny",
      "Action": [
        "ec2:CreateDefaultVpc",
        "ec2:CreateDefaultSubnet"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws organizations create-policy \
  --content file://prevent-default-vpc-scp.json \
  --description "Prevent default VPC creation" \
  --name PreventDefaultVPC \
  --type SERVICE_CONTROL_POLICY

# Attach to Workloads OU
POLICY_ID=$(aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY \
  --query "Policies[?Name=='PreventDefaultVPC'].Id" \
  --output text)

aws organizations attach-policy \
  --policy-id $POLICY_ID \
  --target-id $WORKLOADS_OU
```

**Enforce IMDSv2 on EC2:**
```bash
cat > enforce-imdsv2-scp.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnforceIMDSv2",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringNotEquals": {
          "ec2:MetadataHttpTokens": "required"
        }
      }
    }
  ]
}
EOF

aws organizations create-policy \
  --content file://enforce-imdsv2-scp.json \
  --description "Enforce IMDSv2 on all EC2 instances" \
  --name EnforceIMDSv2 \
  --type SERVICE_CONTROL_POLICY
```

### Exercise 6.4: Tag Policies

```bash
# Enable tag policies
aws organizations enable-policy-type \
  --root-id $ROOT_ID \
  --policy-type TAG_POLICY

# Create tag policy
cat > tag-policy.json <<'EOF'
{
  "tags": {
    "Environment": {
      "tag_key": {
        "@@assign": "Environment"
      },
      "tag_value": {
        "@@assign": [
          "Production",
          "Staging",
          "Development",
          "Sandbox"
        ]
      },
      "enforced_for": {
        "@@assign": [
          "ec2:instance",
          "ec2:volume",
          "s3:bucket",
          "rds:db"
        ]
      }
    },
    "CostCenter": {
      "tag_key": {
        "@@assign": "CostCenter"
      },
      "enforced_for": {
        "@@assign": [
          "ec2:instance",
          "s3:bucket"
        ]
      }
    },
    "Owner": {
      "tag_key": {
        "@@assign": "Owner"
      },
      "enforced_for": {
        "@@assign": [
          "ec2:instance"
        ]
      }
    }
  }
}
EOF

aws organizations create-policy \
  --content file://tag-policy.json \
  --description "Required tags for resources" \
  --name RequiredTags \
  --type TAG_POLICY

# Attach to root (applies to all accounts)
TAG_POLICY_ID=$(aws organizations list-policies \
  --filter TAG_POLICY \
  --query "Policies[?Name=='RequiredTags'].Id" \
  --output text)

aws organizations attach-policy \
  --policy-id $TAG_POLICY_ID \
  --target-id $ROOT_ID
```

### Exercise 6.5: Config Rules for Compliance

**Deploy Custom Config Rules:**
```yaml
# config-rules.yaml
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  RequiredTagsRule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: required-tags
      Description: Checks if resources have required tags
      Source:
        Owner: AWS
        SourceIdentifier: REQUIRED_TAGS
      InputParameters:
        tag1Key: Environment
        tag2Key: CostCenter
        tag3Key: Owner
      Scope:
        ComplianceResourceTypes:
          - AWS::EC2::Instance
          - AWS::S3::Bucket

  EncryptedVolumesRule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: encrypted-volumes
      Description: Checks if EBS volumes are encrypted
      Source:
        Owner: AWS
        SourceIdentifier: ENCRYPTED_VOLUMES

  S3BucketPublicReadRule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: s3-bucket-public-read-prohibited
      Description: Checks if S3 buckets allow public read
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_PUBLIC_READ_PROHIBITED

  RDSEncryptionRule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: rds-storage-encrypted
      Description: Checks if RDS instances are encrypted
      Source:
        Owner: AWS
        SourceIdentifier: RDS_STORAGE_ENCRYPTED

  # Auto-remediation for public S3 buckets
  S3RemediationConfig:
    Type: AWS::Config::RemediationConfiguration
    Properties:
      ConfigRuleName: !Ref S3BucketPublicReadRule
      TargetType: SSM_DOCUMENT
      TargetIdentifier: AWS-PublishSNSNotification
      TargetVersion: "1"
      Parameters:
        AutomationAssumeRole:
          StaticValue:
            Values:
              - !GetAtt RemediationRole.Arn
        TopicArn:
          StaticValue:
            Values:
              - !Ref SecurityAlertTopic
        Message:
          StaticValue:
            Values:
              - "S3 bucket with public read access detected"

  RemediationRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ssm.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole

  SecurityAlertTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: SecurityAlerts
      Subscription:
        - Endpoint: security@example.com
          Protocol: email
```

**Deploy via StackSet:**
```bash
aws cloudformation create-stack-set \
  --stack-set-name Config-Compliance-Rules \
  --template-body file://config-rules.yaml \
  --capabilities CAPABILITY_IAM

aws cloudformation create-stack-instances \
  --stack-set-name Config-Compliance-Rules \
  --deployment-targets OrganizationalUnitIds=$WORKLOADS_OU \
  --regions us-east-1 us-west-2
```

**📝 Daily Summary:**
- Preventive guardrails block actions (SCPs)
- Detective guardrails detect violations (Config rules)
- Tag policies enforce tagging standards
- Compliance tracked centrally in Security Hub
- Document all custom guardrails

---

## Day 7: Logging & Monitoring

**Learning Objectives:**
- Configure CloudTrail organization trail
- Set up centralized CloudWatch
- Implement VPC Flow Logs
- Create security dashboards

### Exercise 7.1: Organization CloudTrail

```bash
# CloudTrail is automatically created by Control Tower
# Verify organization trail exists

aws cloudtrail describe-trails

# Should see trail with:
# - IsOrganizationTrail: true
# - S3BucketName: aws-controltower-logs-*
# - IsMultiRegionTrail: true

# Enable CloudTrail Insights (optional, $0.35 per 100k events)
aws cloudtrail put-insight-selectors \
  --trail-name aws-controltower-BaselineCloudTrail \
  --insight-selectors '[{"InsightType": "ApiCallRateInsight"}]'
```

### Exercise 7.2: VPC Flow Logs

**Enable for All VPCs:**
```yaml
# vpc-flow-logs.yaml
AWSTemplateFormatVersion: '2010-09-09'
Parameters:
  VpcId:
    Type: String
  
  RetentionDays:
    Type: Number
    Default: 30

Resources:
  FlowLogsGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/vpc/flowlogs/${VpcId}'
      RetentionInDays: !Ref RetentionDays

  FlowLogsRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: vpc-flow-logs.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: CloudWatchLogPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                  - logs:DescribeLogGroups
                  - logs:DescribeLogStreams
                Resource: !GetAtt FlowLogsGroup.Arn

  VPCFlowLog:
    Type: AWS::EC2::FlowLog
    Properties:
      ResourceType: VPC
      ResourceIds:
        - !Ref VpcId
      TrafficType: ALL
      LogDestinationType: cloud-watch-logs
      LogGroupName: !Ref FlowLogsGroup
      DeliverLogsPermissionArn: !GetAtt FlowLogsRole.Arn
      LogFormat: '${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${start} ${end} ${action} ${log-status}'
      Tags:
        - Key: Name
          Value: !Sub '${VpcId}-FlowLogs'

Outputs:
  LogGroupName:
    Value: !Ref FlowLogsGroup
```

### Exercise 7.3: Centralized CloudWatch Logs

**Set up Cross-Account Log Aggregation:**
```bash
# In Log Archive account, create destination

# Create destination role
cat > log-destination-role.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

LOG_ROLE_ARN=$(aws iam create-role \
  --role-name CloudWatchLogsDestinationRole \
  --assume-role-policy-document file://log-destination-role.json \
  --query 'Role.Arn' \
  --output text)

# Create destination policy
cat > log-destination-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:us-east-1:$LOG_ARCHIVE_ACCOUNT_ID:log-group:/aws/central-logs:*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name CloudWatchLogsDestinationRole \
  --policy-name LogDestinationPolicy \
  --policy-document file://log-destination-policy.json

# Create log group
aws logs create-log-group \
  --log-group-name /aws/central-logs

# Create destination
DESTINATION_ARN=$(aws logs put-destination \
  --destination-name CentralLogDestination \
  --target-arn "arn:aws:logs:us-east-1:$LOG_ARCHIVE_ACCOUNT_ID:log-group:/aws/central-logs" \
  --role-arn $LOG_ROLE_ARN \
  --query 'destination.arn' \
  --output text)

# Set destination policy (allow all org accounts)
cat > destination-access-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "logs:PutSubscriptionFilter",
      "Resource": "$DESTINATION_ARN",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalOrgID": "$ORG_ID"
        }
      }
    }
  ]
}
EOF

aws logs put-destination-policy \
  --destination-name CentralLogDestination \
  --access-policy file://destination-access-policy.json
```

**Configure Subscription Filters (in spoke accounts):**
```bash
# In each workload account, create subscription filter
aws logs put-subscription-filter \
  --log-group-name /aws/lambda/my-function \
  --filter-name SendToCentral \
  --filter-pattern "" \
  --destination-arn $DESTINATION_ARN
```

### Exercise 7.4: CloudWatch Dashboards

**Create Security Dashboard:**
```bash
cat > security-dashboard.json <<'EOF'
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          [ "AWS/SecurityHub", "ComplianceScore" ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "Security Hub Compliance Score"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          [ "AWS/GuardDuty", "HighSeverityFindings", { "stat": "Sum" } ],
          [ ".", "MediumSeverityFindings", { "stat": "Sum" } ],
          [ ".", "LowSeverityFindings", { "stat": "Sum" } ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "GuardDuty Findings"
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/cloudtrail/organization-trail'\n| fields @timestamp, userIdentity.principalId, eventName, errorCode\n| filter eventName = 'ConsoleLogin' and errorCode = 'Failed'\n| stats count() by userIdentity.principalId",
        "region": "us-east-1",
        "title": "Failed Console Logins (Last Hour)",
        "stacked": false
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/cloudtrail/organization-trail'\n| fields @timestamp, userIdentity.principalId, eventName\n| filter userIdentity.type = 'Root'\n| stats count() by eventName",
        "region": "us-east-1",
        "title": "Root Account Activity"
      }
    }
  ]
}
EOF

aws cloudwatch put-dashboard \
  --dashboard-name SecurityOverview \
  --dashboard-body file://security-dashboard.json
```

### Exercise 7.5: EventBridge Rules for Security Events

```yaml
# security-event-rules.yaml
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  RootAccountUsageRule:
    Type: AWS::Events::Rule
    Properties:
      Name: RootAccountUsage
      Description: Alert on root account usage
      EventPattern:
        detail-type:
          - AWS API Call via CloudTrail
        detail:
          userIdentity:
            type:
              - Root
      State: ENABLED
      Targets:
        - Arn: !Ref SecurityAlertTopic
          Id: SecurityTopic

  UnauthorizedAPICallsRule:
    Type: AWS::Events::Rule
    Properties:
      Name: UnauthorizedAPICalls
      EventPattern:
        detail-type:
          - AWS API Call via CloudTrail
        detail:
          errorCode:
            - "*UnauthorizedOperation"
            - "AccessDenied*"
      State: ENABLED
      Targets:
        - Arn: !Ref SecurityAlertTopic
          Id: SecurityTopic

  SecurityGroupChangesRule:
    Type: AWS::Events::Rule
    Properties:
      Name: SecurityGroupChanges
      EventPattern:
        detail-type:
          - AWS API Call via CloudTrail
        detail:
          eventSource:
            - ec2.amazonaws.com
          eventName:
            - AuthorizeSecurityGroupIngress
            - AuthorizeSecurityGroupEgress
            - RevokeSecurityGroupIngress
            - RevokeSecurityGroupEgress
            - CreateSecurityGroup
            - DeleteSecurityGroup
      State: ENABLED
      Targets:
        - Arn: !Ref SecurityAlertTopic
          Id: SecurityTopic

  IAMPolicyChangesRule:
    Type: AWS::Events::Rule
    Properties:
      Name: IAMPolicyChanges
      EventPattern:
        detail-type:
          - AWS API Call via CloudTrail
        detail:
          eventSource:
            - iam.amazonaws.com
          eventName:
            - DeleteGroupPolicy
            - DeleteRolePolicy
            - DeleteUserPolicy
            - PutGroupPolicy
            - PutRolePolicy
            - PutUserPolicy
            - CreatePolicy
            - DeletePolicy
            - CreatePolicyVersion
            - DeletePolicyVersion
            - AttachRolePolicy
            - DetachRolePolicy
            - AttachUserPolicy
            - DetachUserPolicy
            - AttachGroupPolicy
            - DetachGroupPolicy
      State: ENABLED
      Targets:
        - Arn: !Ref SecurityAlertTopic
          Id: SecurityTopic

  SecurityAlertTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: SecurityAlerts
      Subscription:
        - Endpoint: security-team@example.com
          Protocol: email

  SecurityAlertTopicPolicy:
    Type: AWS::SNS::TopicPolicy
    Properties:
      Topics:
        - !Ref SecurityAlertTopic
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: events.amazonaws.com
            Action: sns:Publish
            Resource: !Ref SecurityAlertTopic
```

**📝 Daily Summary:**
- CloudTrail captures all API calls organization-wide
- VPC Flow Logs track network traffic
- Centralized CloudWatch aggregates logs
- EventBridge alerts on security events
- Dashboards provide visibility

---

## Day 8: Identity & Access Management

**Learning Objectives:**
- Configure AWS SSO
- Implement permission sets
- Set up cross-account roles
- Enforce MFA

### Exercise 8.1: AWS SSO Configuration

```bash
# SSO is automatically configured by Control Tower
# Access SSO Console

# Get SSO instance details
aws sso-admin list-instances

# Note the Instance ARN and Identity Store ID
SSO_INSTANCE_ARN=$(aws sso-admin list-instances \
  --query 'Instances[0].InstanceArn' \
  --output text)

IDENTITY_STORE_ID=$(aws sso-admin list-instances \
  --query 'Instances[0].IdentityStoreId' \
  --output text)
```

### Exercise 8.2: Create Permission Sets

**ReadOnly Permission Set:**
```bash
# Create permission set
READONLY_PS_ARN=$(aws sso-admin create-permission-set \
  --instance-arn $SSO_INSTANCE_ARN \
  --name ReadOnlyAccess \
  --description "Read-only access across all services" \
  --session-duration PT8H \
  --query 'PermissionSet.PermissionSetArn' \
  --output text)

# Attach AWS managed policy
aws sso-admin attach-managed-policy-to-permission-set \
  --instance-arn $SSO_INSTANCE_ARN \
  --permission-set-arn $READONLY_PS_ARN \
  --managed-policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
```

**PowerUser Permission Set:**
```bash
POWERUSER_PS_ARN=$(aws sso-admin create-permission-set \
  --instance-arn $SSO_INSTANCE_ARN \
  --name PowerUserAccess \
  --description "Power user access (no IAM)" \
  --session-duration PT8H \
  --query 'PermissionSet.PermissionSetArn' \
  --output text)

aws sso-admin attach-managed-policy-to-permission-set \
  --instance-arn $SSO_INSTANCE_ARN \
  --permission-set-arn $POWERUSER_PS_ARN \
  --managed-policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

**Custom DeveloperAccess Permission Set:**
```bash
DEVELOPER_PS_ARN=$(aws sso-admin create-permission-set \
  --instance-arn $SSO_INSTANCE_ARN \
  --name DeveloperAccess \
  --description "Developer access with specific permissions" \
  --session-duration PT8H \
  --query 'PermissionSet.PermissionSetArn' \
  --output text)

# Create inline policy
cat > developer-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "s3:*",
        "lambda:*",
        "dynamodb:*",
        "rds:*",
        "cloudformation:*",
        "cloudwatch:*",
        "logs:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "ec2:*ReservedInstances*",
        "rds:*ReservedDBInstances*",
        "iam:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws sso-admin put-inline-policy-to-permission-set \
  --instance-arn $SSO_INSTANCE_ARN \
  --permission-set-arn $DEVELOPER_PS_ARN \
  --inline-policy file://developer-policy.json
```

### Exercise 8.3: Create SSO Groups and Assignments

```bash
# Create groups in Identity Center
# Console: AWS SSO > Groups > Create group

# Groups to create:
# - Administrators
# - Developers
# - ReadOnly
# - SecurityAuditors

# Get group IDs
ADMIN_GROUP_ID=$(aws identitystore list-groups \
  --identity-store-id $IDENTITY_STORE_ID \
  --filters AttributePath=DisplayName,AttributeValue=Administrators \
  --query 'Groups[0].GroupId' \
  --output text)

DEV_GROUP_ID=$(aws identitystore list-groups \
  --identity-store-id $IDENTITY_STORE_ID \
  --filters AttributePath=DisplayName,AttributeValue=Developers \
  --query 'Groups[0].GroupId' \
  --output text)

# Assign groups to accounts
# Admins get AdministratorAccess in all accounts
aws sso-admin create-account-assignment \
  --instance-arn $SSO_INSTANCE_ARN \
  --target-type AWS_ACCOUNT \
  --target-id $PROD_ACCOUNT_ID \
  --permission-set-arn <admin-permission-set-arn> \
  --principal-type GROUP \
  --principal-id $ADMIN_GROUP_ID

# Developers get DeveloperAccess in Dev/Staging
aws sso-admin create-account-assignment \
  --instance-arn $SSO_INSTANCE_ARN \
  --target-type AWS_ACCOUNT \
  --target-id $DEV_ACCOUNT_ID \
  --permission-set-arn $DEVELOPER_PS_ARN \
  --principal-type GROUP \
  --principal-id $DEV_GROUP_ID
```

### Exercise 8.4: Cross-Account IAM Roles

**Create Role in Spoke Account:**
```yaml
# cross-account-role.yaml
AWSTemplateFormatVersion: '2010-09-09'
Parameters:
  TrustedAccountId:
    Type: String
    Description: Account ID that can assume this role

Resources:
  CrossAccountRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: CrossAccountAdminRole
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${TrustedAccountId}:root'
            Action: sts:AssumeRole
            Condition:
              Bool:
                aws:MultiFactorAuthPresent: true
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AdministratorAccess
      MaxSessionDuration: 28800  # 8 hours

Outputs:
  RoleArn:
    Value: !GetAtt CrossAccountRole.Arn
```

**Assume Role Script:**
```bash
#!/bin/bash
# assume-role.sh

ROLE_ARN=$1
SESSION_NAME=${2:-cli-session}
MFA_DEVICE=$3
MFA_TOKEN=$4

if [ -z "$MFA_TOKEN" ]; then
  echo "Usage: ./assume-role.sh <role-arn> [session-name] <mfa-device> <mfa-token>"
  exit 1
fi

CREDENTIALS=$(aws sts assume-role \
  --role-arn $ROLE_ARN \
  --role-session-name $SESSION_NAME \
  --serial-number $MFA_DEVICE \
  --token-code $MFA_TOKEN \
  --duration-seconds 28800)

export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Credentials.SessionToken')

echo "Role assumed successfully. Credentials exported."
```

### Exercise 8.5: Enforce MFA

**SCP to Require MFA:**
```bash
cat > require-mfa-scp.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllExceptListedIfNoMFA",
      "Effect": "Deny",
      "NotAction": [
        "iam:CreateVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:GetUser",
        "iam:ListMFADevices",
        "iam:ListVirtualMFADevices",
        "iam:ResyncMFADevice",
        "sts:GetSessionToken",
        "iam:ChangePassword"
      ],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
EOF

aws organizations create-policy \
  --content file://require-mfa-scp.json \
  --description "Require MFA for all actions" \
  --name RequireMFA \
  --type SERVICE_CONTROL_POLICY
```

**📝 Daily Summary:**
- AWS SSO provides centralized access management
- Permission sets define what users can do
- Groups simplify assignment management
- Cross-account roles enable secure access
- MFA should be enforced via SCP

---

## Day 9: Cost Management

**Learning Objectives:**
- Set up Cost Explorer
- Configure budgets and alerts
- Implement cost allocation tags
- Use AWS Organizations billing

### Exercise 9.1: Enable Cost Explorer

```bash
# Enable Cost Explorer (management account only)
# Console: Billing > Cost Explorer > Enable Cost Explorer

# Takes 24 hours for initial data

# Enable AWS Cost and Usage Report
aws cur put-report-definition \
  --report-definition '{
    "ReportName": "organization-cost-report",
    "TimeUnit": "HOURLY",
    "Format": "Parquet",
    "Compression": "Parquet",
    "AdditionalSchemaElements": ["RESOURCES"],
    "S3Bucket": "cur-reports-'$MANAGEMENT_ACCOUNT_ID'",
    "S3Prefix": "cur",
    "S3Region": "us-east-1",
    "AdditionalArtifacts": ["ATHENA"],
    "RefreshClosedReports": true,
    "ReportVersioning": "OVERWRITE_REPORT"
  }'
```

### Exercise 9.2: Create Budgets

**Monthly Cost Budget:**
```bash
cat > monthly-budget.json <<'EOF'
{
  "BudgetName": "MonthlyOrgBudget",
  "BudgetLimit": {
    "Amount": "1000",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {},
  "CostTypes": {
    "IncludeTax": true,
    "IncludeSubscription": true,
    "UseBlended": false,
    "IncludeRefund": false,
    "IncludeCredit": false,
    "IncludeUpfront": true,
    "IncludeRecurring": true,
    "IncludeOtherSubscription": true,
    "IncludeSupport": true,
    "IncludeDiscount": true,
    "UseAmortized": false
  }
}
EOF

cat > budget-notifications.json <<'EOF'
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "finance@example.com"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "finance@example.com"
      },
      {
        "SubscriptionType": "EMAIL",
        "Address": "cto@example.com"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "FORECASTED",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "finance@example.com"
      }
    ]
  }
]
EOF

aws budgets create-budget \
  --account-id $MANAGEMENT_ACCOUNT_ID \
  --budget file://monthly-budget.json \
  --notifications-with-subscribers file://budget-notifications.json
```

**Per-Account Budgets:**
```bash
# Create budget for each workload account
for ACCOUNT_ID in $PROD_ACCOUNT_ID $STAGING_ACCOUNT_ID $DEV_ACCOUNT_ID; do
  cat > account-budget-$ACCOUNT_ID.json <<EOF
{
  "BudgetName": "Account-$ACCOUNT_ID-Budget",
  "BudgetLimit": {
    "Amount": "200",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {
    "LinkedAccount": ["$ACCOUNT_ID"]
  }
}
EOF

  aws budgets create-budget \
    --account-id $MANAGEMENT_ACCOUNT_ID \
    --budget file://account-budget-$ACCOUNT_ID.json \
    --notifications-with-subscribers file://budget-notifications.json
done
```

### Exercise 9.3: Cost Allocation Tags

```bash
# Activate cost allocation tags (management account)
aws ce update-cost-allocation-tags-status \
  --cost-allocation-tags-status \
    TagKey=Environment,Status=Active \
    TagKey=CostCenter,Status=Active \
    TagKey=Owner,Status=Active \
    TagKey=Project,Status=Active

# Takes 24 hours to appear in Cost Explorer

# Create tag policy (if not done in Day 6)
# See Day 6 Exercise 6.4
```

### Exercise 9.4: Savings Plans / Reserved Instances

```bash
# View RI/SP recommendations
aws ce get-reservation-purchase-recommendation \
  --service "Amazon Elastic Compute Cloud - Compute" \
  --lookback-period-in-days SIXTY_DAYS \
  --term-in-years ONE_YEAR \
  --payment-option NO_UPFRONT

# View Savings Plans recommendations
aws ce get-savings-plans-purchase-recommendation \
  --lookback-period-in-days SIXTY_DAYS \
  --term-in-years ONE_YEAR \
  --payment-option NO_UPFRONT \
  --savings-plans-type COMPUTE_SP
```

### Exercise 9.5: Cost Anomaly Detection

```bash
# Create cost anomaly monitor
MONITOR_ARN=$(aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "OrganizationCostMonitor",
    "MonitorType": "DIMENSIONAL",
    "MonitorDimension": "SERVICE"
  }' \
  --query 'MonitorArn' \
  --output text)

# Create anomaly subscription
aws ce create-anomaly-subscription \
  --anomaly-subscription '{
    "SubscriptionName": "CostAnomalyAlerts",
    "Threshold": 100,
    "Frequency": "DAILY",
    "MonitorArnList": ["'$MONITOR_ARN'"],
    "Subscribers": [
      {
        "Type": "EMAIL",
        "Address": "finance@example.com"
      }
    ]
  }'
```

**📝 Daily Summary:**
- Cost Explorer provides visibility
- Budgets alert before overspending
- Cost allocation tags enable chargeback
- Anomaly detection catches unexpected spikes
- Document monthly cost review process

---

## Day 10: Compliance & Governance

**Learning Objectives:**
- Implement AWS Audit Manager
- Configure Backup policies
- Set up Patch Manager
- Enforce encryption standards

### Exercise 10.1: AWS Audit Manager

```bash
# Enable Audit Manager in Audit account
aws auditmanager register-account \
  --delegated-admin-account $AUDIT_ACCOUNT_ID

# Create assessment for CIS AWS Foundations
FRAMEWORK_ID=$(aws auditmanager list-assessment-frameworks \
  --framework-type Standard \
  --query 'frameworkMetadataList[?name==`CIS AWS Foundations Benchmark v1.2.0`].id' \
  --output text)

aws auditmanager create-assessment \
  --name "CIS-Compliance-Assessment" \
  --description "Monthly CIS compliance check" \
  --framework-id $FRAMEWORK_ID \
  --assessment-reports-destination '{
    "destinationType": "S3",
    "destination": "s3://audit-reports-'$AUDIT_ACCOUNT_ID'/audit-manager"
  }' \
  --scope '{
    "awsAccounts": [
      {"id": "'$PROD_ACCOUNT_ID'"},
      {"id": "'$STAGING_ACCOUNT_ID'"}
    ],
    "awsServices": [
      {"serviceName": "ec2"},
      {"serviceName": "s3"},
      {"serviceName": "iam"},
      {"serviceName": "cloudtrail"}
    ]
  }' \
  --roles '[{
    "roleType": "PROCESS_OWNER",
    "roleArn": "arn:aws:iam::'$AUDIT_ACCOUNT_ID':role/AuditManagerRole"
  }]'
```

### Exercise 10.2: AWS Backup Organization Policies

```yaml
# backup-policy.yaml
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  BackupVault:
    Type: AWS::Backup::BackupVault
    Properties:
      BackupVaultName: DefaultBackupVault
      EncryptionKeyArn: !GetAtt BackupKey.Arn

  BackupKey:
    Type: AWS::KMS::Key
    Properties:
      KeyPolicy:
        Version: '2012-10-17'
        Statement:
          - Sid: Enable IAM User Permissions
            Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: 'kms:*'
            Resource: '*'
          - Sid: Allow Backup Service
            Effect: Allow
            Principal:
              Service: backup.amazonaws.com
            Action:
              - 'kms:CreateGrant'
              - 'kms:Decrypt'
              - 'kms:DescribeKey'
              - 'kms:Encrypt'
              - 'kms:GenerateDataKey'
              - 'kms:ReEncrypt*'
            Resource: '*'

  DailyBackupPlan:
    Type: AWS::Backup::BackupPlan
    Properties:
      BackupPlan:
        BackupPlanName: DailyBackupPlan
        BackupPlanRule:
          - RuleName: DailyBackup
            TargetBackupVault: !Ref BackupVault
            ScheduleExpression: "cron(0 5 ? * * *)"
            StartWindowMinutes: 60
            CompletionWindowMinutes: 120
            Lifecycle:
              DeleteAfterDays: 30
              MoveToColdStorageAfterDays: 7

  BackupSelection:
    Type: AWS::Backup::BackupSelection
    Properties:
      BackupPlanId: !Ref DailyBackupPlan
      BackupSelection:
        SelectionName: AllEC2AndRDS
        IamRoleArn: !GetAtt BackupRole.Arn
        Resources:
          - "arn:aws:ec2:*:*:volume/*"
          - "arn:aws:rds:*:*:db:*"
        Conditions:
          StringEquals:
            - ConditionKey: "aws:ResourceTag/BackupEnabled"
              ConditionValue: "true"

  BackupRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: backup.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup
        - arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores
```

**Deploy via StackSet:**
```bash
aws cloudformation create-stack-set \
  --stack-set-name Backup-Policy \
  --template-body file://backup-policy.yaml \
  --capabilities CAPABILITY_IAM

aws cloudformation create-stack-instances \
  --stack-set-name Backup-Policy \
  --deployment-targets OrganizationalUnitIds=$WORKLOADS_OU \
  --regions us-east-1
```

### Exercise 10.3: Systems Manager Patch Manager

```bash
# Create patch baseline
aws ssm create-patch-baseline \
  --name "Production-Baseline" \
  --operating-system AMAZON_LINUX_2 \
  --approval-rules '{
    "PatchRules": [
      {
        "PatchFilterGroup": {
          "PatchFilters": [
            {
              "Key": "CLASSIFICATION",
              "Values": ["Security", "Bugfix", "Enhancement"]
            },
            {
              "Key": "SEVERITY",
              "Values": ["Critical", "Important"]
            }
          ]
        },
        "ApproveAfterDays": 7,
        "ComplianceLevel": "CRITICAL",
        "EnableNonSecurity": false
      }
    ]
  }' \
  --description "Production patch baseline - 7 day approval"

# Create maintenance window
aws ssm create-maintenance-window \
  --name "Weekly-Patching-Window" \
  --description "Sunday 2 AM - 4 AM patching window" \
  --schedule "cron(0 2 ? * SUN *)" \
  --duration 2 \
  --cutoff 0 \
  --allow-unassociated-targets

# Register targets (instances with tag PatchGroup=Production)
aws ssm register-target-with-maintenance-window \
  --window-id <window-id> \
  --target-type INSTANCE \
  --resource-type INSTANCE \
  --targets "Key=tag:PatchGroup,Values=Production"

# Register patch task
aws ssm register-task-with-maintenance-window \
  --window-id <window-id> \
  --targets "Key=WindowTargetIds,Values=<target-id>" \
  --task-arn "AWS-RunPatchBaseline" \
  --service-role-arn <ssm-role-arn> \
  --task-type RUN_COMMAND \
  --max-concurrency 50% \
  --max-errors 0 \
  --priority 1 \
  --task-invocation-parameters '{
    "RunCommand": {
      "Parameters": {
        "Operation": ["Install"]
      }
    }
  }'
```

### Exercise 10.4: Encryption at Rest Policy

**SCP to Enforce Encryption:**
```bash
cat > enforce-encryption-scp.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedEBS",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:volume/*",
      "Condition": {
        "Bool": {
          "ec2:Encrypted": "false"
        }
      }
    },
    {
      "Sid": "DenyUnencryptedRDS",
      "Effect": "Deny",
      "Action": "rds:CreateDBInstance",
      "Resource": "*",
      "Condition": {
        "Bool": {
          "rds:StorageEncrypted": "false"
        }
      }
    },
    {
      "Sid": "DenyUnencryptedS3",
      "Effect": "Deny",
      "Action": "s3:PutObject",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": ["AES256", "aws:kms"]
        }
      }
    }
  ]
}
EOF

aws organizations create-policy \
  --content file://enforce-encryption-scp.json \
  --description "Enforce encryption at rest" \
  --name EnforceEncryption \
  --type SERVICE_CONTROL_POLICY
```

### Exercise 10.5: Compliance Reporting

**Lambda for Monthly Compliance Report:**
```python
# compliance-report-lambda.py
import boto3
import json
from datetime import datetime

securityhub = boto3.client('securityhub')
s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Get Security Hub compliance score
    findings = securityhub.get_findings(
        Filters={
            'ComplianceStatus': [
                {'Value': 'FAILED', 'Comparison': 'EQUALS'}
            ]
        }
    )
    
    # Get Config compliance
    config = boto3.client('config')
    compliance = config.describe_compliance_by_config_rule()
    
    # Generate report
    report = {
        'date': datetime.now().isoformat(),
        'security_hub_findings': len(findings['Findings']),
        'config_rules': {
            'compliant': len([r for r in compliance['ComplianceByConfigRules'] 
                            if r['Compliance']['ComplianceType'] == 'COMPLIANT']),
            'non_compliant': len([r for r in compliance['ComplianceByConfigRules'] 
                                if r['Compliance']['ComplianceType'] == 'NON_COMPLIANT'])
        }
    }
    
    # Upload to S3
    s3.put_object(
        Bucket='compliance-reports-bucket',
        Key=f"reports/{datetime.now().strftime('%Y-%m-%d')}-compliance.json",
        Body=json.dumps(report, indent=2)
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps(report)
    }
```

**📝 Daily Summary:**
- Audit Manager automates compliance assessments
- AWS Backup provides centralized backup management
- Patch Manager keeps systems updated
- Encryption policies enforced via SCP
- Regular compliance reporting essential

---

## Day 11: Disaster Recovery

**Learning Objectives:**
- Design DR strategy
- Test account recovery
- Backup critical resources
- Create runbooks

### Exercise 11.1: DR Strategy Design

**DR Strategy for Landing Zone:**
```
+-------------------------+
| Management Account (1)  |
+-------------------------+
        │
        ├─ Daily etcd-style backups of Organizations metadata
        ├─ CloudFormation templates version controlled
        └─ Terraform state in S3 with versioning

+-------------------------+
| Log Archive Account (2) |
+-------------------------+
        │
        ├─ S3 versioning enabled
        ├─ Cross-region replication to us-west-2
        └─ Lifecycle policies (Glacier after 90 days)

+-------------------------+
| Workload Accounts (N)   |
+-------------------------+
        │
        ├─ AWS Backup for EC2, RDS, EFS
        ├─ RDS automated backups + snapshots
        ├─ S3 versioning + cross-region replication
        └─ AMIs for critical instances
```

### Exercise 11.2: Backup Organizations Configuration

```python
# backup-org-config.py
import boto3
import json
from datetime import datetime

orgs = boto3.client('organizations')
s3 = boto3.client('s3')

def backup_organizations():
    backup = {
        'timestamp': datetime.now().isoformat(),
        'organization': orgs.describe_organization(),
        'accounts': orgs.list_accounts(),
        'ous': list_all_ous(orgs),
        'policies': list_all_policies(orgs)
    }
    
    # Upload to S3
    bucket = 'landing-zone-dr-backups'
    key = f"org-backups/{datetime.now().strftime('%Y-%m-%d')}-org-config.json"
    
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(backup, indent=2, default=str),
        ServerSideEncryption='AES256'
    )
    
    print(f"Backup saved to s3://{bucket}/{key}")

def list_all_ous(client):
    root_id = client.list_roots()['Roots'][0]['Id']
    ous = []
    
    def recurse_ous(parent_id):
        response = client.list_organizational_units_for_parent(ParentId=parent_id)
        for ou in response.get('OrganizationalUnits', []):
            ous.append(ou)
            recurse_ous(ou['Id'])
    
    recurse_ous(root_id)
    return ous

def list_all_policies(client):
    policies = {}
    for policy_type in ['SERVICE_CONTROL_POLICY', 'TAG_POLICY']:
        policies[policy_type] = []
        response = client.list_policies(Filter=policy_type)
        for policy in response.get('Policies', []):
            policy_detail = client.describe_policy(PolicyId=policy['Id'])
            policies[policy_type].append(policy_detail)
    return policies

if __name__ == '__main__':
    backup_organizations()
```

**Run Daily via Lambda:**
```yaml
# backup-lambda.yaml
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  BackupFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: OrgConfigBackup
      Runtime: python3.11
      Handler: index.lambda_handler
      Role: !GetAtt BackupRole.Arn
      Code:
        ZipFile: |
          # Insert backup-org-config.py code here
      Timeout: 300

  BackupSchedule:
    Type: AWS::Events::Rule
    Properties:
      ScheduleExpression: "cron(0 2 * * ? *)"
      Targets:
        - Arn: !GetAtt BackupFunction.Arn
          Id: BackupTarget

  BackupRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: OrgReadAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - organizations:Describe*
                  - organizations:List*
                Resource: "*"
              - Effect: Allow
                Action:
                  - s3:PutObject
                Resource: "arn:aws:s3:::landing-zone-dr-backups/*"
```

### Exercise 11.3: Account Recovery Procedure

**Document Recovery Runbook:**
```markdown
# Account Recovery Runbook

## Scenario: Lost Access to Management Account

### Prerequisites
- Root account email access
- Root account password
- MFA device (or recovery process)

### Recovery Steps

1. **Reset Root Password (if needed)**
   - Go to AWS Console login
   - Click "Forgot password"
   - Follow email instructions

2. **Reset MFA (if needed)**
   - Contact AWS Support
   - Provide account details
   - Follow identity verification process

3. **Restore Organizations Configuration**
   ```bash
   # Download latest backup
   aws s3 cp s3://landing-zone-dr-backups/org-backups/latest.json ./org-backup.json
   
   # Review configuration
   cat org-backup.json | jq '.ous'
   
   # Recreate OUs (if needed)
   python restore-org-structure.py --backup org-backup.json
   ```

4. **Verify Control Tower**
   - Check drift status
   - Run repair if needed
   - Validate guardrails

5. **Test Access**
   - Verify SSO portal
   - Test account access
   - Confirm guardrails active
```

### Exercise 11.4: DR Testing

**Quarterly DR Test Procedure:**
```bash
#!/bin/bash
# dr-test.sh

echo "=== DR Test Started: $(date) ==="

# 1. Verify backups are accessible
echo "Checking backups..."
aws s3 ls s3://landing-zone-dr-backups/org-backups/ | tail -5

# 2. Test organization backup
echo "Testing organization backup..."
aws s3 cp s3://landing-zone-dr-backups/org-backups/$(date +%Y-%m-%d)-org-config.json /tmp/test-backup.json
if [ $? -eq 0 ]; then
  echo "✓ Organization backup accessible"
else
  echo "✗ Organization backup FAILED"
  exit 1
fi

# 3. Verify cross-region replication
echo "Checking cross-region replication..."
PRIMARY_COUNT=$(aws s3 ls s3://landing-zone-logs-us-east-1/ --recursive | wc -l)
REPLICA_COUNT=$(aws s3 ls s3://landing-zone-logs-us-west-2/ --recursive | wc -l)
echo "Primary logs: $PRIMARY_COUNT, Replica logs: $REPLICA_COUNT"

# 4. Test account access
echo "Testing account access via SSO..."
for ACCOUNT in $PROD_ACCOUNT_ID $DEV_ACCOUNT_ID; do
  ROLE_ARN="arn:aws:iam::$ACCOUNT:role/AWSControlTowerExecution"
  aws sts assume-role --role-arn $ROLE_ARN --role-session-name dr-test > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "✓ Access to account $ACCOUNT successful"
  else
    echo "✗ Access to account $ACCOUNT FAILED"
  fi
done

# 5. Test restore procedure (non-destructive)
echo "Testing restore procedure (dry-run)..."
python restore-org-structure.py --backup /tmp/test-backup.json --dry-run

echo "=== DR Test Completed: $(date) ==="
```

### Exercise 11.5: Cross-Region Failover

**Set up S3 Cross-Region Replication:**
```yaml
# s3-crr.yaml
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  ReplicationRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: s3.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: ReplicationPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - s3:GetReplicationConfiguration
                  - s3:ListBucket
                Resource: !Sub 'arn:aws:s3:::landing-zone-logs-${AWS::AccountId}'
              - Effect: Allow
                Action:
                  - s3:GetObjectVersionForReplication
                  - s3:GetObjectVersionAcl
                Resource: !Sub 'arn:aws:s3:::landing-zone-logs-${AWS::AccountId}/*'
              - Effect: Allow
                Action:
                  - s3:ReplicateObject
                  - s3:ReplicateDelete
                Resource: !Sub 'arn:aws:s3:::landing-zone-logs-dr-${AWS::AccountId}/*'

  ReplicaBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub 'landing-zone-logs-dr-${AWS::AccountId}'
      VersioningConfiguration:
        Status: Enabled
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
```

**📝 Daily Summary:**
- DR strategy must cover all account types
- Regular backups of Organizations configuration
- Test recovery procedures quarterly
- Cross-region replication for critical data
- Document RTO/RPO for each component

---

## Day 12: Advanced Scenarios

**Learning Objectives:**
- Multi-region landing zone
- Account migration
- Troubleshooting Control Tower
- Scaling considerations

### Exercise 12.1: Multi-Region Extension

**Deploy Resources to Secondary Region:**
```bash
# Set up us-west-2 as secondary region

# 1. Enable CloudTrail in us-west-2
aws cloudtrail create-trail \
  --name organization-trail-west \
  --s3-bucket-name aws-controltower-logs-$ACCOUNT_ID \
  --is-organization-trail \
  --is-multi-region-trail \
  --region us-west-2

# 2. Enable Config in us-west-2 (via StackSet)
aws cloudformation create-stack-instances \
  --stack-set-name AWS-Landing-Zone-Baseline \
  --deployment-targets OrganizationalUnitIds=$ROOT_ID \
  --regions us-west-2

# 3. Deploy GuardDuty delegated admin in us-west-2
aws guardduty create-detector \
  --enable \
  --region us-west-2

# 4. Enable Security Hub in us-west-2
aws securityhub enable-security-hub \
  --region us-west-2
```

### Exercise 12.2: Migrate Existing Account

**Steps to Migrate Standalone Account:**
```bash
# 1. Prepare account
# - Remove any SCPs
# - Remove existing organizational memberships
# - Note account ID and root email

# 2. Send invitation from management account
aws organizations invite-account-to-organization \
  --target '{
    "Id": "'$EXISTING_ACCOUNT_ID'",
    "Type": "ACCOUNT"
  }' \
  --notes "Migrating to Landing Zone"

# 3. Accept invitation (in existing account)
INVITATION_ID=$(aws organizations list-handshakes-for-account \
  --query 'Handshakes[0].Id' \
  --output text)

aws organizations accept-handshake \
  --handshake-id $INVITATION_ID

# 4. Move to appropriate OU
aws organizations move-account \
  --account-id $EXISTING_ACCOUNT_ID \
  --source-parent-id $ROOT_ID \
  --destination-parent-id $WORKLOADS_OU

# 5. Enroll in Control Tower
# Console: Control Tower > Accounts > Enroll account
# Select account from dropdown
# Choose OU
# Wait 15-20 minutes

# 6. Apply baseline configuration
aws cloudformation create-stack-set-instance \
  --stack-set-name AWS-Landing-Zone-Baseline \
  --accounts $EXISTING_ACCOUNT_ID \
  --regions us-east-1
```

### Exercise 12.3: Control Tower Drift Detection

```bash
# Check for drift
# Console: Control Tower > Landing zone settings > Drift detected?

# Common drift causes:
# - Manual changes to baseline resources
# - Direct modifications to SCPs
# - Changes to CloudTrail
# - Config rule modifications

# Resolve drift
# Console: Control Tower > Landing zone settings > Resolve drift

# Or via CLI (repair specific OU)
# This isn't a direct CLI command - use Console

# Prevent drift with SCPs
cat > prevent-baseline-changes-scp.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PreventCloudTrailDeletion",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:DeleteTrail",
        "cloudtrail:StopLogging",
        "cloudtrail:UpdateTrail"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:ResourceTag/aws-control-tower": "*"
        }
      }
    }
  ]
}
EOF
```

### Exercise 12.4: Scaling to 100+ Accounts

**Automation Strategy:**
```python
# account-vending-automation.py
import boto3
import yaml
from datetime import datetime

servicecatalog = boto3.client('servicecatalog')
orgs = boto3.client('organizations')

def bulk_provision_accounts(config_file):
    """
    Provision multiple accounts from YAML config
    
    accounts.yaml:
    accounts:
      - name: "Team-A-Dev"
        email: "team-a-dev@example.com"
        ou: "Development"
        cost_center: "Engineering"
      - name: "Team-A-Prod"
        email: "team-a-prod@example.com"
        ou: "Production"
        cost_center: "Engineering"
    """
    
    with open(config_file) as f:
        config = yaml.safe_load(f)
    
    for account_config in config['accounts']:
        print(f"Provisioning {account_config['name']}...")
        
        # Get product ID for Account Factory
        product_id = get_account_factory_product_id()
        
        # Provision account
        response = servicecatalog.provision_product(
            ProductId=product_id,
            ProvisioningArtifactName='AWS Control Tower Account Factory',
            ProvisionedProductName=f"{account_config['name']}-{datetime.now().strftime('%Y%m%d')}",
            ProvisioningParameters=[
                {'Key': 'AccountEmail', 'Value': account_config['email']},
                {'Key': 'AccountName', 'Value': account_config['name']},
                {'Key': 'ManagedOrganizationalUnit', 'Value': account_config['ou']},
                {'Key': 'SSOUserEmail', 'Value': 'admin@example.com'},
                {'Key': 'SSOUserFirstName', 'Value': 'Admin'},
                {'Key': 'SSOUserLastName', 'Value': 'User'}
            ],
            Tags=[
                {'Key': 'CostCenter', 'Value': account_config['cost_center']},
                {'Key': 'ManagedBy', 'Value': 'Automation'}
            ]
        )
        
        print(f"  → Record ID: {response['RecordDetail']['RecordId']}")
        print(f"  → Status: {response['RecordDetail']['Status']}")

def get_account_factory_product_id():
    products = servicecatalog.search_products(
        Filters={'FullTextSearch': ['AWS Control Tower Account Factory']}
    )
    return products['ProductViewSummaries'][0]['ProductId']

if __name__ == '__main__':
    bulk_provision_accounts('accounts.yaml')
```

### Exercise 12.5: Troubleshooting Common Issues

**Issue 1: Account Factory Provisioning Failed**
```bash
# Check provision status
aws servicecatalog describe-record \
  --id <record-id>

# Common failures:
# - Email already in use
# - OU doesn't exist
# - SSO not configured
# - Service quota exceeded

# Check service quotas
aws service-quotas get-service-quota \
  --service-code organizations \
  --quota-code L-0C11B5E6  # Max accounts

# Request increase if needed
aws service-quotas request-service-quota-increase \
  --service-code organizations \
  --quota-code L-0C11B5E6 \
  --desired-value 200
```

**Issue 2: Guardrail Compliance Failure**
```bash
# Identify non-compliant resources
# Console: Control Tower > Guardrails > [Select guardrail]
# View accounts in violation

# For detective guardrails, check Config
aws configservice describe-compliance-by-config-rule \
  --compliance-types NON_COMPLIANT

# Remediate via Systems Manager Automation
# Or manually fix the violation
```

**Issue 3: SSO Access Not Working**
```bash
# Verify SSO status
aws sso-admin list-instances

# Check permission set assignments
aws sso-admin list-account-assignments \
  --instance-arn $SSO_INSTANCE_ARN \
  --account-id $ACCOUNT_ID

# Re-provision permission set if needed
aws sso-admin provision-permission-set \
  --instance-arn $SSO_INSTANCE_ARN \
  --permission-set-arn $PERMISSION_SET_ARN \
  --target-type AWS_ACCOUNT \
  --target-id $ACCOUNT_ID
```

**📝 Daily Summary:**
- Multi-region requires separate guardrail deployment
- Existing accounts can be migrated to Control Tower
- Drift detection prevents configuration divergence
- Automation essential for scale
- Document troubleshooting procedures

---

## Deep Interview Questions

### Architecture & Design (Advanced)

**Q1: Design a complete landing zone for a company with 3 business units, each needing dev/staging/prod environments. Include networking, security, and cost segregation.**

<details>
<summary>Click to see detailed answer</summary>

**Complete Architecture Design:**

### Organizational Structure
```
Root
├── Security OU
│   ├── Log Archive Account
│   ├── Security Tooling Account
│   └── Network Account
├── Infrastructure OU
│   ├── Shared Services Account
│   └── DNS Account
├── Business Unit A
│   ├── BU-A Production
│   ├── BU-A Staging
│   └── BU-A Development
├── Business Unit B
│   ├── BU-B Production
│   ├── BU-B Staging
│   └── BU-B Development
├── Business Unit C
│   ├── BU-C Production
│   ├── BU-C Staging
│   └── BU-C Development
└── Sandbox OU
```

### CIDR Allocation
```
Network Account: 10.0.0.0/16
  └── Transit Gateway subnets

Shared Services: 10.1.0.0/16
  ├── Active Directory: 10.1.0.0/24
  ├── DNS: 10.1.1.0/24
  └── NAT Gateway: 10.1.2.0/24

Business Unit A:
  ├── Production: 10.10.0.0/16
  ├── Staging: 10.11.0.0/16
  └── Development: 10.12.0.0/16

Business Unit B:
  ├── Production: 10.20.0.0/16
  ├── Staging: 10.21.0.0/16
  └── Development: 10.22.0.0/16

Business Unit C:
  ├── Production: 10.30.0.0/16
  ├── Staging: 10.31.0.0/16
  └── Development: 10.32.0.0/16
```

### Security Architecture

**1. Network Isolation:**
- Transit Gateway with separate route tables per environment
- Production route table: Only allows Shared Services + own environment
- Non-prod route tables: Allow cross-environment for testing
- Network ACLs at subnet level
- Security Groups at instance level

**2. IAM Structure:**
- AWS SSO with separate permission sets:
  - BU-A-Admin (only BU-A accounts)
  - BU-A-Developer (dev/staging only)
  - BU-A-ReadOnly (all BU-A accounts, read-only)
- Cross-account roles with MFA enforced
- Service-linked roles for AWS services

**3. SCPs Applied:**
```json
{
  "BU-A-OU": [
    "DenyNonApprovedRegions",
    "EnforceEncryption",
    "RequireMFA",
    "DenyRootAccountUsage",
    "PreventLeavingOrganization"
  ],
  "BU-A-Production": [
    "DenyInstanceTypeChanges",
    "DenyPublicS3Buckets",
    "RequireApprovedAMIs"
  ],
  "BU-A-Development": [
    "LimitInstanceTypes",
    "CostControlSCP"
  ]
}
```

### Cost Segregation

**1. Account-Level Segregation:**
- Each BU has separate accounts
- Consolidated billing in management account
- Cost allocation tags enforced:
  - BusinessUnit: BU-A, BU-B, BU-C
  - Environment: Production, Staging, Development
  - CostCenter: Maps to internal codes

**2. Budgets:**
- Organization-level: $100k/month
- BU-level: $30k/month each
- Environment-level:
  - Production: $15k/month
  - Staging: $5k/month
  - Development: $10k/month
- Alerts at 80%, 100%, 120%

**3. Cost Optimization:**
- Savings Plans purchased centrally, shared across BUs
- Reserved Instances per BU
- Auto-shutdown for dev/staging non-business hours
- S3 Intelligent-Tiering
- RDS scheduled stop/start for non-prod

### Logging & Monitoring

**1. Centralized Logging:**
```
Log Archive Account:
├── CloudTrail (all accounts)
├── Config (all accounts)
├── VPC Flow Logs (all accounts)
├── S3 Access Logs
└── Application Logs (via CloudWatch subscription filters)

Retention:
- CloudTrail: 7 years (Glacier)
- Config: 5 years (Glacier)
- VPC Flow: 90 days (S3-IA)
- Application: 30 days (CloudWatch), 1 year (S3)
```

**2. Security Monitoring:**
- Security Hub (aggregated in Security account)
- GuardDuty (all accounts, delegated admin)
- AWS Config rules for compliance
- EventBridge rules for real-time alerts

### Disaster Recovery

**1. Backup Strategy:**
- AWS Backup in each account
  - Daily backups, 30-day retention
  - Weekly backups, 90-day retention
  - Monthly backups, 1-year retention
- Cross-region replication for production
- Organizations configuration backed up daily to S3

**2. RTO/RPO Targets:**
- Production: RTO 4 hours, RPO 1 hour
- Staging: RTO 8 hours, RPO 4 hours
- Development: RTO 24 hours, RPO 24 hours

### Compliance & Governance

**1. Guardrails:**
- Mandatory: 25 preventive + detective
- Strongly recommended: 15 detective
- Custom: 10 preventive (industry-specific)

**2. Compliance Frameworks:**
- CIS AWS Foundations Benchmark
- PCI DSS (for BU-A Production)
- SOC 2 (all production accounts)
- GDPR (all accounts with EU data)

**3. Audit:**
- AWS Audit Manager assessments monthly
- External audit quarterly
- Penetration testing annually

### Implementation Timeline

**Week 1-2: Foundation**
- Enable Organizations
- Set up Control Tower
- Create core OUs and accounts
- Configure AWS SSO

**Week 3-4: Networking**
- Deploy Transit Gateway
- Create VPCs in all accounts
- Configure routing and security groups
- Set up VPN/Direct Connect to on-prem

**Week 5-6: Security Baseline**
- Deploy SCPs
- Enable GuardDuty, Security Hub, Config
- Set up CloudTrail
- Configure centralized logging

**Week 7-8: Account Vending**
- Provision BU accounts
- Apply baseline configurations
- Configure SSO access
- Test inter-account connectivity

**Week 9-10: Compliance & Monitoring**
- Deploy Config rules
- Set up EventBridge alerts
- Configure dashboards
- Enable Audit Manager

**Week 11-12: Cost Management & DR**
- Set up budgets and alerts
- Enable Cost Explorer
- Configure AWS Backup
- Test DR procedures

### Key Design Decisions Explained

**Q: Why separate Network account?**
- Centralized control of transit gateway
- Prevents accidental deletion
- Clear separation of duties
- Easier to audit network changes

**Q: Why separate OUs per business unit?**
- Different compliance requirements
- Independent cost tracking
- Separate admin teams
- Different risk profiles

**Q: Why not put all production accounts in one OU?**
- Too broad for SCPs (different BUs need different policies)
- Cost allocation harder
- Blast radius too large

**Q: Transit Gateway vs VPC Peering?**
- Transit Gateway scales better (no n² connections)
- Centralized routing
- Supports VPN/Direct Connect
- Easier to manage at scale

**Interview Gold:** "I'd separate by business unit first, then environment within each BU. This allows independent management while sharing common security baseline. Transit Gateway enables hub-and-spoke without complex peering."

</details>

---

**Q2: Your Control Tower landed zone shows drift. Walk me through diagnosing and fixing it.**

<details>
<summary>Click to see detailed answer</summary>

### Understanding Control Tower Drift

**What is Drift?**
Drift occurs when someone makes manual changes that violate Control Tower's baseline configuration. This includes:
- Modifying CloudTrail organization trail
- Changing AWS Config configuration
- Altering SCPs managed by Control Tower
- Modifying AWS SSO permission sets
- Changing OU structure outside Control Tower

### Diagnosis Process

**Step 1: Identify Drift Type**
```bash
# Check drift status
# Console: Control Tower > Landing zone settings

# Drift indicators:
# - "Drift detected" banner (red)
# - Specific resource showing drift
# - Timestamp of when drift was detected
```

**Common Drift Types:**

1. **CloudTrail Drift**
   - Trail disabled
   - Trail configuration changed
   - S3 bucket permissions modified
   - Trail deleted

2. **AWS Config Drift**
   - Recorder stopped
   - Delivery channel modified
   - Configuration rules disabled

3. **SCP Drift**
   - Control Tower managed SCPs modified
   - SCPs detached from OUs
   - Policy content changed

4. **OU Structure Drift**
   - Core OUs renamed
   - Core OUs deleted
   - Accounts moved outside Control Tower management

5. **AWS SSO Drift**
   - Permission sets modified
   - Assignments changed outside Control Tower

### Step 2: Investigate Root Cause

**Check CloudTrail for the Change:**
```bash
# Find who made the change
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=aws-controltower-BaselineCloudTrail \
  --max-results 50 \
  --region us-east-1

# Output shows:
# - Username/Role that made change
# - IP address
# - Timestamp
# - API call (e.g., UpdateTrail, DeleteTrail)
```

**Example CloudTrail Investigation:**
```json
{
  "EventTime": "2025-02-01T14:30:00Z",
  "EventName": "UpdateTrail",
  "Username": "john.doe",
  "SourceIPAddress": "10.0.1.50",
  "RequestParameters": {
    "name": "aws-controltower-BaselineCloudTrail",
    "isMultiRegionTrail": false  // Changed from true!
  }
}
```

### Step 3: Assess Impact

**Questions to Answer:**

1. **What was changed?**
   ```bash
   # Compare current state vs desired state
   aws cloudtrail describe-trails --trail-name-list aws-controltower-BaselineCloudTrail
   
   # Check if:
   # - IsMultiRegionTrail: should be true
   # - IsOrganizationTrail: should be true
   # - LoggingEnabled: should be true
   ```

2. **When was it changed?**
   - Determines audit log gap
   - Affects compliance posture

3. **Who was affected?**
   - If CloudTrail disabled: all accounts not logging
   - If Config disabled: compliance not tracked
   - If SCP detached: guardrail not enforced

4. **What data might be missing?**
   - CloudTrail: API calls not logged
   - Config: Configuration changes not recorded
   - GuardDuty: Security findings missed

### Step 4: Fix the Drift

**Option 1: Auto-Repair via Control Tower (Recommended)**
```bash
# Console: Control Tower > Landing zone settings > Resolve drift
# This will:
# 1. Identify all drifted resources
# 2. Revert to baseline configuration
# 3. Re-enable guardrails
# 4. Take 15-30 minutes

# Monitor progress
# Console shows:
# - Updating: Repair in progress
# - Available: Repair complete
# - Failed: Manual intervention needed
```

**Option 2: Manual Repair (If Auto-Repair Fails)**

**For CloudTrail Drift:**
```bash
# Re-enable if disabled
aws cloudtrail start-logging \
  --name aws-controltower-BaselineCloudTrail

# Fix configuration
aws cloudtrail update-trail \
  --name aws-controltower-BaselineCloudTrail \
  --is-multi-region-trail \
  --is-organization-trail \
  --s3-bucket-name aws-controltower-logs-$ACCOUNT_ID-$REGION

# Verify
aws cloudtrail get-trail-status \
  --name aws-controltower-BaselineCloudTrail
```

**For Config Drift:**
```bash
# Restart Config recorder
aws configservice start-configuration-recorder \
  --configuration-recorder-name aws-controltower-BaselineConfigRecorder

# Verify
aws configservice describe-configuration-recorder-status
```

**For SCP Drift:**
```bash
# List current SCPs on OU
aws organizations list-policies-for-target \
  --target-id $OU_ID \
  --filter SERVICE_CONTROL_POLICY

# Re-attach Control Tower managed SCP
aws organizations attach-policy \
  --policy-id $CT_MANAGED_POLICY_ID \
  --target-id $OU_ID

# Verify
aws organizations describe-policy \
  --policy-id $CT_MANAGED_POLICY_ID
```

### Step 5: Prevent Future Drift

**1. Implement Preventive SCPs:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PreventControlTowerModifications",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:DeleteTrail",
        "cloudtrail:StopLogging",
        "cloudtrail:UpdateTrail",
        "config:DeleteConfigurationRecorder",
        "config:DeleteDeliveryChannel",
        "config:StopConfigurationRecorder",
        "organizations:DetachPolicy"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:ResourceTag/aws-control-tower": "*"
        },
        "StringNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::*:role/AWSControlTowerExecution",
            "arn:aws:iam::*:role/AWSControlTowerAdmin"
          ]
        }
      }
    }
  ]
}
```

**2. Set Up Drift Detection Alerts:**
```yaml
# EventBridge rule for drift detection
Resources:
  DriftDetectionRule:
    Type: AWS::Events::Rule
    Properties:
      Name: ControlTowerDriftAlert
      EventPattern:
        source:
          - aws.controltower
        detail-type:
          - AWS API Call via CloudTrail
        detail:
          eventName:
            - UpdateLandingZone
            - CreateManagedAccount
          eventSource:
            - controltower.amazonaws.com
      State: ENABLED
      Targets:
        - Arn: !Ref AlertTopic
          Id: DriftAlertTarget

  AlertTopic:
    Type: AWS::SNS::Topic
    Properties:
      Subscription:
        - Endpoint: cloudops@example.com
          Protocol: email
```

**3. Regular Drift Checks:**
```bash
#!/bin/bash
# check-drift.sh - Run daily via Lambda/EventBridge

# Check for drift indicators
DRIFT_STATUS=$(aws controltower get-landing-zone-status | jq -r '.status')

if [ "$DRIFT_STATUS" != "AVAILABLE" ]; then
  echo "ALERT: Control Tower drift detected!"
  echo "Status: $DRIFT_STATUS"
  
  # Send SNS alert
  aws sns publish \
    --topic-arn arn:aws:sns:us-east-1:$ACCOUNT_ID:ControlTowerAlerts \
    --message "Control Tower drift detected. Status: $DRIFT_STATUS"
  
  # Create Jira ticket
  # curl -X POST ...
fi
```

**4. Audit Logging:**
```bash
# Enable CloudTrail Insights for unusual API activity
aws cloudtrail put-insight-selectors \
  --trail-name aws-controltower-BaselineCloudTrail \
  --insight-selectors '[{
    "InsightType": "ApiCallRateInsight"
  }]'

# Set up CloudWatch alarm for Control Tower API calls
aws cloudwatch put-metric-alarm \
  --alarm-name ControlTowerAPIActivity \
  --alarm-description "Alert on Control Tower resource modifications" \
  --metric-name ControlTowerModifications \
  --namespace CloudTrail \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:us-east-1:$ACCOUNT_ID:SecurityAlerts
```

### Step 6: Post-Incident

**1. Document the Incident:**
```markdown
# Drift Incident Report

## Summary
- Date: 2025-02-01 14:30 UTC
- Drift Type: CloudTrail disabled
- Duration: 2 hours
- Resolved: 2025-02-01 16:30 UTC

## Root Cause
User john.doe accidentally disabled multi-region
 logging while testing.

## Impact
- CloudTrail logs missing for 2 hours
- 15 accounts affected
- No compliance violations recorded during gap

## Actions Taken
1. Enabled CloudTrail logging
2. Verified all guardrails operational
3. Implemented preventive SCP
4. Retrained user on proper procedures

## Preventive Measures
1. Added SCP to prevent CloudTrail modifications
2. Set up drift detection alerts
3. Updated runbook with recovery procedures
4. Scheduled drift check automation
```

**2. Update Runbooks:**
- Add this specific drift scenario
- Document recovery steps
- Include contact information
- Set up on-call rotation

**3. Review Access:**
- Who has permissions to modify Control Tower resources?
- Are permissions too broad?
- Should we implement break-glass procedures?

### Common Drift Scenarios & Quick Fixes

| Drift Type | Symptom | Quick Fix |
|------------|---------|-----------|
| CloudTrail disabled | "Trail not logging" | `aws cloudtrail start-logging` |
| Config stopped | "Config non-compliant" | `aws configservice start-configuration-recorder` |
| SCP detached | "Guardrail not enforced" | Re-attach via Organizations |
| OU renamed | "OU structure changed" | Rename back via Organizations |
| Permission set modified | "SSO access changed" | Re-provision via SSO console |

### When to Escalate

**Escalate to AWS Support if:**
- Auto-repair fails repeatedly
- Multiple drift types simultaneously
- Can't identify root cause
- Control Tower console unresponsive
- Critical compliance gap

**Before Escalating:**
- Document all troubleshooting steps
- Collect CloudTrail logs
- Note exact error messages
- Prepare account IDs affected

**Interview Gold:** "I'd immediately check CloudTrail to find who made the change and when. Then use Control Tower's auto-repair feature. Most important is preventing future drift with SCPs that deny modifications to Control Tower resources."

</details>

---

**Q3: Design a cost allocation strategy for a landing zone with 50+ accounts. How do you track costs per team, project, and environment?**

<details>
<summary>Click to see detailed answer</summary>

### Multi-Dimensional Cost Allocation Architecture

**Challenge:** Track costs across multiple dimensions simultaneously:
- Team/Business Unit
- Project/Application
- Environment (Prod/Staging/Dev)
- Cost Center
- Product/Service

### Solution Architecture

**1. Organizational Structure for Cost Segregation**
```
Root
├── Business Unit A ($500k/month budget)
│   ├── Team-1 ($100k/month)
│   │   ├── Project-Alpha-Prod
│   │   ├── Project-Alpha-Staging
│   │   └── Project-Alpha-Dev
│   └── Team-2 ($150k/month)
│       ├── Project-Beta-Prod
│       └── Project-Beta-Dev
├── Business Unit B ($300k/month budget)
│   └── Team-3
└── Shared Infrastructure ($200k/month)
    ├── Network Account
    └── Shared Services Account
```

### Tag Strategy (The Foundation)

**Required Tags (Enforced via Tag Policies):**
```json
{
  "tags": {
    "BusinessUnit": {
      "tag_key": {"@@assign": "BusinessUnit"},
      "tag_value": {"@@assign": ["BU-A", "BU-B", "BU-C"]},
      "enforced_for": {
        "@@assign": [
          "ec2:instance",
          "ec2:volume",
          "rds:db",
          "s3:bucket",
          "lambda:function",
          "dynamodb:table"
        ]
      }
    },
    "Team": {
      "tag_key": {"@@assign": "Team"},
      "enforced_for": {"@@assign": ["ec2:instance", "s3:bucket"]}
    },
    "Project": {
      "tag_key": {"@@assign": "Project"},
      "enforced_for": {"@@assign": ["ec2:instance", "rds:db"]}
    },
    "Environment": {
      "tag_key": {"@@assign": "Environment"},
      "tag_value": {"@@assign": ["Production", "Staging", "Development"]},
      "enforced_for": {"@@assign": ["ec2:instance", "rds:db"]}
    },
    "CostCenter": {
      "tag_key": {"@@assign": "CostCenter"},
      "enforced_for": {"@@assign": ["ec2:instance"]}
    }
  }
}
```

**Deploy Tag Policy:**
```bash
aws organizations create-policy \
  --content file://tag-policy.json \
  --name RequiredCostTags \
  --type TAG_POLICY

# Attach to root (applies organization-wide)
aws organizations attach-policy \
  --policy-id $TAG_POLICY_ID \
  --target-id $ROOT_ID
```

### Cost Allocation Tag Activation

```bash
# Activate cost allocation tags (Management Account)
TAGS_TO_ACTIVATE=(
  "BusinessUnit"
  "Team"
  "Project"
  "Environment"
  "CostCenter"
  "Owner"
  "Application"
)

for TAG in "${TAGS_TO_ACTIVATE[@]}"; do
  aws ce update-cost-allocation-tags-status \
    --cost-allocation-tags-status TagKey=$TAG,Status=Active
done

# Takes 24 hours to appear in Cost Explorer
```

### Multi-Level Budgets

**1. Organization-Level Budget:**
```json
{
  "BudgetName": "OrganizationTotal",
  "BudgetLimit": {"Amount": "1000000", "Unit": "USD"},
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

**2. Business Unit Budgets:**
```bash
for BU in "BU-A" "BU-B" "BU-C"; do
  cat > budget-$BU.json <<EOF
{
  "BudgetName": "Budget-$BU",
  "BudgetLimit": {"Amount": "300000", "Unit": "USD"},
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {
    "TagKeyValue": ["user:BusinessUnit\$$BU"]
  }
}
EOF

  aws budgets create-budget \
    --account-id $MGMT_ACCOUNT_ID \
    --budget file://budget-$BU.json \
    --notifications-with-subscribers file://notifications.json
done
```

**3. Team-Level Budgets:**
```bash
# Team budgets with cost allocation by tag
aws budgets create-budget \
  --account-id $MGMT_ACCOUNT_ID \
  --budget '{
    "BudgetName": "Team-Engineering",
    "BudgetLimit": {"Amount": "50000", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST",
    "CostFilters": {
      "TagKeyValue": ["user:Team$Engineering"]
    }
  }'
```

**4. Environment-Specific Budgets:**
```bash
# Production budget (stricter threshold)
aws budgets create-budget \
  --budget '{
    "BudgetName": "Production-Environment",
    "BudgetLimit": {"Amount": "500000", "Unit": "USD"},
    "CostFilters": {
      "TagKeyValue": ["user:Environment$Production"]
    }
  }'

# Development budget (with auto-shutdown)
aws budgets create-budget \
  --budget '{
    "BudgetName": "Development-Environment",
    "BudgetLimit": {"Amount": "50000", "Unit": "USD"},
    "CostFilters": {
      "TagKeyValue": ["user:Environment$Development"]
    }
  }'
```

### Cost and Usage Report (CUR)

**Set Up Detailed CUR:**
```bash
# Create S3 bucket for CUR
aws s3 mb s3://cur-reports-$MGMT_ACCOUNT_ID

# Enable CUR with all dimensions
aws cur put-report-definition \
  --report-definition '{
    "ReportName": "detailed-cost-usage",
    "TimeUnit": "HOURLY",
    "Format": "Parquet",
    "Compression": "Parquet",
    "AdditionalSchemaElements": [
      "RESOURCES",
      "SPLIT_COST_ALLOCATION_DATA"
    ],
    "S3Bucket": "cur-reports-'$MGMT_ACCOUNT_ID'",
    "S3Prefix": "cur",
    "S3Region": "us-east-1",
    "AdditionalArtifacts": [
      "ATHENA",
      "QUICKSIGHT"
    ],
    "RefreshClosedReports": true,
    "ReportVersioning": "OVERWRITE_REPORT"
  }'
```

### Athena Queries for Cost Analysis

**Set Up Athena Database:**
```sql
-- Create database
CREATE DATABASE IF NOT EXISTS cur_database;

-- Table auto-created by CUR with Athena integration

-- Query 1: Cost by Business Unit
SELECT
  line_item_usage_account_id,
  resource_tags_user_business_unit as business_unit,
  SUM(line_item_unblended_cost) as cost
FROM cur_database.detailed_cost_usage
WHERE year = '2025' AND month = '02'
GROUP BY 1, 2
ORDER BY cost DESC;

-- Query 2: Cost by Team and Project
SELECT
  resource_tags_user_team as team,
  resource_tags_user_project as project,
  resource_tags_user_environment as environment,
  SUM(line_item_unblended_cost) as cost
FROM cur_database.detailed_cost_usage
WHERE year = '2025' AND month = '02'
GROUP BY 1, 2, 3
ORDER BY cost DESC;

-- Query 3: Top 10 Most Expensive Resources
SELECT
  line_item_resource_id,
  line_item_product_code,
  resource_tags_user_owner as owner,
  resource_tags_user_project as project,
  SUM(line_item_unblended_cost) as cost
FROM cur_database.detailed_cost_usage
WHERE year = '2025' AND month = '02'
GROUP BY 1, 2, 3, 4
ORDER BY cost DESC
LIMIT 10;

-- Query 4: Untagged Resources (Compliance check)
SELECT
  line_item_resource_id,
  line_item_product_code,
  line_item_usage_account_id,
  SUM(line_item_unblended_cost) as cost
FROM cur_database.detailed_cost_usage
WHERE year = '2025'
  AND month = '02'
  AND (
    resource_tags_user_business_unit IS NULL OR
    resource_tags_user_team IS NULL OR
    resource_tags_user_environment IS NULL
  )
GROUP BY 1, 2, 3
ORDER BY cost DESC;

-- Query 5: Month-over-Month Cost Trend by Team
SELECT
  resource_tags_user_team as team,
  month,
  SUM(line_item_unblended_cost) as cost
FROM cur_database.detailed_cost_usage
WHERE year = '2025'
GROUP BY 1, 2
ORDER BY 1, 2;
```

### QuickSight Dashboards

**Create Executive Cost Dashboard:**
```bash
# Set up QuickSight (one-time)
aws quicksight create-account-subscription \
  --aws-account-id $MGMT_ACCOUNT_ID \
  --account-name "CostDashboard" \
  --authentication-method IAM_AND_QUICKSIGHT \
  --edition ENTERPRISE

# Create data source (Athena)
aws quicksight create-data-source \
  --aws-account-id $MGMT_ACCOUNT_ID \
  --data-source-id cur-athena \
  --name "CUR Athena" \
  --type ATHENA \
  --data-source-parameters '{
    "AthenaParameters": {
      "WorkGroup": "primary"
    }
  }'

# Dashboard components:
# 1. Total spend by Business Unit (pie chart)
# 2. Top 10 projects by cost (bar chart)
# 3. Environment breakdown (stacked bar)
# 4. Trend over time (line chart)
# 5. Untagged resources alert (table)
```

### Chargeback/Showback Automation

**Monthly Cost Report Lambda:**
```python
# monthly-chargeback-report.py
import boto3
import pandas as pd
from datetime import datetime, timedelta
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

ce = boto3.client('ce')
orgs = boto3.client('organizations')

def generate_monthly_report():
    # Get current month
    end_date = datetime.now().strftime('%Y-%m-%d')
    start_date = (datetime.now().replace(day=1)).strftime('%Y-%m-%d')
    
    # Query costs by tag dimensions
    response = ce.get_cost_and_usage(
        TimePeriod={'Start': start_date, 'End': end_date},
        Granularity='MONTHLY',
        Metrics=['UnblendedCost'],
        GroupBy=[
            {'Type': 'TAG', 'Key': 'BusinessUnit'},
            {'Type': 'TAG', 'Key': 'Team'},
            {'Type': 'TAG', 'Key': 'Project'}
        ]
    )
    
    # Process results
    costs = []
    for result in response['ResultsByTime']:
        for group in result['Groups']:
            bu = group['Keys'][0].split('$')[1] if '$' in group['Keys'][0] else 'Untagged'
            team = group['Keys'][1].split('$')[1] if '$' in group['Keys'][1] else 'Untagged'
            project = group['Keys'][2].split('$')[1] if '$' in group['Keys'][2] else 'Untagged'
            cost = float(group['Metrics']['UnblendedCost']['Amount'])
            
            costs.append({
                'BusinessUnit': bu,
                'Team': team,
                'Project': project,
                'Cost': cost
            })
    
    # Create DataFrame
    df = pd.DataFrame(costs)
    
    # Generate summaries
    bu_summary = df.groupby('BusinessUnit')['Cost'].sum().sort_values(ascending=False)
    team_summary = df.groupby('Team')['Cost'].sum().sort_values(ascending=False)
    
    # Send reports to team leads
    send_chargeback_emails(df, bu_summary, team_summary)
    
    # Upload to S3
    s3 = boto3.client('s3')
    csv_buffer = df.to_csv(index=False)
    s3.put_object(
        Bucket='cost-reports-bucket',
        Key=f"chargeback/{start_date}-report.csv",
        Body=csv_buffer
    )

def send_chargeback_emails(df, bu_summary, team_summary):
    # Email each team their costs
    teams = df['Team'].unique()
    
    for team in teams:
        if team == 'Untagged':
            continue
            
        team_data = df[df['Team'] == team]
        team_cost = team_data['Cost'].sum()
        
        # Get team lead email from DynamoDB/parameter store
        email = get_team_lead_email(team)
        
        # Create email
        html = f"""
        <html>
        <h2>Monthly Cost Report - {team}</h2>
        <p>Total Cost: ${team_cost:,.2f}</p>
        <h3>Breakdown by Project:</h3>
        <table border="1">
          <tr><th>Project</th><th>Cost</th></tr>
          {"".join([f"<tr><td>{row['Project']}</td><td>${row['Cost']:,.2f}</td></tr>" 
                    for _, row in team_data.iterrows()])}
        </table>
        </html>
        """
        
        send_email(email, f"Cost Report - {team}", html)

def lambda_handler(event, context):
    generate_monthly_report()
    return {'statusCode': 200}
```

**Schedule Monthly:**
```yaml
# chargeback-schedule.yaml
Resources:
  ChargebackRule:
    Type: AWS::Events::Rule
    Properties:
      ScheduleExpression: "cron(0 9 1 * ? *)"  # 9 AM on 1st of month
      Targets:
        - Arn: !GetAtt ChargebackLambda.Arn
          Id: ChargebackTarget
```

### Shared Services Cost Allocation

**Problem:** Network, DNS, Active Directory costs are shared

**Solution: Cost Allocation Based on Usage**
```python
# allocate-shared-costs.py
def allocate_shared_services():
    # Get shared services costs
    shared_account_cost = get_account_cost(SHARED_SERVICES_ACCOUNT)
    
    # Get workload account usage metrics
    workload_accounts = get_workload_accounts()
    
    # Allocation method 1: By number of resources
    total_resources = sum([count_resources(acc) for acc in workload_accounts])
    
    for account in workload_accounts:
        account_resources = count_resources(account)
        allocated_cost = (account_resources / total_resources) * shared_account_cost
        
        # Record in DynamoDB
        record_allocated_cost(account, 'SharedServices', allocated_cost)
    
    # Allocation method 2: By data transfer (for network costs)
    network_cost = get_service_cost(NETWORK_ACCOUNT, 'VPC')
    total_data_transfer = get_total_data_transfer(workload_accounts)
    
    for account in workload_accounts:
        account_transfer = get_data_transfer(account)
        allocated_network = (account_transfer / total_data_transfer) * network_cost
        
        record_allocated_cost(account, 'Network', allocated_network)
```

### Cost Optimization Automation

**Auto-Shutdown Non-Prod Instances:**
```python
# cost-optimization-lambda.py
import boto3
from datetime import datetime

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    # Get current time
    now = datetime.now()
    is_business_hours = (now.weekday() < 5 and 8 <= now.hour < 18)
    
    # Find non-prod instances
    response = ec2.describe_instances(
        Filters=[
            {'Name': 'tag:Environment', 'Values': ['Development', 'Staging']},
            {'Name': 'instance-state-name', 'Values': ['running', 'stopped']}
        ]
    )
    
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            state = instance['State']['Name']
            
            # Stop if outside business hours
            if not is_business_hours and state == 'running':
                ec2.stop_instances(InstanceIds=[instance_id])
                print(f"Stopped {instance_id}")
            
            # Start during business hours
            elif is_business_hours and state == 'stopped':
                ec2.start_instances(InstanceIds=[instance_id])
                print(f"Started {instance_id}")
```

**Schedule: Run hourly**
```yaml
ScheduleExpression: "cron(0 * * * ? *)"
```

### Reporting & Alerts

**1. Weekly Cost Report to Leadership:**
- Total spend vs budget
- Top 5 cost increases
- Untagged resources count
- Savings recommendations

**2. Budget Alert Escalation:**
- 80%: Team lead notification
- 90%: Director notification
- 100%: Automatic resource review
- 120%: Automatic stop of non-critical resources

**3. Cost Anomaly Alerts:**
```bash
# Enable cost anomaly detection
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "TeamCostMonitor",
    "MonitorType": "DIMENSIONAL",
    "MonitorDimension": "SERVICE"
  }'
```

### Key Metrics to Track

| Metric | Calculation | Target |
|--------|-------------|--------|
| Cost per Team | Sum(tagged resources) | Within budget |
| Untagged Resources | Count(no tags) | <2% |
| Waste (unused) | Idle resources cost | <5% |
| Chargeback Accuracy | Tagged / Total | >95% |
| Budget Variance | Actual vs Budget | ±10% |

**Interview Gold:** "I'd use a combination of account separation, mandatory tagging enforced by tag policies, and detailed CUR analysis in Athena. Key is automation: monthly chargeback reports, untagged resource alerts, and auto-shutdown of non-prod resources. Shared costs allocated based on usage metrics."

</details>

---

---

### AWS Well-Architected Framework

**Q4: How do you apply the AWS Well-Architected Framework's 6 pillars to Landing Zone design? Give specific examples for each pillar.**

<details>
<summary>Click to see detailed answer</summary>

### The 6 Pillars Applied to Landing Zone

The AWS Well-Architected Framework has 6 pillars:
1. Operational Excellence
2. Security
3. Reliability
4. Performance Efficiency
5. Cost Optimization
6. Sustainability

Let's examine how each applies to Landing Zone architecture.

---

## 1. Operational Excellence

**Definition:** The ability to run and monitor systems to deliver business value and continually improve processes.

### Landing Zone Implementation

**1.1 Infrastructure as Code (IaC)**
```
✅ All landing zone resources defined in code
✅ Version controlled (Git)
✅ Automated deployment via CI/CD

Example:
├── terraform/
│   ├── organizations/
│   │   ├── ous.tf
│   │   ├── accounts.tf
│   │   └── scps.tf
│   ├── control-tower/
│   │   └── guardrails.tf
│   ├── networking/
│   │   ├── transit-gateway.tf
│   │   └── vpc-templates.tf
│   └── security/
│       ├── guardduty.tf
│       └── security-hub.tf
```

**1.2 Automated Account Vending**
```python
# account-factory-automation.py
def provision_account(team_name, environment):
    """
    Automated account creation with:
    - Consistent baseline configuration
    - Automatic tagging
    - SSO access provisioning
    - Baseline security controls
    """
    account = create_service_catalog_account(
        name=f"{team_name}-{environment}",
        email=f"{team_name}-{environment}@company.com",
        ou=get_ou_for_environment(environment),
        tags={
            'Team': team_name,
            'Environment': environment,
            'ManagedBy': 'Automation'
        }
    )
    
    # Wait for account creation
    wait_for_account(account['AccountId'])
    
    # Apply baseline
    deploy_baseline_stackset(account['AccountId'])
    
    # Configure SSO access
    provision_sso_access(account['AccountId'], team_name)
    
    return account
```

**1.3 Centralized Logging & Observability**
```
Log Archive Account:
├── CloudTrail (all API calls)
├── Config (all config changes)
├── VPC Flow Logs (all network traffic)
├── CloudWatch Logs (application logs)
└── AWS Security Hub (security findings)

Dashboards:
├── Operational Health Dashboard
│   ├── Account creation success rate
│   ├── Guardrail compliance %
│   ├── Drift detection status
│   └── Failed deployments
├── Security Dashboard
│   ├── GuardDuty findings
│   ├── Security Hub score
│   ├── Unauthorized API calls
│   └── Config compliance
└── Cost Dashboard
    ├── Total spend by OU
    ├── Budget status
    └── Cost anomalies
```

**1.4 Runbooks & Automation**
```bash
# Incident Response Runbooks

# Runbook 1: Account Creation Failed
- Check Service Catalog status
- Verify email not in use
- Check service quotas
- Review CloudTrail for errors
- Retry with different parameters

# Runbook 2: Guardrail Compliance Failure
- Identify non-compliant resource
- Check who created resource (CloudTrail)
- Determine if exception needed
- Remediate or request exception
- Update guardrail if needed

# Runbook 3: Control Tower Drift
- Identify drift type (CloudTrail/Config/SCP)
- Run auto-repair
- If failed, manual remediation steps
- Document root cause
- Implement preventive controls
```

**Operational Excellence Metrics:**
- Mean Time to Provision Account (MTTP): <30 minutes
- Account Creation Success Rate: >99%
- Guardrail Compliance: >98%
- Drift Detection Response Time: <1 hour
- Change Success Rate: >95%

---

## 2. Security

**Definition:** Protect information, systems, and assets while delivering business value.

### Landing Zone Implementation

**2.1 Defense in Depth**
```
Layer 1: Account Isolation
├── Separate AWS accounts per workload
├── SCPs prevent cross-account access
└── Network isolation via VPC

Layer 2: Network Security
├── Private subnets for workloads
├── Transit Gateway with route table isolation
├── Network ACLs
├── Security Groups (least privilege)
└── VPC endpoints (no internet traffic)

Layer 3: Identity & Access
├── AWS SSO (no long-lived credentials)
├── MFA enforced via SCP
├── Least privilege IAM roles
├── Cross-account roles with conditions
└── Service Control Policies

Layer 4: Data Protection
├── Encryption at rest (enforced by SCP)
├── Encryption in transit (TLS 1.2+)
├── KMS with separate keys per account
├── S3 bucket policies (deny unencrypted)
└── Backup encryption

Layer 5: Detective Controls
├── GuardDuty (threat detection)
├── Security Hub (compliance)
├── Config Rules (configuration)
├── CloudTrail (audit logs)
└── Macie (data classification)

Layer 6: Incident Response
├── EventBridge rules for alerts
├── SNS notifications
├── Lambda auto-remediation
├── Systems Manager for patching
└── Forensic account for investigation
```

**2.2 Preventive Controls (SCPs)**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RequireEncryption",
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances",
        "rds:CreateDBInstance"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "ec2:Encrypted": "false",
          "rds:StorageEncrypted": "false"
        }
      }
    },
    {
      "Sid": "RequireMFA",
      "Effect": "Deny",
      "NotAction": [
        "iam:CreateVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:GetUser",
        "iam:ListMFADevices",
        "sts:GetSessionToken"
      ],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    },
    {
      "Sid": "DenyPublicS3",
      "Effect": "Deny",
      "Action": [
        "s3:PutAccountPublicAccessBlock"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "s3:PutAccountPublicAccessBlock": "true"
        }
      }
    }
  ]
}
```

**2.3 Detective Controls**
```yaml
# security-detective-controls.yaml
Resources:
  # GuardDuty finding alert
  GuardDutyHighSeverityRule:
    Type: AWS::Events::Rule
    Properties:
      EventPattern:
        source:
          - aws.guardduty
        detail-type:
          - GuardDuty Finding
        detail:
          severity:
            - 7
            - 7.0
            - 7.1
            - 7.2
            - 7.3
            - 7.4
            - 7.5
            - 7.6
            - 7.7
            - 7.8
            - 7.9
            - 8
            - 8.0
            - 8.1
            - 8.2
            - 8.3
            - 8.4
            - 8.5
            - 8.6
            - 8.7
            - 8.8
            - 8.9
      Targets:
        - Arn: !Ref SecurityAlertTopic
          Id: SecurityTeam
        - Arn: !GetAtt AutoRemediateLambda.Arn
          Id: AutoRemediate

  # Unauthorized API call detection
  UnauthorizedAPICallRule:
    Type: AWS::Events::Rule
    Properties:
      EventPattern:
        detail-type:
          - AWS API Call via CloudTrail
        detail:
          errorCode:
            - "*UnauthorizedOperation"
            - "AccessDenied*"
      Targets:
        - Arn: !Ref SecurityAlertTopic
          Id: UnauthorizedAlert

  # Root account usage detection
  RootAccountUsageRule:
    Type: AWS::Events::Rule
    Properties:
      EventPattern:
        detail-type:
          - AWS API Call via CloudTrail
        detail:
          userIdentity:
            type:
              - Root
      Targets:
        - Arn: !Ref CriticalAlertTopic
          Id: RootUsageAlert
```

**Security Metrics:**
- Security Hub Score: >90%
- GuardDuty Findings MTTR: <4 hours (high severity)
- Config Compliance: >95%
- Unencrypted Resources: 0
- MFA Adoption: 100%
- Root Account Usage: 0 (except emergencies)

---

## 3. Reliability

**Definition:** Ensure a workload performs its intended function correctly and consistently.

### Landing Zone Implementation

**3.1 Multi-AZ Architecture**
```
Control Plane (Control Tower):
├── API Server: Multi-AZ by default
├── CloudTrail: Multi-region
├── Config: Multi-region
└── GuardDuty: Regional (enabled in all regions)

Network Architecture:
├── Transit Gateway: Multi-AZ
├── VPCs: Subnets in 3 AZs minimum
│   ├── us-east-1a
│   ├── us-east-1b
│   └── us-east-1c
└── NAT Gateways: One per AZ (high availability)

Data Layer:
├── S3 (Log Archive): 11 9s durability, multi-AZ
├── Organizations metadata: Backed up daily
└── State files: S3 with versioning
```

**3.2 Backup Strategy**
```python
# Landing Zone Backup Strategy

# Daily Backups:
1. Organizations Configuration
   - All accounts metadata
   - OU structure
   - SCPs
   - Tag policies
   Retention: 90 days

2. Control Tower Configuration
   - Guardrails enabled
   - Account Factory settings
   - Customizations
   Retention: 90 days

3. Network Configuration
   - Transit Gateway config
   - Route tables
   - VPC configurations
   Retention: 30 days

# Weekly Backups:
1. IAM Configuration
   - SSO permission sets
   - Cross-account roles
   - Service-linked roles
   Retention: 1 year

# Continuous Backups:
1. CloudTrail logs: Real-time to S3
2. Config snapshots: Every 6 hours
3. VPC Flow Logs: Real-time to CloudWatch
```

**3.3 Disaster Recovery Plan**
```markdown
# DR Scenarios & Recovery Procedures

## Scenario 1: Management Account Compromise
RTO: 2 hours
RPO: 24 hours (last backup)

Recovery Steps:
1. Activate break-glass credentials
2. Revoke all IAM credentials
3. Reset root password
4. Enable MFA on root
5. Review CloudTrail for malicious activity
6. Restore Organizations config from backup
7. Verify all guardrails active
8. Conduct security review

## Scenario 2: Region Failure (us-east-1)
RTO: 4 hours
RPO: 1 hour

Recovery Steps:
1. Activate DR region (us-west-2)
2. Deploy Control Tower in DR region
3. Restore Organizations structure
4. Re-establish network connectivity
5. Failover critical workloads
6. Update DNS entries
7. Verify all systems operational

## Scenario 3: Control Tower Corruption
RTO: 6 hours
RPO: 24 hours

Recovery Steps:
1. Document current state
2. Backup all current configurations
3. Reset Control Tower (if possible)
4. Restore from Infrastructure-as-Code
5. Re-enroll all accounts
6. Verify guardrails
7. Test account provisioning
```

**3.4 Change Management**
```bash
# Change Management Process

# Pre-Change:
1. Change Request (CR) created in Jira
2. Impact assessment
3. Rollback plan documented
4. Testing in non-prod
5. Approval from CAB (Change Advisory Board)

# During Change:
1. Maintenance window notification
2. Take backup
3. Execute change via IaC
4. Monitor for errors
5. Validate success criteria

# Post-Change:
1. Verify no drift
2. Check all guardrails active
3. Review monitoring dashboards
4. Update documentation
5. Close CR with lessons learned

# Emergency Changes:
- Can skip CAB approval
- Must be documented within 24 hours
- Retrospective required
```

**Reliability Metrics:**
- Landing Zone Availability: 99.99%
- Account Provisioning Success Rate: >99%
- Change Success Rate: >95%
- MTTD (Mean Time to Detect): <5 minutes
- MTTR (Mean Time to Resolve): <1 hour (critical)

---

## 4. Performance Efficiency

**Definition:** Use computing resources efficiently to meet requirements.

### Landing Zone Implementation

**4.1 Efficient Resource Utilization**
```
Account Provisioning:
├── Service Catalog: <5 minutes
├── Parallel provisioning: 10 accounts simultaneously
└── Cached AMIs for faster deployment

Network Architecture:
├── Transit Gateway: 50 Gbps per attachment
├── VPC Endpoints: Reduce NAT Gateway traffic
├── Direct Connect: Dedicated 10 Gbps to on-prem
└── CloudFront: Global content delivery

Monitoring & Logging:
├── CloudWatch Logs Insights: Query millions of logs/sec
├── Athena: Query CUR data in seconds
├── QuickSight: Dashboard refresh <1 minute
└── EventBridge: <1 second event processing
```

**4.2 Scalability Design**
```python
# Account Provisioning at Scale

# Sequential (Old):
for account in accounts:
    provision_account(account)  # 20 minutes each
# Total for 100 accounts: 33 hours

# Parallel (New):
with ThreadPoolExecutor(max_workers=10) as executor:
    futures = [executor.submit(provision_account, acc) 
               for acc in accounts]
    wait(futures)
# Total for 100 accounts: 2 hours

# Architecture supports:
- 1000+ accounts
- 50+ OUs
- 100+ SCPs
- 1000+ guardrails
```

**4.3 Monitoring Optimization**
```yaml
# Efficient log aggregation

# Before: All logs to CloudWatch (expensive)
Estimated cost for 100 accounts:
- CloudWatch Logs: $50,000/month
- Log storage: $10,000/month
- Total: $60,000/month

# After: Tiered logging strategy
1. Critical logs → CloudWatch (real-time alerts)
   Cost: $5,000/month
   
2. Audit logs → S3 (compliance)
   Cost: $1,000/month
   
3. Application logs → S3 (analysis via Athena)
   Cost: $2,000/month
   
4. VPC Flow Logs → S3 with lifecycle (archive to Glacier)
   Cost: $500/month
   
Total: $8,500/month (86% savings)
```

**Performance Metrics:**
- Account Provisioning: <20 minutes (99th percentile)
- API Response Time: <500ms (99th percentile)
- Dashboard Load Time: <2 seconds
- Log Query Time: <5 seconds (90% of queries)

---

## 5. Cost Optimization

**Definition:** Avoid unnecessary costs and maximize return on investment.

### Landing Zone Implementation

**5.1 Cost-Aware Architecture**
```
Account Structure:
├── Consolidated Billing (volume discounts)
├── Reserved Instances (centrally managed)
├── Savings Plans (org-wide, 3-year commitment)
└── Spot Instances (for non-prod workloads)

Resource Optimization:
├── Auto-shutdown non-prod (60% savings)
├── Right-sizing recommendations (AWS Compute Optimizer)
├── S3 Intelligent-Tiering (automatic cost reduction)
├── RDS Reserved Instances (40% savings vs on-demand)
└── Lambda instead of EC2 for small workloads

Waste Elimination:
├── Unattached EBS volumes: Deleted after 7 days
├── Idle load balancers: Flagged for review
├── Unused Elastic IPs: Released automatically
├── Old snapshots: Lifecycle policy (delete >90 days)
└── Untagged resources: Flagged for deletion
```

**5.2 Cost Allocation & Chargeback**
```
Tagging Strategy (enforced via Tag Policies):
├── BusinessUnit: BU-A, BU-B, BU-C
├── Environment: Production, Staging, Development
├── CostCenter: CC-1001, CC-1002, etc.
├── Project: Alpha, Beta, Gamma
└── Owner: team-email@company.com

Monthly Chargeback:
├── Direct costs: EC2, RDS, S3 per team
├── Shared costs allocated:
│   ├── Transit Gateway: By data transfer
│   ├── NAT Gateway: By data processed
│   ├── Active Directory: By user count
│   └── Security tools: By account count
└── Reports sent to:
    ├── Team leads
    ├── Finance
    └── CTO
```

**5.3 Budget & Alerts**
```bash
# Multi-level budget strategy

Organization Level: $1M/month
├── Alert at 80%: Finance notification
├── Alert at 100%: Exec notification
└── Alert at 120%: Emergency meeting

Business Unit Level: $300k/month each
├── Alert at 80%: BU lead notification
├── Alert at 100%: Budget freeze warning
└── Alert at 120%: Non-critical resource review

Environment Level:
├── Production: $150k/month (no auto-actions)
├── Staging: $50k/month (throttle if exceeded)
└── Development: $100k/month (auto-shutdown if exceeded)

Cost Anomaly Detection:
├── Threshold: 20% increase day-over-day
├── Alert: Slack + Email
└── Auto-investigation Lambda:
    ├── Identify top cost changes
    ├── Tag resources causing spike
    └── Create Jira ticket
```

**5.4 Continuous Optimization**
```python
# Weekly cost optimization report

def generate_optimization_report():
    recommendations = {
        'rightsizing': check_oversized_instances(),
        'unused_resources': find_unused_resources(),
        'savings_plans': calculate_savings_plan_opportunity(),
        'reserved_instances': check_ri_utilization(),
        'storage_optimization': find_storage_waste()
    }
    
    total_potential_savings = sum(r['savings'] for r in recommendations.values())
    
    # Send report
    send_to_finance_team(recommendations, total_potential_savings)
    
    # Auto-implement low-risk items
    for rec in recommendations['unused_resources']:
        if rec['age_days'] > 90 and rec['cost'] < 100:
            delete_resource(rec['resource_id'])
            
    return recommendations

# Typical monthly savings opportunities found:
# - Unused resources: $5,000
# - Right-sizing: $15,000
# - Reserved Instances: $50,000
# - Storage optimization: $3,000
# Total: $73,000/month ($876k/year)
```

**Cost Optimization Metrics:**
- Cost per Account: $3,000/month average
- Waste (%): <5% (idle resources)
- Savings Plan Utilization: >95%
- Reserved Instance Utilization: >90%
- Untagged Resources: <2%

---

## 6. Sustainability

**Definition:** Minimize environmental impact of cloud operations.

### Landing Zone Implementation

**6.1 Region Selection**
```
Primary Region: us-east-1 (Virginia)
- Powered by renewable energy (wind, solar)
- Newest hardware (more efficient)
- Best AWS carbon footprint

DR Region: us-west-2 (Oregon)
- 95% renewable energy
- Hydroelectric power
- Cool climate (less cooling needed)

Avoid:
- Regions with high carbon intensity
- Regions with older data centers
- Unnecessary multi-region deployments
```

**6.2 Efficient Resource Usage**
```
Compute Optimization:
├── Graviton instances (60% better energy efficiency)
├── Auto-scaling (only run what's needed)
├── Lambda (serverless, shared infrastructure)
├── Fargate (no idle capacity)
└── Spot instances (reuse spare capacity)

Storage Optimization:
├── S3 Intelligent-Tiering (move cold data to efficient storage)
├── EBS gp3 (more efficient than gp2)
├── Glacier for archives (most energy efficient)
└── Delete unnecessary data (lifecycle policies)

Network Optimization:
├── VPC endpoints (eliminate NAT gateway traffic)
├── CloudFront (edge caching, less origin load)
├── Transit Gateway (efficient routing)
└── Compression enabled (less data transfer)
```

**6.3 Sustainability Metrics**
```python
# Track sustainability KPIs

def calculate_sustainability_score():
    metrics = {
        'compute_efficiency': {
            'graviton_adoption': calculate_graviton_percentage(),
            'avg_cpu_utilization': get_average_utilization(),
            'serverless_ratio': calculate_serverless_percentage()
        },
        'storage_efficiency': {
            'intelligent_tiering': get_intelligent_tiering_percentage(),
            'glacier_usage': get_glacier_percentage(),
            'compression_ratio': get_compression_ratio()
        },
        'carbon_footprint': {
            'renewable_energy_regions': get_renewable_percentage(),
            'estimated_co2': estimate_co2_emissions()
        }
    }
    
    return metrics

# Sample output:
{
  'graviton_adoption': '45%',  # Target: 60%
  'avg_cpu_utilization': '68%',  # Target: 70%+
  'intelligent_tiering': '80%',  # Good
  'renewable_energy_regions': '95%',  # Excellent
  'estimated_co2': '50 tons/month'  # Baseline
}
```

**Sustainability Best Practices:**
- Delete unused resources (lambdas, security groups, etc.)
- Use newest instance types (more efficient)
- Enable auto-scaling (right-size automatically)
- Choose regions powered by renewables
- Implement data lifecycle policies
- Monitor and optimize continuously

---

## Well-Architected Trade-offs

**Understanding Trade-offs is Critical:**

### Example 1: Multi-Region vs Cost
```
Scenario: Should we deploy Control Tower in multiple regions?

✅ Reliability: Improved (region failover)
✅ Performance: Better latency globally
❌ Cost: 2x infrastructure costs
❌ Operational: More complex to manage

Decision: Deploy in single region unless:
- Regulatory requirement
- RTO < 1 hour
- Global users with latency requirements
```

### Example 2: Encryption vs Performance
```
Scenario: Encrypt all EBS volumes by default?

✅ Security: Excellent (data protection)
❌ Performance: Slight overhead (2-5%)
✅ Cost: Free (AWS-managed keys)
✅ Operational: Automated via SCP

Decision: Always encrypt (minimal performance impact, huge security gain)
```

### Example 3: Centralized vs Distributed Logging
```
Scenario: Send all logs to Log Archive account?

✅ Security: Centralized audit trail
✅ Operational: Single pane of glass
❌ Cost: High CloudWatch costs
❌ Performance: Network overhead

Decision: Hybrid approach:
- Critical logs → CloudWatch (real-time)
- Audit logs → S3 (compliance)
- Application logs → Local account (cost)
```

---

## Well-Architected Review Process

**Conduct Quarterly Reviews:**

1. **Assessment**
   - Use AWS Well-Architected Tool
   - Review all 6 pillars
   - Identify high/medium risks

2. **Remediation Plan**
   - Prioritize by risk level
   - Assign owners
   - Set deadlines

3. **Implementation**
   - Execute improvements
   - Test changes
   - Document lessons learned

4. **Measurement**
   - Track KPIs per pillar
   - Compare to previous quarter
   - Celebrate improvements

**Interview Gold:** "Landing zones must balance all 6 pillars. For example, multi-region deployment improves reliability but increases cost and complexity. I'd make decisions based on business requirements, not just technical excellence. A startup might prioritize cost optimization, while a bank prioritizes security and reliability."

</details>

---

**Q5: A CTO asks: "Our landing zone is costing $100k/month. How would you optimize it without sacrificing security or reliability?" Walk through your analysis and recommendations.**

<details>
<summary>Click to see detailed answer</summary>

### Comprehensive Cost Optimization Analysis

**Current State: $100k/month**
**Target: 30-40% reduction without compromising security/reliability**

---

### Step 1: Cost Breakdown Analysis

**First, understand WHERE the money goes:**

```bash
# Query Cost and Usage Report via Athena
SELECT
  line_item_product_code as service,
  SUM(line_item_unblended_cost) as cost,
  ROUND(SUM(line_item_unblended_cost) / 
    (SELECT SUM(line_item_unblended_cost) FROM cur) * 100, 2) as percentage
FROM cur_database.cost_usage_report
WHERE year = '2025' AND month = '02'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;
```

**Typical Landing Zone Cost Breakdown:**
```
Service                 Cost        % of Total
─────────────────────────────────────────────
EC2 (Compute)          $35,000      35%
VPC (Networking)       $15,000      15%
S3 (Storage)           $12,000      12%
CloudTrail             $8,000       8%
NAT Gateway            $7,000       7%
Data Transfer          $6,000       6%
CloudWatch Logs        $5,000       5%
RDS                    $4,000       4%
Lambda                 $3,000       3%
Other                  $5,000       5%
─────────────────────────────────────────────
TOTAL                  $100,000     100%
```

---

### Step 2: Quick Wins (Month 1) - Target $15k savings

**2.1 Eliminate Waste**

**Unused Resources (Est. savings: $5,000/month)**
```python
# identify-waste.py
import boto3

ec2 = boto3.client('ec2')
elbv2 = boto3.client('elbv2')

def find_unused_resources():
    waste = {
        'ebs_volumes': [],
        'elastic_ips': [],
        'load_balancers': [],
        'snapshots': []
    }
    
    # Unattached EBS volumes
    volumes = ec2.describe_volumes(
        Filters=[{'Name': 'status', 'Values': ['available']}]
    )
    for vol in volumes['Volumes']:
        age_days = (datetime.now() - vol['CreateTime']).days
        waste['ebs_volumes'].append({
            'id': vol['VolumeId'],
            'size': vol['Size'],
            'age_days': age_days,
            'monthly_cost': vol['Size'] * 0.10  # $0.10/GB-month
        })
    
    # Unattached Elastic IPs
    eips = ec2.describe_addresses()
    for eip in eips['Addresses']:
        if 'InstanceId' not in eip:
            waste['elastic_ips'].append({
                'ip': eip['PublicIp'],
                'monthly_cost': 3.60  # $0.005/hour
            })
    
    # Unused load balancers (no traffic)
    lbs = elbv2.describe_load_balancers()
    for lb in lbs['LoadBalancers']:
        metrics = get_lb_metrics(lb['LoadBalancerArn'])
        if metrics['request_count'] == 0:
            waste['load_balancers'].append({
                'name': lb['LoadBalancerName'],
                'monthly_cost': 22  # ~$0.0225/hour
            })
    
    # Old snapshots (>90 days, not tagged as "keep")
    snapshots = ec2.describe_snapshots(OwnerIds=['self'])
    for snap in snapshots['Snapshots']:
        age_days = (datetime.now() - snap['StartTime']).days
        if age_days > 90:
            waste['snapshots'].append({
                'id': snap['SnapshotId'],
                'size': snap['VolumeSize'],
                'age_days': age_days,
                'monthly_cost': snap['VolumeSize'] * 0.05
            })
    
    return waste

# Results:
{
  'ebs_volumes': $2,000/month (200GB unused),
  'elastic_ips': $200/month (55 unattached),
  'load_balancers': $1,500/month (68 with no traffic),
  'snapshots': $1,300/month (old backups)
}
Total: $5,000/month
```

**Action Items:**
- Delete unattached EBS volumes after 7 days
- Release unused Elastic IPs immediately
- Delete idle load balancers (or move to ALB)
- Implement snapshot lifecycle policy

**2.2 Right-Size Over-Provisioned Resources (Est. savings: $7,000/month)**

```python
# Use AWS Compute Optimizer recommendations
import boto3

ce = boto3.client('compute-optimizer')

def get_rightsizing_recommendations():
    recommendations = ce.get_ec2_instance_recommendations()
    
    savings = []
    for rec in recommendations['instanceRecommendations']:
        if rec['finding'] == 'OVER_PROVISIONED':
            current_cost = rec['currentInstanceType']['monthlyCost']
            recommended_cost = rec['recommendationOptions'][0]['monthlyCost']
            
            savings.append({
                'instance_id': rec['instanceArn'].split('/')[-1],
                'current_type': rec['currentInstanceType']['instanceType'],
                'recommended_type': rec['recommendationOptions'][0]['instanceType'],
                'monthly_savings': current_cost - recommended_cost
            })
    
    return savings

# Example output:
[
  {
    'instance_id': 'i-1234567890abcdef0',
    'current_type': 'm5.2xlarge',
    'recommended_type': 'm5.xlarge',
    'monthly_savings': $140
  },
  # ... 50 more instances
]
Total potential savings: $7,000/month
```

**Action Items:**
- Downsize over-provisioned instances
- Move to Graviton instances (60% better price/performance)
- Use burstable instances (t3/t4g) for low-utilization workloads

**2.3 Implement Auto-Shutdown for Non-Prod (Est. savings: $3,000/month)**

```python
# auto-shutdown-lambda.py
def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    now = datetime.now()
    
    # Business hours: Mon-Fri, 8 AM - 6 PM
    is_business_hours = (
        now.weekday() < 5 and  # Monday = 0, Friday = 4
        8 <= now.hour < 18
    )
    
    # Find non-prod instances
    filters = [
        {'Name': 'tag:Environment', 'Values': ['Development', 'Staging']},
        {'Name': 'instance-state-name', 'Values': ['running', 'stopped']}
    ]
    
    instances = ec2.describe_instances(Filters=filters)
    
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            state = instance['State']['Name']
            
            # Auto-shutdown logic
            if not is_business_hours and state == 'running':
                # Exclude instances with 'AlwaysOn' tag
                tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
                if tags.get('AlwaysOn') != 'true':
                    ec2.stop_instances(InstanceIds=[instance_id])
                    print(f"Stopped {instance_id}")
            
            elif is_business_hours and state == 'stopped':
                # Auto-start during business hours
                ec2.start_instances(InstanceIds=[instance_id])
                print(f"Started {instance_id}")
```

**Savings Calculation:**
```
Non-prod instances: 100 instances
Hours saved: 128 hours/week (nights + weekends)
Utilization reduction: 76% (128/168 hours)
Current cost: $4,000/month
Savings: $3,000/month (76% of $4,000)
```

---

### Step 3: Medium-Term Optimizations (Month 2-3) - Target $20k savings

**3.1 Storage Optimization (Est. savings: $8,000/month)**

**CloudWatch Logs → S3 + Athena**
```
Current State:
- CloudWatch Logs: $5,000/month
- Retention: 30 days in CloudWatch

Optimized State:
- Critical logs only in CloudWatch: $500/month
- Historical logs in S3: $200/month
- Query via Athena: $100/month (pay per query)
Total: $800/month

Savings: $4,200/month (84% reduction)
```

**Implementation:**
```python
# migrate-logs-to-s3.py
def migrate_logs_to_s3():
    logs = boto3.client('logs')
    s3 = boto3.client('s3')
    
    # Get all log groups
    log_groups = logs.describe_log_groups()
    
    for group in log_groups['logGroups']:
        log_group_name = group['logGroupName']
        
        # Skip critical logs (keep in CloudWatch)
        if is_critical_log(log_group_name):
            continue
        
        # Export to S3
        logs.create_export_task(
            logGroupName=log_group_name,
            fromTime=int((datetime.now() - timedelta(days=30)).timestamp() * 1000),
            to=int(datetime.now().timestamp() * 1000),
            destination='landing-zone-logs',
            destinationPrefix=f'exported-logs/{log_group_name}'
        )
        
        # Reduce CloudWatch retention to 7 days
        logs.put_retention_policy(
            logGroupName=log_group_name,
            retentionInDays=7
        )
```

**S3 Intelligent-Tiering**
```bash
# Enable Intelligent-Tiering on all S3 buckets
for BUCKET in $(aws s3 ls | awk '{print $3}'); do
  aws s3api put-bucket-intelligent-tiering-configuration \
    --bucket $BUCKET \
    --id EntireBucket \
    --intelligent-tiering-configuration '{
      "Id": "EntireBucket",
      "Status": "Enabled",
      "Tierings": [
        {
          "Days": 90,
          "AccessTier": "ARCHIVE_ACCESS"
        },
        {
          "Days": 180,
          "AccessTier": "DEEP_ARCHIVE_ACCESS"
        }
      ]
    }'
done

# Expected savings: $3,800/month (32% reduction on $12k)
```

**3.2 Network Optimization (Est. savings: $7,000/month)**

**NAT Gateway Consolidation**
```
Current State:
- 3 NAT Gateways per VPC (multi-AZ)
- 10 VPCs = 30 NAT Gateways
- Cost: $0.045/hour = $32.40/month each
- Total: $972/month + data processing

Problem: Many VPCs have minimal outbound traffic

Solution 1: VPC Endpoints (no NAT needed)
- S3 Gateway Endpoint: Free
- DynamoDB Gateway Endpoint: Free
- Interface Endpoints: $7.20/month each
  - EC2, ECS, CloudWatch, etc.

Solution 2: Shared NAT in Network Account
- Transit Gateway routes to central NAT
- 3 NAT Gateways (multi-AZ) instead of 30
- Savings: $700/month on NAT hourly costs
```

**Data Transfer Optimization**
```
Current Data Transfer Costs: $6,000/month

Optimization Strategy:
1. VPC Endpoints (eliminate internet traffic):
   - S3 endpoint: Save $2,000/month
   - DynamoDB endpoint: Save $500/month
   
2. CloudFront for static content:
   - Reduce origin requests by 80%
   - Save $1,000/month
   
3. Compress data in transit:
   - Enable gzip on ALB
   - Save $500/month
   
4. Use VPC peering for inter-account:
   - Instead of internet routing
   - Save $300/month

Total savings: $4,300/month
```

**3.3 Reserved Instances & Savings Plans (Est. savings: $5,000/month)**

```python
# Calculate RI/SP recommendations
ce = boto3.client('ce')

# Get RI recommendations
ri_recs = ce.get_reservation_purchase_recommendation(
    Service='Amazon Elastic Compute Cloud - Compute',
    LookbackPeriodInDays='SIXTY_DAYS',
    TermInYears='ONE_YEAR',
    PaymentOption='NO_UPFRONT'
)

# Example output:
{
  'service': 'EC2',
  'estimated_monthly_savings': '$3,500',
  'upfront_cost': '$0',
  'recommended_instances': [
    {'instance_type': 'm5.xlarge', 'quantity': 20},
    {'instance_type': 'm5.2xlarge', 'quantity': 10},
  ]
}

# Get Savings Plans recommendations
sp_recs = ce.get_savings_plans_purchase_recommendation(
    LookbackPeriodInDays='SIXTY_DAYS',
    TermInYears='ONE_YEAR',
    PaymentOption='NO_UPFRONT',
    SavingsPlansType='COMPUTE_SP'
)

# Example output:
{
  'hourly_commitment': '$15',
  'estimated_monthly_savings': '$1,500',
  'coverage': '75%'
}

# Total potential savings: $5,000/month
```

---

### Step 4: Advanced Optimizations (Month 4+) - Target $5k additional

**4.1 Graviton Migration (Est. savings: $3,000/month)**

```bash
# Graviton instances offer 40% better price/performance

# Current: x86 instances
50x m5.xlarge = $4,320/month

# Migrated: Graviton instances
50x m6g.xlarge = $2,592/month (40% less)

# Savings: $1,728/month

# Apply to all compatible workloads:
- Web servers
- Application servers
- Containerized workloads
- Batch processing

Total potential: $3,000/month across all workloads
```

**4.2 Serverless Where Possible (Est. savings: $2,000/month)**

```
Current: Always-on EC2 for infrequent tasks
- 10x t3.medium instances
- Running 24/7 for scheduled jobs
- Cost: $300/month each = $3,000/month

Migrated: Lambda + EventBridge
- Lambda: $50/month (execution time)
- EventBridge: $10/month (rule evaluations)
- Total: $60/month

Savings: $2,940/month (98% reduction)
```

---

### Step 5: Cost Governance (Ongoing) - Prevent regression

**5.1 Enforce Tagging**
```json
// tag-policy.json - Enforce cost allocation tags
{
  "tags": {
    "CostCenter": {
      "tag_key": {"@@assign": "CostCenter"},
      "enforced_for": {"@@assign": [
        "ec2:instance", "rds:db", "s3:bucket"
      ]}
    }
  }
}
```

**5.2 Budget Alerts with Actions**
```yaml
# budget-with-actions.yaml
Resources:
  DevelopmentBudget:
    Type: AWS::Budgets::Budget
    Properties:
      Budget:
        BudgetName: Development-Budget
        BudgetLimit:
          Amount: 5000
          Unit: USD
        TimeUnit: MONTHLY
      NotificationsWithSubscribers:
        - Notification:
            NotificationType: ACTUAL
            ComparisonOperator: GREATER_THAN
            Threshold: 100
          Subscribers:
            - SubscriptionType: EMAIL
              Address: devops@example.com
  
  # Auto-action: Stop non-critical instances
  BudgetAction:
    Type: AWS::Budgets::BudgetsAction
    Properties:
      BudgetName: !Ref DevelopmentBudget
      NotificationType: ACTUAL
      ActionType: APPLY_SCP_POLICY
      ActionThreshold:
        ActionThresholdValue: 120
        ActionThresholdType: PERCENTAGE
      Definition:
        ScpActionDefinition:
          PolicyId: !Ref StopNonCriticalSCP
      ExecutionRoleArn: !GetAtt BudgetActionRole.Arn
```

**5.3 FinOps Dashboard**
```python
# Generate weekly cost review
def weekly_cost_review():
    report = {
        'total_spend': get_monthly_spend(),
        'vs_budget': calculate_budget_variance(),
        'top_costs': get_top_10_resources(),
        'anomalies': detect_cost_anomalies(),
        'savings_opportunities': {
            'unused_resources': find_unused_resources(),
            'rightsizing': get_rightsizing_recommendations(),
            'ri_sp': get_commitment_recommendations()
        }
    }
    
    send_to_leadership(report)
    post_to_slack(report)
```

---

### Summary: Cost Reduction Roadmap

| Phase | Timeframe | Savings | Cumulative | Actions |
|-------|-----------|---------|------------|---------|
| **Quick Wins** | Month 1 | $15k | $85k/mo | Delete waste, right-size, auto-shutdown |
| **Medium-Term** | Month 2-3 | $20k | $65k/mo | Storage optimization, network optimization, RI/SP |
| **Advanced** | Month 4+ | $5k | $60k/mo | Graviton, serverless migrations |
| **Total Reduction** | - | **$40k** | **$60k/mo** | **40% savings** |

**Annual Savings: $480,000**

---

### What We DON'T Compromise

✅ **Security**
- All encryption remains (at rest & in transit)
- GuardDuty, Security Hub, Config: All active
- CloudTrail logs: Still captured (just stored cheaper)
- SCPs: All preventive controls remain

✅ **Reliability**
- Multi-AZ architecture: Maintained
- Backups: All retained (just moved to cheaper storage)
- DR capability: Unchanged
- Monitoring: Critical logs still real-time

✅ **Compliance**
- Audit logs: Still available (S3 with Athena)
- Retention periods: Met
- Security Hub: All checks passing

---

### ROI Analysis

**Investment Required:**
- Engineering time: 160 hours (1 engineer, 1 month)
- Cost: $20,000 (fully loaded)

**Return:**
- Monthly savings: $40,000
- Payback period: 0.5 months
- Annual ROI: 2,300%

**Long-term Benefits:**
- Established cost culture
- Automated cost controls
- Continuous optimization
- Better visibility

---

### Presentation to CTO

```markdown
# Cost Optimization Proposal

## Executive Summary
Reduce landing zone costs from $100k to $60k/month (40% savings)
without compromising security or reliability.

## Current State
- $100k/month spent
- 35% on compute (EC2)
- 15% on networking (NAT, TGW)
- Significant waste identified

## Proposed Changes

### Phase 1 (Month 1): Quick Wins - $15k savings
1. Delete unused resources ($5k)
2. Right-size over-provisioned instances ($7k)
3. Auto-shutdown non-prod ($3k)

### Phase 2 (Month 2-3): Optimization - $20k savings
1. Migrate logs to S3 ($4k)
2. S3 Intelligent-Tiering ($4k)
3. Network optimization ($7k)
4. Reserved Instances/Savings Plans ($5k)

### Phase 3 (Month 4+): Advanced - $5k savings
1. Graviton migration ($3k)
2. Serverless adoption ($2k)

## What Stays the Same
✓ All security controls
✓ High availability (multi-AZ)
✓ Backup retention
✓ Compliance posture

## Investment
- 1 engineer, 1 month
- $20k cost
- Payback in 2 weeks

## Recommendation
Approve phased approach. Start with Phase 1 (low risk, high impact).

## Next Steps
1. Week 1: Implement waste deletion
2. Week 2-3: Right-sizing
3. Week 4: Auto-shutdown
4. Month 2: Begin Phase 2
```

**Interview Gold:** "I'd start with the data - break down costs by service using CUR. Quick wins like deleting unused resources show immediate value. Then move to architectural changes like S3 Intelligent-Tiering and VPC endpoints. Critical: I don't touch security controls or multi-AZ architecture. Cost optimization without compromising the Well-Architected pillars."

</details>

---

### Additional Resources

- [AWS Control Tower User Guide](https://docs.aws.amazon.com/controltower/latest/userguide/)
- [AWS Landing Zone Solution](https://aws.amazon.com/solutions/implementations/aws-landing-zone/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Well-Architected Tool](https://aws.amazon.com/well-architected-tool/)
- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [AWS Cost Optimization](https://aws.amazon.com/pricing/cost-optimization/)

---

**Good luck with your interview! 🏗️**

> Remember: It's not about knowing every command—it's about understanding *why* you'd architect it that way and how to balance the Well-Architected pillars. Practice these scenarios until you can explain the tradeoffs naturally.
