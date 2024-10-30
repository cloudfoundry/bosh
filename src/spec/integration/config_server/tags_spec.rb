require 'spec_helper'

describe 'tags', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa')

  let(:manifest_hash) do
    manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'] = [{
      'name' => 'foobar',
      'jobs' => ['name' => 'id_job', 'release' => 'bosh-release'],
      'vm_type' => 'a',
      'stemcell' => 'default',
      'instances' => 1,
      'networks' => [{ 'name' => 'a' }],
    }, {
      'name' => 'goobar',
      'jobs' => ['name' => 'errand_without_package', 'release' => 'bosh-release'],
      'vm_type' => 'a',
      'stemcell' => 'default',
      'instances' => 1,
      'networks' => [{ 'name' => 'a' }],
      'lifecycle' => 'errand',
    }]
    manifest_hash['tags'] = {
      'tag-key1' => '((/tag-variable1))',
      'tag-key2' => '((tag-variable2))',
    }
    manifest_hash
  end
  let(:deployment_name) { manifest_hash['name'] }
  let(:director_name) { current_sandbox.director_name }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger) }
  let(:client_env) do
    { 'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => current_sandbox.certificate_path.to_s }
  end
  let(:cloud_config_hash) { SharedSupport::DeploymentManifestHelper.simple_cloud_config }
  let(:job_properties) do
    {
      'gargamel' => {
        'color' => '((my_placeholder))',
      },
    }
  end

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  def bosh_run_cck_with_resolution(num_errors, option = 1, env = {})
    output = ''
    bosh_runner.run_interactively('cck', deployment_name: 'simple', client: env['BOSH_CLIENT'], client_secret: env['BOSH_CLIENT_SECRET']) do |runner|
      (1..num_errors).each do
        expect(runner).to have_output 'Skip for now'

        runner.send_keys option.to_s
      end

      expect(runner).to have_output 'Continue?'
      runner.send_keys 'y'

      expect(runner).to have_output 'Succeeded'
      output = runner.output
    end
    output
  end

  before do
    config_server_helper.put_value('/tag-variable1', 'peanuts')
    config_server_helper.put_value(prepend_namespace('tag-variable2'), 'almonds')
  end

  it 'does variable substitution on the initial creation' do
    manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest_hash['tags'] = {
      'tag-key1' => '((/tag-variable1))',
      'tag-key2' => '((tag-variable2))',
    }

    cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env)

    set_vm_metadata_invocations = current_sandbox.cpi.invocations.select { |invocation| invocation.method_name == 'set_vm_metadata' && invocation.inputs['metadata']['compiling'].nil? }
    expect(set_vm_metadata_invocations.count).to eq(5)
    set_vm_metadata_invocations.each do |set_vm_metadata_invocation|
      inputs = set_vm_metadata_invocation.inputs
      unless inputs['metadata']['compiling']
        expect(inputs['metadata']['tag-key1']).to eq('peanuts')
        expect(inputs['metadata']['tag-key2']).to eq('almonds')
      end
    end
  end

  it 'retains the tags with variable substitution on re-deploy' do
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env)

    pre_redeploy_invocations_size = current_sandbox.cpi.invocations.size

    manifest_hash['instance_groups'].first['instances'] = 2
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env)

    invocations = current_sandbox.cpi.invocations.drop(pre_redeploy_invocations_size)
    set_vm_metadata_invocations = invocations.select { |invocation| invocation.method_name == 'set_vm_metadata' }
    expect(set_vm_metadata_invocations.size).to eq(1)

    inputs = set_vm_metadata_invocations.first.inputs
    expect(inputs['metadata']['tag-key2']).to eq('almonds')
    expect(inputs['metadata']['tag-key1']).to eq('peanuts')
  end

  it 'retains the tags with variable substitution on hard stop and start' do
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env)

    instance = director.instance('foobar', '0', deployment_name: 'simple', include_credentials: false, env: client_env)

    bosh_runner.run("stop --hard #{instance.instance_group_name}/#{instance.id}", deployment_name: 'simple', return_exit_code: true, include_credentials: false, env: client_env)
    pre_start_invocations_size = current_sandbox.cpi.invocations.size

    bosh_runner.run("start #{instance.instance_group_name}/#{instance.id}", deployment_name: 'simple', return_exit_code: true, include_credentials: false, env: client_env)

    invocations = current_sandbox.cpi.invocations.drop(pre_start_invocations_size)
    set_vm_metadata_invocation = invocations.select { |invocation| invocation.method_name == 'set_vm_metadata' }.last
    inputs = set_vm_metadata_invocation.inputs
    expect(inputs['metadata']['tag-key1']).to eq('peanuts')
    expect(inputs['metadata']['tag-key2']).to eq('almonds')
  end

  it 'retains the tags with variable substitution on recreate' do
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env)

    current_sandbox.cpi.kill_agents
    pre_kill_invocations_size = current_sandbox.cpi.invocations.size

    recreate_vm_without_waiting_for_process = 3
    bosh_run_cck_with_resolution(1, recreate_vm_without_waiting_for_process, client_env)

    invocations = current_sandbox.cpi.invocations.drop(pre_kill_invocations_size)
    set_vm_metadata_invocation = invocations.select { |invocation| invocation.method_name == 'set_vm_metadata' }.last
    inputs = set_vm_metadata_invocation.inputs
    expect(inputs['metadata']['tag-key1']).to eq('peanuts')
    expect(inputs['metadata']['tag-key2']).to eq('almonds')
  end

  context 'and we are running an errand' do
    it 'applies the tags to the errand while it is running' do
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env)

      pre_errand_invocations_size = current_sandbox.cpi.invocations.size

      bosh_runner.run('run-errand goobar', deployment_name: 'simple', include_credentials: false, env: client_env)

      invocations = current_sandbox.cpi.invocations.drop(pre_errand_invocations_size)
      set_vm_metadata_invocation = invocations.select { |invocation| invocation.method_name == 'set_vm_metadata' }.last
      inputs = set_vm_metadata_invocation.inputs
      expect(inputs['metadata']['tag-key1']).to eq('peanuts')
      expect(inputs['metadata']['tag-key2']).to eq('almonds')
    end
  end
end
