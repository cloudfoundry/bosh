require 'spec_helper'

describe 'recreate command', type: :integration do
  with_reset_sandbox_before_each

  def instance_states
    director.instances.each_with_object({}) do |instance, result|
      unless instance.last_known_state.empty?
        result["#{instance.instance_group_name}/#{instance.index}"] = instance.last_known_state
      end
    end
  end

  context 'when attempting to recreate an errand instance' do
    before do
      deploy_from_scratch(manifest_hash: Bosh::Spec::DeploymentManifestHelper.manifest_with_errand)
    end

    it 'fails gracefully with a useful message' do
      output = isolated_recreate(
        deployment: 'errand',
        instance_group: 'fake-errand-name',
        index: 0,
        params: { failure_expected: true },
      )
      expect(output).to include('Isolated recreate can not be run on instances of type errand. Try the bosh run-errand command.')
    end
  end

  context 'after a successful deploy' do
    before do
      deploy_from_scratch(Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups)
    end

    it 'recreates the specified instance' do
      initial_instances = director.instances
      instance_to_be_recreated = director.find_instance(initial_instances, 'foobar', '0')

      output = isolated_recreate(instance_group: 'foobar', index: 0)
      expect(output).to match(%r{Updating instance foobar/.+ \(0\): Stopping instance})
      expect(output).to match(%r{Updating instance foobar/.+ \(0\): Starting instance})

      instances_after_instance_recreate = director.instances
      instance_was_recreated = director.find_instance(instances_after_instance_recreate, 'foobar', '0')
      expect(instance_to_be_recreated.vm_cid).not_to eq(instance_was_recreated.vm_cid)

      expect((initial_instances - [instance_to_be_recreated]).map(&:vm_cid))
        .to match_array((instances_after_instance_recreate - [instance_was_recreated]).map(&:vm_cid))

      expect(instance_states).to eq(
        'foobar/0' => 'running',
        'foobar/1' => 'running',
        'foobar/2' => 'running',
      )
    end

    context 'after a hard stop' do
      before do
        isolated_stop(instance_group: 'foobar', index: 0, params: { hard: true })
      end

      it 'creates the missing vm and starts the instance' do
        expect do
          output = isolated_recreate(instance_group: 'foobar', index: 0)
          expect(output).to match(%r{Updating instance foobar/.+ \(0\): Starting instance})
        end.to change { instance_states }
          .from(
            'foobar/1' => 'running',
            'foobar/2' => 'running',
          )
          .to(
            'foobar/0' => 'running',
            'foobar/1' => 'running',
            'foobar/2' => 'running',
          )
      end
    end

    context 'when the agent is unresponsive' do
      it 'still recreates successfully with --ignore-unresponsive-agent' do
        initial_instances = director.instances
        instance_to_be_recreated = director.find_instance(initial_instances, 'foobar', '0')
        instance_to_be_recreated.kill_agent

        output = isolated_recreate(instance_group: 'foobar', index: 0, params: { ignore_unresponsive_agent: true })
        expect(output).to match(%r{Updating instance foobar/.+ \(0\): Stopping instance})
        expect(output).to match(%r{Updating instance foobar/.+ \(0\): Starting instance})

        instances_after_instance_recreate = director.instances
        instance_was_recreated = director.find_instance(instances_after_instance_recreate, 'foobar', '0')
        expect(instance_to_be_recreated.vm_cid).not_to eq(instance_was_recreated.vm_cid)

        expect((initial_instances - [instance_to_be_recreated]).map(&:vm_cid))
          .to match_array((instances_after_instance_recreate - [instance_was_recreated]).map(&:vm_cid))

        expect(instance_states).to eq(
          'foobar/0' => 'running',
          'foobar/1' => 'running',
          'foobar/2' => 'running',
        )
      end
    end
  end

  context 'after a failed deploy' do
    context 'when there are unrelated instances that are not converged' do
      before do
        prepare_for_deploy
        jobs = [
          {
            'name' => 'job_with_bad_template',
            'release' => 'bosh-release',
            'properties' => {
              'gargamel' => {
                'color' => 'original_value',
              },
            },
          },
        ]
        instance_group = Bosh::Spec::DeploymentManifestHelper.simple_instance_group(name: 'bad-instance-group', jobs: jobs)
        manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'] << instance_group
        deploy(manifest_hash: manifest_hash)

        manifest_hash['instance_groups'].last['jobs'].first['properties'] = {
          'fail_instance_index' => 0,
          'fail_on_job_start' => true,
          'gargamel' => {
            'color' => 'updated_value',
          },
        }

        deploy(manifest_hash: manifest_hash, failure_expected: true)
      end

      it 'recreating only touches the specified instance' do
        isolated_stop(instance_group: 'foobar', index: 0)
        output = isolated_recreate(instance_group: 'foobar', index: 0)
        expect(output).to match(/Updating instance foobar/)
        expect(output).to_not match(/Updating instance bad-instance-group/)
      end
    end
  end
end
