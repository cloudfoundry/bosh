require_relative '../spec_helper'

describe 'stop command', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'] << {
      'name' => 'another-job',
      'jobs' => [
        {
          'name' => 'foobar',
          'release' => 'bosh-release',
          'properties' => {
            'test_property' => 'first_deploy',
          },
        },
      ],
      'vm_type' => 'a',
      'instances' => 1,
      'networks' => [{ 'name' => 'a' }],
      'stemcell' => 'default',
    }
    manifest_hash
  end

  def vm_states
    director.instances.each_with_object({}) do |instance, result|
      unless instance.last_known_state.empty?
        result["#{instance.instance_group_name}/#{instance.index}"] = instance.last_known_state
      end
    end
  end

  context 'after a successful deploy' do
    before do
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
    end

    context 'with an index or id' do
      it 'stops the indexed job' do
        expect do
          output = isolated_stop(instance_group: 'foobar', index: 0)
          expect(output).to match(/Stopping instance foobar: foobar.* \(0\)/)
        end.to change { vm_states }
          .from(
            'another-job/0' => 'running',
            'foobar/0' => 'running',
            'foobar/1' => 'running',
            'foobar/2' => 'running',
          )
          .to(
            'another-job/0' => 'running',
            'foobar/0' => 'stopped',
            'foobar/1' => 'running',
            'foobar/2' => 'running',
          )

        instance_before_with_index1 = director.instances.find { |instance| instance.index == '1' }
        instance_uuid = instance_before_with_index1.id

        expect do
          output = isolated_stop(instance_group: 'foobar', id: instance_uuid)
          expect(output).to match %r{Stopping instance foobar: foobar/#{instance_uuid} \(\d\)}
        end.to change { vm_states }
          .from(
            'another-job/0' => 'running',
            'foobar/0' => 'stopped',
            'foobar/1' => 'running',
            'foobar/2' => 'running',
          )
          .to(
            'another-job/0' => 'running',
            'foobar/0' => 'stopped',
            'foobar/1' => 'stopped',
            'foobar/2' => 'running',
          )
      end
    end

    it 'maintains instance state across a deploy' do
      isolated_stop(instance_group: 'foobar', index: 0)
      expect(vm_states).to eq(
        'another-job/0' => 'running',
        'foobar/0' => 'stopped',
        'foobar/1' => 'running',
        'foobar/2' => 'running',
      )
      deploy(manifest_hash: manifest_hash)
      expect(vm_states).to eq(
        'another-job/0' => 'running',
        'foobar/0' => 'stopped',
        'foobar/1' => 'running',
        'foobar/2' => 'running',
      )
    end

    context 'given the --hard flag' do
      it 'deletes the VM(s)' do
        expect do
          output = isolated_stop(instance_group: 'foobar', index: 0, params: { hard: true })
          expect(output).to match %r{Stopping instance foobar: foobar/.* \(0\)}
          expect(output).to match 'Deleting VM: '
        end.to change { director.vms.count }.by(-1)
        expect do
          deploy(manifest_hash: manifest_hash)
        end.not_to(change { director.vms.count })
      end
    end
  end

  context 'after a failed deploy' do
    context 'when there are unrelated instances that are not converged' do
      let(:late_fail_manifest) do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'] << {
          'name' => 'another-job',
          'jobs' => [
            {
              'name' => 'foobar',
              'release' => 'bosh-release',
              'properties' => {
                'test_property' => 'second_deploy',
              },
            },
          ],
          'vm_type' => 'a',
          'instances' => 1,
          'networks' => [{ 'name' => 'a' }],
          'stemcell' => 'default',
        }
        manifest_hash['instance_groups'] << {
          'name' => 'the-broken-job',
          'jobs' => [
            {
              'name' => 'job_with_post_start_script',
              'release' => 'bosh-release',
              'properties' => {
                'exit_code' => 1,
              },
            },
          ],
          'vm_type' => 'a',
          'instances' => 1,
          'networks' => [{ 'name' => 'a' }],
          'stemcell' => 'default',
        }

        manifest_hash
      end

      before do
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
        deploy(manifest_hash: late_fail_manifest, failure_expected: true)
      end

      it 'only stops the indexed job' do
        output = isolated_stop(instance_group: 'foobar', index: 0)
        expect(output).not_to include('another-job')
        expect(output).to include('foobar')
      end
    end
  end

  context 'hard-stopping a job with persistent disk, followed by a re-deploy' do
    before do
      manifest_hash['instance_groups'].first['persistent_disk'] = 1024
      manifest_hash['instance_groups'].first['instances'] = 1
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
    end

    it 'is successful (regression: #108398600) ' do
      isolated_stop(instance_group: 'foobar', index: 0, params: { hard: true })
      expect(vm_states).to eq('another-job/0' => 'running')
      expect do
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      end.to_not raise_error
      expect(vm_states).to eq('another-job/0' => 'running')
    end
  end
end
