require_relative '../spec_helper'
require 'fileutils'

describe 'deploy with hotswap', type: :integration do
  with_reset_sandbox_before_each
  let(:manifest) do
    manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups(instances: 1)
    manifest['update'] = manifest['update'].merge('strategy' => 'duplicate-and-replace-vm')
    manifest
  end
  let(:cloud_config) do
    cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config['networks'][0]['type'] = network_type
    cloud_config
  end
  let(:network_type) { 'dynamic' }

  context 'a very simple deploy' do
    instance_slug_regex = %r/foobar\/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/

    before do
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: cloud_config)
    end

    it 'should create vms that require recreation and download packages to them before updating' do
      deploy_simple_manifest(manifest_hash: manifest, recreate: true)
      output = bosh_runner.run('task 4')

      expect(output)
        .to match(%r{Creating missing vms: foobar\/.*\n.*Downloading packages: foobar.*\n.*Updating instance foobar})
    end

    it 'should show new vms in bosh vms command' do
      old_vm = table(bosh_runner.run('vms', json: true))[0]

      deploy_simple_manifest(manifest_hash: manifest, recreate: true)
      vms = table(bosh_runner.run('vms', json: true))

      expect(vms.length).to eq(1)

      vm_pattern = {
        'active' => /true|false/,
        'az' => '',
        'instance' => instance_slug_regex,
        'ips' => /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/,
        'process_state' => /[a-z]{7}/,
        'vm_cid' => /[0-9]{1,6}/,
        'vm_type' => 'a',
      }

      new_vm = vms[0]

      expect(new_vm).to match(vm_pattern)

      expect(new_vm['active']).to eq('true')
      expect(new_vm['az']).to eq(old_vm['az'])
      expect(new_vm['vm_type']).to eq(old_vm['vm_type'])
      expect(new_vm['instance']).to eq(old_vm['instance'])
      expect(new_vm['vm_cid']).to_not eq(old_vm['vm_cid'])
      expect(new_vm['process_state']).to eq('running')
      expect(new_vm['ips']).to_not eq(old_vm['ips'])
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

    context 'when changing network settings' do
      it 'hotswaps vms' do
        old_vm = table(bosh_runner.run('vms', json: true))[0]

        cloud_config['networks'][0]['name'] = 'crazy-train'
        upload_cloud_config(cloud_config)
        out =  deploy_simple_manifest(manifest_hash: manifest)
        expect(out).to match /Creating missing vms: foobar/
        expect(out).to match /Downloading packages: foobar/

        vms = table(bosh_runner.run('vms', json: true))

        expect(vms.length).to eq(1)

        vm_pattern = {
          'active' => /true|false/,
          'az' => '',
          'instance' => instance_slug_regex,
          'ips' => /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/,
          'process_state' => /[a-z]{7}/,
          'vm_cid' => /[0-9]{1,6}/,
          'vm_type' => 'a',
        }

        new_vm = vms[0]

        expect(new_vm).to match(vm_pattern)

        expect(new_vm['active']).to eq('true')
        expect(new_vm['az']).to eq(old_vm['az'])
        expect(new_vm['vm_type']).to eq(old_vm['vm_type'])
        expect(new_vm['instance']).to eq(old_vm['instance'])
        expect(new_vm['vm_cid']).to_not eq(old_vm['vm_cid'])
        expect(new_vm['process_state']).to eq('running')
        expect(new_vm['ips']).to_not eq(old_vm['ips'])
      end
    end

    context 'when the instance is on a manual network' do
      let(:network_type) { 'manual' }

      it 'should show new vms in bosh vms command' do
        old_vm = table(bosh_runner.run('vms', json: true))[0]

        deploy_simple_manifest(manifest_hash: manifest, recreate: true)
        vms = table(bosh_runner.run('vms', json: true))

        expect(vms.length).to eq(1)

        vm_pattern = {
          'active' => /true|false/,
          'az' => '',
          'instance' => instance_slug_regex,
          'ips' => /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/,
          'process_state' => /[a-z]{7}/,
          'vm_cid' => /[0-9]{1,6}/,
          'vm_type' => 'a',
        }

        new_vm = vms[0]

        expect(new_vm).to match(vm_pattern)

        expect(new_vm['active']).to eq('true')
        expect(new_vm['az']).to eq(old_vm['az'])
        expect(new_vm['vm_type']).to eq(old_vm['vm_type'])
        expect(new_vm['instance']).to eq(old_vm['instance'])
        expect(new_vm['vm_cid']).to_not eq(old_vm['vm_cid'])
        expect(new_vm['process_state']).to eq('running')
        expect(new_vm['ips']).to_not eq(old_vm['ips'])
      end

      context 'when doing a no-op deploy' do
        it 'should not create new vms' do
          old_vm = table(bosh_runner.run('vms', json: true))[0]

          deploy_simple_manifest(manifest_hash: manifest)
          vms = table(bosh_runner.run('vms', json: true))

          expect(vms.length).to eq(1)

          vm_pattern = {
            'active' => /true|false/,
            'az' => '',
            'instance' => instance_slug_regex,
            'ips' => /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/,
            'process_state' => /[a-z]{7}/,
            'vm_cid' => /[0-9]{1,6}/,
            'vm_type' => 'a',
          }

          new_vm = vms[0]

          expect(new_vm).to match(vm_pattern)

          expect(new_vm['active']).to eq('true')
          expect(new_vm['az']).to eq(old_vm['az'])
          expect(new_vm['vm_type']).to eq(old_vm['vm_type'])
          expect(new_vm['instance']).to eq(old_vm['instance'])
          expect(new_vm['vm_cid']).to eq(old_vm['vm_cid'])
          expect(new_vm['process_state']).to eq('running')
          expect(new_vm['ips']).to eq(old_vm['ips'])
        end
      end

      context 'when using instances with static ip addresses' do
        before do
          manifest['instance_groups'][0]['networks'][0]['static_ips'] = ['192.168.1.10']
          deploy_simple_manifest(manifest_hash: manifest)
        end

        it 'should not hotswap vms' do
          task_id = nil
          expect do
            deploy_simple_manifest(manifest_hash: manifest, recreate: true)
            task_id = bosh_runner.get_most_recent_task_id
          end.not_to(change { director.instances.first.ips })

          task_log = bosh_runner.run("task #{task_id} --debug")
          expect(task_log).to match(/Skipping hotswap for static ip enabled instance #{instance_slug_regex}/)
        end
      end
    end
  end

  context 'when running dry run initially' do
    before do
      deploy_from_scratch(
        manifest_hash: manifest,
        cloud_config_hash: cloud_config,
        dry_run: true,
      )
    end

    it 'does not interfere with a successful deployment later' do
      _, exit_code = deploy_from_scratch(
        manifest_hash: manifest,
        cloud_config_hash: cloud_config,
        return_exit_code: true,
      )

      expect(exit_code).to eq(0)
    end
  end
end
