## 0002 - Azure Network Design, Subnet Segmentation, and Access Posture

## Context
The capstone platform requires a secure Azure network foundation for infrastructure services, GitLab, GitLab runners, application workloads, database services, administrative access, and internet-facing web traffic.

This environment is intended to model a production-style DevSecOps platform rather than a flat lab network. The network must provide clear separation between workload types, reduce unnecessary exposure, and support least-privilege traffic flows between subnets.

The platform includes several distinct workload categories:

Infrastructure services, including the domain controller, GitLab server, Minikube host, Ansible, and internal DevOps tooling
GitLab runners
Application workloads
Database services
Azure Bastion
Azure Application Gateway

The network design must address several security and operational concerns:

GitLab runners execute pipeline jobs and should not share the same subnet as GitLab itself.
Virtual machines should not be directly reachable from the public internet.
Public web traffic should enter through a controlled ingress layer.
Administrative access should use a controlled management path.
Database access should be limited to approved application sources.
NSG rules should be intentional and should avoid broad any-any access.

## Decision
We will use a segmented Azure virtual network design with four workload subnets plus two dedicated Azure service subnets.

The VNet address space will be:
Network	  CIDR
VNet	    10.0.0.0/16

The subnet design will be:
Subnet	              CIDR	            Purpose
AzureBastionSubnet 	  10.0.0.0/26	      Dedicated subnet for Azure Bastion administrative access
snet-infra	          10.0.1.0/24	      Domain controller, GitLab server, Minikube host, Ansible, and internal DevOps tooling
snet-runners	        10.0.2.0/24	      Self-hosted GitLab runners
snet-app	            10.0.3.0/24	      Private application workloads
snet-data	            10.0.4.0/24	      SQL/database workloads
snet-app-gateway	    10.0.5.0/24	      Dedicated subnet for Azure Application Gateway

GitLab will remain in snet-infra for the current phase of the capstone.

This is an intentional simplification. GitLab is part of the internal infrastructure platform for this phase, along with the domain controller, Minikube host, Ansible, and DevOps tooling. A future design could move GitLab into a dedicated subnet if stronger control-plane separation is needed.

GitLab runners will be placed in snet-runners and will not share a subnet with GitLab.

Runners are isolated because they execute CI/CD jobs. Pipeline jobs may run scripts, build code, download dependencies, handle artifacts, use deployment credentials, and interact with internal systems. Because runners execute less-trusted workload activity, they should not sit in the same subnet as GitLab or other infrastructure services.

No virtual machine will receive a public IP address.

This posture will be enforced through Terraform by not associating public IP resources to VM network interfaces. Inbound NSG rules for VM subnets will not allow direct SSH, RDP, HTTP, HTTPS, SQL, or other administrative/application access from the public internet.

Azure Application Gateway will be the sole public entry point for web traffic.

Public users will access the application through Application Gateway. Application Gateway will receive internet traffic and forward approved traffic to private application workloads in snet-app. The application VMs themselves will remain private.

Azure Bastion will be the sole administrative entry point for interactive VM access.
Administrators will connect through Azure Bastion to reach private VM IP addresses over SSH or RDP. Direct administrative access from the internet to VM subnets will not be allowed.

Network Security Groups will follow a default-deny and least-privilege philosophy.
NSG rules will be created based on source, destination, port, protocol, and purpose. Broad allow rules such as Any to Any should be avoided unless there is a specific documented reason.

The intended access model is:

Traffic Type	                          Approved Path
Public web traffic	                    Internet →  Application Gateway → App subnet
Interactive admin access	              Administrator → Azure Bastion → Private VM IP
GitLab runner automation	              Runner subnet → approved internal targets
GitLab runner communication with GitLab	Runner subnet → GitLab in infra subnet on required ports
App-to-database traffic	                App subnet → Data subnet on required database ports
Domain services	                        Approved subnets → Domain controller on required AD/DNS ports
Direct public VM access	                Not allowed

