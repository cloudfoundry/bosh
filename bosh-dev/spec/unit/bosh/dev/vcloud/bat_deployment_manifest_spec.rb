require 'spec_helper'
require 'bosh/dev/bat/director_uuid'
require 'bosh/dev/vcloud/bat_deployment_manifest'
require 'bosh/stemcell/archive'
require 'psych'

module Bosh::Dev::VCloud
  describe BatDeploymentManifest do
    subject { described_class.new(env, 'manual', director_uuid, stemcell_archive) }
    let(:env) { {} }
    let(:director_uuid) { instance_double('Bosh::Dev::Bat::DirectorUuid', value: 'director-uuid') }
    let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', version: 13, name: 'bosh-infra-hyper-os') }

    its(:filename) { should eq('bat.yml') }
    its(:net_type) { should eq('manual') }

    it 'is writable' do
      expect(subject).to be_a(Bosh::Dev::WritableManifest)
    end

    it 'requires the net type to match the manifest' do
      expect { described_class.new(env, 'manual', director_uuid, stemcell_archive) }.to_not raise_error
      expect { described_class.new(env, 'dynamic', director_uuid, stemcell_archive) }.to raise_error
    end

    describe '#to_h' do
      let(:expected_yml) { <<YAML }
---
cpi: vcloud
properties:
  uuid: director-uuid
  second_static_ip: fake-second-ip
  pool_size: 1
  stemcell:
    name: bosh-infra-hyper-os
    version: 13
  instances: 1
  networks:
  - name: static
    static_ip: ip
    type: manual
    cidr: net_cidr
    reserved:
      - reserved1
      - reserved2
    static:
      - net_static
    gateway: net_gateway
    vlan: net_id
  vapp_name: vapp
  vcds:
  - control:
      time_limit_sec:
        default: 360
YAML

      before do
        env.merge!(
          'BOSH_VCLOUD_BAT_IP' => 'ip',
          'BOSH_VCLOUD_SECOND_BAT_IP' => 'fake-second-ip',
          'BOSH_VCLOUD_NET_ID' => 'net_id',
          'BOSH_VCLOUD_NETWORK_CIDR' => 'net_cidr',
          'BOSH_VCLOUD_NETWORK_STATIC' => 'net_static',
          'BOSH_VCLOUD_NETWORK_GATEWAY' => 'net_gateway',
          'BOSH_VCLOUD_NETWORK_RESERVED' => 'reserved1|reserved2',
          'BOSH_VCLOUD_VAPP_NAME' => 'vapp'
        )
      end

      it 'generates the correct YAML' do
        expect(subject.to_h).to eq(Psych.load(expected_yml))
      end
    end
  end
end
