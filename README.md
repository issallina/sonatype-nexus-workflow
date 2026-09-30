# Sonatype Nexus Workflows

This repository contains GitHub Actions workflows for building and deploying the Sonatype Nexus infrastructure.

The workflows use files from the private `sonatype-nexus-project` repository. This repository mainly controls when those infrastructure tasks run and provides the required AWS and Terraform inputs through GitHub secrets.

## Workflows

| Workflow | File | How it starts | Main purpose |
| --- | --- | --- | --- |
| Packer AMI Build | `.github/workflows/packer-build.yml` | Manual run only | Builds an AWS machine image with Packer |
| AMI Lifecycle Management | `.github/workflows/packer-workflow.yml` | Manual run only | Builds an AMI or purges AMIs using the selected action |
| Sonatype Nexus CD | `.github/workflows/terraform-deploy.yml` | Manual run only | Creates or removes the infrastructure with Terraform |

## Required setup

Before running either workflow:

1. Make sure the GitHub Actions runner can read the private `sonatype-nexus-project` repository.
2. Add the required secrets to the repository or to each GitHub environment used by the deployment workflow.
3. Make sure the AWS credentials have permission to perform the requested action.
4. Make sure the infrastructure repository contains the expected `packer` and `terraform` directories.

The workflows use AWS region `us-east-1` for the Packer build. The Terraform workflow uses the region selected when the workflow is started.

## Required secrets

| Secret | Used by | Description |
| --- | --- | --- |
| `INFRA_REPO_PAT` | Both workflows | Personal access token that can clone the private infrastructure repository |
| `AWS_ACCESS_KEY_ID` | Both workflows | AWS access key used by the GitHub Actions runner |
| `AWS_SECRET_ACCESS_KEY` | Both workflows | Secret AWS key used by the GitHub Actions runner |
| `PACKER_SOURCE_AMI` | Packer workflow | Source AMI ID used as the starting image |
| `PACKER_SG_ID` | Packer workflow | AWS security group ID used during the image build |
| `PACKER_KEY_NAME` | Packer workflow | AWS EC2 key pair name used by Packer |
| `TFVARS` | Terraform workflow | Complete Terraform variable file content for the deployment |

Do not commit AWS credentials, personal access tokens, Terraform variable files, or other secret values to this repository.

## Packer AMI Lifecycle Management

File: `.github/workflows/packer-workflow.yml`

### When it runs

This workflow runs only when a user starts it manually with **Run workflow**. Select one of these actions:

| Action | Result |
| --- | --- |
| `apply` | Initializes and runs the Packer build to create an AMI |
| `destroy` | Runs `sonatype-nexus-project/packer/packer-destroy.sh` to purge AMIs |

### What it does

The workflow runs on an Ubuntu runner and checks out the private `sonatype-nexus-project` repository. For `apply`, it:

1. Connects to AWS using `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in region `us-east-1`.
2. Installs the latest Packer version.
3. Runs `packer init .` and `packer build .` in `sonatype-nexus-project/packer`.
4. Passes the Packer values through environment variables:
	- `PACKER_SOURCE_AMI` becomes `PKR_VAR_source_ami`.
	- `PACKER_SG_ID` becomes `PKR_VAR_security_group_id`.
	- `PACKER_KEY_NAME` becomes `PKR_VAR_ssh_keypair_name`.

For `destroy`, the workflow runs the AMI purge script instead of setting up Packer or building an image.



## Sonatype Nexus CD

File: `.github/workflows/terraform-deploy.yml`

This workflow is used to create or remove the Sonatype Nexus infrastructure.

### When it runs

This workflow only runs when a user starts it manually. The user must select both inputs:

| Input | Options | Meaning |
| --- | --- | --- |
| `actions` | `apply`, `destroy` | Create/update infrastructure or remove it |
| `environment` | `us-east-1`, `us-east-2`, `us-west-1`, `us-west-2` | AWS region and GitHub environment to use |

The selected value is also used as the GitHub Actions environment name. Configure environment-specific secrets and approval rules in GitHub if needed.

### Required environmnet secrets

| Secret | Description |
| --- | --- |
| `TFVARS` | Complete Terraform variable file content for the deployment |

Configure `TFVARS` separately in each GitHub Environment: `us-east-1`, `us-east-2`, `us-west-1`, and `us-west-2`. Each environment's value should contain the Terraform variables for that region:

```text
region
vpc_cidr
subnet_cidrs
ports
instance_type
ssh_public_key
```

Use Terraform variable-file syntax and values matching the variable types defined in the private infrastructure repository.



### What it does

The workflow runs on an Ubuntu runner:

1. Checks out the private `sonatype-nexus-project` repository into the `sonatype-nexus-project` directory.
2. Creates `sonatype-nexus-project/terraform/terraform.tfvars` from the `TFVARS` secret.
3. Installs Terraform using the official HashiCorp setup action.
4. Connects to AWS using the selected region.
5. Changes to `sonatype-nexus-project/terraform` and runs `terraform init`.
6. Selects a state file named `terraform-<region>.tfstate`, for example `terraform-us-east-1.tfstate`.
7. Runs one of these commands:
	- `terraform apply` when `actions` is `apply`.
	- `terraform destroy` when `actions` is `destroy`.
8. Uses `-auto-approve`, so Terraform does not ask for confirmation in the workflow.

### Important warning about destroy

The `destroy` option can remove AWS resources. Review the selected region, Terraform variables, and state file before starting a destroy run. Because the workflow uses `-auto-approve`, the removal starts without an interactive confirmation prompt.

## Running a workflow

### Run the Packer AMI lifecycle workflow

1. Open the **Actions** tab in GitHub.
2. Select **AMI Lifecycle Management**.
3. Select **Run workflow** and choose `apply` or `destroy`.
4. Review the job output and the resulting AMI changes in AWS.

### Run the Terraform workflow

1. Open the **Actions** tab in GitHub.
2. Select **Sonatype Nexus CD**.
3. Select **Run workflow**.
4. Choose `apply` or `destroy`.
5. Choose the AWS region.
6. Start the workflow.
7. Review the Terraform output and AWS resources after the job finishes.

## Repository files

```text
.
├── .github/
│   └── workflows/
│       ├── packer-build.yml
│       └── terraform-deploy.yml
├── .gitignore
└── README.md
```

The Terraform and Packer source files are stored in the private `sonatype-nexus-project` repository.