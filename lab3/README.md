# Lab 3 - Teraform and GitHub Actions

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
