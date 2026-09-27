# Lab 1

## Scripts

### create-security-group.sh
Creates a security group named acs730-week1-sg and allows SSH access only from the current machine's public IP, fetched dynamically via checkip.amazonaws.com.

### create-instance.sh
Launches a test EC2 instance using the latest Amazon Linux 2023 AMI (queried dynamically via SSM). The instance is tagged Name=acs730-week1 and attached to LabInstanceProfile so it automatically receives AWS permissions.

### delete-instance.sh
Finds any instance tagged acs730-week1 and terminates it. Safe to run multiple times.

### delete-security-group.sh
Deletes the acs730-week1-sg security group after the test instance has been terminated

## Experiments

### Experiment 1: Instance profile, seen from inside

**Prediction 1:** SSH-ing into the instance launched by the script (which carries LabInstanceProfile) and running `aws sts get-caller-identity` should return a valid `assumed-role/LabRole` identity, since the instance profile supplies temporary credentials automatically.

**Prediction 2:** After removing the `--iam-instance-profile` line and launching a second instance, running the same command there should fail with an "Unable to locate credentials" error, since no IAM role is attached.

**Explanation:** An instance with LabInstanceProfile attached can authenticate to AWS automatically because the profile injects temporary credentials at launch, while an instance without it has no way to prove its identity to AWS.

### Experiment 5: The safety net, tested safely

**Prediction:** Creating fake.pem should NOT show up in git status because *.pem is in .gitignore. After commenting out that line, fake.pem should appear as an untracked file.

**Result:** Confirmed both predictions. With *.pem active, git status showed no trace of fake.pem. After commenting out the rule, fake.pem appeared under "Untracked files."

**Explanation:** The dangerous moment was right after commenting out the *.pem rule while fake.pem still existed — if `git add .` had been run at that point, a real key file would have been staged and could have been committed and pushed, permanently exposing it in the repo history.
