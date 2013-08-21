require 'spec_helper'
require 'bosh/dev/vsphere/bat_deployment_manifest'
require 'psych'

module Bosh::Dev
  module VSphere
    describe BatDeploymentManifest do
      subject { BatDeploymentManifest.new('fake director_uuid', 'fake stemcell_version') }

      its(:filename) { should eq ('bat.yml') }

      it 'is writable' do
        expect(subject).to be_a(WritableManifest)
      end

      describe '#to_h' do
        let(:expected_yml) do
          <<YAML
---
cpi: vsphere
properties:
  uuid: fake director_uuid
  static_ip: ip
  pool_size: 1
  stemcell:
    name: bosh-stemcell
    version: fake stemcell_version
  instances: 1
  mbus: nats://nats:0b450ada9f830085e2cdeff6@ip:4222
  network:
    cidr: net_cidr
    reserved:
      - reserved1
      - reserved2
    static:
      - net_static
    gateway: net_gateway
    vlan: net_id
YAML
        end

        before do
          ENV.stub(:to_hash).and_return({
                                          'BOSH_VSPHERE_BAT_IP' => 'ip',
                                          'BOSH_VSPHERE_NET_ID' => 'net_id',
                                          'BOSH_VSPHERE_NETWORK_CIDR' => 'net_cidr',
                                          'BOSH_VSPHERE_NETWORK_STATIC' => 'net_static',
                                          'BOSH_VSPHERE_NETWORK_GATEWAY' => 'net_gateway',
                                          'BOSH_VSPHERE_NETWORK_RESERVED' => 'reserved1|reserved2',
                                        })
        end

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end
    end
  end
end
