# infrastructure_personal_profile

Terraform code for managing my personal cloud infrastructure on **AWS** and **Cloudflare**. It is organized into two independent projects that can be deployed separately.

| Project | What it provisions |
|---|---|
| `hubstream` | EC2 instance running a Kubernetes (k3s) cluster, hosting the HubStream WebRTC app and a monitoring stack (Prometheus + Grafana + Loki) |
| `portfolio` | S3 static website for the personal portfolio page, with Cloudflare DNS |

---

## Architecture Overview

```
Cloudflare DNS
├── hubstream.yourdomain.com  → EC2 Elastic IP (proxied)
├── grafana.yourdomain.com    → EC2 Elastic IP (proxied)
├── prometheus.yourdomain.com → EC2 Elastic IP (proxied)
└── yourdomain.com / www      → S3 website endpoint (CNAME, proxied)

AWS
├── EC2 (t4g.medium, ARM64, Ubuntu 22.04)
│   └── k3s Kubernetes cluster
│       ├── hubstream namespace  → HubStream server + client deployments
│       └── monitoring namespace → Prometheus, Grafana, Loki, Alertmanager
├── S3 bucket                   → Portfolio static website
├── IAM Roles
│   ├── EC2 SSM role            → Allows SSM remote command execution
│   └── GitHub Actions role     → OIDC-based keyless CI/CD deploy role
└── Elastic IP                  → Static public IP for the EC2 instance
```

---

## Project Structure

```
infrastructure_personal_profile/
├── modules/
│   ├── single_node_cluster/   # Reusable module: EC2 + networking + IAM + Cloudflare DNS
│   └── static_website_s3/     # Reusable module: S3 static site + Cloudflare DNS
└── projects/
    ├── hubstream/             # Deploys the EC2 cluster + monitoring DNS records
    └── portfolio/             # Deploys the S3 portfolio site
```

Each project under `projects/` is an independent Terraform root with its own state. They can be applied in any order without dependencies on each other.

---

## Prerequisites

