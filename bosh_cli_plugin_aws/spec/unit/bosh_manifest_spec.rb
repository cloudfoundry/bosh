require 'spec_helper'

describe Bosh::AwsCliPlugin::BoshManifest do
  let(:vpc_receipt) { Psych.load_file(asset "test-output.yml") }
  let(:route53_receipt) { Psych.load_file(asset "test-aws_route53_receipt.yml") }
  let(:rds_receipt) { Psych.load_file(asset "test-aws_rds_bosh_receipt.yml") }
  let(:manifest_options) {{hm_director_user: 'hm', hm_director_password: 'hm_password'}}
  let(:stemcell_name) { nil }

  it "sets the correct elastic ip" do
    expect(described_class.new(vpc_receipt, route53_receipt, 'deadbeef', rds_receipt, manifest_options).vip).to eq("50.200.100.3")
  end

  it "warns when vip is missing" do
    route53_receipt['elastic_ips']['bosh']['ips'] = []

    manifest = described_class.new(vpc_receipt, route53_receipt, 'deadbeef', rds_receipt, manifest_options)
    expect(manifest).to receive(:warning).with("Missing vip field")
    manifest.to_y
  end

  describe "generated yaml" do
    let(:manifest) do
      manifest = described_class.new(vpc_receipt, route53_receipt, 'deadbeef', rds_receipt, manifest_options)
      manifest.stemcell_name = stemcell_name if stemcell_name
      YAML.load(manifest.to_y)
    end
    let(:properties) { manifest['properties'] }

    it "is valid" do
      expect(manifest).to be_a Hash
    end

    it "has director ssl key and cert" do
      director_ssl_properties = properties['director']['ssl']
      expect(director_ssl_properties['key']).to_not be_nil
      expect(director_ssl_properties['cert']).to_not be_nil
    end

    it "sets director_uuid" do
      expect(manifest['director_uuid']).to eq 'deadbeef'
    end

    it "sets deployment name" do
      expect(manifest['name']).to eq 'vpc-bosh-dev102'
      expect(properties['director']['name']).to eq 'vpc-bosh-dev102'
    end

    it "sets the subnet" do
      expect(manifest['networks'][0]['subnets'][0]['cloud_properties']['subnet']).to eq 'subnet-4bdf6c26'
    end

    it "sets availablility_zone" do
      expect(manifest['resource_pools'][0]['cloud_properties']['availability_zone']).to eq 'us-east-1a'
      expect(manifest['compilation']['cloud_properties']['availability_zone']).to eq 'us-east-1a'
    end

    it "sets the director's elastic ip" do
      expect(manifest['jobs'][0]['networks'][1]['static_ips'][0]).to eq '50.200.100.3'
    end
    it "sets hm director credentials" do
      expect(properties['hm']['director_account']).to eq({
        'user' => 'hm',
        'password' => 'hm_password'
      })
    end

    it "sets aws settings" do
      aws = properties['aws']
      expect(aws['access_key_id']).to eq '...'
      expect(aws['secret_access_key']).to eq '...'
      expect(aws['region']).to eq 'us-east-1'
      expect(aws['default_key_name']).to eq 'dev102'
      expect(aws['ec2_endpoint']).to eq 'ec2.us-east-1.amazonaws.com'
    end

    it "sets the rds properties" do
      db = properties['mysql']
      expect(db['user']).to eq 'uaf71ad63a7cbd2'
      expect(db['password']).to eq 'p76ad85e9793e58b7112a4881be100dee'
      expect(db['host']).to eq 'bosh.cabaz18bo7yr.us-east-1.rds.amazonaws.com'
      expect(db['port']).to eq 3306
    end

    context 'setting the stemcell name' do
      let(:stemcell_name) { 'stemcell-name' }

      it "sets stemcell name" do
        resource_pool = manifest['resource_pools'].first
        expect(resource_pool['stemcell']['name']).to eq('stemcell-name')
      end
    end
  end
end
