require 'spec_helper'

describe Bosh::Aws::BoshManifest do
  let(:vpc_receipt) { YAML.load_file(asset "test-output.yml") }
  let(:route53_receipt) { YAML.load_file(asset "test-aws_route53_receipt.yml") }

  it "sets the correct elastic ip" do
    described_class.new(vpc_receipt, route53_receipt, 'deadbeef').vip.should == "50.200.100.3"
  end

  it "warns when vip is missing" do
    route53_receipt['elastic_ips']['bosh']['ips'] = []

    manifest = described_class.new(vpc_receipt, route53_receipt, 'deadbeef')
    manifest.should_receive(:warning).with("Missing vip field")
    manifest.to_y
  end

  it "generates the template" do
    manifest = described_class.new(vpc_receipt, route53_receipt, 'deadbeef')
    spec = manifest.to_y
    spec.should == <<-YAML
---
name: vpc-bosh-dev102
director_uuid: deadbeef

networks:
- name: default
  type: manual
  subnets:
  - range: 10.10.0.0/24
    gateway: 10.10.0.1
    dns:
    - 10.10.0.6
    cloud_properties:
      subnet: subnet-4bdf6c26
- name: vip_network
  type: vip
  # Fake network properties to satisfy bosh diff
  subnets:
  - range: 127.0.99.0/24
    gateway: 127.0.99.1
    dns:
    - 127.0.99.250

jobs:
- name: bosh
  networks:
  - name: vip_network
    static_ips:
    - 50.200.100.3

properties:
  template_only:
    aws:
      availability_zone: us-east-1a

  aws:
    access_key_id: ...
    secret_access_key: ...
    region: us-east-1
    default_key_name: dev102

   
YAML
  end
end
