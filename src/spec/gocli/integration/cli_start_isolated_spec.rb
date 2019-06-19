require_relative '../spec_helper'

describe 'start command', type: :integration do
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

    context 'with an index' do
      it 'starts the indexed job if it was stopped' do
        isolated_stop(instance_group: 'foobar', index: 0)

        expect do
          output = isolated_start(instance_group: 'foobar', index: 0)
          expect(output).to match(/Starting instance foobar: foobar.* \(0\)/)
        end.to change { vm_states }
          .from(
            'another-job/0' => 'running',
            'foobar/0' => 'stopped',
            'foobar/1' => 'running',
            'foobar/2' => 'running',
          )
          .to(
            'another-job/0' => 'running',
            'foobar/0' => 'running',
            'foobar/1' => 'running',
            'foobar/2' => 'running',
          )
      end
    end

    context 'with an id' do
      it 'starts the corresponding job if it was stopped' do
        instance_before_with_index1 = director.instances.find { |instance| instance.index == '1' }
        instance_uuid = instance_before_with_index1.id

        isolated_stop(instance_group: 'foobar', index: instance_uuid)

        expect do
          output = isolated_start(instance_group: 'foobar', id: instance_uuid)
          expect(output).to match %r{Starting instance foobar: foobar/#{instance_uuid} \(\d\)}
        end.to change { vm_states }
          .from(
            'another-job/0' => 'running',
            'foobar/0' => 'running',
            'foobar/1' => 'stopped',
            'foobar/2' => 'running',
          )
          .to(
            'another-job/0' => 'running',
            'foobar/0' => 'running',
            'foobar/1' => 'running',
            'foobar/2' => 'running',
          )
      end
    end

    it 'does not update the instance on subsequent deploys' do
      isolated_stop(instance_group: 'foobar', index: 0)
      isolated_start(instance_group: 'foobar', index: 0)

      output = deploy_simple_manifest(manifest_hash: manifest_hash)
      expect(output).not_to include('foobar')
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

      it 'only starts the indexed job' do
        isolated_stop(instance_group: 'foobar', index: 0)
        output = isolated_start(instance_group: 'foobar', index: 0)
        expect(output).not_to include('another-job')
        expect(output).to include('foobar')
      end
    end
  end
end
