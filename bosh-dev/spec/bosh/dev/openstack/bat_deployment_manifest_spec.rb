require 'spec_helper'
require 'bosh/dev/openstack/bat_deployment_manifest'
require 'psych'

module Bosh::Dev
  module Openstack
    describe BatDeploymentManifest do
      let(:net_type) { 'dynamic' }

      subject { BatDeploymentManifest.new(net_type, 'fake director_uuid', 'fake stemcell_version') }

      its(:filename) { should eq ('bat.yml') }

      it 'is writable' do
        expect(subject).to be_a(WritableManifest)
      end

      describe '#to_h' do
        before do
          ENV.stub(:to_hash).and_return({
                                          'BOSH_OPENSTACK_VIP_BAT_IP' => 'vip',
                                          'BOSH_OPENSTACK_NET_ID' => 'net_id',
                                          'BOSH_OPENSTACK_NETWORK_CIDR' => 'net_cidr',
                                          'BOSH_OPENSTACK_NETWORK_RESERVED' => 'net_reserved',
                                          'BOSH_OPENSTACK_NETWORK_STATIC' => 'net_static',
                                          'BOSH_OPENSTACK_NETWORK_GATEWAY' => 'net_gateway',
                                        })
        end

        context 'manual' do
          let(:net_type) { 'manual' }
          let(:expected_yml) do
            <<YAML
---
cpi: openstack
properties:
  static_ip: vip
  uuid: fake director_uuid
  pool_size: 1
  stemcell:
    name: bosh-stemcell
    version: fake stemcell_version
  instances: 1
  key_name:  jenkins
  mbus: nats://nats:0b450ada9f830085e2cdeff6@vip:4222
  network:
    cidr: net_cidr
    reserved:
      - net_reserved
    static:
      - net_static
    gateway: net_gateway
    security_groups: ["default"]
    net_id: net_id
YAML
          end

          it 'generates the correct YAML' do
            expect(subject.to_h).to eq(Psych.load(expected_yml))
          end
        end

        context 'dynamic' do
          let(:net_type) { 'dynamic' }

          let(:expected_yml) do
            <<YAML
---
cpi: openstack
properties:
  static_ip: vip
  uuid: fake director_uuid
  pool_size: 1
  stemcell:
    name: bosh-stemcell
    version: fake stemcell_version
  instances: 1
  key_name:  jenkins
  mbus: nats://nats:0b450ada9f830085e2cdeff6@vip:4222
  security_groups: default
YAML
          end

          it 'generates the correct YAML' do
            expect(subject.to_h).to eq(Psych.load(expected_yml))
          end
        end
      end
    end
  end
end
