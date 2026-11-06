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
