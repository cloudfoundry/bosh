require 'spec_helper'

# Requests are properly sent in correct order between director, cpi and agent
describe 'CPI and Agent:', type: :integration do
  with_reset_sandbox_before_each(agent_wait_timeout: 3)

  let(:instances) { 1 }
  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: instances)
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
    create_disk_invocations = fresh_deploy_invocations.find_all { |i| i.method == 'create_disk' }
    expect(create_disk_invocations.length).to eq(1)
    create_disk_invocations.first.response
  end

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
      { target: 'agent', method: 'get_state', agent_id: agent_id },
      { target: 'cpi', method: 'set_vm_metadata', vm_cid: vm_cid },
      { target: 'agent', method: 'compile_package', agent_id: agent_id },
      { target: 'cpi', method: 'delete_vm', vm_cid: vm_cid },
    ]
  end

  def prepare_sequence(agent_id)
    [
      { target: 'agent', method: 'get_state', agent_id: agent_id },
      { target: 'agent', method: 'prepare', agent_id: agent_id },
    ]
  end

  def create_vm_with_persistent_disk_calls(vm_cid, agent_id, disk_cid)
    [
      *create_vm_sequence(vm_cid, agent_id),
      *update_settings_sequence(agent_id),
      *prepare_sequence(agent_id),
      *stop_jobs_sequence(agent_id),
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

  def stop_jobs_sequence(agent_id)
    [
      { target: 'agent', method: 'drain', agent_id: agent_id },
      { target: 'agent', method: 'stop', agent_id: agent_id },
      { target: 'agent', method: 'run_script', agent_id: agent_id, argument_matcher: match(['post-stop', {}]) },
    ]
  end

  def start_jobs_sequence(agent_id)
    [
      { target: 'agent', method: 'run_script', agent_id: agent_id, argument_matcher: match(['pre-start', {}]) },
      { target: 'agent', method: 'start', agent_id: agent_id },
      { target: 'agent', method: 'get_state', agent_id: agent_id },
      { target: 'agent', method: 'run_script', agent_id: agent_id, argument_matcher: match(['post-start', {}]) },
    ]
  end

  def detach_disk_sequence(vm_cid, agent_id, disk_id)
    [
      { target: 'cpi', method: 'snapshot_disk', disk_id: disk_id },
      { target: 'agent', method: 'list_disk', agent_id: agent_id },
      { target: 'agent', method: 'unmount_disk', agent_id: agent_id, argument_matcher: match([disk_id]) },
      { target: 'agent', method: 'remove_persistent_disk', agent_id: agent_id, argument_matcher: match([disk_id]) },
      { target: 'cpi', method: 'detach_disk', vm_cid: vm_cid, disk_id: disk_id },
    ]
  end

  def hotswap_update_sequence(old_vm_id, old_vm_agent_id, hotswap_vm_id, hotswap_vm_agent_id, disk_id)
    [
      { target: 'agent', method: 'get_state', agent_id: old_vm_agent_id },
      *create_vm_sequence(hotswap_vm_id, hotswap_vm_agent_id),
      *update_settings_sequence(hotswap_vm_agent_id),
      *prepare_sequence(hotswap_vm_agent_id),
      *stop_jobs_sequence(old_vm_agent_id),
      *detach_disk_sequence(old_vm_id, old_vm_agent_id, disk_id),
      *attach_disk_sequence(hotswap_vm_id, hotswap_vm_agent_id, disk_id),
      { target: 'agent', method: 'list_disk', agent_id: hotswap_vm_agent_id },
      { target: 'agent', method: 'apply', agent_id: hotswap_vm_agent_id },
      *start_jobs_sequence(hotswap_vm_agent_id),
    ]
  end

  context 'on a fresh deploy with persistent disk' do
    it 'requests between BOSH Director, CPI and Agent are sent in correct order' do
      invocations = fresh_deploy_invocations.dup

      vm_creation_calls = invocations.find_all { |i| i.method == 'create_vm' }

      compilation_vm1_cid, compilation_vm1_agent_id = cid_and_agent(vm_creation_calls.shift)
      compilation_vm2_cid, compilation_vm2_agent_id = cid_and_agent(vm_creation_calls.shift)
      deployed_vm_cid,     deployed_vm_agent_id     = cid_and_agent(vm_creation_calls.shift)

      compilation_vm1_calls = compilation_vm_sequence(compilation_vm1_cid, compilation_vm1_agent_id)
      compilation_vm2_calls = compilation_vm_sequence(compilation_vm2_cid, compilation_vm2_agent_id)
      deployed_vm_calls = create_vm_with_persistent_disk_calls(deployed_vm_cid, deployed_vm_agent_id, disk_id)

      expect(invocations.shift(compilation_vm1_calls.length)).to be_sequence_of_calls(*compilation_vm1_calls)
      expect(invocations.shift(compilation_vm2_calls.length)).to be_sequence_of_calls(*compilation_vm2_calls)
      expect(invocations).to be_sequence_of_calls(*deployed_vm_calls)
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

      create_vm_calls = raw_invocations.find_all { |i| i.method == 'create_vm' }
      expect(create_vm_calls.length).to eq(1)
      updated_vm_id, updated_vm_agent_id = cid_and_agent(create_vm_calls.first)

      expect(raw_invocations).to be_sequence_of_calls(
        { target: 'agent', method: 'get_state', agent_id: old_vm_agent_id },
        *stop_jobs_sequence(old_vm_agent_id),
        *detach_disk_sequence(old_vm_id, old_vm_agent_id, disk_id),
        { target: 'cpi', method: 'delete_vm', vm_cid: old_vm_id },
        *create_vm_sequence(updated_vm_id, updated_vm_agent_id),
        *attach_disk_sequence(updated_vm_id, updated_vm_agent_id, disk_id),
        *update_settings_sequence(updated_vm_agent_id),
        { target: 'agent', method: 'get_state', agent_id: updated_vm_agent_id },
        { target: 'agent', method: 'list_disk', agent_id: updated_vm_agent_id },
        { target: 'agent', method: 'apply', agent_id: updated_vm_agent_id },
        *start_jobs_sequence(updated_vm_agent_id),
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
            create_vm_calls = raw_invocations.find_all { |i| i.method == 'create_vm' }
            expect(create_vm_calls.length).to eq(1)
            hotswap_vm_id, hotswap_vm_agent_id = cid_and_agent(create_vm_calls.first)

            expect(raw_invocations).to be_sequence_of_calls(
              *hotswap_update_sequence(old_vm_id, old_vm_agent_id, hotswap_vm_id, hotswap_vm_agent_id, disk_id),
            )
          end
        end

        context 'when the first deploy results in an unresponsive agent' do
          it 'updates the correct vms' do
            current_sandbox.cpi.commands.make_create_vm_have_unresponsive_agent

            failing_task_output = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)
            failing_invocations = get_invocations(failing_task_output)

            create_vm_calls = failing_invocations.find_all { |i| i.method == 'create_vm' }
            expect(create_vm_calls.length).to eq(1)
            failing_vm_id, failing_vm_agent_id = cid_and_agent(create_vm_calls.first)

            expect(failing_invocations).to be_sequence_of_calls(
              { target: 'agent', method: 'get_state', agent_id: old_vm_agent_id },
              *create_vm_sequence(failing_vm_id, failing_vm_agent_id),
              { target: 'cpi', method: 'delete_vm', argument_matcher: include('vm_cid' => failing_vm_id) },
            )

            current_sandbox.cpi.commands.allow_create_vm_to_have_responsive_agent
            task_output = deploy_simple_manifest(manifest_hash: manifest_hash)

            raw_invocations = get_invocations(task_output)
            create_vm_calls = raw_invocations.find_all { |i| i.method == 'create_vm' }
            expect(create_vm_calls.length).to eq(1)
            hotswap_vm_id, hotswap_vm_agent_id = cid_and_agent(create_vm_calls.first)

            expect(raw_invocations).to be_sequence_of_calls(
              *hotswap_update_sequence(old_vm_id, old_vm_agent_id, hotswap_vm_id, hotswap_vm_agent_id, disk_id),
            )
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
          manifest_hash['update'] = manifest_hash['update'].merge('vm_strategy' => 'create-swap-delete')
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

          create_vm_calls = failing_invocations.find_all { |i| i.method == 'create_vm' }
          expect(create_vm_calls.length).to eq(1)

          reusable_failing_vm_id, reusable_failing_vm_agent_id = cid_and_agent(create_vm_calls.first)

          up_to_pre_start = hotswap_update_sequence(
            old_vm_id,
            old_vm_agent_id,
            reusable_failing_vm_id,
            reusable_failing_vm_agent_id,
            disk_id,
          ).take(23)

          expect(failing_invocations).to be_sequence_of_calls(
            *up_to_pre_start,
          )

          task_output = deploy_simple_manifest(manifest_hash: succeeding_manifest_hash)

          raw_invocations = get_invocations(task_output)
          expect(raw_invocations).to be_sequence_of_calls(
            { target: 'agent', method: 'get_state', agent_id: reusable_failing_vm_agent_id },
            { target: 'agent', method: 'prepare', agent_id: reusable_failing_vm_agent_id },
            *stop_jobs_sequence(reusable_failing_vm_agent_id),
            { target: 'cpi', method: 'snapshot_disk', disk_id: disk_id },
            { target: 'agent', method: 'list_disk', agent_id: reusable_failing_vm_agent_id },
            *update_settings_sequence(reusable_failing_vm_agent_id),
            *start_jobs_sequence(reusable_failing_vm_agent_id),
          )
        end
      end
    end
  end
end
