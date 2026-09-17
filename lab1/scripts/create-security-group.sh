#!/bin/bash

aws ec2 create-security-group \
  --group-name acs730-lab1-security-group \
  --description "ACS730 Lab 1 security group"

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --group-names acs730-lab1-security-group \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$SECURITY_GROUP_ID" \
  --protocol tcp \
  --port 22 \
  --cidr 3.90.187.119/32

echo "Security Group ID: $SECURITY_GROUP_ID"
