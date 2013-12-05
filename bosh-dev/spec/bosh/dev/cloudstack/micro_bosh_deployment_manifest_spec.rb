require 'spec_helper'
require 'bosh/dev/cloudstack/micro_bosh_deployment_manifest'
require 'yaml'

module Bosh::Dev::Cloudstack
  describe MicroBoshDeploymentManifest do
    subject { MicroBoshDeploymentManifest.new(env, net_type) }
    let(:env) { {} }
    let(:net_type) { 'dynamic' }

    its(:filename) { should eq('micro_bosh.yml') }

    it 'is writable' do
      expect(subject).to be_a(Bosh::Dev::WritableManifest)
    end

    describe '#to_h' do
      before do
        env.merge!(
          'BOSH_CLOUDSTACK_VIP_DIRECTOR_IP' => 'vip',
          'BOSH_CLOUDSTACK_NETWORK_NAME' => 'network_name',
          'BOSH_CLOUDSTACK_ENDPOINT' => 'endpoint_url',
          'BOSH_CLOUDSTACK_API_KEY' => 'api_key',
          'BOSH_CLOUDSTACK_SECRET_ACCESS_KEY' => 'secret_access_key',
          'BOSH_CLOUDSTACK_DEFAULT_ZONE' => 'default_zone',
          'BOSH_CLOUDSTACK_DEFAULT_KEY_NAME' => 'key_name',
          'BOSH_CLOUDSTACK_PRIVATE_KEY' => 'private_key_path',
        )
      end

      context 'when net_type is "dynamic"' do
        let(:net_type) { 'dynamic' }
        let(:expected_yml) { <<YAML }
---
name: microbosh-cloudstack-dynamic
logging:
  level: DEBUG
network:
  type: dynamic
  vip: vip
  cloud_properties:
    network_name: network_name
resources:
  persistent_disk: 4096
  cloud_properties:
    instance_type: m1.small
cloud:
  plugin: cloudstack
  properties:
    cloudstack:
      endpoint: endpoint_url
      api_key: api_key
      secret_access_key: secret_access_key
      default_key_name: key_name
      private_key: private_key_path
      default_zone: default_zone
      default_security_groups: []
apply_spec:
  agent:
    blobstore:
      address: vip
    nats:
      address: vip
  properties: {}
YAML

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end
    end
  end
end
