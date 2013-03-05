require 'spec_helper'

describe Bosh::Aws::MicroboshManifest do
  let(:receipt) { YAML.load_file(asset "test-output.yml") }
  let(:config) { receipt['original_configuration'] }
  let(:manifest) { Bosh::Aws::MicroboshManifest.new(receipt) }

  it 'warns when name is missing' do
    config['name'] = nil
    manifest.stub(:private_key_path)
    manifest.should_receive(:warning).with('Missing name field').at_least(1).times
    manifest.to_y
  end

  it 'warns when vip is missing' do
    receipt['elastic_ips']['micro']['ips'] = []
    manifest.should_receive(:warning).with('Missing vip field').at_least(1).times
    manifest.to_y
  end

  it 'warns when subnet is missing' do
    receipt['vpc']['subnets'] = {}
    manifest.should_receive(:warning).with('Missing bosh subnet field').at_least(1).times
    manifest.to_y
  end

  it 'warns when availability_zone is missing' do
    config['vpc']['subnets']['bosh'].delete('availability_zone')
    manifest.should_receive(:warning).with('Missing availability zone in vpc.subnets.bosh').at_least(1).times
    manifest.to_y
  end

  it 'warns when access_key_id is missing' do
    config['aws'].delete('access_key_id')
    manifest.should_receive(:warning).with("Missing aws access_key_id field").at_least(1).times
    manifest.to_y
  end

  it 'warns when secret_access_key is missing' do
    config['aws'].delete('secret_access_key')
    manifest.should_receive(:warning).with("Missing aws secret_access_key field").at_least(1).times
    manifest.to_y
  end

  it 'warns when region is missing' do
    config['aws'].delete('region')
    manifest.should_receive(:warning).with("Missing aws region field").at_least(1).times
    manifest.to_y
  end

  it 'warns when private_key is missing' do
    config['key_pairs'] = {}
    manifest.should_receive(:warning).with("Missing key_pairs field, must have at least 1 keypair").at_least(1).times
    manifest.to_y
  end

  it 'does not warn when name is present' do
    config['name'] = 'bill'
    manifest.should_not_receive(:warning).with('Missing name field')
    manifest.to_y
  end
end
