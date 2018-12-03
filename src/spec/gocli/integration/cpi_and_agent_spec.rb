require 'spec_helper'

# Requests are properly sent in correct order between director, cpi and agent
describe 'CPI and Agent:', type: :integration do
  with_reset_sandbox_before_each(agent_wait_timeout: 3)

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
    manifest_hash['instance_groups'].first['persistent_disk_pool'] = Bosh::Spec::NewDeployments::DISK_TYPE['name']
    manifest_hash
  end

  let!(:fresh_deploy_invocations) do
    task_output = deploy_from_scratch(
      manifest_hash: manifest_hash,
      cloud_config_hash: cloud_config_hash,
    )

    get_invocations(task_output)
  end

  let(:cloud_config_hash) do
    Bosh::Spec::NewDeployments.simple_cloud_config.merge(
      'disk_types' => [
        Bosh::Spec::NewDeployments::DISK_TYPE,
      ],
    )
  end

  let(:old_vm_id) do
    old_vm_create_invocation.response
  end

  let(:old_vm_agent_id) do
    old_vm_create_invocation.arguments['agent_id']
  end

  let(:old_vm_create_invocation) do
    fresh_deploy_invocations.find_all { |i| i.method == 'create_vm' }.last
  end

  let(:disk_id) do
    fresh_deploy_invocations.find { |i| i.method == 'create_disk' }.response
  end

  context 'on a fresh deploy with persistent disk' do
    it 'requests between BOSH Director, CPI and Agent are sent in correct order' do
      invocations = Support::InvocationsHelper::InvocationIterator.new(fresh_deploy_invocations)

      expect(fresh_deploy_invocations.find_all { |i| i.target == 'cpi' }.size).to eq(27)

      # Compilation VM
      expect(invocations.next).to be_cpi_call(message: 'info')
      create_compilation_vm1 = invocations.next
      compilation_vm1_agent_id = create_compilation_vm1.arguments['agent_id']
      expect(create_compilation_vm1).to be_cpi_call(message: 'create_vm')
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(message: 'set_vm_metadata')
      expect(invocations.next).to be_agent_call(
        message: 'ping',
        agent_id: compilation_vm1_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'update_settings',
        agent_id: compilation_vm1_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'apply',
        agent_id: compilation_vm1_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'get_state',
        agent_id: compilation_vm1_agent_id,
      )
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(message: 'set_vm_metadata')
      expect(invocations.next).to be_agent_call(
        message: 'compile_package',
        agent_id: compilation_vm1_agent_id,
      )
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(
        message: 'delete_vm',
        argument_matcher: match('vm_cid' => create_compilation_vm1.response),
      )

      # Compilation VM
      expect(invocations.next).to be_cpi_call(message: 'info')
      create_compilation_vm2 = invocations.next
      compilation_vm2_agent_id = create_compilation_vm2.arguments['agent_id']
      expect(create_compilation_vm2).to be_cpi_call(message: 'create_vm')
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(message: 'set_vm_metadata')
      expect(invocations.next).to be_agent_call(
        message: 'ping',
        agent_id: compilation_vm2_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'update_settings',
        agent_id: compilation_vm2_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'apply',
        agent_id: compilation_vm2_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'get_state',
        agent_id: compilation_vm2_agent_id,
      )
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(message: 'set_vm_metadata')
      expect(invocations.next).to be_agent_call(
        message: 'compile_package',
        agent_id: compilation_vm2_agent_id,
      )
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(
        message: 'delete_vm',
        argument_matcher: match('vm_cid' => create_compilation_vm2.response),
      )

      # VM
      expect(invocations.next).to be_cpi_call(message: 'info')
      create_vm = invocations.next
      deployed_vm_agent_id = create_vm.arguments['agent_id']
      expect(create_vm).to be_cpi_call(message: 'create_vm')
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(message: 'set_vm_metadata')
      expect(invocations.next).to be_agent_call(
        message: 'ping',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'update_settings',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'apply',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'get_state',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'prepare',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'drain',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'stop',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'run_script',
        argument_matcher: match(['post-stop', {}]),
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(message: 'info')
      create_disk = invocations.next
      expect(create_disk).to be_cpi_call(message: 'create_disk')
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(
        message: 'attach_disk',
        argument_matcher: match(
          'vm_cid' => create_vm.response,
          'disk_id' => create_disk.response,
        ),
      )
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(message: 'set_disk_metadata')
      expect(invocations.next).to be_agent_call(
        message: 'ping',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'mount_disk',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'update_settings',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'apply',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'run_script',
        argument_matcher: match(['pre-start', {}]),
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'start',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'get_state',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'run_script',
        argument_matcher: match(['post-start', {}]),
        agent_id: deployed_vm_agent_id,
      )
    end
  end

  context 'on an update deployment with persistent disk' do
    let(:updated_manifest_hash) do
      updated_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      updated_manifest_hash['instance_groups'].first['persistent_disk_pool'] = Bosh::Spec::NewDeployments::DISK_TYPE['name']
      updated_manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }
      updated_manifest_hash
    end

    it 'requests between BOSH Director, CPI and Agent are sent in correct order', no_create_swap_delete: true do
      task_output = deploy_simple_manifest(manifest_hash: updated_manifest_hash)
      raw_invocations = get_invocations(task_output)
      invocations = Support::InvocationsHelper::InvocationIterator.new(raw_invocations)

      expect(raw_invocations.find_all { |i| i.target == 'cpi' }.size).to eq(14)

      # Old VM
      expect(invocations.next).to be_agent_call(
        message: 'get_state',
        agent_id: old_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'drain',
        agent_id: old_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'stop',
        agent_id: old_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'run_script',
        argument_matcher: match(['post-stop', {}]),
        agent_id: old_vm_agent_id,
      )
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(message: 'snapshot_disk')
      expect(invocations.next).to be_agent_call(
        message: 'list_disk',
        agent_id: old_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'unmount_disk',
        agent_id: old_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'remove_persistent_disk',
        agent_id: old_vm_agent_id,
      )
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(
        message: 'detach_disk',
        argument_matcher: match(
          'vm_cid' => old_vm_id,
          'disk_id' => disk_id,
        ),
      )
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(message: 'delete_vm', argument_matcher: match('vm_cid' => old_vm_id))

      # New VM
      expect(invocations.next).to be_cpi_call(message: 'info')
      create_vm = invocations.next
      deployed_vm_agent_id = create_vm.arguments['agent_id']
      expect(create_vm).to be_cpi_call(message: 'create_vm')
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(message: 'set_vm_metadata')
      expect(invocations.next).to be_agent_call(
        message: 'ping',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(
        message: 'attach_disk',
        argument_matcher: match(
          'vm_cid' => create_vm.response,
          'disk_id' => disk_id,
        ),
      )
      expect(invocations.next).to be_cpi_call(message: 'info')
      expect(invocations.next).to be_cpi_call(message: 'set_disk_metadata')
      expect(invocations.next).to be_agent_call(
        message: 'ping',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'mount_disk',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'update_settings',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'apply',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'get_state',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'list_disk',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'apply',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'run_script',
        agent_id: deployed_vm_agent_id,
        argument_matcher: match(['pre-start', {}]),
      )
      expect(invocations.next).to be_agent_call(
        message: 'start',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'get_state',
        agent_id: deployed_vm_agent_id,
      )
      expect(invocations.next).to be_agent_call(
        message: 'run_script',
        argument_matcher: match(['post-start', {}]),
        agent_id: deployed_vm_agent_id,
      )
    end

    context 'when create-swap-delete is enabled', create_swap_delete: true do
      context 'with a simple manifest' do
        before do
          manifest_hash['update'] = manifest_hash['update'].merge('vm_strategy' => 'create-swap-delete')
          manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }
        end

        context 'when the deploy succeeds' do
          it 'requests between BOSH Director, CPI and Agent are sent in correct order' do
            task_output = deploy_simple_manifest(manifest_hash: manifest_hash)
            raw_invocations = get_invocations(task_output)
            invocations = Support::InvocationsHelper::InvocationIterator.new(raw_invocations)

            expect(raw_invocations.find_all { |i| i.target == 'cpi' }.size).to eq(12)

            # old vm
            expect(invocations.next).to be_agent_call(
              message: 'get_state',
              agent_id: old_vm_agent_id,
            )

            # new vm
            expect(invocations.next).to be_cpi_call(message: 'info')
            new_create_vm = invocations.next
            newly_created_vm_id = new_create_vm.arguments['agent_id']
            expect(new_create_vm).to be_cpi_call(message: 'create_vm')
            expect(invocations.next).to be_cpi_call(message: 'info')
            expect(invocations.next).to be_cpi_call(message: 'set_vm_metadata')
            expect(invocations.next).to be_agent_call(
              message: 'ping',
              agent_id: newly_created_vm_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'update_settings',
              agent_id: newly_created_vm_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'apply',
              agent_id: newly_created_vm_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'get_state',
              agent_id: newly_created_vm_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'prepare',
              agent_id: newly_created_vm_id,
            )

            # old vm
            expect(invocations.next).to be_agent_call(
              message: 'drain',
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'stop',
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'run_script',
              argument_matcher: match(['post-stop', {}]),
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_cpi_call(message: 'info')
            expect(invocations.next).to be_cpi_call(message: 'snapshot_disk')
            expect(invocations.next).to be_agent_call(
              message: 'list_disk',
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'unmount_disk',
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'remove_persistent_disk',
              argument_matcher: match([disk_id]),
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_cpi_call(message: 'info')
            expect(invocations.next).to be_cpi_call(
              message: 'detach_disk',
              argument_matcher: match(
                'vm_cid' => old_vm_id,
                'disk_id' => disk_id,
              ),
            )

            # new vm
            expect(invocations.next).to be_cpi_call(message: 'info')
            expect(invocations.next).to be_cpi_call(
              message: 'attach_disk',
              argument_matcher: match(
                'vm_cid' => new_create_vm.response,
                'disk_id' => disk_id,
              ),
            )
            expect(invocations.next).to be_cpi_call(message: 'info')
            expect(invocations.next).to be_cpi_call(message: 'set_disk_metadata')
            expect(invocations.next).to be_agent_call(
              message: 'ping',
              agent_id: newly_created_vm_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'mount_disk',
              agent_id: newly_created_vm_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'list_disk',
              agent_id: newly_created_vm_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'apply',
              agent_id: newly_created_vm_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'run_script',
              agent_id: newly_created_vm_id,
              argument_matcher: match(['pre-start', {}]),
            )
            expect(invocations.next).to be_agent_call(
              message: 'start',
              agent_id: newly_created_vm_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'get_state',
              agent_id: newly_created_vm_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'run_script',
              argument_matcher: match(['post-start', {}]),
              agent_id: newly_created_vm_id,
            )
          end
        end

        context 'when the first deploy results in an unresponsive agent' do
          it 'updates the correct vms' do
            current_sandbox.cpi.commands.make_create_vm_have_unresponsive_agent

            failing_task_output = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)
            get_invocations(failing_task_output)

            current_sandbox.cpi.commands.allow_create_vm_to_have_responsive_agent
            task_output = deploy_simple_manifest(manifest_hash: manifest_hash)

            raw_invocations = get_invocations(task_output)
            invocations = Support::InvocationsHelper::InvocationIterator.new(raw_invocations)

            expect(invocations.next).to be_agent_call(
              message: 'get_state',
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_cpi_call(message: 'info')
            create_vm_call = invocations.next
            new_vm_agent_id = create_vm_call.arguments['agent_id']
            expect(create_vm_call).to be_cpi_call(message: 'create_vm')
            expect(invocations.next).to be_cpi_call(message: 'info')
            expect(invocations.next).to be_cpi_call(message: 'set_vm_metadata')
            expect(invocations.next).to be_agent_call(
              message: 'ping',
              agent_id: new_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'update_settings',
              agent_id: new_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'apply',
              agent_id: new_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'get_state',
              agent_id: new_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'prepare',
              agent_id: new_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'drain',
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'stop',
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'run_script',
              agent_id: old_vm_agent_id,
              argument_matcher: match(['post-stop', {}]),
            )
            expect(invocations.next).to be_cpi_call(message: 'info')
            expect(invocations.next).to be_cpi_call(message: 'snapshot_disk')
            expect(invocations.next).to be_agent_call(
              message: 'list_disk',
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'unmount_disk',
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'remove_persistent_disk',
              agent_id: old_vm_agent_id,
            )
            expect(invocations.next).to be_cpi_call(message: 'info')
            expect(invocations.next).to be_cpi_call(message: 'detach_disk')
            expect(invocations.next).to be_cpi_call(message: 'info')
            expect(invocations.next).to be_cpi_call(message: 'attach_disk')
            expect(invocations.next).to be_cpi_call(message: 'info')
            expect(invocations.next).to be_cpi_call(message: 'set_disk_metadata')
            expect(invocations.next).to be_agent_call(
              message: 'ping',
              agent_id: new_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'mount_disk',
              agent_id: new_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'list_disk',
              agent_id: new_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'apply',
              agent_id: new_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'run_script',
              agent_id: new_vm_agent_id,
              argument_matcher: match(['pre-start', {}]),
            )
            expect(invocations.next).to be_agent_call(
              message: 'start',
              agent_id: new_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'get_state',
              agent_id: new_vm_agent_id,
            )
            expect(invocations.next).to be_agent_call(
              message: 'run_script',
              agent_id: new_vm_agent_id,
              argument_matcher: match(['post-start', {}]),
            )
            expect(invocations.next).to be_nil
          end
        end
      end

      context 'when the first deploy fails with a reusable VM' do
        let(:failing_manifest_hash) do
          manifest_hash['releases'] = [{ 'name' => 'bosh-release', 'version' => '0.1-dev' }]
          manifest_hash['instance_groups'].first['persistent_disk_pool'] = Bosh::Spec::NewDeployments::DISK_TYPE['name']
          manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }
          manifest_hash['instance_groups'].first['jobs'] = [
            {
              'name' => 'job_with_bad_template',
              'properties' => {
                'gargamel' => {
                  'color' => 'chartreuse',
                },
                'fail_on_job_start' => true,
                'fail_instance_index' => 0,
              },
            },
          ]
          manifest_hash['instance_groups'].first['instances'] = 1
          manifest_hash
        end

        let(:succeeding_manifest_hash) do
          succeeding_manifest_hash = Bosh::Common::DeepCopy.copy(failing_manifest_hash)
          succeeding_manifest_hash['instance_groups'].first['jobs'] = []
          succeeding_manifest_hash['instance_groups'].first['instances'] = 1
          succeeding_manifest_hash
        end

        it 'makes CPI and agent calls in the correct order in the subsequent deploy to reuse the VM' do
          failing_task_output = deploy_simple_manifest(manifest_hash: failing_manifest_hash, failure_expected: true)
          failing_invocations = get_invocations(failing_task_output)

          reuseable_failing_vm_agent_id = failing_invocations.find { |i| i.method == 'create_vm' }.arguments['agent_id']

          task_output = deploy_simple_manifest(manifest_hash: succeeding_manifest_hash)

          raw_invocations = get_invocations(task_output)
          invocations = Support::InvocationsHelper::InvocationIterator.new(raw_invocations)

          expect(invocations.next).to be_agent_call(
            message: 'get_state',
            agent_id: reuseable_failing_vm_agent_id,
          )
          expect(invocations.next).to be_agent_call(
            message: 'prepare',
            agent_id: reuseable_failing_vm_agent_id,
          )
          expect(invocations.next).to be_agent_call(
            message: 'drain',
            agent_id: reuseable_failing_vm_agent_id,
          )
          expect(invocations.next).to be_agent_call(
            message: 'stop',
            agent_id: reuseable_failing_vm_agent_id,
          )
          expect(invocations.next).to be_agent_call(
            message: 'run_script',
            agent_id: reuseable_failing_vm_agent_id,
            argument_matcher: match(['post-stop', {}]),
          )
          expect(invocations.next).to be_cpi_call(message: 'info')
          expect(invocations.next).to be_cpi_call(message: 'snapshot_disk')
          expect(invocations.next).to be_agent_call(
            message: 'list_disk',
            agent_id: reuseable_failing_vm_agent_id,
          )
          expect(invocations.next).to be_agent_call(
            message: 'update_settings',
            agent_id: reuseable_failing_vm_agent_id,
          )
          expect(invocations.next).to be_agent_call(
            message: 'apply',
            agent_id: reuseable_failing_vm_agent_id,
          )
          expect(invocations.next).to be_agent_call(
            message: 'run_script',
            agent_id: reuseable_failing_vm_agent_id,
            argument_matcher: match(['pre-start', {}]),
          )
          expect(invocations.next).to be_agent_call(
            message: 'start',
            agent_id: reuseable_failing_vm_agent_id,
          )
          expect(invocations.next).to be_agent_call(
            message: 'get_state',
            agent_id: reuseable_failing_vm_agent_id,
          )
          expect(invocations.next).to be_agent_call(
            message: 'run_script',
            agent_id: reuseable_failing_vm_agent_id,
            argument_matcher: match(['post-start', {}]),
          )
          expect(invocations.next).to be_nil
        end
      end
    end
  end
end
