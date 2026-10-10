# Lab 3 - Terraform and GitHub Actions

## Credential model

**Why a real account uses OIDC, not stored keys.**
With OIDC, GitHub creates a short-lived signed token for each run, and the runner
exchanges it with AWS STS for temporary credentials. Nothing is stored in GitHub,
so there is no secret to rotate and no secret to leak.

**Why this course uses session credentials, and what limits the damage.**
AWS Academy denies IAM writes (iam:CreateOpenIDConnectProvider and iam:CreateRole),
so I cannot build OIDC here. Instead, refresh-gha-creds.sh copies my lab session
credentials (access key, secret key, session token) into GitHub Actions secrets.
If they leak, the damage is limited by time: they stop working when the lab
session ends.

## Operations

**ExpiredToken on a deploy.**
The lab session ended, so the credentials stored in GitHub Actions are no longer
valid. Fix: start a new lab session, run refresh-gha-creds.sh again, and re-run
the job. Nothing in the repository changes.

**"Input required and not supplied: aws-region".**
The AWS_REGION variable does not exist in the repository. This is not a credential
problem. Fix: run the refresh script, or run
`gh variable set AWS_REGION --body us-east-1`. The workflow must read it as
`vars.AWS_REGION`, not `secrets.AWS_REGION`.

**Terraform version:** 1.10.3 (same version on the workstation and in the workflow).

## Experiments

### Experiment 1 - Let the credentials die

**Prediction:** After I click End Lab, the session credentials stored in GitHub
Actions secrets are no longer valid. I predicted the deploy workflow would fail at
the "Configure AWS session credentials" step with an ExpiredToken error.

**What I saw:** I ended the lab and re-ran a deploy run. My prediction about the
step was wrong. It failed at the "terraform init" step with this error:
"Error refreshing state: Unable to access object "lab3/terraform.tfstate" in S3
bucket "acs730-tfstate-731254789382": operation error S3: HeadObject, https
response error StatusCode: 403, api error Forbidden: Forbidden".

**Explanation:** Nothing was wrong with the repository. The credentials belong to
the lab session, so after the session ended they could not read the state file in
S3. I started a new lab session, ran refresh-gha-creds.sh again, and re-ran the
same job. It passed. I changed 0 files in the repository.

### Experiment 3 - Give the apply step a pull request

**Prediction:** If I change the apply condition to `if: always()`, terraform apply
will run on a pull request, before anyone reviews or merges the change.

**What I saw:** I opened a pull request from a branch with this change. The plan
step printed "No changes", and the apply step also ran and printed
"Apply complete! Resources: 0 added, 0 changed, 0 destroyed."

**Explanation:** The workflow file in the pull request branch is the one that runs.
So anyone who can open a pull request could edit main.tf and the workflow, and the
change would be applied to my AWS account with my credentials, without a merge.
That is why apply must only run on push to main. I closed the pull request without
merging it.
