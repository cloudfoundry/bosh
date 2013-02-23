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

stemcell_tgz = ARGV[0]

region = Net::HTTP.get('169.254.169.254', '/latest/meta-data/placement/availability-zone').chop

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

cloud_config = OpenStruct.new(:logger => Logger.new("ami.log"))
Bosh::Clouds::Config.configure(cloud_config)

cloud = Bosh::Clouds::Provider.create("aws", options)

Dir.mktmpdir do |dir|
  %x{tar xzf #{stemcell_tgz} --directory=#{dir}} || raise("Failed to untar stemcell")
  stemcell_manifest = "#{dir}/stemcell.MF"
  stemcell_properties = YAML.load_file(stemcell_manifest)
  image = "#{dir}/image"

  ami = cloud.create_stemcell(image, stemcell_properties['cloud_properties'])
  cloud.ec2.images[ami].public = true

  puts "created AMI: #{ami}"
  File.open('stemcell-ami.txt', "w") { |f| f << ami }

  stemcell_properties["cloud_properties"]["ami"] = { region => ami }

  FileUtils.rm_rf(image)
  FileUtils.touch(image)

  File.open(stemcell_manifest, 'w' ) do |out|
    YAML.dump(stemcell_properties, out )
  end

  light_stemcell_name = File.dirname(stemcell_tgz) + "/light-" + File.basename(stemcell_tgz)
  Dir.chdir(dir) do
    %x{tar cvzf #{light_stemcell_name} *}  || raise("Failed to build light stemcell")
  end
end
