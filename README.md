# GCP + Terraform + Ansible VM User Management

A production-style DevOps project that provisions Google Cloud VMs with Terraform and configures Linux users and SSH authentication with Ansible. GitHub Actions runs the complete workflow using Google Cloud Workload Identity Federation (WIF), so no long-lived GCP service-account key is stored in GitHub.

## What this project does

The pipeline:

1. Authenticates GitHub Actions to GCP using the existing WIF provider.
2. Creates the GCP networking and supporting resources with Terraform.
3. Creates three Ubuntu 24.04 VMs in `asia-south1-a`.
4. Generates a temporary Ed25519 SSH key on the GitHub runner for bootstrap access.
5. Adds the temporary public key to the VMs through Terraform metadata.
6. Uses Ansible to create the local users `ram`, `vicky`, and `mahesh`.
7. Reuses existing passwords from Secret Manager or generates strong passwords when required.
8. Stores newly generated passwords in Secret Manager.
9. Configures SSH so the managed local users can authenticate with passwords.
10. Validates the effective SSH configuration before the deployment is considered successful.

## Architecture

```text
                         GitHub Actions
                               |
                    GitHub OIDC / WIF
                               |
                               v
                    GCP Deploy Service Account
                               |
             +-----------------+-----------------+
             |                                   |
             v                                   v
         Terraform                           Ansible
             |                                   |
     +-------+--------+                 +--------+---------+
     |                |                 |                  |
     v                v                 v                  v
   VPC/Subnet      3 Ubuntu VMs     Linux users       SSH configuration
  10.0.0.0/24      asia-south1-a     ram/vicky/mahesh   password authentication
                         |
                         +------------------+
                                            |
                                            v
                                      Secret Manager
                                  ram/vicky/mahesh passwords
```

## Repository structure

```text
.
├── .github/
│   └── workflows/
│       ├── deploy.yml
│       └── terraform-plan.yml
│
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── example.yml
│   ├── playbooks/
│   │   └── users.yml
│   ├── roles/
│   │   ├── users/
│   │   │   ├── defaults/main.yml
│   │   │   └── tasks/
│   │   │       ├── controller_credentials.yml
│   │   │       └── main.yml
│   │   └── ssh/
│   │       └── tasks/main.yml
│   └── requirements.yml
│
├── terraform/
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── versions.tf
│   └── modules/
│       ├── network/
│       ├── service-account/
│       ├── secret-manager/
│       └── vm/
│
├── .gitignore
└── README.md
```

## GCP configuration

Current environment:

| Setting | Value |
|---|---|
| Region | `asia-south1` |
| Zone | `asia-south1-a` |
| Subnet CIDR | `10.0.0.0/24` |
| VM count | `3` |
| VM image | Ubuntu 24.04 LTS |
| VM machine type | `e2-micro` |
| Managed users | `ram`, `vicky`, `mahesh` |

The VMs currently receive public IPv4 addresses because the initial access model requires direct SSH access.

> **Security:** TCP/22 is currently open from `0.0.0.0/0` for the initial setup. Before production use, restrict SSH to trusted CIDRs or move to IAP, VPN, a bastion, or another private-access design.

## GitHub Actions authentication

GitHub Actions uses OIDC to exchange a short-lived GitHub identity for Google Cloud credentials through Workload Identity Federation.

The WIF provider is restricted to this repository:

```text
attribute.repository == 'kirthi0071/ansible-servers'
```

The provider mapping includes:

```text
attribute.repository = assertion.repository
google.subject      = assertion.sub
```

### Required GitHub repository variables

Configure:

```text
GCP_WIF_PROVIDER
GCP_SERVICE_ACCOUNT
```

`GCP_WIF_PROVIDER` should contain the complete WIF provider resource name.

`GCP_SERVICE_ACCOUNT` should contain the Google service-account email used by GitHub Actions.

No long-lived GCP JSON service-account key is required.

## Terraform flow

Terraform is responsible for infrastructure, not application/user configuration.

```text
terraform init
      |
      v
terraform validate
      |
      v
terraform apply
      |
      +--> VPC + subnet
      |
      +--> VM service account
      |
      +--> Secret Manager secret containers
      |
      +--> 3 Compute Engine VMs
              |
              +--> temporary bootstrap public SSH key
```

The Terraform state is stored remotely in the configured GCS backend.

## Ansible flow

After Terraform creates the VMs, the workflow obtains their public IPs from Terraform outputs and creates an inventory dynamically.

The Ansible playbook has two stages.

### Stage 1: Controller credential preparation

The controller checks Secret Manager for:

```text
ram-password
vicky-password
mahesh-password
```

If a usable secret value exists, it is reused. Otherwise Ansible generates a strong password with Python `secrets` and stores a new Secret Manager version.

Password values are protected with `no_log` and are never committed to the repository.

### Stage 2: VM configuration

Ansible connects using the temporary bootstrap key and:

```text
Create/update ram
Create/update vicky
Create/update mahesh
        |
        v
Configure SSH password authentication
        |
        v
Validate sshd configuration
        |
        v
Restart SSH
        |
        v
Run sshd -T and verify effective settings
```

## Why SSH originally showed `passwordauthentication no`

This was the main troubleshooting issue in the project.

The Linux users were created successfully, but that alone does **not** enable password-based SSH login.

The effective OpenSSH configuration initially reported:

```text
passwordauthentication no
kbdinteractiveauthentication no
usepam yes
```

This happened because the Ubuntu cloud image has SSH configuration under:

```text
/etc/ssh/sshd_config.d/
```

including files such as:

```text
50-cloudimg-settings.conf
60-cloudimg-settings.conf
```

