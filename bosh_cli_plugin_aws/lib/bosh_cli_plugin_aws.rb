require 'aws-sdk'
require 'logger'

# since this plugin is abusing the AWS CPI, the following hack is needed so that
# task_checkpoint & logger is available when ResourceWait.for_resource is called
require "cloud"
Config = Struct.new(:task_checkpoint, :logger)
Bosh::Clouds::Config.configure(Config.new(true, Logger.new(File::NULL)))

require "cloud/aws/resource_wait"
require "common/ssl"

require "bosh_cli_plugin_aws/version"
require "bosh_cli_plugin_aws/ec2"
require "bosh_cli_plugin_aws/route53"
require "bosh_cli_plugin_aws/s3"
require "bosh_cli_plugin_aws/vpc"
require "bosh_cli_plugin_aws/rds"
require "bosh_cli_plugin_aws/elb"
require "bosh_cli_plugin_aws/bosh_bootstrap"
require "bosh_cli_plugin_aws/micro_bosh_bootstrap"
require "bosh_cli_plugin_aws/aws_config"
require "bosh_cli_plugin_aws/aws_provider"
require "bosh/cli/commands/aws"
require "bosh/cli/commands/micro"
require "bosh_cli_plugin_aws/microbosh_manifest"
require "bosh_cli_plugin_aws/bat_manifest"
require "bosh_cli_plugin_aws/bosh_manifest"
require "bosh_cli_plugin_aws/migration_helper"
require "bosh_cli_plugin_aws/migration"
require "bosh_cli_plugin_aws/migrator"
