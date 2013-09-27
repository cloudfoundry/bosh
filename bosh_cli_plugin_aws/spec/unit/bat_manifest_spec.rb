require 'spec_helper'

describe Bosh::Aws::BatManifest do
  subject { described_class.new(vpc_receipt, route53_receipt, 'stemcell-version', 'director-uuid', 'stemcell-name') }
  let(:vpc_receipt)     { Psych.load_file(asset('test-output.yml')) }
  let(:route53_receipt) { Psych.load_file(asset('test-aws_route53_receipt.yml')) }

  its(:stemcell_version) { should eq 'stemcell-version' }
  its(:vip)              { should eq '50.200.100.2' }
  its(:director_uuid)    { should eq 'director-uuid' }

  context 'when vip is missing' do
    before { route53_receipt['elastic_ips']['bat']['ips'] = [] }

    it 'warns' do
      subject.should_receive(:warning).with('Missing vip field')
      subject.to_y
    end
  end

  context 'when domain is missing' do
    before { vpc_receipt['vpc']['domain'] = nil }

    it 'warns' do
      subject
        .should_receive(:warning)
        .with('Missing domain field')
        .at_least(1).times
      subject.to_y
    end
  end

  it 'generates the template' do
    expect(subject.to_y).to eq(<<YAML)
---
name: bat
director_uuid: director-uuid
cpi: aws

release:
  name: bat
  version: latest

resource_pools:
- name: default
  stemcell:
    name: stemcell-name
    version: stemcell-version
  network: default
  size: 1
  cloud_properties:
    instance_type: m1.small
    availability_zone: us-east-1a

compilation:
  reuse_compilation_vms: true
  workers: 8
  network: default
  cloud_properties:
    instance_type: c1.medium
    availability_zone: us-east-1a

update:
  canaries: 1
  canary_watch_time: 3000-90000
  update_watch_time: 3000-90000
  max_in_flight: 1
  max_errors: 1

networks:

- name: default
  type: manual
  subnets:
  - range: 10.10.0.0/24
    reserved:
    - 10.10.0.2 - 10.10.0.9
    static:
    - 10.10.0.10 - 10.10.0.30
    gateway: 10.10.0.1
    security_groups:
    - bat
    cloud_properties:
      security_groups: bat
      subnet: subnet-4bdf6c26

jobs:
- name: "batlight"
  template: "batlight"
  instances: 1
  resource_pool: default
  networks:
  - name: default
    default: [dns, gateway]

properties:
  static_ip: 50.200.100.2
  uuid: director-uuid
  pool_size: 1
  stemcell:
    name: stemcell-name
    version: stemcell-version
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
  batlight:
    missing: nope

YAML
  end
end
