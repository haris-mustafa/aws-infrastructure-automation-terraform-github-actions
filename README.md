# AWS DevOps Project: Terraform + GitHub Actions

A small but complete DevOps project. The whole AWS environment is created with
**Terraform (Infrastructure as Code)** and deployed automatically by a
**GitHub Actions CI/CD pipeline**.

## What the app does

A tiny website with two features:

1. **Visitor counter**: every page load increments a counter in DynamoDB.
   Every 10th visit sends you an email alert.
2. **File upload**: upload a file from the browser straight to a private S3
   bucket. Each upload sends you an email alert.

## Architecture

```
                    Browser
                       |
        +--------------+----------------+
        | (HTML page)                   | (API calls)
        v                               v
  EC2 + nginx (in VPC)          API Gateway (HTTP API)
                                  |                 |
                       POST /visit                  GET /upload-url
                                  v                 v
                         Lambda: counter      Lambda: upload-url
                           |         |                |
                           v         v                v (presigned URL)
                      DynamoDB      SNS <--------- S3 bucket <--- browser PUTs file
                                     |    (S3 event on upload)
                                     v
                                   Email

  CloudWatch: logs, alarms (Lambda errors, EC2 CPU) -> SNS, dashboard
```

| AWS service | Role in the project |
|---|---|
| **VPC** | Private network, public subnet, internet gateway, security group |
| **EC2** | Amazon Linux server running nginx that serves the website |
| **S3** | Stores uploaded files (private, encrypted); Terraform state bucket |
| **DynamoDB** | Stores the visitor count |
| **Lambda** | Two Python functions (counter, presigned upload URL) |
| **API Gateway** | Public HTTP API in front of the Lambdas |
| **SNS** | Email alerts (milestones, uploads, alarms) |
| **CloudWatch** | Log groups, alarms, dashboard |
| **IAM** | Least-privilege roles for Lambda and EC2 |

## Project structure

```
aws-devops-project/
├── README.md                    <- you are here
├── requirements-dev.txt         <- test dependencies
├── app/
│   ├── lambda/
│   │   ├── visitor_counter.py   <- Lambda: POST /visit
│   │   └── upload_url.py        <- Lambda: GET /upload-url
│   └── web/index.html           <- website served by nginx on EC2
├── tests/test_lambdas.py        <- unit tests (no AWS needed)
├── terraform/
│   ├── versions.tf              <- providers + remote state (S3)
│   ├── variables.tf             <- settings
│   ├── vpc.tf  ec2.tf  s3.tf  dynamodb.tf
│   ├── lambda.tf  api_gateway.tf  sns.tf  cloudwatch.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example <- copy to terraform.tfvars
├── scripts/bootstrap_backend.sh <- creates the state bucket (run once)
└── .github/workflows/
    ├── ci.yml                   <- tests + terraform validate on PRs/branches
    ├── deploy.yml               <- test -> plan -> apply -> smoke test on main
    └── destroy.yml              <- manual teardown
```

## Prerequisites

- An AWS account and an IAM user with access keys (AdministratorAccess is fine
  for learning; use least privilege for real projects)
- [AWS CLI](https://aws.amazon.com/cli/), [Terraform >= 1.10](https://developer.hashicorp.com/terraform/install), Python 3.12, Git
- A GitHub account

## Quick start (local deploy)

```bash
# 1. Configure AWS credentials
aws configure                         # region: ap-south-1

# 2. Run the tests
pip install -r requirements-dev.txt
pytest -v

# 3. Create the Terraform state bucket (once)
./scripts/bootstrap_backend.sh        # prints the bucket name

# 4. Configure and deploy
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit alert_email!
terraform init -backend-config="bucket=<bucket-from-step-3>"
terraform plan
terraform apply

# 5. Confirm the SNS subscription email, then open the website_url output
```

## CI/CD with GitHub Actions

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | PR / push to non-main branch | pytest, `terraform fmt -check`, `terraform validate` (no AWS access) |
| `deploy.yml` | push to `main` | pytest, `terraform plan`, `terraform apply`, smoke-test the API |
| `destroy.yml` | manual | `terraform destroy` (needs you to type `DESTROY`) |

Add these in **GitHub repo > Settings > Secrets and variables > Actions**:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | access key of your IAM user |
| `AWS_SECRET_ACCESS_KEY` | its secret key |
| `TF_STATE_BUCKET` | bucket name printed by `bootstrap_backend.sh` |
| `ALERT_EMAIL` | email that should receive alerts |

## Test it

- Open `website_url`: the counter should show 1, then 2, ...
- Upload a file: you get an email, and the file appears in the S3 bucket
- Reach 10 visits: milestone email
- Open CloudWatch > Dashboards > `devops-demo-dashboard`
- Change something small (e.g. a title in `index.html`), push to `main`,
  and watch the pipeline redeploy it

## Cost

Mostly Free-Tier friendly, but the EC2 instance and API calls can cost a little
after the free tier. **Always run `terraform destroy` (or the Destroy workflow)
when you finish experimenting.** The state bucket is not managed by Terraform;
delete it manually in the S3 console if you want it gone.

## Cleanup

```bash
cd terraform && terraform destroy
```

## Troubleshooting

| Problem | Fix |
|---|---|
| No emails | Click the confirmation link in the "AWS Notification - Subscription Confirmation" email (check spam) |
| Website not loading right after apply | Wait 1-2 minutes; nginx installs on first boot |
| `Error acquiring the state lock` | A previous run crashed; `terraform force-unlock <ID>` |
| `terraform fmt -check` fails in CI | Run `terraform fmt -recursive` locally and commit |
| Upload fails in the browser | Open DevTools > Network and check the S3 PUT response / CORS error |
| Region mismatch | Keep `ap-south-1` identical in `versions.tf`, `variables.tf`, the workflows, and the bootstrap script |

## Ideas to extend

- Replace access keys with GitHub OIDC (no long-lived secrets)
- Add HTTPS with CloudFront + ACM, serve the site from S3 instead of EC2
- Split Terraform into modules and add `dev` / `prod` environments
- Add `tflint` / `checkov` security scanning to `ci.yml`
