require_relative '../spec_helper'
require 'fileutils'

describe 'deploy with hotswap', type: :integration do
  context 'a very simple deploy' do
    with_reset_sandbox_before_each

    let(:manifest) do
      manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups(instances: 1)
      manifest['update'] = manifest['update'].merge('strategy' => 'hot-swap')
      manifest
    end

    before do
      cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config['networks'][0]['type'] = 'dynamic'

      manifest['instance_groups'][0]['networks'][0].delete('static_ips')
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: cloud_config)
    end

    it 'should create vms that require recreation and download packages to them before updating' do
      deploy_simple_manifest(manifest_hash: manifest, recreate: true)
      output = bosh_runner.run('task 4')

      expect(output).to match(/Creating missing vms: foobar\/.*\n.*Downloading packages: foobar.*\n.*Updating instance foobar/)
    end

    it 'should show new vms in bosh vms command' do
      deploy_simple_manifest(manifest_hash: manifest, recreate: true)
      vms = table(bosh_runner.run('vms', json: true))

      expect(vms.length).to eq(2)

      vm_pattern = {
        'active' => /./,
        'az' => '',
        'instance' => /foobar\/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/,
        'ips' => /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/,
        'process_state' => /[a-z]{7}/,
        'vm_cid' => /[0-9]{1,6}/,
        'vm_type' => 'a',
      }

      vm0 = vms[0]
      vm1 = vms[1]

      expect(vm0).to match(vm_pattern)
      expect(vm1).to match(vm_pattern)

      expect(vm0['active']).to eq("false")
      expect(vm1['active']).to eq("true")
      expect(vm0['az']).to eq(vm1['az'])
      expect(vm0['vm_type']).to eq(vm1['vm_type'])
      expect(vm0['instance']).to eq(vm1['instance'])
      expect(vm0['vm_cid']).to_not eq(vm1['vm_cid'])
      expect(vm0['process_state']).to_not eq(vm1['process_state'])
      expect(vm0['ips']).to_not eq(vm1['ips'])
    end

    context 'when using instances with persistent disk' do
      before do
        manifest['instance_groups'][0]['persistent_disk'] = 1000
        deploy_simple_manifest(manifest_hash: manifest)
      end

      it 'should attach disks to new hotswap vms' do
        instance = director.instances.first
        disk_cid = instance.disk_cids[0]
        expect(disk_cid).not_to be_empty

        expect(current_sandbox.cpi.disk_attached_to_vm?(instance.vm_cid, disk_cid)).to eq(true)

        director.start_recording_nats
        deploy_simple_manifest(manifest_hash: manifest, recreate: true)

        instance = director.instances.first
        expect(current_sandbox.cpi.disk_attached_to_vm?(instance.vm_cid, disk_cid)).to eq(true)
        nats_messages = extract_agent_messages(director.finish_recording_nats, instance.agent_id)
        expect(nats_messages).to include('mount_disk')
      end
    end

    it 'should show the new vm only in bosh instances command' do
      # get original vm info
      instances = table(bosh_runner.run('instances', json: true))

      expect(instances.length).to eq(1)
      original_instance = instances[0]

      expect(original_instance).to match(
        'az' => '',
        'instance' => %r|foobar/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}|,
        'ips' => /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/,
        'process_state' => 'running',
      )

      deploy_simple_manifest(manifest_hash: manifest, recreate: true)

      # get new vm info
      # assert it is different
      new_instances = table(bosh_runner.run('instances', json: true))

      expect(new_instances.length).to eq(1)
      new_instance = new_instances[0]
      expect(new_instance).to_not eq original_instance
    end

    it 'should run software on the newly created vm' do
      manifest['instance_groups'].first['jobs'].first['properties'] = { 'test_property' => 1 }
      deploy_simple_manifest(manifest_hash: manifest, recreate: true)

      foobar_instance = director.instance('foobar', '0')

      template = foobar_instance.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('test_property=1')
    end
  end
end
