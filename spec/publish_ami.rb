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

stemcell_tgz = File.expand_path(ARGV[0])
AWS_TEST_MODE = ENV["AWS_TEST_MODE"]
BUCKET_NAME = AWS_TEST_MODE ? 'bosh-jenkins-artifacts-dry' : 'bosh-jenkins-artifacts'

region = AWS_TEST_MODE ? "us-east-1" : Net::HTTP.get('169.254.169.254', '/latest/meta-data/placement/availability-zone').chop

access_key_id = ENV['BOSH_AWS_ACCESS_KEY_ID']
secret_access_key = ENV['BOSH_AWS_SECRET_ACCESS_KEY']

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

cloud_config = OpenStruct.new(:logger => Logger.new("ami.log"), :task_checkpoint => nil)
Bosh::Clouds::Config.configure(cloud_config)

cloud = Bosh::Clouds::Provider.create("aws", options)

Dir.mktmpdir do |dir|
  %x{tar xzf #{stemcell_tgz} --directory=#{dir}} || raise("Failed to untar stemcell")
  stemcell_manifest = "#{dir}/stemcell.MF"
  stemcell_properties = Psych.load_file(stemcell_manifest)
  image = "#{dir}/image"

  if AWS_TEST_MODE
    ami_id = "ami-dryrun"
  else
    ami_id = cloud.create_stemcell(image, stemcell_properties['cloud_properties'])
    cloud.ec2.images[ami_id].public = true
  end

  puts "created AMI: #{ami_id}"
  File.open('stemcell-ami.txt', "w") { |f| f << ami_id }

  stemcell_properties["cloud_properties"]["ami"] = { region => ami_id }

  FileUtils.rm_rf(image)
  FileUtils.touch(image)

  File.open(stemcell_manifest, 'w' ) do |out|
    Psych.dump(stemcell_properties, out )
  end

  light_stemcell_name = File.dirname(stemcell_tgz) + "/light-" + File.basename(stemcell_tgz)
  Dir.chdir(dir) do
    %x{tar cvzf #{light_stemcell_name} *}  || raise("Failed to build light stemcell")
  end
end
