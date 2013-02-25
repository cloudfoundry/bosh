require 'aws-sdk'

require "bosh_aws_bootstrap/ec2"
require "bosh_aws_bootstrap/route53"
require "bosh_aws_bootstrap/s3"
require "bosh_aws_bootstrap/version"

require "cloud/aws/helpers"

require "bosh_aws_bootstrap/vpc"
require "bosh_aws_bootstrap/rds"
require "bosh_aws_bootstrap/elb"
require "bosh/cli/commands/aws"
require "bosh_aws_bootstrap/microbosh_manifest"
require "bosh_aws_bootstrap/bat_manifest"
require "bosh_aws_bootstrap/bosh_manifest"
