require 'spec_helper'

describe Bosh::Aws::BatManifest do
  let(:receipt) { YAML.load_file(asset "test-output.yml") }
  let(:config) { receipt['original_configuration'] }
  let(:stemcell_version) { '1.1.1.pre' }
  let(:manifest) { Bosh::Aws::BatManifest.new(receipt, stemcell_version, 'deadbeef') }

  it 'returns the stemcell_version' do
    manifest.stemcell_version.should == stemcell_version
  end

  it "sets the correct elastic ip" do
    manifest.vip.should == "123.4.5.9"
  end

  it "warns when vip is missing" do
    receipt['elastic_ips']['bat']['ips'] = []

    manifest = Bosh::Aws::BatManifest.new(receipt, stemcell_version, 'deadbeef')
    manifest.should_receive(:warning).with("Missing vip field")
    manifest.to_y
  end

  context "mocked director uuid call" do

    it 'warns when domain is missing' do
      receipt["vpc"]["domain"] = nil
      manifest.should_receive(:warning).with('Missing domain field').at_least(1).times
      manifest.to_y
    end

    it 'finds the director UUID' do
      manifest.director_uuid.should == 'deadbeef'
    end

    it 'generates the template' do
      spec = manifest.to_y
      spec.should == <<YAML
---
cpi: aws
properties:
  static_ip: 123.4.5.9
  uuid: deadbeef
  pool_size: 1
  stemcell:
    name: bosh-stemcell
    version: 1.1.1.pre
  instances: 1
  key_name:  dev102
  mbus: nats://nats:0b450ada9f830085e2cdeff6@micro.cfdev.com:4222
  network:
    cidr: 10.10.0.0/24
    reserved:
    - 10.10.0.2 - 10.10.0.9
    static:
    - 10.10.0.10 - 10.10.0.30
    gateway: 10.10.0.1
    subnet: subnet-4bdf6c26
    security_groups:
    - bat
YAML
    end
  end

end