The initial NSG philosophy will be:

Source	                    Destination	          Allowed Traffic	       Purpose
Internet	                  snet-app-gateway	    TCP 443	               Public HTTPS ingress
Internet	                  snet-app-gateway	    TCP 80	               Optional HTTP-to-HTTPS redirect
Internet                    AzureBastionSubnet    TCP 443                Allow HTTPS access to Azure Bastion
Internet	                  VM subnets	          Deny	                 Prevent direct VM exposure
snet-app-gateway	          snet-app	            TCP 80 or 443	         Forward web traffic to private application workloads
snet-app	                  snet-data	            TCP 1433	             Application access to SQL database
GatewayManager service tag  AzureBastionSubnet    TCP 443, 8080          Allow Azure platform management traffic for Bastion
AzureBastionSubnet	        VM subnets	          TCP 22, 3389	         Administrative SSH/RDP through Bastion
snet-runners	              snet-infra	          TCP 443, 22, 5986	     GitLab access and approved automation to infrastructure targets
snet-runners                Internet              TCP 443                Allow runners to pull packages, download dependencies, pull container images, and communicate with GitLab.com
snet-runners	              snet-app	            TCP 22, 5986	         CI/CD and Ansible automation over SSH or WinRM
snet-runners	              snet-data	            TCP 22, 5986	         Optional controlled database administration automation
approved VNet sn  	        Domain controller	    Required AD/DNS ports	 DNS, Kerberos, LDAP, SMB, and domain services
AllowHttpsInbound	Inbound	Internet	*	443	TCP
AllowGatewayManagerInbound	Inbound	GatewayManager	*	443	TCP
AllowBastionHostCommunication	Inbound	VirtualNetwork	VirtualNetwork	8080, 5701	*
AllowAzureLoadBalancerInbound	Inbound	AzureLoadBalancer	*	443	TCP
AllowSshRdpOutbound	Outbound	*	VirtualNetwork	22, 3389	*
AllowAzureCloudOutbound	Outbound	*	AzureCloud	443	TCP
AllowBastionCommunication	Outbound	VirtualNetwork	VirtualNetwork	8080, 5701	*
AllowHttpOutbound	Outbound	*	Internet	80	*

Rule/Traffic Flow	            Direction	    Source	            Destination	          Port(s)	                    Protocol	      Purpose
AllowAppGatewayHttpsInbound	  Inbound	      Internet	          snet-app-gateway	    443	                        TCP	            Allow public HTTPS traffic to Application Gateway
AllowAppGatewayHttpInbound	  Inbound	      Internet	          snet-app-gateway	    80	                        TCP	            Optional HTTP ingress for HTTP-to-HTTPS redirection
DenyInternetToVMSubnets	      Inbound	      Internet	          VM subnets	          Any	                        Any	            Prevent direct Internet exposure of VMs
AllowAppGatewayToApp	        Inbound	      snet-app-gateway	  snet-app	            80, 443	                    TCP	            Allow Application Gateway to forward traffic to private application workloads
AllowAppToData	              Inbound	      snet-app	          snet-data	            1433	                      TCP	            Allow application workloads to access SQL Server
AllowRunnerToInfra	          Inbound	      snet-runners	      snet-infra	          443, 22, 5986	              TCP	            Allow GitLab and approved automation to infrastructure targets
AllowRunnerInternetHttps	    Outbound	    snet-runners	      Internet	            443	                        TCP	            Allow runners to communicate with GitLab.com, pull packages, dependencies, and container images
AllowRunnerToApp	            Outbound	    snet-runners	      snet-app	            22, 5986	                  TCP	            Allow CI/CD and Ansible automation over SSH or WinRM
AllowRunnerToData	            Outbound	    snet-runners	      snet-data	            22, 5986	                  TCP	            Allow optional controlled database administration automation
AllowADDomainServices	        Inbound	      Approved VNet       subnets	              DC Required AD/DNS ports	  TCP/UDP	        Allow DNS, Kerberos, LDAP, SMB, and other required Active Directory/domain services
AllowHttpsInbound	            Inbound	      Internet	          AzureBastionSubnet	  443	                        TCP	            Allow HTTPS access to Azure Bastion
AllowGatewayManagerInbound	  Inbound	      GatewayManager	    AzureBastionSubnet	  443	                        TCP	            Allow Azure platform management traffic for Bastion
AllowBastionHostCommunication	Inbound	      VirtualNetwork	    VirtualNetwork	      8080, 5701	                Any	            Allow internal Bastion host communication
AllowAzureLoadBalancerInbound	Inbound	      AzureLoadBalancer	  AzureBastionSubnet	  443	                        TCP	            Allow Azure Load Balancer traffic required by Bastion
AllowSshRdpOutbound	          Outbound	    AzureBastionSubnet	VirtualNetwork	      22, 3389	                  Any	            Allow Bastion to establish SSH and RDP sessions to target VMs
AllowAzureCloudOutbound	      Outbound	    AzureBastionSubnet	AzureCloud	          443	                        TCP	            Allow Bastion to communicate with required Azure services
AllowBastionCommunication	    Outbound	    VirtualNetwork	    VirtualNetwork	      8080, 5701	                Any	            Allow internal Bastion communication
AllowHttpOutbound	            Outbound	    AzureBastionSubnet	Internet	            80	                        Any	            Allow required outbound HTTP communication

