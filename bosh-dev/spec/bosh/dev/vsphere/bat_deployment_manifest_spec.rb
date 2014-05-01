require 'spec_helper'
require 'bosh/dev/bat/director_uuid'
require 'bosh/dev/vsphere/bat_deployment_manifest'
require 'bosh/stemcell/archive'
require 'psych'

module Bosh::Dev::VSphere
  describe BatDeploymentManifest do
    subject { described_class.new(env, director_uuid, stemcell_archive) }
    let(:env) { {} }
    let(:director_uuid) { instance_double('Bosh::Dev::Bat::DirectorUuid', value: 'director-uuid') }
    let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', version: 13, name: 'bosh-infra-hyper-os') }

    its(:filename) { should eq ('bat.yml') }

    it 'is writable' do
      expect(subject).to be_a(Bosh::Dev::WritableManifest)
    end

    describe '#to_h' do
      let(:expected_yml) { <<YAML }
---
cpi: vsphere
properties:
  uuid: director-uuid
  static_ip: ip
  second_static_ip: fake-second-ip
  pool_size: 1
  stemcell:
    name: bosh-infra-hyper-os
    version: 13
  instances: 1
  mbus: nats://nats:0b450ada9f830085e2cdeff6@ip:4222
  network:
    type: manual
    cidr: net_cidr
    reserved:
      - reserved1
      - reserved2
    static:
      - net_static
    gateway: net_gateway
    vlan: net_id
YAML

      before do
        env.merge!(
          'BOSH_VSPHERE_BAT_IP' => 'ip',
          'BOSH_VSPHERE_SECOND_BAT_IP' => 'fake-second-ip',
          'BOSH_VSPHERE_NET_ID' => 'net_id',
          'BOSH_VSPHERE_NETWORK_CIDR' => 'net_cidr',
          'BOSH_VSPHERE_NETWORK_STATIC' => 'net_static',
          'BOSH_VSPHERE_NETWORK_GATEWAY' => 'net_gateway',
          'BOSH_VSPHERE_NETWORK_RESERVED' => 'reserved1|reserved2',
        )
      end

      it 'generates the correct YAML' do
        expect(subject.to_h).to eq(Psych.load(expected_yml))
      end
    end
  end
end