Before you begin, make sure you have the following installed and configured:

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with credentials (`aws configure`)
- A [Cloudflare](https://cloudflare.com) account with your domain's DNS managed there
- Your domain's nameservers must be pointed to Cloudflare

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/yuchia329/infrastructure_personal_profile.git
cd infrastructure_personal_profile
```

### 2. Deploy the HubStream EC2 cluster

```bash
cd projects/hubstream
```

Copy the example variables file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and fill in all required values (see the [Variables Reference](#variables-reference) section below). Then deploy:

```bash
terraform init
terraform plan    # Review what will be created
terraform apply
```

After a successful apply, Terraform will print:

```
Outputs:
  domain_url  = "https://hubstream.yourdomain.com"
  public_ip   = "1.2.3.4"
  ssh_command = "ssh -i ./hubstream.pem ubuntu@1.2.3.4"
```

The `.pem` SSH key is automatically written to `projects/hubstream/hubstream.pem`.

### 3. Deploy the portfolio S3 website

```bash
cd projects/portfolio
```

Copy or create a `terraform.tfvars` file:

```hcl
domain_name        = "yourdomain.com"
cloudflare_zone_id = "YOUR_CLOUDFLARE_ZONE_ID"
cloudflare_api_token = "YOUR_CLOUDFLARE_API_TOKEN"
```

Then deploy:

```bash
terraform init
terraform plan
terraform apply
```

This creates the S3 bucket and sets the Cloudflare `CNAME` records for both the root domain and `www`.

---

## Variables Reference

### `projects/hubstream`

| Variable | Description | Example |
|---|---|---|
| `aws_region` | AWS region to deploy into | `"us-east-1"` |
| `project_name` | Prefix used for all resource names | `"hubstream"` |
| `environment` | Environment tag applied to resources | `"production"` |
| `instance_type` | EC2 instance type — must be ARM64 (`t4g`) | `"t4g.medium"` |
| `allowed_ssh_cidr` | CIDR block allowed to SSH and access the k8s API | `"1.2.3.4/32"` |
| `domain_name` | Your root domain managed in Cloudflare | `"yourdomain.com"` |
| `subdomain` | Subdomain for the main app (use `"@"` for the apex) | `"hubstream"` |
| `cloudflare_zone_id` | Zone ID from Cloudflare dashboard | `"abc123..."` |
| `cloudflare_api_token` | Cloudflare API token with **Zone DNS Edit** permission | `"xyz..."` |
| `github_repos` | GitHub repos allowed to assume the deploy role via OIDC | `["youruser/HubStream"]` |

> **Tip:** Find your Cloudflare Zone ID in the Cloudflare Dashboard → your domain → Overview → right sidebar.

> **Tip:** Create an API token at [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens) with **Zone → DNS → Edit** permission scoped to your domain.

### `projects/portfolio`

| Variable | Description | Example |
|---|---|---|
| `domain_name` | Your root domain (also used as the S3 bucket name) | `"yourdomain.com"` |
| `cloudflare_zone_id` | Zone ID from Cloudflare dashboard | `"abc123..."` |
| `cloudflare_api_token` | Cloudflare API token with **Zone DNS Edit** permission | `"xyz..."` |

---

## What Gets Created

### `hubstream` project

| AWS Resource | Purpose |
|---|---|
| VPC + Subnet + Internet Gateway | Isolated network for the EC2 instance |
| Security Group | Opens ports 22, 80, 443, 4000 (WebSocket), 40000–49999 UDP (WebRTC media), 6443 (k8s API) |
| Elastic IP | Static public IP that survives instance reboots |
| EC2 Instance (t4g.medium) | ARM64 Ubuntu 22.04 — bootstrapped with Docker via `user_data` |
| SSH Key Pair | Auto-generated ED25519 key, saved locally as `hubstream.pem` |
| IAM Role (EC2) | Grants the EC2 instance SSM access and permission to pull from S3 |
| IAM Role (GitHub Actions) | Keyless OIDC authentication for GitHub Actions CI/CD |
| IAM OIDC Provider | Connects GitHub's token issuer to AWS |
| Cloudflare A Records | `hubstream`, `grafana`, and `prometheus` subdomains → EC2 Elastic IP |

### `portfolio` project

| Resource | Purpose |
|---|---|
| S3 Bucket | Hosts the static website files |
| S3 Bucket Policy | Allows public read access |
| Cloudflare CNAME (root) | `yourdomain.com` → S3 website endpoint |
| Cloudflare CNAME (www) | `www.yourdomain.com` → root domain |

---

## GitHub Actions CI/CD Setup

The `hubstream` project creates an IAM role that allows GitHub Actions to deploy without storing any AWS credentials. To wire it up:

1. In your GitHub repository, go to **Settings → Environments → Prod** and add the following secrets:
   - `DOCKERHUB_USERNAME`
   - `DOCKERHUB_TOKEN`

2. The `role-to-assume` ARN in your workflow must match the role name Terraform created:
   ```
   arn:aws:iam::<YOUR_ACCOUNT_ID>:role/hubstream-github-actions-deploy-role
   ```

3. The `github_repos` variable in `terraform.tfvars` **must exactly match** the casing of your repository name on GitHub (e.g., `"yuchia329/HubStream"`, not `"yuchia329/hubstream"`). GitHub OIDC claims are case-sensitive.

---

## Security Notes

- **Never commit `terraform.tfvars`** — it contains your Cloudflare API token and other secrets. It is already included in `.gitignore`.
- **Never commit `*.tfstate`** — state files can contain sensitive resource IDs and outputs. Also included in `.gitignore`.
- The SSH CIDR (`allowed_ssh_cidr`) defaults to `0.0.0.0/0` in the example. For production, **restrict this to your own IP** (`curl ifconfig.me`).
- The Cloudflare proxy (`proxied = true`) is enabled on all DNS records, which hides the real EC2 IP from the public internet.

---

## Useful Commands

```bash
# See what Terraform will create/change before applying
terraform plan

# Apply changes
terraform apply

# Destroy all resources in a project (use with caution!)
terraform destroy

# SSH into the EC2 instance (after apply)
ssh -i ./hubstream.pem ubuntu@<public_ip>

# View Terraform outputs
terraform output
```

---

## Modules

### `modules/single_node_cluster`

A self-contained module that provisions everything needed to run a single-node Kubernetes cluster on EC2. Accepts `project_name` as a prefix for all resource names, making it reusable across different projects.

**Inputs:** `aws_region`, `project_name`, `environment`, `instance_type`, `allowed_ssh_cidr`, `domain_name`, `subdomain`, `cloudflare_zone_id`, `cloudflare_api_token`, `github_repos`

**Outputs:** `public_ip`, `domain_url`, `fqdn`, `ssh_command`, `cloudflare_record_id`

### `modules/static_website_s3`

Provisions an S3 bucket configured for static website hosting and sets up the corresponding Cloudflare CNAME records.

**Inputs:** `domain_name`, `cloudflare_zone_id`, `cloudflare_api_token`

**Outputs:** `website_endpoint`