require 'spec_helper'

describe 'restart command', type: :integration do
  with_reset_sandbox_before_each

  def instance_states
    director.instances.each_with_object({}) do |instance, result|
      unless instance.last_known_state.empty?
        result["#{instance.instance_group_name}/#{instance.index}"] = instance.last_known_state
      end
    end
  end

  context 'when attempting to restart an errand instance' do
    before do
      deploy_from_scratch(manifest_hash: Bosh::Spec::Deployments.manifest_with_errand)
    end

    it 'fails gracefully with a useful message' do
      output = isolated_restart(
        deployment: 'errand',
        instance_group: 'fake-errand-name',
        index: 0,
        params: { failure_expected: true },
      )
      expect(output).to include('Isolated restart can not be run on instances of type errand. Try the bosh run-errand command.')
    end
  end

  context 'after a successful deploy' do
    before do
      deploy_from_scratch(Bosh::Spec::Deployments.simple_manifest_with_instance_groups)
    end

    it 'restarts the specified instance' do
      output = isolated_restart(instance_group: 'foobar', index: 0)
      expect(output).to match(/Updating instance foobar.* \(0\): Stopping instance/)
      expect(output).to match(/Updating instance foobar.* \(0\): Starting instance/)

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
          output = isolated_restart(instance_group: 'foobar', index: 0)
          expect(output).to match(/Updating instance foobar.* \(0\): Creating VM/)
          expect(output).to match(/Updating instance foobar.* \(0\): Starting instance/)
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

      it 'does not update the instance on subsequent deploys' do
        isolated_restart(instance_group: 'foobar', index: 0)

        output = deploy_simple_manifest
        expect(output).to_not match(/Updating instance foobar.* \(0\)/)
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
        instance_group = Bosh::Spec::Deployments.simple_instance_group(name: 'bad-instance-group', jobs: jobs)
        manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
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

      it 'restarting only touches the specified instance' do
        isolated_stop(instance_group: 'foobar', index: 0)
        output = isolated_restart(instance_group: 'foobar', index: 0)
        expect(output).to match(/Updating instance foobar.* \(0\)/)
        expect(output).to_not match(/Updating instance bad-instance-group.* \(0\)/)
      end

      it 'only restarts the specified hard stopped instance' do
        isolated_stop(instance_group: 'foobar', index: 0, params: { hard: true })
        output = isolated_restart(instance_group: 'foobar', index: 0)
        expect(output).to match(/Updating instance foobar.* \(0\)/)
        expect(output).to_not match(/Updating instance bad-instance-group.* \(0\)/)
      end
    end
  end
end
