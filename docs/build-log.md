# Capstone Platform — Build Log

Living record of what's been built, in what order, and current status. Update this alongside ADRs and the troubleshooting log as work progresses — a short status note + date is enough here; details belong in the relevant ADR or troubleshooting entry.

**Legend:** ✅ Done · 🔄 In Progress · ⬜ Not Started

---

## Azure Track

### Phase 0 — Conventions & Decisions
**Status:** ✅ Done

- ADR-0001 accepted: naming pattern `<resourcetype>-<instancenumber>-<workload>-<env>-<region>`, and mandatory tag schema (`environment`, `region`, `owner`, `project`, `costcenter`; optional `createddate`)
- Lowercase-only standard for names and tag keys; shared tag keys across both clouds to support unified cost reporting
- Constrained-resource naming exceptions (storage accounts, key vaults, etc.) handled case-by-case and documented in the ADR's exceptions section
- AWS resource abbreviation table built (Appendix A); Azure abbreviations referenced from Microsoft's CAF docs (Appendix B)

### Phase 1 — Bootstrap State Backend
**Status:** ✅ Done

- Resource Group: `rg-01-capstone-dev-eus`
- Storage Account: `lxvcapstonedevtf01` (manually named exception — global uniqueness + Azure's 24-char, hyphen-free constraint)
- Blob Container: `tf-state` (private access), state key `terraform.tfstate`
- `CanNotDelete` management lock applied to the storage account
- Blob versioning enabled; container and blob soft delete configured (7-day retention)
- Built with Terraform, staged on local state, migrated to remote backend
- Budget alerts configured across all Azure subscriptions and the AWS account (50/80/100% thresholds)

**Incident:** resource group was created without the agreed naming convention; corrected via a native Azure resource move + `terraform state rm`/`import` rather than a destructive rename, to avoid risking the live state file. Full writeup in `troubleshooting.md`.

  ### Problem ###
  - Problem: Renamed Terraform resources and backend, accidentally orphaned the remote state.
  - Symptoms: Pipeline failed with backend initialization/403 errors.
  - Root Cause: Backend storage was recreated and pipeline still referenced the old backend or lacked correct access.
  - Resolution: Recreated backend, migrated local state with terraform init -migrate-state, updated backend configuration, verified RBAC, and reconfigured the pipeline.
  ### Lessons Learned: 
  - Always back up terraform.tfstate before backend changes. 
  - Treat backend changes like infrastructure migrations. 
  - Verify terraform state list and terraform plan before re-enabling CICD.
  - Protect the backend storage account from accidental deletion.

### Phase 2 — Pipeline Identity (OIDC Federation)
**Status:** ✅ Done

- Decision: OIDC workload identity federation over a static service-principal secret, for GitLab CI → Azure auth

- Steps Taken
  - Entra ID app registration: Done/Registered  
  - Service Priciple: Done/Created 
  - Federated credential configured (issuer, subject claim, GitLab.com project scoped to master branch)
  - RBAC Contributor role assigned at resource group scope

- Create Gitlab Pipeline to plan and apply Terraform infrastructure configurations

- Steps Taken
  - Create Gitlab Variables to pass into the jobs/container as Global Terraform Environment variables in order for the SP to authenticate to Azure
    - Azure App Registration client ID
    - Azure Tenant ID
    - Azure Subscription ID
  - Enabled Gitlab caching to decrease pipeline run time
    - Set the Global variable 'TF_PLUGIN_CACHE_DIR' to cache provider versions and hashed to optimize the terraform init process
    - Cache the Terraform.lock.hcl file in order to decrease pipeline run time
  - Create a Gitlab OIDC token inside of each job to set to the AzureADTokenExchange API to pass along to Azure AD in order for Azure to check trust rules
  - Output plan artifact from the plan job to pass along to the apply job in order to avoid running terraform plan in the second job
  - Add the 'Storage Blob Data Contributor' role to the SP to allow Terraform to access the state file in the remote backend
    - Created local 'role assignment' variable set with 2 roles
    - Used for_each meta argument to loop through the role assignments and assign both roles to the sp instead of creating individual role assignments 
  - Set a manual approval gate on TF apply in order to allow for reviewing changes before implementing them

### Phase 3 — Networking Foundation
**Status:** ✅ Done
VNet, subnets, NSGs.

Networking is the foundation everything else sits on. Get it wrong here and you're either refactoring subnets while VMs are running on top of them, or you've got security gaps that are painful to close after the fact. In a real org, the network design gets reviewed before a single `terraform apply` touches it.

So before any code, I want your thinking on four questions. Don't look anything up yet — just reason through them:

**Question 1:** How many subnets do you think you need, and what's your reasoning for splitting them the way you do? Think about what workloads you're running (DC, GitLab, runners, SQL, app VM, Minikube, Bastion) and whether they should all share the same network segment.

  I would use a minimum of 5 subnets for this environment:

  Azure Bastion subnet
  This subnet is dedicated to Azure Bastion, which provides secure SSH/RDP access to private VMs without exposing public IP addresses. Azure requires this subnet to be named AzureBastionSubnet, and it should be at least /26.
  
  Infrastructure subnet
  This subnet would contain core infrastructure services such as the domain controller, GitLab server, Minikube, DevOps tooling, and Ansible. These systems support the environment and need to be separated from application and database workloads.
  
  GitLab Runners subnet
  GitLab runners should have their own subnet because they execute pipeline jobs, pull external dependencies, and may run code that is less trusted than the GitLab server itself. Separating runners allows tighter control over their inbound and outbound traffic, especially internet access and access to internal services.
  
  Application subnet
  This subnet would host the web application or application VM. Keeping the application tier separate allows the app to communicate with required services while limiting unnecessary access to infrastructure or database systems.
  
  Database subnet
  This subnet would contain the SQL/database resources. It should be the most restricted subnet. Ideally, only the application subnet should be allowed to communicate with the database subnet, such as allowing traffic from the app subnet to SQL on port 1433.

  Application Gateway subnet
  Microsoft recommends a /24 subnet for Application Gateway v2 so there is enough room for autoscaling and maintenance operations, even though smaller subnets can work in limited cases.

  The main reason for splitting the network this way is security, not just organization. Each subnet can have its own Network Security Group, which controls what traffic is allowed in and out. For example, if SQL were placed in the same subnet as GitLab or other infrastructure tools, it would be harder to restrict database access independently. By placing SQL in its own subnet, I can create a rule such as: only allow the application subnet to reach the database subnet on port 1433, and deny everything else.

  This design gives better isolation between management systems, CI/CD runners, application workloads, and database resources. It also makes future scaling easier because each workload type has its own network segment and security boundary.

**Question 2:** What address space are you going to use for your VNet, and how are you going to split it across subnets? Pick real CIDR ranges — don't just say "something in 10.x.x.x."

  VNet address space: 10.0.0.0/16

  I will use 10.0.0.0/16 for the Azure VNet. This provides 65,536 total addresses, ranging from 10.0.0.0 to 10.0.255.255, which gives enough room for the current design and future expansion.

  I will split the VNet into the following subnets:

  Subnet	CIDR Range	Purpose
  Azure Bastion subnet	10.0.0.0/26	Reserved for Azure Bastion. Must be named AzureBastionSubnet exactly.
  Infrastructure subnet	10.0.1.0/24	Domain controller, GitLab server, and Minikube host.
  Runners subnet	10.0.2.0/24	GitLab runners, kept separate from the GitLab server for isolation.
  App subnet	10.0.3.0/24	Application workloads.
  DB subnet	10.0.4.0/24	Database resources, separated for tighter security controls.
  App GW subnet 10.0.5.0/24 Application Gateway

  Each /24 subnet provides 256 total addresses, with 251 usable addresses in Azure because Azure reserves 5 IP addresses per subnet. The Bastion subnet uses /26, which provides 64 total addresses, satisfying Azure Bastion’s minimum size requirement.

  This layout keeps major resource types separated, makes network security rules easier to manage, and leaves plenty of unused space in the 10.0.0.0/16 VNet for future subnets such as monitoring, logging, private endpoints, or additional environments.

**Question 3:** Which of your VMs should be reachable from the internet, and which ones absolutely should not be?

  No individual VM should be directly reachable from the internet with its own public IP address.

  The only internet-facing entry points should be managed Azure services. Azure Bastion provides secure administrative access over HTTPS through the Azure portal. It is a managed PaaS service that sits in a dedicated subnet named AzureBastionSubnet; it is not a traditional VM that I manage or expose with SSH/RDP.

  The web application should be reachable by users, but the web app VM itself should remain private. Instead of assigning a public IP directly to the web VM, I would place it behind an Azure Application Gateway. The Application Gateway would be the public internet-facing endpoint, terminate SSL/TLS, and forward approved traffic to the private web application VM in the app subnet.

  The following VMs should not be directly reachable from the internet:

  Domain Controller
  GitLab server
  GitLab runners
  Minikube host
  Ansible/DevOps tooling
  SQL/database server
  Web app VM directly

  Administrative access to private VMs should go through Azure Bastion or controlled Just-in-Time access, not public SSH or RDP. The database should be especially restricted, allowing only required traffic from the application subnet, such as SQL traffic on TCP 1433.

  This design follows a more secure enterprise pattern: expose only managed edge services to the internet, keep all VMs private, and use NSGs to strictly control traffic between subnets.

  Component	              Internet reachable?	              Reason
Azure Bastion service	    Yes, via managed HTTPS access	    Used for admin access, not a VM you manage
Application Gateway	      Yes	                              Public entry point for the web app
Web app VM	              No direct public IP	              Receives traffic from Application Gateway only
GitLab	                  No	                              Internal DevOps service
GitLab runners	          No	                              Higher-risk CI/CD execution environment
Domain Controller	        No	                              Critical internal identity service
SQL/DB VM	                No	                              Only app subnet should reach it
Minikube/Ansible/dev too	No	                              Internal infrastructure only

**Question 4:** How are you going to access VMs for administration given that none of them should have public IPs?

  For interactive administration, I will use Azure Bastion. Azure Bastion will have a public IP as part of the managed Bastion service, but the VMs themselves will not have public IPs. Administrators will connect through Bastion using the Azure portal or native client support, and Bastion will connect to the target VMs using their private IP addresses over SSH or RDP.

  For automated administration, such as Ansible configuration from the CI/CD pipeline, the pipeline runner must also have a private network path to the VMs. Since the VMs do not have public IPs, Ansible cannot reach them from the public internet.

  The preferred approach is to run self-hosted GitLab runners inside the Azure VNet, in the dedicated runners subnet. Those runners would have private IP connectivity to the infrastructure, app, and database subnets, controlled by NSG rules. The runner can then connect to each VM over private IP using SSH or WinRM, depending on the operating system.

  For example:

  Admin user → Azure Bastion → VM private IP
  GitLab runner in Azure runners subnet → VM private IP
  Ansible → SSH/WinRM over the private VNet

  If using GitLab.com SaaS runners instead, they would not automatically be able to reach private Azure VMs. In that case, I would need a secure bridge such as a VPN, private connectivity, or a self-hosted runner deployed inside Azure. For this design, I would use self-hosted GitLab runners in the Azure VNet so the pipeline can configure private VMs without exposing them to the internet.

  NSGs would still restrict access so the runners can only reach the required management ports on the required VMs, rather than having unrestricted access to every subnet.

Subnet and NSG Design
Subnet Plan
Subnet	CIDR	Purpose
Azure Bastion subnet	10.0.0.0/26	Managed admin access through Azure Bastion. Must be named AzureBastionSubnet.
Infrastructure subnet	10.0.1.0/24	Domain Controller, GitLab, Minikube, Ansible/DevOps tooling
Runners subnet	10.0.2.0/24	Self-hosted GitLab runners
App subnet	10.0.3.0/24	Private web application VM
DB subnet	10.0.4.0/24	SQL/database VM
Application Gateway subnet	10.0.5.0/24	Dedicated subnet for Azure Application Gateway v2
Condensed NSG Rule Matrix
Source	Destination	Port/Protocol	Direction	Purpose
Internet	Application Gateway subnet	TCP 443	Inbound to App Gateway	Public HTTPS access to the web app
Internet	Application Gateway subnet	TCP 80	Inbound to App Gateway	Optional HTTP-to-HTTPS redirect
Application Gateway subnet	App subnet	TCP 80 or 443	Inbound to App subnet	Forward web traffic to the private app VM
App subnet	DB subnet	TCP 1433	Inbound to DB subnet	Allow app to connect to SQL database
Bastion subnet	Infrastructure subnet	TCP 22, 3389	Inbound to Infrastructure subnet	Admin SSH/RDP through Azure Bastion
Bastion subnet	Runners subnet	TCP 22, 3389	Inbound to Runners subnet	Admin SSH/RDP through Azure Bastion, if needed
Bastion subnet	App subnet	TCP 22, 3389	Inbound to App subnet	Admin SSH/RDP through Azure Bastion
Bastion subnet	DB subnet	TCP 22, 3389	Inbound to DB subnet	Emergency/admin SSH/RDP through Azure Bastion
Runners subnet	Infrastructure subnet	TCP 22, 5986	Inbound to Infrastructure subnet	Ansible/CI configuration of infra VMs
Runners subnet	App subnet	TCP 22, 5986	Inbound to App subnet	Ansible/CI configuration of app VMs
Runners subnet	DB subnet	TCP 22, 5986	Inbound to DB subnet	Optional Ansible/CI configuration of DB VMs
Runners subnet	Internet	TCP 443	Outbound from Runners subnet	Pull packages, containers, dependencies, and communicate with GitLab
VNet subnets	Domain Controller	TCP/UDP 53, 88, TCP 389, 445	Inbound to Infrastructure subnet	DNS, Kerberos, LDAP, and domain services
Any	DB subnet	Any	Inbound to DB subnet	Deny all traffic except explicitly allowed rules
Internet	All VM subnets	Any	Inbound to VM subnets	Deny direct public access to all VMs
Azure Bastion Subnet Rules

If an NSG is attached to AzureBastionSubnet, the Bastion subnet also needs Azure platform rules so the managed Bastion service can function correctly.

Source	Destination	Port/Protocol	Direction	Purpose
Internet	AzureBastionSubnet	TCP 443	Inbound to Bastion subnet	Allow HTTPS access to Azure Bastion
GatewayManager service tag	AzureBastionSubnet	TCP 443	Inbound to Bastion subnet	Allow Azure platform management traffic
VirtualNetwork service tag	AzureBastionSubnet	TCP 8080, 5701	Inbound to Bastion subnet	Allow Bastion internal host communication
AzureLoadBalancer service tag	AzureBastionSubnet	TCP 443	Inbound to Bastion subnet	Allow Azure Load Balancer health probes
AzureBastionSubnet	VM subnets	TCP 22, 3389	Outbound from Bastion subnet	Allow Bastion to connect to private VMs
AzureBastionSubnet	AzureCloud service tag	TCP 443	Outbound from Bastion subnet	Allow Bastion platform communication
Security Notes

No VM should have a direct public IP address.

The only public entry points should be:

Application Gateway for public web traffic.
Azure Bastion for administrative access.

The web app VM stays private in the App subnet and receives traffic only from the Application Gateway. The database stays private in the DB subnet and only accepts SQL traffic from the App subnet on TCP 1433.

GitLab runners are isolated in their own subnet because they execute CI/CD jobs. They should only be allowed to reach the ports required for automation, such as SSH 22, WinRM 5986, HTTPS 443, and approved internal deployment targets.

Azure NSGs already include default deny behavior. Explicit deny rules can still be added to document intent, enforce priority order, and make the security posture easier to review.

All other inbound traffic should be denied by default.

Overview

Designed the Azure networking foundation for the environment, including the VNet, subnet segmentation, NSG strategy, Azure Bastion access, Application Gateway placement, and private VM connectivity.

The design keeps all VMs private and separates infrastructure, CI/CD runners, application workloads, and database resources into dedicated network segments. Azure Bastion provides administrative access, while Application Gateway provides the public entry point for the web application.

Design Questions
Question 1: How many subnets are needed, and why should the workloads be separated?

Answer:

The environment uses six subnets:

Subnet	Purpose
AzureBastionSubnet	Dedicated Azure Bastion subnet
Infrastructure	Domain Controller, GitLab, Minikube, Ansible/DevOps tooling
Runners	Self-hosted GitLab runners
Application	Web/application workloads
Database	SQL/database workloads
Application Gateway	Dedicated Application Gateway v2 subnet

The primary reason for subnet separation is security and workload isolation.

GitLab runners are separated because they execute CI/CD jobs, retrieve external dependencies, and may execute less-trusted code. A dedicated subnet allows tighter control over runner access to internal resources and the internet.

The application and database tiers are separated so database access can be restricted independently. For example, the database subnet can allow SQL traffic from the application subnet on TCP 1433 while rejecting unnecessary traffic from other network segments.

This design provides:

Workload isolation
Independent NSG policies
Reduced lateral network access
Easier security review
Better scalability
Clearer network boundaries
Question 2: What address space should the VNet use, and how should it be divided?

Answer:

VNet: 10.0.0.0/16

The /16 provides sufficient address space for the current environment while leaving significant room for future expansion.

Subnet	CIDR	Purpose
AzureBastionSubnet	10.0.0.0/26	Azure Bastion
Infrastructure	10.0.1.0/24	DC, GitLab, Minikube, Ansible/DevOps tooling
Runners	10.0.2.0/24	Self-hosted GitLab runners
Application	10.0.3.0/24	Application workloads
Database	10.0.4.0/24	SQL/database workloads
Application Gateway	10.0.5.0/24	Application Gateway v2

The remaining 10.0.0.0/16 address space is available for future network segments such as monitoring, logging, private endpoints, or additional workloads.

Question 3: Which VMs should be reachable from the internet?

Answer:

No individual VM should be directly reachable from the internet or have its own public IP address.

The public-facing services are:

Component	Internet Reachable	Purpose
Azure Bastion	Yes	Administrative access
Application Gateway	Yes	Public web application entry point
Web App VM	No	Receives application traffic through Application Gateway
GitLab	No	Internal DevOps service
GitLab Runners	No	Internal CI/CD execution
Domain Controller	No	Internal identity infrastructure
SQL/DB VM	No	Private database tier
Minikube/Ansible/DevOps	No	Internal infrastructure

The Application Gateway provides the public endpoint for the web application and forwards approved traffic to the private application VM.

Azure Bastion provides administrative access to private VMs without exposing SSH or RDP directly to the internet.

Question 4: How will private VMs be administered?

Answer:

Interactive administration uses Azure Bastion.

Administrator
      ↓
Azure Bastion
      ↓
Private VM IP

VMs remain private and do not require public IP addresses. Bastion connects to the target VMs using their private IP addresses over SSH or RDP.

Automated administration uses self-hosted GitLab runners deployed inside the Azure VNet.

GitLab Pipeline
      ↓
Self-Hosted GitLab Runner
      ↓
Private VNet
      ↓
Target VM
      ↓
SSH / WinRM

The runners have private connectivity to the required infrastructure, application, and database resources.

Ansible can therefore configure systems using:

SSH — TCP 22
WinRM HTTPS — TCP 5986

NSGs restrict the runners to only the management ports and destinations required for automation.

GitLab.com SaaS runners would not automatically have network connectivity to private Azure VMs. Using self-hosted runners inside the Azure VNet avoids exposing management interfaces to the public internet.

Subnet Design

Subnet	CIDR	Purpose
AzureBastionSubnet	10.0.0.0/26	Managed administrative access
Infrastructure	10.0.1.0/24	Domain Controller, GitLab, Minikube, Ansible/DevOps tooling
Runners	10.0.2.0/24	Self-hosted GitLab runners
Application	10.0.3.0/24	Private web application VM
Database	10.0.4.0/24	SQL/database VM
Application Gateway	10.0.5.0/24	Application Gateway v2

NSG Design
Application Traffic
Source	Destination	Port	Purpose
Internet	Application Gateway	TCP 443	Public HTTPS
Internet	Application Gateway	TCP 80	Optional HTTP → HTTPS redirect
Application Gateway	Application subnet	TCP 80/443	Forward application traffic
Application subnet	Database subnet	TCP 1433	SQL connectivity

Administrative Traffic
Source	Destination	Port	Purpose
Bastion subnet	Infrastructure	TCP 22/3389	SSH/RDP administration
Bastion subnet	Runners	TCP 22/3389	SSH/RDP administration
Bastion subnet	Application	TCP 22/3389	SSH/RDP administration
Bastion subnet	Database	TCP 22/3389	SSH/RDP administration

CI/CD and Automation Traffic
Source	Destination	Port	Purpose
Runners	Infrastructure	TCP 22/5986	Ansible/CI administration
Runners	Application	TCP 22/5986	Application deployment/configuration
Runners	Database	TCP 22/5986	Database VM configuration if required
Runners	Internet	TCP 443	GitLab, packages, containers, dependencies

Domain Services
Required domain traffic from applicable VNet subnets to the Domain Controller includes:

DNS — TCP/UDP 53
Kerberos — TCP/UDP 88
LDAP — TCP 389
SMB — TCP 445

Additional Active Directory ports may be required depending on the final domain-joined workload configuration.

Azure Bastion NSG Requirements
If an NSG is associated with AzureBastionSubnet, the required Azure Bastion platform traffic must be permitted.

Source	Destination	Port	Purpose
Internet	AzureBastionSubnet	TCP 443	Bastion HTTPS access
GatewayManager	AzureBastionSubnet	TCP 443	Azure management traffic
VirtualNetwork	AzureBastionSubnet	TCP 8080/5701	Bastion internal communication
AzureLoadBalancer	AzureBastionSubnet	TCP 443	Health probes
AzureBastionSubnet	VM subnets	TCP 22/3389	SSH/RDP to private VMs
AzureBastionSubnet	AzureCloud	TCP 443	Azure platform communication

Security Decisions
No VM receives a direct public IP address.
Public ingress is limited to Azure-managed edge services:
Application Gateway → Public application traffic
Azure Bastion → Administrative access
The application VM remains private and receives application traffic through Application Gateway.
The database remains private and accepts SQL traffic only from approved application resources on TCP 1433.
GitLab runners remain isolated in their own subnet because they execute CI/CD workloads. Runner access to other network segments is limited to required deployment and management ports.
NSGs enforce segmentation between infrastructure, runners, application, database, Bastion, and Application Gateway resources.
Azure NSGs provide default deny behavior for traffic that is not otherwise permitted. Explicit deny rules may be used where useful to document security intent or enforce rule priority.

Result
The Azure network foundation provides:

Private VM architecture
Dedicated administrative access through Azure Bastion
Public application access through Application Gateway
Segmented infrastructure, CI/CD, application, and database workloads
Controlled east-west traffic through NSGs
Private CI/CD and Ansible administration
Address space reserved for future expansion

### Phase 4 — Core Security
**Status:** ⬜ In-Progress
Key Vault, Bastion, RBAC role assignments for day-to-day contributors.
  ## Key Vault
    Which subnet should Key Vault's private endpoint live in?
    Should Key Vault allow public network access or be restricted to VNet only?
    What's the naming convention for Key Vault given it's a constrained resource (3-24 chars, globally unique, alphanumeric only)?
    Soft delete and purge protection — should they be enabled, and what retention period?

### Phase 5 — Compute
**Status:** ⬜ Not Started
Domain controller, GitLab, GitLab runners, SQL, app VM, Minikube.

### Phase 6 — Configuration Management Handoff
**Status:** ⬜ Not Started
Ansible playbooks/roles to configure VMs after Terraform provisions them.

### Phase 7 — Secure Traffic
**Status:** ⬜ Not Started
Application Gateway/WAF, SSL/certificate management.

### Phase 8 — Application CI/CD Integration
**Status:** ⬜ Not Started
Wire the existing GitLab pipeline (build/analyze/test/publish/docker/deploy) into the new environment.

---

## AWS Track
**Status:** ⬜ Not Started

Same stack mirrored intentionally (not copy-pasted) to build cloud-agnostic pattern recognition. Bootstrap will follow the same shape as the Azure track (S3 + DynamoDB for state/locking instead of Storage Account + blob lease) once started.

---

## Related Documents
- ADR-0001 — Naming and Tagging Convention: `docs/adr/0001-naming-and-tagging.md`
- Troubleshooting Log: `troubleshooting.md`
- Architecture Diagrams: `diagrams/`