# RacerX

## Overview

This is a tool that installs the speedtest cli on a Raspberry Pi(rpi) so you can run it regularly and record the results. This will give you trend data on your ISPs performance.

It uses ansible to install and configure your rpi. It then runs speedtest at the set interval and records the results and sends them to AWS Cloudwatch Logs to keep the historical data and visualize it.

## Install

To install, first make sure you have Ansible installed, then run the following Ansible command from the root of this repo, replacing the key/secret with your own AWS credentials.

Also make sure your hosts.yamnl is configfured correctly
``` shell
ansible-playbook ansible/playbook.yaml \
  --inventory-file ansible/hosts.yaml \
  --extra-vars "access_key=<your_aws_access_key> access_secret=<your_aws_access_secret>"
```

## TODO

- use CFN/CDK to create restricted role and log setup, etc
- setup logrotate?
- make sure timestamp is recorded with UTC
- make hosts.yaml more configurable
