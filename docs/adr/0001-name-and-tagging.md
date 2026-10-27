# 0001 - Naming and Tagging Convention 

## Status 
Accepted 

## Context 
This document will define the standard and consistent naming convention across Azure and AWS in order to identify resources, attribute cost, and so that the two clouds' resource names are comparable to each other. 

## Decision
Use lowercase only for both key:value. Do not create multiple abbreviations for the same service (`sec` vs `secret`, `sg` vs `secgrp`).
Naming: <resourcetype>-<instancenumber>-<workload>-<env>-<region>
  e.g. vm-01-gitlab-dev-eus (Azure), ec2-01-gitlab-dev-use1 (AWS)

Tags (same keys on both providers): 
  mandatory: 
    environment:required {prod,dev,staging}, 
    region:region
    owner:user/department, 
    project:appname,
    costcenter:someidentifier
  optional: 
    createdate:yyyy-mm-dd

- Standard resources — VMs, NSGs, VNets, subnets, resource groups, NICs. Generous length limits (usually 64-80+ chars), allow hyphens, scoped uniqueness (just needs to be unique within the resource group, not globally). Your full <resourcetype>-<instancenumber>-<workload>-<env>-<region> pattern works fine here, no exceptions needed.

- Constrained resources — Storage Accounts (3-24 chars, lowercase alphanumeric only, no hyphens, globally unique across all of Azure), Key Vault (3-24 chars, globally unique), Container Registries (5-50 chars, alphanumeric only, globally unique), S3 buckets on AWS (3-63 chars, globally unique across all of AWS), Windows VM hostnames (15-char NetBIOS cap). These can't follow the standard pattern at all — the question is what to do instead.

- For Azure specifically — don't hand-roll this. There's a community Terraform provider, aztfmod/azurecaf, that's become the de facto standard in real Azure shops for exactly this problem. You feed it your workload/env/region/resource-type inputs, and it knows every single Azure resource type's length limit, allowed character set, and casing rules, and generates a compliant name for you — truncating intelligently and applying the right rules per type. It's literally built around Microsoft's own CAF naming guidance, which is the same standard you're already following. Worth pulling into your azure/modules early so you're not maintaining truncation logic by hand for 40+ resource types.

- For AWS — no equivalent off-the-shelf provider, so you build a small local naming module yourself. The pattern: a locals block (or a tiny reusable module) holding a lookup map of { resource_type = { max_length, allowed_chars } }, plus a function (Terraform's substr()) that truncates your generated name down to the limit. For genuinely globally-unique resources like S3 buckets, truncation alone isn't enough — two engineers could still collide on the same name — so you append a short deterministic or random suffix, commonly either random_string/random_id resources from the random provider, or a substring of the AWS account ID (which is already globally unique and deterministic, so re-running plan doesn't generate a new name each time — prefer this over random_string for that reason).

## Consequences
- Cost reports can be unioned across both clouds using shared tag keys.
- Resource names are longer but self-documenting.
- Need to revisit if a third cloud or region is added.
- Follows Azure's naming convention notes for both Azure/AWS (https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- Naming convention matches Microsoft's CAF naming convention
- Azure Policy / AWS Tag Policy will reject untagged resources | not enforced yet 

## Exceptions 
Storage account name: lxvcapstonedevtf01

- Storage Accounts can't use the standard hyphenated pattern due to Azure's 24-char, lowercase-alphanumeric-only restriction — named manually on a case-by-case basis.
  
# Appendix A – AWS Resource Abbreviations

| AWS Resource                 | Abbreviation |
| ---------------------------- | ------------ |
| Account                      | acct         |
| Availability Zone            | az           |
| Virtual Private Cloud (VPC)  | vpc          |
| Subnet                       | snet         |
| Route Table                  | rt           |
| Internet Gateway             | igw          |
| NAT Gateway                  | nat          |
| Transit Gateway              | tgw          |
| VPC Endpoint                 | vpce         |
| Security Group               | sg           |
| Network ACL                  | nacl         |
| EC2 Instance                 | ec2          |
| Launch Template              | lt           |
| Auto Scaling Group           | asg          |
| Elastic Load Balancer        | elb          |
| Application Load Balancer    | alb          |
| Network Load Balancer        | nlb          |
| Target Group                 | tg           |
| Elastic IP                   | eip          |
| EBS Volume                   | ebs          |
| EFS File System              | efs          |
| FSx File System              | fsx          |
| S3 Bucket                    | s3           |
| RDS Instance                 | rds          |
| Aurora Cluster               | aur          |
| DynamoDB Table               | ddb          |
| ElastiCache Cluster          | cache        |
| Redshift Cluster             | rs           |
| OpenSearch Domain            | os           |
| Lambda Function              | lfn          |
| Step Functions State Machine | sfn          |
| EventBridge Bus              | eb           |
| SNS Topic                    | sns          |
| SQS Queue                    | sqs          |
| API Gateway                  | apigw        |
| CloudFront Distribution      | cfd          |
| Route 53 Hosted Zone         | r53          |
| ACM Certificate              | acm          |
| Secrets Manager Secret       | sec          |
| Systems Manager Parameter    | param        |
| KMS Key                      | kms          |
| IAM Role                     | iam-role     |
| IAM Policy                   | iam-pol      |
| IAM User                     | iam-user     |
| IAM Group                    | iam-grp      |
| CloudWatch Log Group         | log          |
| CloudWatch Alarm             | alarm        |
| CloudTrail Trail             | ct           |
| Config Rule                  | cfg          |
| Backup Vault                 | bkv          |
| ECR Repository               | ecr          |
| ECS Cluster                  | ecs          |
| ECS Service                  | ecs-svc      |
| EKS Cluster                  | eks          |
| EKS Node Group               | eks-ng       |


A few rules keep this maintainable:

* Prefer AWS-native abbreviations when they already exist (`vpc`, `ec2`, `rds`, `s3`, `eks`, `ecr`).
* Use lowercase only.
* Do not create multiple abbreviations for the same service (`sec` vs `secret`, `sg` vs `secgrp`).
* Once adopted, never rename abbreviations without updating the ADR and all automation that validates names.

# Appendix B – Azure Resource Abbreviations

https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming