require 'spec_helper'

describe 'start command', type: :integration do
  with_reset_sandbox_before_each

  def job_states
    director.instances.each_with_object({}) do |instance, result|
      unless instance.last_known_state.empty?
        result["#{instance.instance_group_name}/#{instance.index}"] = instance.last_known_state
      end
    end
  end

  def vm_states
    director.instances.each_with_object({}) do |instance, result|
      result["#{instance.instance_group_name}/#{instance.index}"] = instance.vm_state
    end
  end

  context 'when attempting to start an errand instance' do
    before do
      deploy_from_scratch(manifest_hash: SharedSupport::DeploymentManifestHelper.manifest_with_errand)
    end

    it 'fails gracefully with a useful message' do
      output = isolated_start(
        deployment: 'errand',
        instance_group: 'fake-errand-name',
        index: 0,
        params: { failure_expected: true },
      )
      expect(output).to include('Isolated start can not be run on instances of type errand. Try the bosh run-errand command.')
    end
  end

  context 'after a successful deploy' do
    before do
      deploy_from_scratch
    end

    context 'with an index' do
      it 'starts the indexed job if it was stopped' do
        isolated_stop(instance_group: 'foobar', index: 0)

        expect do
          output = isolated_start(instance_group: 'foobar', index: 0)
          expect(output).to match(/Updating instance foobar.* \(0\): Starting instance/)
        end.to change { job_states }
          .from(
            'foobar/0' => 'stopped',
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

    context 'with an id' do
      it 'starts the corresponding job if it was stopped' do
        instance_before_with_index1 = director.instances.find { |instance| instance.index == '1' }
        instance_uuid = instance_before_with_index1.id

        isolated_stop(instance_group: 'foobar', index: instance_uuid)

        expect do
          output = isolated_start(instance_group: 'foobar', id: instance_uuid)
          expect(output).to match(/Updating instance foobar.* \(1\): Starting instance/)
        end.to change { job_states }
          .from(
            'foobar/0' => 'running',
            'foobar/1' => 'stopped',
            'foobar/2' => 'running',
          )
          .to(
            'foobar/0' => 'running',
            'foobar/1' => 'running',
            'foobar/2' => 'running',
          )
      end
    end

    it 'does not update the instance on subsequent deploys' do
      isolated_stop(instance_group: 'foobar', index: 0)
      isolated_start(instance_group: 'foobar', index: 0)

      output = deploy_simple_manifest
      expect(output).not_to include('foobar')
    end

    context 'after a hard stop' do
      before do
        isolated_stop(instance_group: 'foobar', index: 0, params: { hard: true })
      end

      it 'creates the missing vm and starts the instance' do
        expect do
          output = isolated_start(instance_group: 'foobar', index: 0)
          expect(output).to match(/Updating instance foobar.* \(0\): Creating VM/)
          expect(output).to match(/Updating instance foobar.* \(0\): Starting instance/)
        end.to change { job_states }
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
        isolated_start(instance_group: 'foobar', index: 0)

        output = deploy_simple_manifest
        expect(output).not_to include('foobar')
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
        instance_group = SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'bad-instance-group', jobs: jobs)
        manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
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

      it 'starting only touches the specified instance' do
        isolated_stop(instance_group: 'foobar', index: 0)
        output = isolated_start(instance_group: 'foobar', index: 0)
        expect(output).to match(/Updating instance foobar.* \(0\): Starting instance/)
        expect(output).to_not match(/Updating instance bad-instance-group.* \(0\): Starting instance/)
      end

      it 'only starts the specified hard stopped instance' do
        isolated_stop(instance_group: 'foobar', index: 0, params: { hard: true })
        output = isolated_start(instance_group: 'foobar', index: 0)
        expect(output).to match(/Updating instance foobar.* \(0\): Starting instance/)
        expect(output).to_not match(/Updating instance bad-instance-group.* \(0\): Starting instance/)
      end
    end

    context 'when only some instances have updated' do
      let(:successful_manifest) do
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
        SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups(jobs: jobs)
      end

      it 'starting does not change job templates already deployed on the instance' do
        prepare_for_deploy
        deploy(manifest_hash: successful_manifest)

        # workaround to get correct update order
        instances = director.instances.sort_by(&:id)
        bootstrap = instances.select(&:bootstrap).first
        instances.reject!(&:bootstrap)
        instances.unshift(bootstrap)

        first_instance = instances[0]
        middle_instance = instances[1]
        last_instance = instances[2]

        jobs = [
          {
            'name' => 'job_with_bad_template',
            'release' => 'bosh-release',
            'properties' => {
              'fail_instance_index' => middle_instance.index,
              'fail_on_job_start' => true,
              'gargamel' => {
                'color' => 'updated_value',
              },
            },
          },
        ]
        failing_manifest = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups(jobs: jobs)
        deploy(manifest_hash: failing_manifest, failure_expected: true)

        isolated_stop(instance_group: 'foobar', index: first_instance.index)
        isolated_start(instance_group: 'foobar', index: first_instance.index)

        config_file = first_instance.read_job_template('job_with_bad_template', 'config/config.yml')
        expect(config_file).to include('updated_value')

        isolated_stop(instance_group: 'foobar', index: middle_instance.index)
        expect {
          isolated_start(instance_group: 'foobar', index: middle_instance.index)
        }.to raise_error(Bosh::Spec::BoshCliRunner::Error)

        config_file = middle_instance.read_job_template('job_with_bad_template', 'config/config.yml')
        expect(config_file).to include('updated_value')

        isolated_stop(instance_group: 'foobar', index: last_instance.index)
        isolated_start(instance_group: 'foobar', index: last_instance.index)

        config_file = last_instance.read_job_template('job_with_bad_template', 'config/config.yml')
        expect(config_file).to include('original_value')
      end
    end

    context 'when the instance is hard stopped' do
      before do
        prepare_for_deploy
        jobs = [
          {
            'name' => 'job_with_bad_template',
            'release' => 'bosh-release',
            'properties' => {
              'gargamel' => {
                'color' => 'value',
              },
            },
          },
        ]
        manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups(
          name: 'bad-instance-group',
          jobs: jobs, instances: 1
        )

        deploy(manifest_hash: manifest_hash)

        manifest_hash['instance_groups'].first['jobs'].first['properties']
          .merge!('fail_on_job_start' => true, 'fail_instance_index' => 0)

        deploy(manifest_hash: manifest_hash, failure_expected: true)
      end

      it 'does not change state when start is issued' do
        expect(job_states).to eq('bad-instance-group/0' => 'stopped')
        expect(vm_states).to eq('bad-instance-group/0' => 'started')

        isolated_stop(instance_group: 'bad-instance-group', index: 0, params: { 'hard' => true })
        expect(job_states).to eq({}) # VM state absent, instance state is detached
        expect(vm_states).to eq('bad-instance-group/0' => 'detached')

        isolated_start(instance_group: 'bad-instance-group', index: 0, params: { failure_expected: true })

        expect(job_states).to eq('bad-instance-group/0' => 'running')
        expect(vm_states).to eq('bad-instance-group/0' => 'started')
      end
    end
  end
end
