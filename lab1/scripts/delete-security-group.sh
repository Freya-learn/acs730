#!/bin/bash

SECURITY_GROUP_ID="sg-0198c11a9428794b5"

aws ec2 delete-security-group \
  --group-id "$SECURITY_GROUP_ID"
