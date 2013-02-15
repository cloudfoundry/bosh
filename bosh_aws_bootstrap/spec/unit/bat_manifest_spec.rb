require 'spec_helper'

describe Bosh::Aws::BatManifest do
  let(:config) { YAML.load_file(asset "config.yml") }
  let(:receipt) { YAML.load_file(asset "test-output.yml") }
  let(:stemcell_version) { '1.1.1.pre' }
  let(:manifest) { Bosh::Aws::BatManifest.new(config, receipt, stemcell_version) }

  it 'returns the stemcell_version' do
    manifest.stemcell_version.should == stemcell_version
  end

  context "mocked director uuid call" do

    before do
      mock_director_uuid('deadbeef')
    end

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
  static_ip: bat.cfdev.com
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

  def mock_director_uuid(uuid)
    URI.should_receive(:parse).and_return('foo')
    Net::HTTP.should_receive(:get).with('foo').and_return({'uuid' => uuid}.to_yaml)
  end
end
