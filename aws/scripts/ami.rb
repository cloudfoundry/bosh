#!/usr/bin/env ruby
#

require 'rubygems'
require 'bosh_aws_cpi'
require 'cloud'
require 'ostruct'

unless ARGV.length == 3
  puts "usage: ami.rb <region> <access_key_id> <secret_access_key>"
  exit(1)
end

region = ARGV[0]
access_key_id = ARGV[1]
secret_access_key = ARGV[2]

    cloud_properties = {
    "architecture" => "x86_64",
    "root_device_name" => "/dev/sda1"
}

aws = {
  "ec2_endpoint" => "ec2.#{region}.amazonaws.com",
  "access_key_id" => access_key_id,
  "secret_access_key" => secret_access_key
}

# just mock the registry struct, as we don't use it
options = {
    "aws" => aws,
    "registry" => {
        "endpoint" => "",
        "user" => "",
        "password" => ""
    }
}

cloud_config = OpenStruct.new(:logger => Logger.new("ami.log"))
Bosh::Clouds::Config.configure(cloud_config)

cloud = Bosh::Clouds::Provider.create("aws", options)

ami = cloud.create_stemcell("/home/ubuntu/stemcell/image", cloud_properties)

puts ami
