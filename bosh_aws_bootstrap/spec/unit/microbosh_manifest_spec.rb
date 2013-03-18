require 'spec_helper'

describe Bosh::Aws::MicroboshManifest do
  let(:vpc_receipt) { YAML.load_file(asset "test-output.yml") }
  let(:route53_receipt) { YAML.load_file(asset "test-aws_route53_receipt.yml") }
  let(:vpc_config) { vpc_receipt['original_configuration'] }
  let(:manifest) { Bosh::Aws::MicroboshManifest.new(vpc_receipt, route53_receipt) }

  it 'warns when name is missing' do
    vpc_config['name'] = nil
    manifest.stub(:private_key_path)
    manifest.should_receive(:warning).with('Missing name field').at_least(1).times
    manifest.to_y
  end

  it 'warns when vip is missing' do
    route53_receipt['elastic_ips']['micro']['ips'] = []
    manifest.should_receive(:warning).with('Missing vip field').at_least(1).times
    manifest.to_y
  end

  it 'warns when subnet is missing' do
    vpc_receipt['vpc']['subnets'] = {}
    manifest.should_receive(:warning).with('Missing bosh subnet field').at_least(1).times
    manifest.to_y
  end

  it 'warns when availability_zone is missing' do
    vpc_config['vpc']['subnets']['bosh'].delete('availability_zone')
    manifest.should_receive(:warning).with('Missing availability zone in vpc.subnets.bosh').at_least(1).times
    manifest.to_y
  end

  it 'warns when access_key_id is missing' do
    vpc_config['aws'].delete('access_key_id')
    manifest.should_receive(:warning).with("Missing aws access_key_id field").at_least(1).times
    manifest.to_y
  end

  it 'warns when secret_access_key is missing' do
    vpc_config['aws'].delete('secret_access_key')
    manifest.should_receive(:warning).with("Missing aws secret_access_key field").at_least(1).times
    manifest.to_y
  end

  it 'warns when region is missing' do
    vpc_config['aws'].delete('region')
    manifest.should_receive(:warning).with("Missing aws region field").at_least(1).times
    manifest.to_y
  end

  it 'warns when private_key is missing' do
    vpc_config['key_pairs'] = {}
    manifest.should_receive(:warning).with("Missing key_pairs field, must have at least 1 keypair").at_least(1).times
    manifest.to_y
  end

  it 'does not warn when name is present' do
    vpc_config['name'] = 'bill'
    manifest.should_not_receive(:warning).with('Missing name field')
    manifest.to_y
  end
end
