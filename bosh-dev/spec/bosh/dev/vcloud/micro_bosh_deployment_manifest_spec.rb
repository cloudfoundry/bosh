require 'spec_helper'
require 'bosh/dev/vcloud/micro_bosh_deployment_manifest'
require 'psych'

module Bosh::Dev::VCloud
  describe MicroBoshDeploymentManifest do
    subject { described_class.new(env) }
    let(:env) { {} }

    it 'is writable' do
      expect(subject).to be_a(Bosh::Dev::WritableManifest)
    end

    its(:filename) { should eq('micro_bosh.yml') }

    describe '#to_h' do
      let(:expected_yml) { <<YAML }
---
name: microbosh-vcloud-jenkins

network:
  name: micro-network
  ip: ip
  vip: vip
  netmask: netmask
  gateway: gateway
  dns:
  - dns
  cloud_properties:
    name: net_id

resources:
   persistent_disk: 4096
   cloud_properties:
      ram: 2048
      disk: 8192
      cpu: 1

cloud:
  plugin: vcloud
  properties:
    agent:
      ntp:
       - ntp_server
    vcds:
      - url: https://vcloud
        user: vcloud_user
        password: vcloud_pwd
        entities:
          organization: vcloud_org
          virtual_datacenter: vcloud_datacenter
          vapp_catalog: vcloud_vapp_catalog
          media_catalog: vcloud_media_catalog
          media_storage_profile: vcloud_storage_profile
          vm_metadata_key: vcloud_vm_metadata_key
          description: 'MicroBosh on vCloudDirector'
          control:
            wait_max: 900
env:
  vapp: vcloud_vapp_name
logging:
  level: debug
YAML

      before do
        env.merge!(
          'BOSH_VCLOUD_MICROBOSH_IP' => 'ip',
          'BOSH_VCLOUD_MICROBOSH_VIP' => 'vip',
          'BOSH_VCLOUD_NETMASK' => 'netmask',
          'BOSH_VCLOUD_GATEWAY' => 'gateway',
          'BOSH_VCLOUD_DNS' => 'dns',
          'BOSH_VCLOUD_NET_ID' => 'net_id',
          'BOSH_VCLOUD_NTP_SERVER' => 'ntp_server',
          'BOSH_VCLOUD_URL' => 'https://vcloud',
          'BOSH_VCLOUD_USER' => 'vcloud_user',
          'BOSH_VCLOUD_PASSWORD' => 'vcloud_pwd',
          'BOSH_VCLOUD_ORG' => 'vcloud_org',
          'BOSH_VCLOUD_VDC' => 'vcloud_datacenter',
          'BOSH_VCLOUD_VAPP_CATALOG' => 'vcloud_vapp_catalog',
          'BOSH_VCLOUD_MEDIA_CATALOG' => 'vcloud_media_catalog',
          'BOSH_VCLOUD_MEDIA_STORAGE_PROFILE' => 'vcloud_storage_profile',
          'BOSH_VCLOUD_VM_METADATA_KEY' => 'vcloud_vm_metadata_key',
          'BOSH_VCLOUD_WAIT_MAX' => 900,
          'BOSH_VCLOUD_VAPP_NAME' => 'vcloud_vapp_name',
        )
      end

      it 'generates the correct YAML' do
        expect(subject.to_h).to eq(Psych.load(expected_yml))
      end
    end
  end
end
