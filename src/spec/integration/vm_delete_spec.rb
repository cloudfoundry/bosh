require 'spec_helper'

describe 'vm delete', type: :integration do
  with_reset_sandbox_before_each
  with_reset_hm_before_each

  before do
    bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell_with_api_version.tgz')}")
    upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
    create_and_upload_test_release

    manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 1
    deploy(manifest_hash: manifest_hash)
  end

  context 'when bosh has deployed the vm' do
    it 'deletes the vm by its vm_cid' do
      instance = director.instances.first
      expect(current_sandbox.cpi.has_vm(instance.vm_cid)).to be_truthy
      output = bosh_runner.run("delete-vm #{instance.vm_cid}", deployment_name: 'simple')
      expect(current_sandbox.cpi.has_vm(instance.vm_cid)).not_to be_truthy
      expect(director.vms.count).to eq(0)
      expect(output).to match(/Delete VM: [0-9]+/)
      expect(output).to match(/Delete VM: VM [0-9]+ is successfully deleted/)
      expect(output).to match(/Succeeded/)

      # wait for resurrection
      resurrected_instance = director.wait_for_vm(instance.instance_group_name, instance.index, 300, deployment_name: 'simple')
      expect(resurrected_instance.vm_cid).to_not eq(instance.vm_cid)
      expect(director.vms.count).to eq(1)

      # no reference to instance
      id = resurrected_instance.vm_cid
      expect(current_sandbox.cpi.has_vm(id)).to be_truthy
      output = bosh_runner.run("delete-vm #{id}", deployment_name: 'simple')
      expect(current_sandbox.cpi.has_vm(id)).not_to be_truthy
      expect(output).to match(/Delete VM: [0-9]+/)
      expect(output).to match(/Delete VM: VM [0-9]+ is successfully deleted/)
      expect(output).to match(/Succeeded/)

      # vm does not exists
      current_sandbox.cpi.commands.make_delete_vm_to_raise_vmnotfound
      output = bosh_runner.run("delete-vm #{id}", deployment_name: 'simple')

      expect(output).to match(/Delete VM: [0-9]+/)
      expect(output).to match(/Warning: VM [0-9]+ does not exist. Deletion is skipped/)
      expect(output).to match(/Succeeded/)

      cpi_invocations = current_sandbox.cpi.invocations

      [26, 35].each do |cpi_call_index|
        expect(cpi_invocations[cpi_call_index].method_name).to eq('delete_vm')
        expect(cpi_invocations[cpi_call_index].context).to match(
          'director_uuid' => kind_of(String),
          'request_id' => kind_of(String),
          'vm' => {
            'stemcell' => {
              'api_version' => 25,
            },
          },
        )
      end

      expect(cpi_invocations[38].method_name).to eq('delete_vm')
      expect(cpi_invocations[38].context).to match(
        'director_uuid' => kind_of(String),
        'request_id' => kind_of(String),
        'vm' => {
          'stemcell' => {
            'api_version' => 2,
          },
        },
      )
    end
  end

  context 'when bosh has not deployed the vm' do
    let(:ca_cert) do
      File.read(current_sandbox.nats_certificate_paths['ca_path'])
    end

    let(:client_cert) do
      File.read(current_sandbox.nats_certificate_paths['clients']['test_client']['certificate_path'])
    end

    let(:client_priv_key) do
      File.read(current_sandbox.nats_certificate_paths['clients']['test_client']['private_key_path'])
    end

    let(:env) do
      {
        'bosh' => {
          'mbus' => {
            'cert' => {
              'ca' => ca_cert,
              'certificate' =>  client_cert,
              'private_key' => client_priv_key,
            },
          },
        },
      }
    end

    it 'deletes the vm by its vm_cid' do
      network = { 'a' => { 'ip' => '192.168.1.5', 'type' => 'dynamic' } }
      id = current_sandbox.cpi.create_vm(SecureRandom.uuid, current_sandbox.cpi.latest_stemcell['id'], {}, network, [], env)

      expect(current_sandbox.cpi.has_vm(id)).to be_truthy
      bosh_runner.run("delete-vm #{id}", deployment_name: 'simple')
      expect(current_sandbox.cpi.has_vm(id)).not_to be_truthy

      expect { bosh_runner.run("delete-vm #{id}", deployment_name: 'simple') }.not_to raise_error

      cpi_invocations = current_sandbox.cpi.invocations

      [27, 30].each do |cpi_call_index|
        expect(cpi_invocations[cpi_call_index].method_name).to eq('delete_vm')
        expect(cpi_invocations[cpi_call_index].context).to match(
          'director_uuid' => kind_of(String),
          'request_id' => kind_of(String),
          'vm' => {
            'stemcell' => {
              'api_version' => 2,
            },
          },
        )
      end
    end
  end
end
