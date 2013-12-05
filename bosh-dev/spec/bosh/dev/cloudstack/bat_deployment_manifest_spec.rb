require 'spec_helper'
require 'bosh/dev/cloudstack/bat_deployment_manifest'
require 'bosh/stemcell/archive'
require 'psych'
require 'bosh/dev/bat/director_uuid'
require 'bosh/stemcell/archive'

module Bosh::Dev::Cloudstack
  describe BatDeploymentManifest do
    subject { described_class.new(env, net_type, director_uuid, stemcell_archive) }
    let(:env) { {} }
    let(:net_type) { 'dynamic' }
    let(:director_uuid) { instance_double('Bosh::Dev::Bat::DirectorUuid', value: 'director-uuid') }
    let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', version: 13, name: 'stemcell-name') }

    its(:filename) { should eq ('bat.yml') }

    it 'is writable' do
      expect(subject).to be_a(Bosh::Dev::WritableManifest)
    end

    describe '#to_h' do
      before do
        env.merge!(
          'BOSH_CLOUDSTACK_VIP_BAT_IP'       => 'vip',
          'BOSH_CLOUDSTACK_NETWORK_NAME'      => 'network_name',
        )
      end

      context 'dynamic' do
        let(:net_type) { 'dynamic' }
        let(:expected_yml) { <<YAML }
---
cpi: cloudstack
properties:
  static_ip: vip
  uuid: director-uuid
  pool_size: 1
  stemcell:
    name: stemcell-name
    version: 13
  instances: 1
  key_name:  jenkins
  mbus: nats://nats:0b450ada9f830085e2cdeff6@vip:4222
  network:
    type: dynamic
    cloud_properties:
      security_groups: []
      network_name: network_name
YAML

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end
    end
  end
end
