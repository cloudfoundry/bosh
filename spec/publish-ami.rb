#!/usr/bin/env ruby
#

require 'cloud'
require 'bosh_aws_cpi'
require 'ostruct'
require 'net/http'
require 'yaml'

unless ARGV.length == 1
  puts "usage: #{$0} </path/to/stemcell.tgz>"
  exit(1)
end

stemcell_tgz = ARGV[1]

region = Net::HTTP.get('169.254.169.254', '/latest/meta-data/placement/availability-zone').chop

access_key_id = ENV['BOSH_JENKINS_AWS_ACCESS_KEY_ID']
secret_access_key = ENV['BOSH_JENKINS_AWS_SECRET_ACCESS_KEY']

aws = {
    "default_key_name" => "fake",
    "region" => region,
    "access_key_id" => access_key_id,
    "secret_access_key" => secret_access_key
}

# just fake the registry struct, as we don't use it
options = {
    "aws" => aws,
    "registry" => {
        "endpoint" => "http://fake.registry",
        "user" => "fake",
        "password" => "fake"
    }
}

cloud_config = OpenStruct.new(:logger => Logger.new("ami.log"))
Bosh::Clouds::Config.configure(cloud_config)

cloud = Bosh::Clouds::Provider.create("aws", options)

Dir.mktmpdir do |dir|
  %x{tar xzf #{stemcell_tgz}}
  stemcell_properties = YAML.load_file('stemcell.MF')['cloud_properties']
  ami = cloud.create_stemcell("#{dir}/image", stemcell_properties)

  cloud.ec2.images[ami].public = true

  puts "created AMI: #{ami}"
  File.open('stemcell-ami.txt', "w") { |f| f << ami }
end
