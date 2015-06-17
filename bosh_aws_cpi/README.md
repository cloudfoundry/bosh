# BOSH AWS Cloud Provider Interface
Copyright (c) 2009-2012 VMware, Inc.

For online documentation see: http://rubydoc.info/gems/bosh_aws_cpi/

## Options

These options are passed to the AWS CPI when it is instantiated.

### AWS options

* `access_key_id` (required)
  AWS IAM user access key
* `secret_access_key` (required)
  AWS IAM secret access key
* `default_key_name` (required)
  default AWS ssh key name to assign to created virtual machines
* `default_security_groups` (required)
  list of AWS security group names or ids to assign to created virtual machines, note that name and id can not be used together in this attribute.
* `ec2_private_key` (required)
  local path to the ssh private key, must match `default_key_name`
* `region` (required)
  EC2 region
* `ec2_endpoint` (optional)
  URL of the EC2 endpoint to connect to, defaults to the endpoint corresponding to the selected region,
  or `default_ec2_endpoint` if no region has been selected
* `elb_endpoint` (optional)
  URL of the ELB endpoint to connect to, default to the endpoint corresponding to the selected region,
  or `default_elb_endpoint` if no region has been selected
* `max_retries` (optional)
  maximum number of time to retry an AWS API call, defaults to `DEFAULT_MAX_RETRIES`

### Registry options

The registry options are passed to the AWS CPI by the BOSH director based on the settings in `director.yml`, but can be
overridden if needed.

* `endpoint` (required)
  registry URL
* `user` (required)
  registry user
* `password` (required)
  registry password

### Agent options

Agent options are passed to the AWS CPI by the BOSH director based on the settings in `director.yml`, but can be
overridden if needed.

### Resource pool options

These options are specified under `cloud_options` in the `resource_pools` section of a BOSH deployment manifest.

* `availability_zone` (optional)
  the EC2 availability zone the VMs should be created in
* `instance_type` (required)
  which [type of instance](http://aws.amazon.com/ec2/instance-types/) the VMs should belong to
* `spot_bid_price` (optional)
  the [AWS spot instance](http://aws.amazon.com/ec2/purchasing-options/spot-instances/) bid price to use.  When specified spot instances are started rather than on demand instances.  _NB: this will dramatically slow down resource pool creation._

### Network options

These options are specified under `cloud_options` in the `networks` section of a BOSH deployment manifest.

* `type` (required)
  can be either `dynamic` for a DHCP assigned IP by AWS, or `vip` to use an Elastic IP (which needs to be already
  allocated)

* `security_groups` (optional)
  the AWS security group names or ids to assign to VMs. If not specified, it'll use the default security groups set at the AWS options. Note that name and id can not be used together in this attribute.

## Example

This is a sample of how AWS specific properties are used in a BOSH deployment manifest:

    ---
    name: sample
    director_uuid: 38ce80c3-e9e9-4aac-ba61-97c676631b91

    ...

    networks:
      - name: nginx_network
        type: vip
        cloud_properties: {}
      - name: default
        type: dynamic
        cloud_properties:
          security_groups:
          - default

    ...

    resource_pools:
      - name: common
        network: default
        size: 3
        stemcell:
          name: bosh-aws-xen-ubuntu
          version: latest
        cloud_properties:
          instance_type: m1.small

    ...

    properties:
      aws:
        access_key_id: AKIAIYJWVDUP4KRWBESQ
        secret_access_key: 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
        default_key_name: bosh
        default_security_groups: ["bosh"]
        ec2_private_key: /home/bosh/.ssh/bosh
