# Lab 5 - Terraform network with CI against LocalStack

## What I built

One Terraform configuration in lab5/ that can point at real AWS or at LocalStack.
The switch is one variable: use_localstack.

It builds:
- a VPC (10.42.0.0/16)
- two public subnets (a and b), made with for_each
- an internet gateway, a route table with a 0.0.0.0/0 route, and one route table association per subnet
- a security group, with ingress rules made by a dynamic block
- one EC2 web server that installs nginx with user_data
- an optional S3 bucket, controlled by count

There are no hardcoded ids. The AMI and the availability zones come from data sources.

## Why for_each here and count there

Subnets use for_each because each subnet is a different thing with a stable name (a, b).
Terraform puts the key in the address, for example aws_subnet.public["a"].
- If I add key "c", the plan is "1 to add, 0 to change, 0 to destroy".
- If I remove key "a", the plan is "1 to destroy", and subnet "b" is not touched.

If the subnets used count, it would be a trap.
The addresses would be [0], [1], [2].
If I delete the middle one, everything after it moves down one place.
Then Terraform compares public[1] in the state with a different subnet in the config,
so it plans to destroy and recreate two subnets just to remove one.

The bucket uses count because the input is only yes or no for one resource.
There are only two possible plans: "0 to add" or "1 to add". There is no key to keep stable.

In short: count when the question is "how many", for_each when the question is "which ones".

## Experiments

### Experiment 3: break only the formatting

Prediction: the "fmt and validate" job fails at terraform fmt -check, and the LocalStack job does not run because of needs: gates.

Result: "fmt and validate" failed after 6 seconds. "plan and apply against LocalStack" was skipped. After I ran terraform fmt -recursive, git diff showed only one change: the three extra spaces were removed.

Explanation: fmt -check fails on any formatting change, even when the code itself is correct. The job stopped at the first step, so it failed in 6 seconds (the undeclared variable break took 15 seconds, because fmt passed and validate failed later). The LocalStack job normally takes about 1m54s, and needs: gates saved all of that time.

### Experiment 5: point at real AWS on purpose, plan only

Prediction: provider_target shows aws (us-east-1), and the AMI comes from the data source, not the LocalStack placeholder.

Result: provider_target = "aws (us-east-1)". Plan: 9 to add (not 10, because create_artifact_bucket is false by default). ami = "ami-0820d0c589175bc01", a real Amazon Linux 2023 image. I did not apply.

Explanation: without -var-file=localstack.tfvars, use_localstack is false, so the provider uses the real AWS endpoints and the LabRole credentials of the workstation. The line that would have warned me is provider_target = "aws (us-east-1)" under "Changes to Outputs". If I had applied, real resources would be billed against the $50 budget.

## Why not plan and apply against real AWS on every pull request

- It costs money on every run. Every pull request would build and destroy real infrastructure. With 27 students pushing many times, that is thousands of runs from one fixed $50 budget. LocalStack costs nothing and leaves nothing behind.
- It needs a long-lived AWS key in the repository. Applying from Actions means an access key in GitHub secrets, which can leak and must be rotated. In an Academy account we cannot make a small, limited key, because IAM writes are denied, so the only key that works is a broad one.
- Academy sessions expire after a few hours. A pull request opened at night can fail the next morning for a reason that has nothing to do with the code. Then people learn to ignore red checks, and a check that people ignore is worse than no check. I saw this myself: lab3-deploy is red on this pull request only because the session credentials in GitHub are old.
- It is slow and flaky: minutes for each run, API rate limits, eventual consistency errors, and many pull requests using the same names and state in one account.
- LocalStack has a limit too. A green LocalStack run shows that the configuration is correct and the graph builds. It does not show that IAM is right (LocalStack does not check IAM) or that user_data works (LocalStack never boots the instance). The real AWS check should run once, on merge or on a schedule, not on every pull request.

## Note

The handout's providers.tf had skip_requester_charged. This argument does not exist in AWS provider 5.x, and terraform validate failed with "Unsupported argument". I changed it to skip_requesting_account_id.
