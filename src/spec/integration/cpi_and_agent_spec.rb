require 'spec_helper'

# Requests are properly sent in correct order between director, cpi and agent
describe 'CPI and Agent:', type: :integration do
  with_reset_sandbox_before_each(agent_wait_timeout: 3)

  def create_vm_sequence(vm_cid, agent_id)
    [
      {
        target: 'cpi',
        method: 'create_vm',
        agent_id: agent_id,
        response_matcher: be(vm_cid),
      },
      { target: 'cpi', method: 'set_vm_metadata', vm_cid: vm_cid },
      { target: 'agent', method: 'ping', agent_id: agent_id, can_repeat: true },
    ]
  end

  def update_settings_sequence(agent_id)
    [
      { target: 'agent', method: 'update_settings', agent_id: agent_id },
      { target: 'agent', method: 'apply', agent_id: agent_id },
    ]
  end

  def compilation_vm_sequence(vm_cid, agent_id)
    [
      *create_vm_sequence(vm_cid, agent_id),
      *update_settings_sequence(agent_id),
      { target: 'cpi', method: 'set_vm_metadata', vm_cid: vm_cid },
      { target: 'agent', method: 'compile_package', agent_id: agent_id },
      { target: 'cpi', method: 'delete_vm', vm_cid: vm_cid },
    ]
  end

  def prepare_sequence(agent_id)
    [
      { target: 'agent', method: 'prepare', agent_id: agent_id },
    ]
  end

  def create_vm_with_persistent_disk_calls(vm_cid, agent_id, disk_cid)
    [
      *create_vm_sequence(vm_cid, agent_id),
      *update_settings_sequence(agent_id),
      *prepare_sequence(agent_id),
      *stop_jobs_sequence(
        agent_id,
        'env' => {
          'BOSH_VM_NEXT_STATE' => 'delete',
          'BOSH_INSTANCE_NEXT_STATE' => 'keep',
          'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
        },
      ),
      { target: 'cpi', method: 'create_disk', response_matcher: be(disk_cid) },
      *attach_disk_sequence(vm_cid, agent_id, disk_cid),
      *update_settings_sequence(agent_id),
      *start_jobs_sequence(agent_id),
    ]
  end

  def attach_disk_sequence(vm_cid, agent_id, disk_cid)
    [
      { target: 'cpi', method: 'attach_disk', vm_cid: vm_cid, argument_matcher: include('disk_id' => disk_cid) },
      { target: 'cpi', method: 'set_disk_metadata', argument_matcher: include('disk_cid' => disk_cid) },
      { target: 'agent', method: 'ping', agent_id: agent_id, can_repeat: true },
      { target: 'agent', method: 'mount_disk', agent_id: agent_id, argument_matcher: match([disk_cid]) },
    ]
  end

  def stop_jobs_sequence(agent_id, pre_stop_env_vars)
    [
      { target: 'agent', method: 'run_script', agent_id: agent_id, argument_matcher: match(['pre-stop', pre_stop_env_vars]) },
      { target: 'agent', method: 'drain', agent_id: agent_id },
      { target: 'agent', method: 'stop', agent_id: agent_id },
      { target: 'agent', method: 'run_script', agent_id: agent_id, argument_matcher: match(['post-stop', {}]) },
    ]
  end

  def start_jobs_sequence(agent_id)
    [
      { target: 'agent', method: 'run_script', agent_id: agent_id, argument_matcher: match(['pre-start', {}]) },
      { target: 'agent', method: 'start', agent_id: agent_id },
      { target: 'agent', method: 'run_script', agent_id: agent_id, argument_matcher: match(['post-start', {}]) },
      { target: 'agent', method: 'run_script', agent_id: agent_id, argument_matcher: match(['post-deploy', {}]) },
    ]
  end

  def detach_disk_sequence(vm_cid, agent_id, disk_id)
    [
      { target: 'agent', method: 'unmount_disk', agent_id: agent_id, argument_matcher: match([disk_id]) },
      { target: 'agent', method: 'remove_persistent_disk', agent_id: agent_id, argument_matcher: match([disk_id]) },
      { target: 'cpi', method: 'detach_disk', vm_cid: vm_cid, disk_id: disk_id },
    ]
  end

  def snapshot_disk_sequence(agent_id, disk_id)
    [
      { target: 'cpi', method: 'snapshot_disk', disk_id: disk_id },
      { target: 'agent', method: 'list_disk', agent_id: agent_id },
    ]
  end

  def list_disk_apply_sequence(agent_id)
    [
      { target: 'agent', method: 'list_disk', agent_id: agent_id },
      { target: 'agent', method: 'apply', agent_id: agent_id },
    ]
  end

  def delete_vm_sequence(vm_id)
    [
      { target: 'cpi', method: 'delete_vm', vm_cid: vm_id },
    ]
  end

  def create_disk_sequence(disk_id)
    [
      { target: 'cpi', method: 'create_disk', response_matcher: be(disk_id) },
    ]
  end

  def hotswap_detach_disk_sequence(old_vm_id, old_vm_agent_id, hotswap_vm_id, hotswap_vm_agent_id, disk_id)
    [
      *create_vm_sequence(hotswap_vm_id, hotswap_vm_agent_id),
      *update_settings_sequence(hotswap_vm_agent_id),
      *prepare_sequence(hotswap_vm_agent_id),
      *stop_jobs_sequence(
        old_vm_agent_id,
        'env' => {
          'BOSH_VM_NEXT_STATE' => 'delete',
          'BOSH_INSTANCE_NEXT_STATE' => 'keep',
          'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
        },
      ),
      *snapshot_disk_sequence(old_vm_agent_id, disk_id),
      *detach_disk_sequence(old_vm_id, old_vm_agent_id, disk_id),
    ]
  end

  def hotswap_update_sequence(old_vm_id, old_vm_agent_id, hotswap_vm_id, hotswap_vm_agent_id, disk_id)
    [
      *hotswap_detach_disk_sequence(old_vm_id, old_vm_agent_id, hotswap_vm_id, hotswap_vm_agent_id, disk_id),
      *attach_disk_sequence(hotswap_vm_id, hotswap_vm_agent_id, disk_id),
      { target: 'agent', method: 'update_settings', agent_id: hotswap_vm_agent_id },
      *list_disk_apply_sequence(hotswap_vm_agent_id),
    ]
  end

  def update_sequence(old_vm_id, old_vm_agent_id, updated_vm_id, updated_vm_agent_id, disk_id)
    [
      *stop_jobs_sequence(
        old_vm_agent_id,
        'env' => {
          'BOSH_VM_NEXT_STATE' => 'delete',
          'BOSH_INSTANCE_NEXT_STATE' => 'keep',
          'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
        },
      ),
      *snapshot_disk_sequence(old_vm_agent_id, disk_id),
      *detach_disk_sequence(old_vm_id, old_vm_agent_id, disk_id),
      *delete_vm_sequence(old_vm_id),
      *create_vm_sequence(updated_vm_id, updated_vm_agent_id),
      *attach_disk_sequence(updated_vm_id, updated_vm_agent_id, disk_id),
      *update_settings_sequence(updated_vm_agent_id),
      *list_disk_apply_sequence(updated_vm_agent_id),
      *start_jobs_sequence(updated_vm_agent_id),
    ]
  end

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::DeploymentManifestHelper.deployment_manifest(instances: instances)
    manifest_hash['instance_groups'].first['persistent_disk_type'] = Bosh::Spec::DeploymentManifestHelper::DISK_TYPE['name']
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
    Bosh::Spec::DeploymentManifestHelper.simple_cloud_config.merge(
      'disk_types' => [
        Bosh::Spec::DeploymentManifestHelper::DISK_TYPE,
      ],
    )
  end

  context 'with a single instance' do
    let(:instances) { 1 }

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
      create_disk_invocations = fresh_deploy_invocations.find_all { |i| i.method == 'create_disk' }
      expect(create_disk_invocations.length).to eq(1)
      create_disk_invocations.first.response
    end

    let(:vm_creation_calls) { fresh_deploy_invocations.find_all { |i| i.method == 'create_vm' } }

    let(:compilation_vm1_create_vm) { vm_creation_calls[0] }
    let(:compilation_vm2_create_vm) { vm_creation_calls[1] }
    let(:deployed_vm_create_vm) { vm_creation_calls[2] }

    let(:compilation_vm1_cid) { cid_and_agent(compilation_vm1_create_vm).first }
    let(:compilation_vm1_agent_id) { cid_and_agent(compilation_vm1_create_vm).last }

    let(:compilation_vm2_cid) { cid_and_agent(compilation_vm2_create_vm).first }
    let(:compilation_vm2_agent_id) { cid_and_agent(compilation_vm2_create_vm).last }

    let(:deployed_vm_cid) { cid_and_agent(deployed_vm_create_vm).first }
    let(:deployed_vm_agent_id) { cid_and_agent(deployed_vm_create_vm).last }

    let(:reference) do
      {
        compilation_vm1_cid => 'compilation_vm1_cid',
        compilation_vm1_agent_id => 'compilation_vm1_agent_id',
        compilation_vm2_cid => 'compilation_vm2_cid',
        compilation_vm2_agent_id => 'compilation_vm2_agent_id',
        deployed_vm_cid => 'deployed_vm_cid',
        deployed_vm_agent_id => 'deployed_vm_agent_id',
        disk_id => 'disk_id',
      }
    end

    context 'on a fresh deploy with persistent disk' do
      it 'requests between BOSH Director, CPI and Agent are sent in correct order' do
        compilation_vm1_calls = compilation_vm_sequence(compilation_vm1_cid, compilation_vm1_agent_id)
        compilation_vm2_calls = compilation_vm_sequence(compilation_vm2_cid, compilation_vm2_agent_id)

        invocations = fresh_deploy_invocations.dup
        expect(invocations.shift(compilation_vm1_calls.length)).to be_sequence_of_calls(
          calls: compilation_vm1_calls,
          reference: reference,
        )
        expect(invocations.shift(compilation_vm2_calls.length)).to be_sequence_of_calls(
          calls: compilation_vm2_calls,
          reference: reference,
        )

        expect(invocations).to be_sequence_of_calls(
          calls: [
            *create_vm_sequence(deployed_vm_cid, deployed_vm_agent_id),
            *update_settings_sequence(deployed_vm_agent_id),
            *prepare_sequence(deployed_vm_agent_id),
            *stop_jobs_sequence(
              deployed_vm_agent_id,
              'env' => {
                'BOSH_VM_NEXT_STATE' => 'keep',
                'BOSH_INSTANCE_NEXT_STATE' => 'keep',
                'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
              },
            ),
            *create_disk_sequence(disk_id),
            *attach_disk_sequence(deployed_vm_cid, deployed_vm_agent_id, disk_id),
            *update_settings_sequence(deployed_vm_agent_id),
            *start_jobs_sequence(deployed_vm_agent_id),
          ],
          reference: reference,
        )
      end
    end

    context 'on an update deployment with persistent disk' do
      let(:updated_manifest_hash) do
        updated_manifest_hash = Bosh::Spec::DeploymentManifestHelper.deployment_manifest(instances: 1)
        updated_manifest_hash['instance_groups'].first['persistent_disk_type'] = Bosh::Spec::DeploymentManifestHelper::DISK_TYPE['name']
        updated_manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }
        updated_manifest_hash
      end

      let(:update_invocations) do
        task_output = deploy_simple_manifest(manifest_hash: updated_manifest_hash)
        get_invocations(task_output)
      end

      let(:updated_create_vm_call) do
        create_vm_calls = update_invocations.find_all { |i| i.method == 'create_vm' }
        expect(create_vm_calls.length).to eq(1)
        create_vm_calls.first
      end

      let(:updated_vm_id) { cid_and_agent(updated_create_vm_call).first }
      let(:updated_vm_agent_id) { cid_and_agent(updated_create_vm_call).last }

      before do
        reference.merge!(
          updated_vm_id => 'updated_vm_id',
          updated_vm_agent_id => 'updated_vm_agent_id',
        )
      end

      it 'requests between BOSH Director, CPI and Agent are sent in correct order', no_create_swap_delete: true do
        expect(update_invocations).to be_sequence_of_calls(
          calls: [
            *stop_jobs_sequence(
              old_vm_agent_id,
              'env' => {
                'BOSH_VM_NEXT_STATE' => 'delete',
                'BOSH_INSTANCE_NEXT_STATE' => 'keep',
                'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
              },
            ),
            *snapshot_disk_sequence(old_vm_agent_id, disk_id),
            *detach_disk_sequence(old_vm_id, old_vm_agent_id, disk_id),
            *delete_vm_sequence(old_vm_id),

            *create_vm_sequence(updated_vm_id, updated_vm_agent_id),
            *attach_disk_sequence(updated_vm_id, updated_vm_agent_id, disk_id),
            *update_settings_sequence(updated_vm_agent_id),
            *list_disk_apply_sequence(updated_vm_agent_id),
            *start_jobs_sequence(updated_vm_agent_id),
          ],
          reference: reference,
        )
      end

      context 'when create-swap-delete is enabled', create_swap_delete: true do
        context 'with a simple manifest' do
          context 'when the deploy succeeds' do
            let(:update_invocations) do
              updated_manifest_hash['update'] = manifest_hash['update'].merge('vm_strategy' => 'create-swap-delete')
              updated_manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }

              task_output = deploy_simple_manifest(manifest_hash: updated_manifest_hash)
              get_invocations(task_output)
            end

            it 'requests between BOSH Director, CPI and Agent are sent in correct order' do
              expect(update_invocations).to be_sequence_of_calls(
                calls: [
                  *hotswap_update_sequence(old_vm_id, old_vm_agent_id, updated_vm_id, updated_vm_agent_id, disk_id),
                  *start_jobs_sequence(updated_vm_agent_id),
                ],
                reference: reference,
              )
            end
          end

          context 'when something fails' do
            let(:failing_create_vm_call) do
              create_vm_calls = update_invocations.find_all { |i| i.method == 'create_vm' }
              expect(create_vm_calls.length).to eq(1)
              create_vm_calls.first
            end

            let(:failing_vm_id) { cid_and_agent(failing_create_vm_call).first }
            let(:failing_vm_agent_id) { cid_and_agent(failing_create_vm_call).last }

            let(:final_invocations) do
              manifest_hash['update'] = manifest_hash['update'].merge('vm_strategy' => 'create-swap-delete')
              manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }

              task_output = deploy_simple_manifest(manifest_hash: manifest_hash)
              get_invocations(task_output)
            end

            let(:final_create_vm_call) do
              create_vm_calls = final_invocations.find_all { |i| i.method == 'create_vm' }
              create_vm_calls.first
            end

            let(:final_vm_id) { final_create_vm_call && cid_and_agent(final_create_vm_call).first }
            let(:final_vm_agent_id) { final_create_vm_call && cid_and_agent(final_create_vm_call).last }

            before do
              reference.merge!(
                final_vm_id => 'final_vm_id',
                final_vm_agent_id => 'final_vm_agent_id',
              )
            end

            context 'when the first deploy results in an unresponsive agent' do
              let(:update_invocations) do
                updated_manifest_hash['update'] = manifest_hash['update'].merge('vm_strategy' => 'create-swap-delete')
                updated_manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }

                current_sandbox.cpi.commands.make_create_vm_have_unresponsive_agent
                task_output = deploy_simple_manifest(manifest_hash: updated_manifest_hash, failure_expected: true)
                failing_invocations = get_invocations(task_output)
                current_sandbox.cpi.commands.allow_create_vm_to_have_responsive_agent
                failing_invocations
              end

              it 'updates the correct vms' do
                expect(update_invocations).to be_sequence_of_calls(
                  calls: [
                    *create_vm_sequence(failing_vm_id, failing_vm_agent_id),
                    *delete_vm_sequence(failing_vm_id),
                  ],
                  reference: reference,
                )

                expect(final_invocations).to be_sequence_of_calls(
                  calls: [
                    *hotswap_update_sequence(old_vm_id, old_vm_agent_id, final_vm_id, final_vm_agent_id, disk_id),
                    *start_jobs_sequence(final_vm_agent_id),
                  ],
                  reference: reference,
                )
              end
            end

            context 'when the first deploy fails to detach the disk' do
              let(:update_invocations) do
                updated_manifest_hash['update'] = manifest_hash['update'].merge('vm_strategy' => 'create-swap-delete')
                updated_manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }

                current_sandbox.cpi.commands.make_detach_disk_to_raise_not_implemented
                task_output = deploy_simple_manifest(manifest_hash: updated_manifest_hash, failure_expected: true)
                failing_invocations = get_invocations(task_output)
                current_sandbox.cpi.commands.allow_detach_disk_to_succeed
                failing_invocations
              end

              it 'updates the correct vms' do
                expect(update_invocations).to be_sequence_of_calls(
                  calls: hotswap_detach_disk_sequence(old_vm_id, old_vm_agent_id, failing_vm_id, failing_vm_agent_id, disk_id),
                  reference: reference,
                )

                expect(final_invocations).to be_sequence_of_calls(
                  calls: [
                    *prepare_sequence(old_vm_agent_id),
                    *stop_jobs_sequence(
                      old_vm_agent_id,
                      'env' => {
                        'BOSH_VM_NEXT_STATE' => 'delete',
                        'BOSH_INSTANCE_NEXT_STATE' => 'keep',
                        'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
                      },
                    ),
                    *snapshot_disk_sequence(old_vm_agent_id, disk_id),
                    *detach_disk_sequence(old_vm_id, old_vm_agent_id, disk_id),

                    *attach_disk_sequence(updated_vm_id, updated_vm_agent_id, disk_id),
                    { target: 'agent', method: 'update_settings', agent_id: updated_vm_agent_id },
                    *list_disk_apply_sequence(updated_vm_agent_id),

                    *start_jobs_sequence(updated_vm_agent_id),
                  ],
                  reference: reference,
                )
              end
            end

            context 'when the first deploy fails with a reusable VM', create_swap_delete: true do
              let(:failing_manifest_hash) do
                failing_manifest_hash = Bosh::Common::DeepCopy.copy(manifest_hash)
                failing_manifest_hash['releases'] = [{ 'name' => 'bosh-release', 'version' => '0.1-dev' }]
                failing_manifest_hash['instance_groups']
                  .first['persistent_disk_type'] = Bosh::Spec::DeploymentManifestHelper::DISK_TYPE['name']
                failing_manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }
                failing_manifest_hash['instance_groups'].first['jobs'] = [
                  {
                    'name' => 'job_with_bad_template',
                    'release' => 'bosh-release',
                    'properties' => {
                      'gargamel' => {
                        'color' => 'chartreuse',
                      },
                      'fail_on_job_start' => true,
                      'fail_instance_index' => 0,
                    },
                  },
                ]
                failing_manifest_hash['update'] = manifest_hash['update'].merge('vm_strategy' => 'create-swap-delete')
                failing_manifest_hash['instance_groups'].first['instances'] = 1
                failing_manifest_hash
              end

              let(:update_invocations) do
                task_output = deploy_simple_manifest(manifest_hash: failing_manifest_hash, failure_expected: true)
                failing_invocations = get_invocations(task_output)
                failing_invocations
              end

              it 'makes CPI and agent calls in the correct order in the subsequent deploy to reuse the VM' do
                expect(
                  [
                    *update_invocations,
                    *final_invocations,
                  ],
                ).to be_sequence_of_calls(
                  calls: [
                    # update deploy
                    *hotswap_update_sequence(old_vm_id, old_vm_agent_id, updated_vm_id, updated_vm_agent_id, disk_id),
                    { target: 'agent', method: 'run_script', agent_id: updated_vm_agent_id,
                      argument_matcher: match(['pre-start', {}]) },

                    # final deploy
                    *prepare_sequence(updated_vm_agent_id),
                    *stop_jobs_sequence(
                      updated_vm_agent_id,
                      'env' => {
                        'BOSH_VM_NEXT_STATE' => 'keep',
                        'BOSH_INSTANCE_NEXT_STATE' => 'keep',
                        'BOSH_DEPLOYMENT_NEXT_STATE' => 'keep',
                      },
                    ),
                    *snapshot_disk_sequence(updated_vm_agent_id, disk_id),
                    *update_settings_sequence(updated_vm_agent_id),
                    *start_jobs_sequence(updated_vm_agent_id),
                  ],
                  reference: reference,
                )
              end
            end
          end
        end
      end
    end
  end
end
