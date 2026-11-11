# 0004 - Branching and Promotion Strategy

## Status
Accepted

## Context
The platform is built by one engineer, with all CI/CD running in GitLab. A few facts constrain how branches can be used:

- The pipeline authenticates to Azure with OIDC. The Entra ID federated credential trusts tokens from the `master` branch only (ADR-0003), so only pipelines on `master` can change Azure.
- Pipelines currently run on `master` only. Jobs run when their own code changes (bootstrap, dev environment, modules), and every apply is a manual gate that uses the reviewed plan file.
- There is one environment today (dev). A production environment is planned later.
- `master` is mirrored to a public GitHub repository, so its history is part of the portfolio.
- Early in the build, work was committed straight to `master`, which left fix-up commits ("fixed directory path", "fixed anchor reference") in the history of the branch that deploys.

The strategy has to keep `master` deployable, keep the OIDC trust boundary simple, and grow from one environment to two without restructuring.

## Options Considered

### GitFlow
Long-lived `develop` and `master` branches, plus `release/*` and `hotfix/*` branches.
Rejected: designed for versioned software releases with parallel release lines. For a single-engineer infrastructure repo it adds merge overhead and long-lived branches with no matching benefit.

### Environment branches
One long-lived branch per environment (for example `dev` and `prod`), promoting changes by merging between them.
Rejected: environment branches drift apart over time, and each one would need its own federated credential, which widens the set of branches that can change Azure.

### Trunk-based development (GitLab Flow with pipeline promotion)
`master` is the only long-lived branch. Work happens on short-lived branches merged through merge requests. Environments are promoted by the pipeline from `master`, not by merging between branches.
Selected.

## Decision

### Branches
- `master` is the trunk and is always deployable. It is the only branch that can change Azure.
- All other branches are short-lived and scoped to one unit of work, named by type:
  - `feature/` new infrastructure or capabilities (for example `feature/phase4-secrets`)
  - `fix/` corrections
  - `ci/` pipeline changes
  - `docs/` documentation only
- A phase-sized feature branch may live for several weeks. It merges `master` in regularly so it does not drift.

### Merging
- Every change reaches `master` through a merge request with a short description: what changed, why, and how it was tested.
- `master` is a protected branch: no direct pushes, no force pushes, merges through merge requests only.
- Long-running branches are squash-merged so `master` records one commit per unit of work.
- Source branches are deleted after merge.

### Promotion between environments
- Environments are promoted by the pipeline from the same commit on `master`, never by merging between branches.
- Today: dev plans run automatically on `master` and apply through a manual gate.
- When production exists: the same `master` commit is applied to dev first, then to prod through a GitLab protected environment that requires approval.

### Mirroring
- Only protected branches (`master`) are mirrored to GitHub. Feature branches and work in progress stay private in GitLab.

## Consequences
The OIDC trust boundary stays simple: one branch, one federated credential, and branch protection on `master` is the control that decides who can change Azure.

`master` history reads as one commit per change, which suits a public portfolio repository.

Adding a production environment requires no change to the branching model, only new pipeline jobs and a protected environment.

Because pipelines run on `master` only, nothing validates a branch before it merges. A broken change is found after merge, on the branch that deploys. Accepted for now; the revisit triggers below close this gap.

Squash merging removes the individual commits of a long-running branch from `master`. The detailed history remains in the merge request in GitLab.

### Revisit trigger: validate branches before merge
Add merge request pipelines that run `terraform fmt -check` and `terraform validate`, and require them to pass before merge. This needs no Azure access.

### Revisit trigger: plan on merge requests
Running `terraform plan` on merge requests needs a separate read-only pipeline identity with its own federated credential, so branches can preview changes but never apply them. To be decided in its own ADR.

### Revisit trigger: production environment
When prod is added, give production its own pipeline identity. Its client ID is stored as a CI/CD variable scoped to a GitLab protected environment that requires approval, so only an approved production job can authenticate with production access.

### Revisit trigger: additional contributors
If anyone else contributes, require an approving review on merge requests before merge.