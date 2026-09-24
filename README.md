# Sonatype Nexus Workflows

This repository contains GitHub Actions workflows for building and deploying the Sonatype Nexus infrastructure.

The workflows use files from the private `sonatype-nexus-project` repository. This repository mainly controls when those infrastructure tasks run and provides the required AWS and Terraform inputs through GitHub secrets.

## Workflows

| Workflow | File | How it starts | Main purpose |
| --- | --- | --- | --- |
| Packer AMI Build | `.github/workflows/packer-build.yml` | Push to `main` or manual run | Builds an AWS machine image with Packer |
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

## Packer AMI Build

File: `.github/workflows/packer-build.yml`

### When it runs

This workflow runs in either of these cases:

- A commit is pushed to the `main` branch.
- A user starts it manually with **Run workflow**. Manual runs do not need any input values.

### What it does

The workflow runs one job named `Packer Build` on an Ubuntu runner:

1. Checks out the private `sonatype-nexus-project` repository into the `sonatype-nexus-project` directory.
2. Connects to AWS using `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
3. Uses AWS region `us-east-1`.
4. Installs the latest Packer version.
5. Changes to `sonatype-nexus-project/packer` and runs `packer init`.
6. Runs `packer build` in the same directory.
7. Passes the Packer values through environment variables:
	- `PACKER_SOURCE_AMI` becomes `PKR_VAR_source_ami`.
	- `PACKER_SG_ID` becomes `PKR_VAR_security_group_id`.
	- `PACKER_KEY_NAME` becomes `PKR_VAR_ssh_keypair_name`.

The result is an AMI created by the Packer configuration in the private infrastructure repository. The workflow itself does not deploy that AMI to other environments.

## Sonatype Nexus CD

File: `.github/workflows/terraform-deploy.yml`

CD means continuous delivery. This workflow is used to create or remove the Sonatype Nexus infrastructure.

### When it runs

This workflow only runs when a user starts it manually. The user must select both inputs:

| Input | Options | Meaning |
| --- | --- | --- |
| `actions` | `apply`, `destroy` | Create/update infrastructure or remove it |
| `environment` | `us-east-1`, `us-east-2`, `us-west-1`, `us-west-2` | AWS region and GitHub environment to use |

The selected value is also used as the GitHub Actions environment name. Configure environment-specific secrets and approval rules in GitHub if needed.

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

### Run the Packer workflow manually

1. Open the **Actions** tab in GitHub.
2. Select **Packer AMI Build**.
3. Select **Run workflow** on the `main` branch.
4. Review the job output and the AMI created in AWS.

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

The Terraform and Packer source files are stored in the private `sonatype-nexus-project` repository, not in this repository.

## Troubleshooting

- **Repository checkout fails:** Check `INFRA_REPO_PAT`, repository access, and the repository name in the workflow.
- **AWS authentication fails:** Check both AWS secrets and confirm that the credentials are valid for the selected region.
- **Packer variables are missing:** Check `PACKER_SOURCE_AMI`, `PACKER_SG_ID`, and `PACKER_KEY_NAME`.
- **Terraform variables are missing:** Check that `TFVARS` contains valid Terraform variable assignments and is configured in the GitHub environment used for the run.
- **Terraform uses the wrong state:** Confirm the selected region and the corresponding `terraform-<region>.tfstate` file.
- **Terraform cannot initialize:** Check the Terraform backend settings and AWS permissions in the private infrastructure repository.