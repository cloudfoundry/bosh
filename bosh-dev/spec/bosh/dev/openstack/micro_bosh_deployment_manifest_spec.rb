require 'spec_helper'
require 'bosh/dev/openstack/micro_bosh_deployment_manifest'
require 'yaml'

module Bosh::Dev
  module Openstack
    describe MicroBoshDeploymentManifest do
      let(:net_type) { 'dynamic' }

      subject { MicroBoshDeploymentManifest.new(net_type) }

      its(:filename) { should eq('micro_bosh.yml') }

      it 'is writable' do
        expect(subject).to be_a(WritableManifest)
      end

      describe '#to_h' do
        before do
          ENV.stub(:to_hash).and_return({
                                          'BOSH_OPENSTACK_VIP_DIRECTOR_IP' => 'vip',
                                          'BOSH_OPENSTACK_MANUAL_IP' => 'ip',
                                          'BOSH_OPENSTACK_NET_ID' => 'net_id',
                                          'BOSH_OPENSTACK_AUTH_URL' => 'auth_url',
                                          'BOSH_OPENSTACK_USERNAME' => 'username',
                                          'BOSH_OPENSTACK_API_KEY' => 'api_key',
                                          'BOSH_OPENSTACK_TENANT' => 'tenant',
                                          'BOSH_OPENSTACK_REGION' => 'region',
                                          'BOSH_OPENSTACK_PRIVATE_KEY' => 'private_key_path',
                                        })
        end

        context 'when net_type is "manual"' do
          let(:net_type) { 'manual' }
          let(:expected_yml) do
            <<YAML
---
name: microbosh-openstack-manual
logging:
  level: DEBUG
network:
  type: manual
  vip: vip
  ip: ip
  cloud_properties:
    net_id: net_id
resources:
  persistent_disk: 4096
  cloud_properties:
    instance_type: m1.small
cloud:
  plugin: openstack
  properties:
    openstack:
      auth_url: auth_url
      username: username
      api_key: api_key
      tenant: tenant
      region: region
      endpoint_type: publicURL
      default_key_name: jenkins
      default_security_groups:
      - default
      private_key: private_key_path
apply_spec:
  agent:
    blobstore:
      address: vip
    nats:
      address: vip
  properties: {}
YAML
          end

          it 'generates the correct YAML' do
            expect(subject.to_h).to eq(Psych.load(expected_yml))
          end
        end

        context 'when net_type is "dynamic"' do
          let(:net_type) { 'dynamic' }
          let(:expected_yml) do
            <<YAML
---
name: microbosh-openstack-dynamic
logging:
  level: DEBUG
network:
  type: dynamic
  vip: vip
resources:
  persistent_disk: 4096
  cloud_properties:
    instance_type: m1.small
cloud:
  plugin: openstack
  properties:
    openstack:
      auth_url: auth_url
      username: username
      api_key: api_key
      tenant: tenant
      region: region
      endpoint_type: publicURL
      default_key_name: jenkins
      default_security_groups:
      - default
      private_key: private_key_path
apply_spec:
  agent:
    blobstore:
      address: vip
    nats:
      address: vip
  properties: {}
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
