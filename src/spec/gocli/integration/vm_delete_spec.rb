require_relative '../spec_helper'

describe 'vm delete', type: :integration do
  include Bosh::Spec::BlockingDeployHelper
  with_reset_sandbox_before_each
  with_reset_hm_before_each

  before do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

    manifest_hash['instance_groups'].first['instances'] = 1
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
  end

  context 'when bosh has deployed the vm' do
    it 'deletes the vm by its vm_cid' do
      instance = director.instances.first
      expect(current_sandbox.cpi.has_vm(instance.vm_cid)).to be_truthy
      output = bosh_runner.run("delete-vm #{instance.vm_cid}", deployment_name: 'simple')
      expect(current_sandbox.cpi.has_vm(instance.vm_cid)).not_to be_truthy
      expect(director.vms.count).to eq(0)
      expect(output).to match /Delete VM: [0-9]{1,6}/
      expect(output).to match /Delete VM: VM [0-9]{1,6} is successfully deleted/
      expect(output).to match /Succeeded/

      #wait for resurrection
      resurrected_instance = director.wait_for_vm(instance.job_name, instance.index, 300, deployment_name: 'simple')
      expect(resurrected_instance.vm_cid).to_not eq(instance.vm_cid)
      expect(director.vms.count).to eq(1)

      #no reference to instance
      id = resurrected_instance.vm_cid
      expect(current_sandbox.cpi.has_vm(id)).to be_truthy
      output = bosh_runner.run("delete-vm #{id}", deployment_name: 'simple')
      expect(current_sandbox.cpi.has_vm(id)).not_to be_truthy
      expect(output).to match /Delete VM: [0-9]{1,6}/
      expect(output).to match /Delete VM: VM [0-9]{1,6} is successfully deleted/
      expect(output).to match /Succeeded/

      #vm does not exists
      current_sandbox.cpi.commands.make_delete_vm_to_raise_vmnotfound
      output = bosh_runner.run("delete-vm #{id}", deployment_name: 'simple')

      expect(output).to match /Delete VM: [0-9]{1,6}/
      expect(output).to match /Warning: VM [0-9]{1,6} does not exist. Deletion is skipped/
      expect(output).to match /Succeeded/
    end
  end

  context 'when bosh has not deployed the vm' do
    let(:ca_cert) {
      File.read(current_sandbox.nats_certificate_paths['ca_path'])
    }

    let(:client_cert) {
      File.read(current_sandbox.nats_certificate_paths['clients']['test_client']['certificate_path'])
    }

    let(:client_priv_key) {
      File.read(current_sandbox.nats_certificate_paths['clients']['test_client']['private_key_path'])
    }

    let(:env) do
      {
          'bosh' => {
              'mbus' => {
                  'cert' => {
                      'ca' => ca_cert,
                      'certificate' =>  client_cert,
                      'private_key' => client_priv_key
                  }
              }
          }
      }
    end

    it 'deletes the vm by its vm_cid' do
      network ={'a' => {'ip' => '192.168.1.5', 'type' => 'dynamic'}}
      id = current_sandbox.cpi.create_vm(SecureRandom.uuid, current_sandbox.cpi.latest_stemcell['id'], {}, network, [], env)

      expect(current_sandbox.cpi.has_vm(id)).to be_truthy
      bosh_runner.run("delete-vm #{id}", deployment_name: 'simple')
      expect(current_sandbox.cpi.has_vm(id)).not_to be_truthy

      expect { bosh_runner.run("delete-vm #{id}", deployment_name: 'simple') }.not_to raise_error
    end
  end
end