snet-app-gateway — 10.0.5.0/24
Rule	                          Direction	            Source	              Destination	          Port(s)	        Protocol	      Action	              Purpose
AllowAppGatewayHttps            Inbound	Inbound	Internet	10.0.5.0/24	443	TCP	Allow	Public HTTPS traffic to Application Gateway
AllowAppGatewayHttp             Inbound	Inbound	Internet	10.0.5.0/24	80	TCP	Allow	Optional HTTP-to-HTTPS redirect

snet-app — 10.0.3.0/24
Rule	                          Direction	            Source	              Destination	          Port(s)	        Protocol	      Action	              Purpose
AllowAppGatewayToApp	          Inbound	            10.0.5.0/24	10.0.3.0/24	80, 443	TCP	Allow	Application Gateway traffic to private application workloads
AllowRunnerToApp	              Inbound	            10.0.2.0/24	10.0.3.0/24	22, 5986	TCP	Allow	CI/CD and Ansible automation over SSH or WinRM
DenyInternetToApp	              Inbound	Internet	10.0.3.0/24	*	*	Deny	Prevent direct Internet exposure

snet-data — 10.0.4.0/24
Rule	                          Direction	            Source	              Destination	          Port(s)	        Protocol	      Action	              Purpose
AllowAppToData	                Inbound	            10.0.3.0/24	10.0.4.0/24	1433	TCP	Allow	Application access to SQL Server
AllowRunnerToData	              Inbound	            10.0.2.0/24	10.0.4.0/24	22, 5986	TCP	Allow	Controlled database administration automation
DenyInternetToData	            Inbound	Internet	10.0.4.0/24	*	*	Deny	Prevent direct Internet exposure

snet-infra — 10.0.1.0/24
Rule	                          Direction	            Source	              Destination	          Port(s)	        Protocol	      Action	              Purpose
AllowRunnerToInfra	            Inbound	            10.0.2.0/24	10.0.1.0/24	22, 443, 5986	TCP	Allow	GitLab runner and approved infrastructure automation
AllowADDomainServices	          Inbound	Approved VNet subnet CIDRs	Domain Controller	Required AD/DNS ports	TCP/UDP	Allow	DNS, Kerberos, LDAP, SMB, and other required AD services
DenyInternetToInfra	            Inbound	Internet	10.0.1.0/24	*	*	Deny	Prevent direct Internet exposure

