# ACS730 Assignment 1 - Multi-Environment Deployment

Student: Liyang Yin
Repository: https://github.com/Freya-learn/acs730

## Introduction

In this assignment I took the Terraform from Week 7 (a security group and EC2 web servers that use Session Manager, with no SSH) and made it work for three environments: dev, staging and prod. The resources now live in one reusable module, and each environment calls the module with its own values and its own state file. The GitHub Actions pipeline applies staging automatically when code is merged to main, and prod waits for a human approval. The AWS credentials are now stored only on the GitHub Environments, not at repository level. I also added a database password that Terraform reads from SSM Parameter Store, and a CloudWatch alarm on CPU. At the end I compare this pipeline with an AWS-native pipeline and give my recommendation.

## Task 1 - Reusable module

The module is in `terraform/modules/web/`. It creates one security group (port 80 in, no port 22) and one or more EC2 instances that use `LabInstanceProfile`, so they can be reached with Session Manager.

Inputs (`variables.tf`). I chose as inputs only the values that are different between environments:

| Input | Type | Validation | Why it is an input |
|---|---|---|---|
| `environment` | string | must be dev, staging or prod | used in names and tags |
| `instance_type` | string | t3.micro or t3.small only | prod could be bigger; the list protects the budget |
| `instance_names` | set(string) | 1 to 3 names | prod has two servers, dev and staging have one |
| `http_ingress_cidrs` | list(string) | every item must be a valid CIDR | each environment can limit who reaches port 80 |
| `extra_tags` | map(string) | none, default `{}` | optional extra tags |

Values that are the same in all three environments are `locals`, not inputs: the instance profile name, the name prefix, the common tags and the SSM parameter path.

Outputs (`outputs.tf`): `instance_ids`, `public_ips`, `security_group_id`, `cpu_alarm_names` and `db_password_parameter` (the parameter name only, never the value).

Why `for_each` and not `count`: with `for_each` each instance has a stable address based on its name, for example `aws_instance.web["web-2"]`. If I remove one name, Terraform destroys only that instance. With `count` the address is a position, `aws_instance.web[1]`. If I remove the first item, every later instance moves to a new index and Terraform wants to replace them. For servers that should not be rebuilt by accident, `for_each` is safer.

The module also uses `lifecycle { ignore_changes = [ami] }`. The AMI comes from the public AL2023 SSM parameter and changes when Amazon publishes a new image. Without this, a new AMI released between the staging apply and the prod apply would make Terraform replace the servers.

## Task 2 - Three environment directories

`terraform/dev/`, `terraform/staging/` and `terraform/prod/` each have a `main.tf` that calls `../modules/web` and an `outputs.tf`. The only differences are the values they pass and the backend key:

| Environment | Backend key | instance_names |
|---|---|---|
| dev | `assignment1/dev/terraform.tfstate` | web-1 |
| staging | `assignment1/staging/terraform.tfstate` | web-1 |
| prod | `assignment1/prod/terraform.tfstate` | web-1, web-2 |

All three use the same bucket `acs730-tfstate-731254789382` with encryption and S3 native locking (`use_lockfile = true`). I changed the key in the same edit as the copy, before `terraform init`, and checked that the first plan in staging and prod only added resources and destroyed nothing. `evidence/backend-state-keys.txt` shows three different keys in one bucket.

## Task 3 - GitHub Environments

- `staging`: no protection rules, so a merge to main applies it with no human in the loop.
- `prod`: one required reviewer (Freya-learn). "Allow administrators to bypass" is turned off, so as the repository owner I cannot skip the gate. A deployment branch rule allows only `main`.

The workflow is `.github/workflows/assignment1.yml`, scoped with `paths: assignment1/**`. On a pull request it runs fmt, validate and plan for staging. On a push to main it runs `deploy-staging`, and `deploy-prod` starts only after staging succeeds and the reviewer approves. The paths filter excludes `assignment1/evidence/**` and `assignment1/REPORT.md`, so committing evidence after teardown does not deploy staging again.

Before merging I disabled three old workflows (`lab3-deploy`, `lab3-ci`, `lab4-ci`). They have no paths filter, and `lab3-deploy` would have applied Lab 3 again on the merge to main. Evidence: `evidence/environments.json`.

## Task 4 - Scoped credentials and OIDC trust policy