OpenSSH reads the main configuration together with files in the `sshd_config.d` directory. The effective value is therefore not determined simply by looking at the last line we added to `/etc/ssh/sshd_config`.

In this project, the cloud-image configuration was explicitly setting password authentication to `no`. That is why an Ansible task could successfully add:

```text
PasswordAuthentication yes
```

to the main file while:

```bash
sshd -T
```

still returned:

```text
passwordauthentication no
```

### How we diagnosed it

The manual fix that worked on the VMs was to edit the cloud-image files directly:

```text
/etc/ssh/sshd_config.d/50-cloudimg-settings.conf
/etc/ssh/sshd_config.d/60-cloudimg-settings.conf
```

and then restart SSH.

We then changed the Ansible role to discover those files remotely and manage the directives there instead of assuming that modifying only `/etc/ssh/sshd_config` would be sufficient.

The role also runs:

```bash
sshd -t
```

before restarting SSH, and then:

```bash
sshd -T
```

to check the **effective** configuration.

This distinction is important:

```text
sshd_config files = configured values

sshd -T           = effective values actually used by sshd
```

The deployment should only pass when the effective configuration reports:

```text
passwordauthentication yes
kbdinteractiveauthentication yes
usepam yes
```

## SSH troubleshooting

If the pipeline fails at:

```text
TASK [ssh : Assert password authentication is enabled]
```

check the preceding task:

```text
TASK [ssh : Show effective SSH authentication settings]
```

### Case 1: `passwordauthentication no`

Inspect the cloud-image files first:

```bash
sudo grep -nE 'PasswordAuthentication|KbdInteractiveAuthentication|UsePAM' \
  /etc/ssh/sshd_config \
  /etc/ssh/sshd_config.d/*.conf
```

Then inspect the effective configuration:

```bash
sudo sshd -T | grep -E \
  'passwordauthentication|kbdinteractiveauthentication|usepam|authenticationmethods'
```

### Case 2: `passwordauthentication yes` but login still fails

Check whether SSH is requiring public-key authentication:

```bash
sudo sshd -T | grep -i authenticationmethods
```

Also confirm that the Linux user has a password and is not locked:

```bash
sudo passwd -S ram
sudo passwd -S vicky
sudo passwd -S mahesh
```

Check whether the shell is valid:

```bash
getent passwd ram
getent passwd vicky
getent passwd mahesh
```

### Case 3: SSH configuration syntax error

Validate before restarting:

```bash
sudo sshd -t
```

If this command returns no output and exit code `0`, the configuration syntax is valid.

### Case 4: Check the SSH service

```bash
sudo systemctl status ssh --no-pager
sudo journalctl -u ssh -n 100 --no-pager
```

## Bootstrap SSH key

The workflow creates an ephemeral Ed25519 key pair on the GitHub-hosted runner:

```text
GitHub runner
   |
   +--> private key: runner temporary directory
   |
   +--> public key --> Terraform --> VM metadata
   |
   +--> Ansible uses private key
```

The private key is not committed, stored in GitHub, or persisted as a permanent deployment credential. It exists only for the workflow job.

The bootstrap user is:

```text
ansible-bootstrap
```

The managed users (`ram`, `vicky`, `mahesh`) are separate local Linux accounts and use the passwords managed through Secret Manager.

## Secrets

Password secrets are stored in Google Cloud Secret Manager.

Important rules:

- Never put passwords in `.tfvars` files.
- Never commit passwords to Git.
- Never print password values in CI logs.
- Keep Ansible `no_log` enabled for credential-handling tasks.
- Restrict Secret Manager access to the identities that actually need it.

## Running through GitHub Actions

The main deployment workflow is manually triggered with `workflow_dispatch`.

Run:

```text
GitHub repository
  -> Actions
  -> Provision and Configure VMs
  -> Run workflow
```

The workflow performs:

```text
Checkout
  -> WIF authentication
  -> gcloud setup
  -> Terraform setup
  -> Ansible installation
  -> Generate temporary SSH key
  -> Terraform init
  -> Terraform validate
  -> Terraform apply
  -> Generate Ansible inventory
  -> Run Ansible
```

A successful run should finish with all three VMs passing the SSH assertion and the final Ansible recap showing no failed hosts.

## Local Terraform usage

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

For CI/CD, prefer the GitHub Actions workflow because it already handles WIF authentication, the temporary bootstrap key, Terraform outputs, and dynamic Ansible inventory.

## Security improvements before production

This repository intentionally represents an initial working implementation. Before using it for a real production environment, consider:

- Restricting TCP/22 instead of allowing `0.0.0.0/0`.
- Using private VMs where possible.
- Using IAP/VPN/bastion access instead of public SSH.
- Removing public IPs from VMs where they are not required.
- Applying least-privilege IAM roles to the GitHub deployer.
- Applying least-privilege IAM roles to VM service accounts.
- Enabling centralized logging and monitoring.
- Adding Terraform plan approval before production apply.
- Adding Ansible Molecule or other automated role tests.
- Rotating/revoking bootstrap access after provisioning if the architecture requires it.
- Using unique credentials per environment/VM when the security model requires it.
- Protecting the Terraform state bucket with appropriate IAM, retention, and security controls.

## Current known design choice

The same Secret Manager password for each username is applied to all three VMs. For example, the `ram-password` secret is the password for `ram` on each VM.

If each VM needs a unique password, change the secret naming scheme to include the VM identity, for example:

```text
ansible-vm-01-ram-password
ansible-vm-02-ram-password
ansible-vm-03-ram-password
```

## Status

The infrastructure and credential-management portions are working. The SSH role includes explicit diagnostics and an effective-configuration assertion so that SSH authentication failures are detected during deployment rather than after the infrastructure is considered complete.
