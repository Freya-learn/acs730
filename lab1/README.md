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
