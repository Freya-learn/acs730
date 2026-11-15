# Lab 6 - Ansible, SSM and a Packer Golden AMI

## Three required answers

1. **Runner-to-instance mechanism:** I used AWS Systems Manager Session Manager. The instance opens an outbound connection to SSM, so there is no port 22 open and no SSH private key stored in GitHub secrets. The runner only uses the temporary Academy session credentials.
2. **What changed=0 on a second run proves:** It does not mean the playbook did nothing. Every task checked the real state of the server and found it already matched the role, so nothing needed to change. This makes it safe to run the same playbook on a new server or an old server, and from the pipeline on every merge.
3. **Why deregistering an AMI is not enough:** The AMI is only a pointer. The EBS snapshot behind it holds the data and it is what costs money. Deregistering leaves the snapshot, so I read the snapshot id first and then deleted the snapshot too.

## Boot-to-ready comparison

| Path | Seconds | What it includes |
|------|---------|------------------|
| Converge-on-boot (stock AL2023 + Ansible) | 228 | instance launch, boot, SSM agent registration, dnf downloads, Ansible run, service start |
| Golden AMI (Packer) | 47 | instance launch, boot, service start (already configured in the image) |

Building the golden AMI with Packer took about 5 minutes 40 seconds, once.

**Where the time went in the slow path:** Most of the time was not the Ansible logic. It was waiting for the SSM agent to register, and then dnf downloading packages over the network. This happens again for every new instance.

**The golden AMI moves the cost, it does not remove it:** The work still happens, but once at build time instead of every time an instance starts. If I launch many instances, the AMI wins. If I launch only one, it loses, because I paid for a full Packer build to save about 3 minutes.

**What breaks with golden AMIs:** The image is frozen at bake time, so later security updates are not inside it and it needs to be rebuilt regularly. It is also hard to see what is inside without the build log. A playbook is its own documentation.

**What breaks with converge-on-boot:** Every launch depends on package mirrors being reachable at that moment. If the mirror is down, the instance boots but never becomes ready. This is bad for autoscaling at night.

**Recommendation:** Golden AMI, because web servers are usually launched in groups by autoscaling and must be ready fast. I would change to converge-on-boot if we only launch one or two servers and they change very often.

## Notes

- The SSM connection copies files through an S3 bucket. The bucket must be in the same region as `ansible_aws_ssm_region` (both us-east-1), or the first task fails with PermanentRedirect.
- Terraform state is only on the workstation. Before running the workflow, I ran `terraform destroy` on the workstation, because the runner has no state and would try to create a security group with the same name. After the workflow, I deleted the runner's instances and security group by tag.
- I added `${path.root}/` to the two file paths in `web.pkr.hcl`, so `packer validate` also passes when it runs from the repository root (as `check-lab.sh` does).

## Experiments

### Experiment 1 - Break idempotency with shell
**Prediction:** A shell task will report changed every run. With `creates:` it will report changed=0.
**Result:** With `ansible.builtin.shell: mkdir -p /opt/acs730-web/logs`, the second run showed changed=1 on both hosts. After adding `creates: /opt/acs730-web/logs`, it showed changed=0. After removing the task, changed=0 again.
**Explanation:** Ansible cannot know what a shell command does, so it cannot check if the work is already done. `creates:` tells Ansible which path to check, so it can skip the command.

### Experiment 2 - state: latest vs state: present
**Prediction:** The second run will show changed=0 today, but it depends on the day. If a new package version is released between runs, `latest` will report changed and upgrade it.
**Result:** With `latest`, both runs showed changed=0, because no new python3 or rsync update was available today. After changing back to `present`, changed=0.
**Explanation:** In a pipeline that runs on every merge, I want `present`. With `latest`, the result depends on the date, and packages can be upgraded without anyone asking. That can break the application and makes runs not repeatable.
