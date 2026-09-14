# GCP + Terraform + Ansible Local User Management

This project provisions 3 GCP VMs in `asia-south1-a`, then uses Ansible to configure the same local users (`ram`, `vicky`, `mahesh`) on every VM.

## Architecture

```text
GitHub Actions
  └─ Workload Identity Federation (existing provider)
       ├─ Terraform
       │   ├─ Custom VPC
       │   ├─ 10.0.0.0/24 subnet
       │   ├─ 3 Ubuntu VMs with public IPs
       │   ├─ Custom VM service account
       │   └─ Secret Manager secret containers
       └─ Ansible
           ├─ Creates/reuses strong passwords
           ├─ Stores generated passwords in Secret Manager
           ├─ Creates ram/vicky/mahesh on all VMs
           └─ Enables and safely reloads SSH password authentication
```

The GitHub Actions runner creates an **ephemeral SSH key only for bootstrap**. The application users authenticate with their local passwords after Ansible completes.

## Existing WIF provider

The provider should map:

```text
attribute.repository = assertion.repository
```

and restrict access with:

```text
attribute.repository == 'kirthi0071/ansible-servers'
```

The repository shown above is the exact repository this project uses.

## GitHub repository variables

Configure these repository variables:

- `GCP_WIF_PROVIDER`: full Workload Identity Provider resource name from the existing WIF setup.
- `GCP_SERVICE_ACCOUNT`: service account email used by GitHub Actions through WIF.

No long-lived GCP JSON key is required.

The GitHub Actions service account needs permission to provision Compute Engine resources, create/manage the VM service account, manage Secret Manager secret resources, and impersonate/use the VM service account. Grant only the minimum roles required by your organization.

## Network

- Region: `asia-south1`
- Zone: `asia-south1-a`
- Custom VPC
- Subnet: `10.0.0.0/24`
- 3 VMs with public IPv4 addresses for the initial setup
- TCP/22 is currently allowed from `0.0.0.0/0` for the requested initial login model.

**Before production, replace this with a trusted CIDR and preferably use VPN/IAP/bastion/private access.**

## Password lifecycle

Ansible checks `ram-password`, `vicky-password`, and `mahesh-password` in Secret Manager.

- If a secret already has a current value, Ansible reuses it.
- If it has no usable value, Ansible generates a strong, memorable password using Python `secrets`, stores a new Secret Manager version, and applies the password to the local Linux account.
- Password values are hidden from Ansible output with `no_log`.
- Passwords are never committed to Git.

The same password for each user is used on all three VMs because the requirement is the same users across every VM. If unique credentials per VM are needed later, change the secret naming model to include the VM name.

## Bootstrap model

The workflow does not need a permanent SSH private key. It creates a temporary Ed25519 keypair on the GitHub runner, passes the public key to Terraform as VM metadata, and uses the private key to run Ansible in the same workflow job. The temporary key is discarded when the runner is destroyed.

## Repository layout

```text
terraform/
  modules/network
  modules/service-account
  modules/secret-manager
  modules/vm
ansible/
  inventory
  playbooks
  roles/users
  roles/ssh
.github/workflows/
  terraform-plan.yml
  deploy.yml
```

## Local usage

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

For CI/CD, use the GitHub Actions workflow after configuring the WIF repository variables.