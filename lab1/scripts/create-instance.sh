#!/bin/bash

AMI_ID="ami-0e34b50e714a297f1"
SECURITY_GROUP_ID="sg-0198c11a9428794b5"
SUBNET_ID="subnet-00cdb0b062590b25f"
KEY_NAME="vockey"

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --subnet-id "$SUBNET_ID" \
  --key-name "$KEY_NAME" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"
