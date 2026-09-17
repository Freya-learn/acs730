#!/bin/bash

INSTANCE_ID="i-0ad41410dc5739f99"

aws ec2 terminate-instances \
  --instance-ids "$INSTANCE_ID"
