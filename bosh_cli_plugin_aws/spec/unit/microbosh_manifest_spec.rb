require 'spec_helper'

describe Bosh::Aws::MicroboshManifest do
  subject(:manifest) { described_class.new(vpc_receipt, route53_receipt, manifest_options) }

  let(:vpc_receipt) { Psych.load_file(asset "test-output.yml") }
  let(:route53_receipt) { Psych.load_file(asset "test-aws_route53_receipt.yml") }
  let(:vpc_config) { vpc_receipt['original_configuration'] }
  let(:hm_director_user) { 'hm' }
  let(:hm_director_password) { 'hmpasswd' }
  let(:manifest_options) { {hm_director_user: hm_director_user, hm_director_password: hm_director_password} }

  its(:network_type) { should eq('manual') }

  it 'sets health manager director credentials' do
    manifest.hm_director_user.should == 'hm'
    manifest.hm_director_password.should == 'hmpasswd'
  end

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

  context 'when subnet is missing' do
    before { vpc_receipt['vpc']['subnets'] = {} }

    it 'warns that the subnet is missing' do
      manifest.should_receive(:warning).with('Missing bosh subnet field').at_least(1).times
      manifest.to_y
    end

    its(:network_type) { should eq('dynamic') }
  end

  it 'warns when availability_zone is missing' do
    vpc_config['vpc']['subnets']['bosh1'].delete('availability_zone')
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

  describe 'loading the director ssl config' do
    context 'when the setting is set correctly' do
      it 'loads the director ssl cert files' do
        vpc_receipt['ssl_certs']['director_cert']['certificate'] = asset('ca/bosh.pem')
        vpc_receipt['ssl_certs']['director_cert']['private_key'] = asset('ca/bosh.key')

        manifest.director_ssl_cert.should match /BEGIN CERTIFICATE/
        manifest.director_ssl_key.should match /BEGIN RSA PRIVATE KEY/
      end
    end

    context 'when the settings is a file that does not exist' do
      let(:non_existant_cert) { asset('ca/not_real_ca.pem') }
      let(:non_existant_key) { asset('ca/not_real_ca.key') }

      before do
        FileUtils.rm_f(non_existant_cert)
        FileUtils.rm_f(non_existant_key)
      end

      it 'creates the certificate for the user' do
        vpc_receipt['ssl_certs']['director_cert']['certificate'] = non_existant_cert
        vpc_receipt['ssl_certs']['director_cert']['private_key'] = non_existant_key

        manifest.director_ssl_cert.should match /BEGIN CERTIFICATE/
        manifest.director_ssl_key.should match /BEGIN RSA PRIVATE KEY/
      end
    end
  end
end
