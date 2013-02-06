require 'spec_helper'

describe Bosh::Aws::MicroboshManifest do
  let(:config) { YAML.load_file(asset "config.yml") }
  let(:receipt) { YAML.load_file(asset "test-output.yml") }
  let(:manifest) { Bosh::Aws::MicroboshManifest.new(config, receipt) }

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

  it 'does not warn when availability_zone is missing' do
    config['vpc']['subnets']['bosh'].delete('availability_zone')
    manifest.should_not_receive(:warning)
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
    config['key_pairs'].delete(config['name'])
    manifest.should_receive(:warning).with("Missing keypair 'dev102'").at_least(1).times
    manifest.to_y
  end

  it 'does not warn when name is present' do
    config['name'] = 'bill'
    manifest.should_not_receive(:warning).with('Missing name field')
    manifest.to_y
  end
end