snet-runners — 10.0.2.0/24
Rule	                          Direction	            Source	              Destination	          Port(s)	        Protocol	      Action	              Purpose
AllowRunnerInternetHttps	      Outbound	            10.0.2.0/24	Internet	443	TCP	Allow	GitLab.com, packages, dependencies, and container registries
AllowRunnerToInfra	            Outbound	            10.0.2.0/24	10.0.1.0/24	22, 443, 5986	TCP	Allow	Infrastructure automation
AllowRunnerToApp	              Outbound	            10.0.2.0/24	10.0.3.0/24	22, 5986	TCP	Allow	Application automation
AllowRunnerToData	              Outbound	            10.0.2.0/24	10.0.4.0/24	22, 5986	TCP	Allow	Controlled database administration automation
DenyInternetToRunners	          Inbound	Internet	10.0.2.0/24	*	*	Deny	Prevent unsolicited Internet access to runner VMs

AzureBastionSubnet — 10.0.0.0/26
Rule	                          Direction	            Source	              Destination	          Port(s)	        Protocol	      Action	              Purpose
AllowHttpsInbound	              Inbound	Internet	10.0.0.0/26	443	TCP	Allow	HTTPS access to Azure Bastion
AllowGatewayManager             Inbound	Inbound	GatewayManager	10.0.0.0/26	443	TCP	Allow	Azure platform management traffic
AllowBastionHostCommunication   Inbound	VirtualNetwork	VirtualNetwork	8080, 5701	*	Allow	Internal Bastion host communication
AllowAzureLoadBalancer          Inbound	Inbound	AzureLoadBalancer	10.0.0.0/26	443	TCP	Allow	Azure Load Balancer traffic required by Bastion
AllowSshRdpOutbound	            Outbound	            10.0.0.0/26	VirtualNetwork	22, 3389	*	Allow	SSH/RDP from Bastion to target VMs
AllowAzureCloudOutbound	        Outbound	            10.0.0.0/26	AzureCloud	443	TCP	Allow	Required Azure service communication
AllowBastionCommunication	      Outbound	            VirtualNetwork	VirtualNetwork	8080, 5701	*	Allow	Bastion internal communication
AllowHttpOutbound	              Outbound	            10.0.0.0/26	Internet	80	*	Allow	Required outbound HTTP communication

## Consequences

This design reduces public attack surface because VMs do not have public IP addresses and are not directly reachable from the internet.

Using Application Gateway as the only public web entry point creates a controlled ingress layer for application traffic. This supports future TLS termination, routing rules, health probes, centralized ingress policy, and possible Web Application Firewall integration.

Using Azure Bastion as the only interactive administrative entry point removes the need to expose SSH or RDP to the public internet. This improves the administrative access posture and keeps management traffic on private VM addresses.

Keeping GitLab in snet-infra simplifies the initial design and keeps core platform services together during the current capstone phase.

The tradeoff is that GitLab shares a subnet with other infrastructure services, including the domain controller and DevOps tooling. This creates a broader trust zone than a dedicated GitLab subnet would. The risk is accepted for now because this is a controlled capstone environment, and GitLab runners are still isolated in their own subnet.

Separating GitLab runners from GitLab reduces blast radius. If a runner is compromised through a malicious pipeline job, dependency, script, or artifact, the compromise should not automatically place the attacker in the same subnet as GitLab or the domain controller.

Separating application and database workloads allows tighter access control. The database subnet can deny inbound traffic by default and only allow required database traffic from the application subnet.

The design is more complex than placing all VMs into one subnet. There are more subnets, NSGs, and traffic flows to maintain. This is intentional because the environment is being designed to model secure, production-style infrastructure.

The design requires disciplined NSG rule management. Overly broad allow rules would weaken the value of subnet segmentation. Overly restrictive rules may break application, domain, CI/CD, or administrative workflows. Each NSG rule should have a clear purpose.

This ADR establishes the expected network and access posture for the capstone platform. Future Terraform code should implement this design and should not introduce public VM access, shared GitLab/runner placement, or unnecessary direct internet access.