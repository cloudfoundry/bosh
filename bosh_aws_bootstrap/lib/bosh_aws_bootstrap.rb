require 'aws-sdk'
require 'logger'

# since this plugin is abusing the AWS CPI, the following hack is needed so that
# task_checkpoint & logger is available when ResourceWait.for_resource is called
require "cloud"
Config = Struct.new(:task_checkpoint, :logger)
Bosh::Clouds::Config.configure(Config.new(true, Logger.new('/dev/null')))

require "cloud/aws/resource_wait"

require "bosh_aws_bootstrap/ec2"
require "bosh_aws_bootstrap/route53"
require "bosh_aws_bootstrap/s3"
require "bosh_aws_bootstrap/vpc"
require "bosh_aws_bootstrap/rds"
require "bosh_aws_bootstrap/elb"
require "bosh_aws_bootstrap/bosh_bootstrap"
require "bosh_aws_bootstrap/micro_bosh_bootstrap"
require "bosh/cli/commands/aws"
require "bosh/cli/commands/micro"
require "bosh_aws_bootstrap/microbosh_manifest"
require "bosh_aws_bootstrap/bat_manifest"
require "bosh_aws_bootstrap/bosh_manifest"