The three secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN` now exist only on the `staging` and `prod` environments. I created them there first, ran the pipeline to check it still worked, and then deleted the repository-level copies. Evidence: `evidence/secrets-scope.txt` (the repository list is empty).

From now on the per-session refresh is:

```
./scripts/refresh-gha-creds.sh Freya-learn/acs730 staging prod
```

The old form without environment names still exits with success, but it writes repository-level secrets that no job can read anymore.

### OIDC trust policy for the prod role (written, not deployed)

In a real AWS account I would not store any AWS keys in GitHub. The prod job would get a short-lived token from GitHub's OIDC provider and exchange it for a role. This is the trust policy I would attach to the prod role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::731254789382:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:Freya-learn/acs730:environment:prod"
        }
      }
    }
  ]
}
```

What each part prevents:

- `Principal.Federated`: only tokens from the GitHub OIDC provider registered in this account are trusted. A token from any other identity provider cannot use this role.
- `Action: sts:AssumeRoleWithWebIdentity`: the role can only be taken with a web identity token, not with normal IAM user keys.
- `aud = sts.amazonaws.com`: the token must be created for AWS STS. A GitHub token that was created for a different service cannot be reused here.
- `sub = repo:Freya-learn/acs730:environment:prod`: this is the most important condition. GitHub puts the environment name into the `sub` claim when a job runs with `environment: prod`. So only a job in this repository that runs in the prod environment can assume the role. Because the prod environment requires a reviewer and only allows `main`, the role can only be used after a person approves a deployment from main. `StringEquals` is used, not `StringLike`, so there is no wildcard.

Compared with a loose condition like `repo:Freya-learn/acs730:*`: that wildcard matches every job in the repository, on any branch, in any environment, and in pull requests. Anyone with push access could create a new branch, add a workflow that assumes the prod role, and run `terraform destroy` or read prod data. The approval gate would not help, because their job does not need to use the prod environment at all. Pinning `sub` to the prod environment ties the AWS permission to the GitHub approval.

The workflow would also need `permissions: id-token: write` and the `role-to-assume` option of `aws-actions/configure-aws-credentials` instead of the three secrets.

Why it is not deployed: AWS Academy Learner Lab denies the IAM write actions this needs (creating an OIDC identity provider and creating a role with a custom trust policy). That is why this course uses session credentials and the refresh script instead.

## Task 5 - Real deployment

I merged pull request #13 to main. Branch protection on `main` still requires three checks from Lab 5 (`summary`, `fmt and validate`, `plan and apply against LocalStack`). Those checks only run when `lab5/` changes, so this pull request could never get them. The assignment1 plan check had passed, so I merged as the repository owner with `gh pr merge 13 --merge --admin`. I did not change the protection rules, so the earlier labs keep their checks.

The push to main started run #6. `deploy-staging` applied automatically in 40 seconds: 3 resources added (security group, one instance, one alarm). `deploy-prod` then waited for review (`evidence/prod-approval-pending.png`). I approved it (`evidence/prod-approval-approved.png`) and prod applied 5 resources (security group, two instances, two alarms). The apply logs are saved as text in `evidence/staging-apply.txt` and `evidence/prod-apply.txt`, because run logs expire with Actions retention.

## Task 6 - Secrets management with SSM Parameter Store

The placeholder database password is stored as a `SecureString` in SSM Parameter Store, one per environment. I created it once by hand from the workstation, before the first plan that reads it. This is the documented pre-step:

```
for env in dev staging prod; do aws ssm put-parameter --name "/acs730/assignment1/$env/db-password" --type SecureString --value "placeholder-$env-not-a-real-password" --description "ACS730 A1 placeholder DB password ($env)"; done
```

Terraform only reads it, with `data "aws_ssm_parameter" "db_password"`. No Terraform resource creates it. If Terraform created and read the same parameter, it would be circular, and a fresh environment (like the CI runner) would fail at plan time. The module passes the value into `user_data`, which writes it to `/etc/acs730/app.env` with mode 600 on first boot. Terraform marks the value as sensitive, so it shows as `(sensitive value)` in plans and in pipeline logs. The password is not in the repository.

Note: the module has a second `aws_ssm_parameter` data source, for the public AL2023 AMI id. That one is published by AWS. It is also read-only.

Limitation: the value is still stored in the Terraform state and in the instance user data. The state bucket is encrypted and private, but in a real project I would give the application permission to read the parameter at start-up, so the secret never passes through Terraform.

Evidence: `evidence/ssm-parameter.txt`.

## Task 7 - CloudWatch alarm

