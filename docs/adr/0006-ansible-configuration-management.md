# ADR-0006 — Ansible for VM Configuration Management

**Status:** Accepted

## Context
Phase 5 provisions Azure VMs via Terraform with nginx installed through cloud-init.
A separate tool is needed to manage ongoing configuration and content delivery —
file deployment, service state, and future role-based configuration — without
re-running Terraform or SSHing manually each time.

The control node is WSL on the engineer's local machine. The target VM is in Azure
with SSH key auth only, no password, and no public access except on port 22 from
approved admin IPs.

## Decision
Use Ansible as the configuration management layer, running agentlessly from the WSL
control node over SSH. Terraform owns infrastructure provisioning; Ansible owns
everything that happens on the machine after it exists.

## Structure
| Path | Purpose |
|------|---------|
| `ansible/inventory.ini` | Static inventory, `webservers_azure` group |
| `ansible/group_vars/webservers_azure.yml` | SSH connection vars |
| `ansible/site.yml` | Site deployment playbook |
| `ansible.cfg` | Default inventory path |

## Alternatives Considered
**Chef / Puppet** — agent-based, requires installing and managing an agent on every
VM. Heavier operational overhead for a small environment. Rejected.

**Terraform `remote-exec` provisioner** — tightly couples configuration to
provisioning. Makes re-runs risky and blurs the boundary between infrastructure and
configuration. Rejected in favor of clean tool separation.

**Manual SCP + SSH** — not repeatable, not version-controlled, not auditable.
Rejected.

## Consequences
- Clear boundary: Terraform = infrastructure, Ansible = configuration
- Deployments are idempotent and version-controlled
- Inventory must be kept in sync with Terraform outputs manually until dynamic
  inventory is implemented
- SSH key must be present on the control node; not managed by CI/CD yet
- Future: add an Ansible stage to the GitLab CI pipeline so deploys run
  automatically on merge to master