require 'aws-sdk'

# since this plugin is abusing the AWS CPI, the following hack is needed so that
# task_checkpoint is available when ResourceWait.for_resource is called
require "cloud"
Config = Struct.new(:task_checkpoint)
Bosh::Clouds::Config.configure(Config.new)

require "cloud/aws/resource_wait"

require "bosh_aws_bootstrap/version"
require "bosh_aws_bootstrap/ec2"
require "bosh_aws_bootstrap/route53"
require "bosh_aws_bootstrap/s3"
require "bosh_aws_bootstrap/vpc"
require "bosh_aws_bootstrap/rds"
require "bosh_aws_bootstrap/elb"
require "bosh/cli/commands/aws"
require "bosh/cli/commands/micro"
require "bosh_aws_bootstrap/microbosh_manifest"
require "bosh_aws_bootstrap/bat_manifest"
require "bosh_aws_bootstrap/bosh_manifest"
