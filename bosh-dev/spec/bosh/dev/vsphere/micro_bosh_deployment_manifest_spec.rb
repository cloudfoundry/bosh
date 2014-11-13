require 'spec_helper'
require 'bosh/dev/vsphere/micro_bosh_deployment_manifest'
require 'psych'

module Bosh::Dev::VSphere
  describe MicroBoshDeploymentManifest do
    subject { described_class.new(env, 'manual') }
    let(:env) { {} }

    it 'is writable' do
      expect(subject).to be_a(Bosh::Dev::WritableManifest)
    end

    its(:filename) { should eq('micro_bosh.yml') }

    it 'requires the net type to be manual' do
      expect { described_class.new(env, 'dynamic') }.to raise_error
      expect { described_class.new(env, 'manual') }.not_to raise_error
    end

    context "When no disk_path is specified" do
      describe '#to_h' do
        let(:expected_yml) { <<YAML }
---
name: microbosh-vsphere-jenkins

network:
  ip: ip
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
  plugin: vsphere
  properties:
    agent:
      ntp:
       - ntp_server
    vcenters:
      - host: vcenter
        user: vcenter_user
        password: vcenter_pwd
        datacenters:
          - name: vcenter_dc
            vm_folder: vcenter_ubosh_folder_prefix_VMs
            template_folder: vcenter_ubosh_folder_prefix_Templates
            disk_path: vcenter_ubosh_folder_prefix_Disks
            datastore_pattern: vcenter_ubosh_datastore_pattern
            persistent_datastore_pattern: vcenter_ubosh_datastore_pattern
            allow_mixed_datastores: true
            clusters:
              - vcenter_cluster:
                  resource_pool: vcenter_rp
apply_spec:
  properties:
    ntp:
    - ntp_server
    vcenter:
      host: vcenter
      user: vcenter_user
      password: vcenter_pwd
      datacenters:
        - name: vcenter_dc
          vm_folder: vcenter_folder_prefix_VMs
          template_folder: vcenter_folder_prefix_Templates
          disk_path: vcenter_folder_prefix_Disks
          datastore_pattern: vcenter_datastore_pattern
          persistent_datastore_pattern: vcenter_datastore_pattern
          allow_mixed_datastores: true
          clusters:
            - vcenter_cluster:
                resource_pool: vcenter_rp
YAML

        before do
          env.merge!(
            'BOSH_VSPHERE_MICROBOSH_IP' => 'ip',
            'BOSH_VSPHERE_NETMASK' => 'netmask',
            'BOSH_VSPHERE_GATEWAY' => 'gateway',
            'BOSH_VSPHERE_DNS' => 'dns',
            'BOSH_VSPHERE_NET_ID' => 'net_id',
            'BOSH_VSPHERE_NTP_SERVER' => 'ntp_server',
            'BOSH_VSPHERE_VCENTER' => 'vcenter',
            'BOSH_VSPHERE_VCENTER_USER' => 'vcenter_user',
            'BOSH_VSPHERE_VCENTER_PASSWORD' => 'vcenter_pwd',
            'BOSH_VSPHERE_VCENTER_DC' => 'vcenter_dc',
            'BOSH_VSPHERE_VCENTER_CLUSTER' => 'vcenter_cluster',
            'BOSH_VSPHERE_VCENTER_RESOURCE_POOL' => 'vcenter_rp',
            'BOSH_VSPHERE_VCENTER_FOLDER_PREFIX' => 'vcenter_folder_prefix',
            'BOSH_VSPHERE_VCENTER_UBOSH_FOLDER_PREFIX' => 'vcenter_ubosh_folder_prefix',
            'BOSH_VSPHERE_VCENTER_DATASTORE_PATTERN' => 'vcenter_datastore_pattern',
            'BOSH_VSPHERE_VCENTER_UBOSH_DATASTORE_PATTERN' => 'vcenter_ubosh_datastore_pattern',
          )
        end

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end
    end

    context "When a disk_path is specified" do
      describe '#to_h' do
        let(:expected_yml) { <<YAML }
---
name: microbosh-vsphere-jenkins

network:
  ip: ip
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
  plugin: vsphere
  properties:
    agent:
      ntp:
       - ntp_server
    vcenters:
      - host: vcenter
        user: vcenter_user
        password: vcenter_pwd
        datacenters:
          - name: vcenter_dc
            vm_folder: vcenter_ubosh_folder_prefix_VMs
            template_folder: vcenter_ubosh_folder_prefix_Templates
            disk_path: vcenter_disk_folder
            datastore_pattern: vcenter_ubosh_datastore_pattern
            persistent_datastore_pattern: vcenter_ubosh_datastore_pattern
            allow_mixed_datastores: true
            clusters:
              - vcenter_cluster:
                  resource_pool: vcenter_rp
apply_spec:
  properties:
    ntp:
    - ntp_server
    vcenter:
      host: vcenter
      user: vcenter_user
      password: vcenter_pwd
      datacenters:
        - name: vcenter_dc
          vm_folder: vcenter_folder_prefix_VMs
          template_folder: vcenter_folder_prefix_Templates
          disk_path: vcenter_disk_folder
          datastore_pattern: vcenter_datastore_pattern
          persistent_datastore_pattern: vcenter_datastore_pattern
          allow_mixed_datastores: true
          clusters:
            - vcenter_cluster:
                resource_pool: vcenter_rp
YAML

        before do
          env.merge!(
            'BOSH_VSPHERE_MICROBOSH_IP' => 'ip',
            'BOSH_VSPHERE_NETMASK' => 'netmask',
            'BOSH_VSPHERE_GATEWAY' => 'gateway',
            'BOSH_VSPHERE_DNS' => 'dns',
            'BOSH_VSPHERE_NET_ID' => 'net_id',
            'BOSH_VSPHERE_NTP_SERVER' => 'ntp_server',
            'BOSH_VSPHERE_VCENTER' => 'vcenter',
            'BOSH_VSPHERE_VCENTER_USER' => 'vcenter_user',
            'BOSH_VSPHERE_VCENTER_PASSWORD' => 'vcenter_pwd',
            'BOSH_VSPHERE_VCENTER_DC' => 'vcenter_dc',
            'BOSH_VSPHERE_VCENTER_CLUSTER' => 'vcenter_cluster',
            'BOSH_VSPHERE_VCENTER_RESOURCE_POOL' => 'vcenter_rp',
            'BOSH_VSPHERE_VCENTER_FOLDER_PREFIX' => 'vcenter_folder_prefix',
            'BOSH_VSPHERE_VCENTER_UBOSH_FOLDER_PREFIX' => 'vcenter_ubosh_folder_prefix',
            'BOSH_VSPHERE_VCENTER_DATASTORE_PATTERN' => 'vcenter_datastore_pattern',
            'BOSH_VSPHERE_VCENTER_UBOSH_DATASTORE_PATTERN' => 'vcenter_ubosh_datastore_pattern',
            'BOSH_VSPHERE_VCENTER_DISK_PATH' => 'vcenter_disk_folder',
          )
        end

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end
    end
  end
end
