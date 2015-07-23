require 'spec_helper'

describe Bosh::AwsCliPlugin::BatManifest do
  subject { described_class.new(vpc_receipt, route53_receipt, 'stemcell-version', 'director-uuid', 'stemcell-name') }
  let(:vpc_receipt)     { Psych.load_file(asset('test-output.yml')) }
  let(:route53_receipt) { Psych.load_file(asset('test-aws_route53_receipt.yml')) }

  its(:stemcell_version) { should eq 'stemcell-version' }
  its(:vip)              { should eq '50.200.100.2' }
  its(:director_uuid)    { should eq 'director-uuid' }

  let(:yaml_manifest) do
'---
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
    instance_type: m1.medium
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

networks:

- name: default
  type: manual
  subnets:
  - range: 10.10.0.0/24
    reserved:
    - RESERVED_IP_RANGE
    static:
    - STATIC_IP_RANGE
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
  vip: 50.200.100.2
  second_static_ip: 10.10.0.30
  uuid: director-uuid
  pool_size: 1
  stemcell:
    name: stemcell-name
    version: \'stemcell-version\'
  instances: 1
  key_name:  dev102
  networks:
  - name: default
    static_ip: 10.10.0.29
    type: manual
    cidr: 10.10.0.0/24
    reserved:
    - RESERVED_IP_RANGE
    static:
    - STATIC_IP_RANGE
    gateway: 10.10.0.1
    subnet: subnet-4bdf6c26
    security_groups:
    - bat
  batlight:
    missing: nope

'
  end

  let(:env) { {} }
  before { stub_const('ENV', env) }

  context 'when vip is missing' do
    before { route53_receipt['elastic_ips']['bat']['ips'] = [] }

    it 'warns' do
      expect(subject).to receive(:warning).with('Missing vip field')
      subject.to_y
    end
  end

  its(:vip) { should eq('50.200.100.2') }

  its(:static_ip) { should eq('10.10.0.29') }

  context 'when BOSH_AWS_STATIC_IP environment variable is set' do
    before { env['BOSH_AWS_STATIC_IP'] = '192.168.0.1' }

    its(:static_ip) { should eq('192.168.0.1') }
  end

  its(:second_static_ip) { should eq('10.10.0.30') }

  context 'when BOSH_AWS_SECOND_STATIC_IP environment variable is set' do
    before { env['BOSH_AWS_SECOND_STATIC_IP'] = '192.168.0.1' }

    its(:second_static_ip) { should eq('192.168.0.1') }
  end

  it 'generates the template' do
    expected_yaml = yaml_manifest.gsub('RESERVED_IP_RANGE', '10.10.0.2 - 10.10.0.9')
    expected_yaml = expected_yaml.gsub('STATIC_IP_RANGE', '10.10.0.10 - 10.10.0.30')
    expect(subject.to_y).to eq(expected_yaml)
  end

  context 'when ip address range environment variables are present' do
    it 'generates manifest that includes given ranges' do
      env['BOSH_AWS_NETWORK_RESERVED'] = 'fake reserved ip range'
      env['BOSH_AWS_NETWORK_STATIC'] = 'fake static ip range'

      expected_yaml = yaml_manifest.gsub('RESERVED_IP_RANGE', env['BOSH_AWS_NETWORK_RESERVED'])
      expected_yaml = expected_yaml.gsub('STATIC_IP_RANGE', env['BOSH_AWS_NETWORK_STATIC'])

      expect(subject.to_y).to eq(expected_yaml)
    end
  end

  context 'when ip address range environment variables are present' do
    it 'generates manifest that includes given ranges' do
      env['BOSH_AWS_NETWORK_RESERVED'] = ''
      env['BOSH_AWS_NETWORK_STATIC'] = ''

      expected_yaml = yaml_manifest.gsub('RESERVED_IP_RANGE', '10.10.0.2 - 10.10.0.9')
      expected_yaml = expected_yaml.gsub('STATIC_IP_RANGE', '10.10.0.10 - 10.10.0.30')

      expect(subject.to_y).to eq(expected_yaml)
    end
  end
end