The module creates one `aws_cloudwatch_metric_alarm` for each instance, on `AWS/EC2 CPUUtilization`. It goes to ALARM when the average CPU is above 80% for two 5-minute periods. I chose CPU because EC2 reports it every 5 minutes even when the server is idle, so the alarm reaches OK instead of staying in INSUFFICIENT_DATA. A metric like request count would have no data on a server nobody calls. Evidence: `evidence/cloudwatch-alarm.json` and `evidence/cloudwatch-alarm.png`, captured after several evaluation periods.

The alarm has no action yet. In a real setup I would add an SNS topic so the team gets an email.

## Task 8 - Recommendation: GitHub Actions or an AWS-native pipeline?

The question is for a team that is fully committed to AWS and has no multi-cloud plans. For this team I recommend an **AWS-native pipeline (CodePipeline with CodeBuild)**, with GitHub kept as the source repository. My reasons:

**1. Where the identity lives.** In CodeBuild, the build runs with an IAM service role. There are no keys to store and no OIDC provider or trust policy to keep correct. In this assignment, a big part of the work was moving secrets and writing the OIDC trust policy, and a small mistake in the `sub` condition could open prod to any branch. With CodeBuild, permissions are normal IAM policies, and every action is in CloudTrail under one account, which the team already monitors.

**2. Access to private resources (VPC).** CodeBuild can run inside the team's VPC, so it can reach a private database or an internal API. GitHub-hosted runners run on the internet. The day the pipeline needs VPC-internal access, for example to run database migrations, the team must add self-hosted runners.

**3. Who runs and patches the runners, and what it costs.** With GitHub-hosted runners the cost is low, but they cannot reach the VPC (point 2). Self-hosted runners are EC2 instances the team must patch, scale and secure, and they are a target because they hold credentials. CodeBuild is paid per build minute, and AWS maintains the build images.

**4. What the team already knows.** An AWS-only team already uses IAM, CloudWatch and CloudTrail. CodeBuild logs go to CloudWatch, and a manual approval action in CodePipeline does the same job as the prod reviewer in GitHub Environments. The team does not need to learn a second permission system.

The trade-offs I accept: GitHub Actions has a bigger marketplace, the workflow file is easier to read than buildspec plus pipeline definition, and the developer experience next to the pull request is better. If the team had multi-cloud plans, these points would matter more. For a team that will stay on AWS, keeping identity, network and logs inside AWS is the stronger choice.

**My recommendation: AWS-native pipeline (CodePipeline + CodeBuild).**

## Task 9 - Teardown

After the evidence was captured, I destroyed staging, prod and dev with `terraform destroy`, with the output saved in `evidence/destroy-complete.txt`, and ran `scripts/cleanup-check.sh` to confirm only the workstation is still running.

## Conclusion

What I learned:

- **The state key is the real separation between environments.** Copying `dev/` was easy; the risk was the one line with the key. I checked the plan in each new environment before the first apply: if staging had used the dev key, its first plan would have tried to change dev's resources.
- **State locking works.** Once my local `terraform destroy` and a pipeline plan ran on the staging state at the same time. The pipeline failed with "Error acquiring the state lock" instead of reading a half-written state. I re-ran it after the destroy finished. This showed me why local applies and CI should not touch the same environment at the same time.
- **Credentials follow the environment.** After the secrets moved to environments, the old refresh command still "succeeds" but writes to a place no job reads. A silent success is worse than an error, so I recorded the new command.
- **Small practical problems take real time.** The workstation disk was full because every lab directory had its own 700 MB copy of the AWS provider. I removed the old `.terraform` folders and set up a shared plugin cache.

What I would change in a real project:

1. Use the OIDC role from Task 4 instead of stored session keys.
2. Run a plan for prod during the pull request (a separate read-only role), so the reviewer sees the prod plan before approving.
3. Save the plan with `terraform plan -out` and apply that exact file, so prod applies exactly what was reviewed.
4. Add an SNS action to the alarm, and let the application read its secret from Parameter Store at start-up instead of through Terraform.

## Evidence

All files are in `assignment1/evidence/`:

| File | Shows |
|---|---|
| backend-state-keys.txt | three different state keys in one bucket |
| environments.json | staging and prod settings, reviewer and branch policy |
| secrets-scope.txt | no AWS secrets at repository level, three on each environment |
| prod-approval-pending.png | prod job waiting for review |
| prod-approval-approved.png | prod job after approval |
| staging-apply.txt | automatic staging apply after merge |
| prod-apply.txt | prod apply after approval |
| ssm-parameter.txt | the SecureString parameter (value not shown) |
| cloudwatch-alarm.json | alarm definition and state |
| cloudwatch-alarm.png | alarm in the CloudWatch console |
| destroy-complete.txt | destroy output for all environments |
