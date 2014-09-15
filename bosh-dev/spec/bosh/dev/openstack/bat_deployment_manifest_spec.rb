require 'spec_helper'
require 'bosh/dev/openstack/bat_deployment_manifest'
require 'bosh/stemcell/archive'
require 'psych'
require 'bosh/dev/bat/director_uuid'
require 'bosh/stemcell/archive'

module Bosh::Dev::Openstack
  describe BatDeploymentManifest do
    subject { described_class.new(env, net_type, director_uuid, stemcell_archive) }
    let(:env) { {} }
    let(:net_type) { 'dynamic' }
    let(:director_uuid) { instance_double('Bosh::Dev::Bat::DirectorUuid', value: 'director-uuid') }
    let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', version: 13, name: 'stemcell-name') }

    its(:filename) { should eq ('bat.yml') }
    its(:net_type) { should eq (net_type) }

    it 'is writable' do
      expect(subject).to be_a(Bosh::Dev::WritableManifest)
    end

    it 'allows BOSH_OPENSTACK_KEY_NAME to be optional' do
      expect(subject.to_h['properties']).to_not include('key_name')

      env.merge!(
        'BOSH_OPENSTACK_KEY_NAME' => 'fake-key-name',
      )

      expect(subject.to_h['properties']).to include('key_name' => 'fake-key-name')

      env.merge!(
        'BOSH_OPENSTACK_KEY_NAME' => '',
      )

      expect(subject.to_h['properties']).to_not include('key_name')
    end

    describe '#to_h' do
      before do
        env.merge!(
          'BOSH_OPENSTACK_VIP_BAT_IP'           => 'vip',
          'BOSH_OPENSTACK_STATIC_BAT_IP_0'      => 'fake-static-ip',
          'BOSH_OPENSTACK_STATIC_BAT_IP_1'      => 'fake-second-network-static-ip',
          'BOSH_OPENSTACK_SECOND_STATIC_BAT_IP' => 'fake-second-static-ip',
          'BOSH_OPENSTACK_NET_ID_0'             => 'net_id',
          'BOSH_OPENSTACK_NETWORK_CIDR_0'       => 'net_cidr',
          'BOSH_OPENSTACK_NETWORK_RESERVED_0'   => 'net_reserved',
          'BOSH_OPENSTACK_NETWORK_STATIC_0'     => 'net_static',
          'BOSH_OPENSTACK_NETWORK_GATEWAY_0'    => 'net_gateway',
          'BOSH_OPENSTACK_NET_ID_1'             => 'second_net_id',
          'BOSH_OPENSTACK_NETWORK_CIDR_1'       => 'second_net_cidr',
          'BOSH_OPENSTACK_NETWORK_RESERVED_1'   => 'second_net_reserved',
          'BOSH_OPENSTACK_NETWORK_STATIC_1'     => 'second_net_static',
          'BOSH_OPENSTACK_NETWORK_GATEWAY_1'    => 'second_net_gateway',
        )
      end

      context 'manual' do
        let(:net_type) { 'manual' }
        let(:expected_yml) { <<YAML }
---
cpi: openstack
properties:
  vip: vip
  second_static_ip: fake-second-static-ip
  uuid: director-uuid
  pool_size: 1
  stemcell:
    name: stemcell-name
    version: 13
  instance_type: m1.big
  flavor_with_no_ephemeral_disk: no-ephemeral
  instances: 1
  mbus: nats://nats:0b450ada9f830085e2cdeff6@vip:4222
  networks:
  - name: default
    static_ip: fake-static-ip
    type: manual
    cidr: net_cidr
    reserved:
      - net_reserved
    static:
      - net_static
    gateway: net_gateway
    cloud_properties:
      security_groups: [ default ]
      net_id: net_id
  - name: second
    static_ip: fake-second-network-static-ip
    type: manual
    cidr: second_net_cidr
    reserved:
      - second_net_reserved
    static:
      - second_net_static
    gateway: second_net_gateway
    cloud_properties:
      security_groups: [ default ]
      net_id: second_net_id
YAML

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end

      context 'dynamic' do
        let(:net_type) { 'dynamic' }
        let(:expected_yml) { <<YAML }
---
cpi: openstack
properties:
  vip: vip
  second_static_ip: fake-second-static-ip
  uuid: director-uuid
  pool_size: 1
  stemcell:
    name: stemcell-name
    version: 13
  instance_type: m1.big
  flavor_with_no_ephemeral_disk: no-ephemeral
  instances: 1
  mbus: nats://nats:0b450ada9f830085e2cdeff6@vip:4222
  networks:
  - name: default
    static_ip: fake-static-ip
    type: dynamic
    cloud_properties:
      security_groups: [ default ]
      net_id: net_id
  - name: second
    static_ip: fake-second-network-static-ip
    type: dynamic
    cloud_properties:
      security_groups: [ default ]
      net_id: second_net_id
YAML

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end
    end
  end
end
