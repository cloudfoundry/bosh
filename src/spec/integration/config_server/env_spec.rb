require 'spec_helper'

describe 'env values in instance groups and resource pools', type: :integration do
  let(:manifest_hash) do
    Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell.merge(
      'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
        name: 'our_instance_group',
        jobs: [
          { 'name' => 'job_1_with_many_properties',
            'release' => 'bosh-release',
            'properties' => job_properties },
        ],
        instances: 1,
      )],
    )
  end
  let(:deployment_name) { manifest_hash['name'] }
  let(:director_name) { current_sandbox.director_name }
  let(:cloud_config)  { Bosh::Spec::NewDeployments.simple_cloud_config }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger) }
  let(:client_env) do
    { 'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => current_sandbox.certificate_path.to_s }
  end
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

  context 'when instance groups env is using variables' do
    with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa')

    let(:cloud_config_hash) { Bosh::Spec::NewDeployments.simple_cloud_config }

    let(:env_hash) do
      {
        'env1' => '((env1_placeholder))',
        'env2' => 'env_value2',
        'env3' => {
          'color' => '((color_placeholder))',
        },
        'bosh' => {
          'group' => 'foobar',
        },
      }
    end

    let(:expected_env_hash) do
      {
        'env1' => 'lazy smurf',
        'env2' => 'env_value2',
        'env3' => {
          'color' => 'super_color',
        },
        'bosh' => {
          'mbus' => Hash,
          'dummy_agent_key_merged' => 'This key must be sent to agent', # merged from the director yaml configuration (agent.env.bosh key)
          'group' => 'testdirector-simple-foobar',
          'groups' => ['testdirector', 'simple', 'foobar', 'testdirector-simple', 'simple-foobar', 'testdirector-simple-foobar'],

        },
      }
    end

    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'] = [{
        'name' => 'foobar',
        'jobs' => ['name' => 'job_1_with_many_properties', 'release' => 'bosh-release'],
        'vm_type' => 'a',
        'stemcell' => 'default',
        'instances' => 1,
        'networks' => [{ 'name' => 'a' }],
        'properties' => { 'gargamel' => { 'color' => 'black' } },
        'env' => env_hash,
      }]
      manifest_hash
    end

    before do
      config_server_helper.put_value(prepend_namespace('env1_placeholder'), 'lazy smurf')
      config_server_helper.put_value(prepend_namespace('color_placeholder'), 'super_color')
    end

    it 'should interpolate them correctly' do
      deploy_from_scratch(no_login: true, cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash, include_credentials: false, env: client_env)
      create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(create_vm_invocations.last.inputs['env']).to match(expected_env_hash)
      deployments = table(bosh_runner.run('deployments', json: true, include_credentials: false, env: client_env))
      expect(deployments).to eq [{
        'name' => 'simple',
        'release_s' => 'bosh-release/0+dev.1',
        'stemcell_s' => 'ubuntu-stemcell/1',
        'team_s' => '',
      }]
    end

    it 'should not log interpolated env values in the debug logs and deploy output' do
      deploy_output = deploy_from_scratch(no_login: true, cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash, include_credentials: false, env: client_env)
      expect(deploy_output).to_not include('lazy smurf')
      expect(deploy_output).to_not include('super_color')

      task_id = deploy_output.match(/^Task (\d+)$/)[1]

      debug_output = bosh_runner.run("task --debug --event --cpi --result #{task_id}", no_login: true, include_credentials: false, env: client_env)
      expect(debug_output).to_not include('lazy smurf')
      expect(debug_output).to_not include('super_color')
    end
  end

  context 'when remove_dev_tools key exist' do
    with_reset_sandbox_before_each(
      remove_dev_tools: true,
      config_server_enabled: true,
      user_authentication: 'uaa',
    )

    let(:env_hash) do
      {
        'env1' => '((env1_placeholder))',
        'env2' => 'env_value2',
        'env3' => {
          'color' => '((color_placeholder))',
        },
        'bosh' => {
          'password' => 'foobar',
        },
      }
    end

    let(:simple_manifest) do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'][0]['instances'] = 1
      manifest_hash['instance_groups'][0]['env'] = env_hash
      manifest_hash
    end

    let(:cloud_config) { Bosh::Spec::NewDeployments.simple_cloud_config }

    before do
      config_server_helper.put_value(prepend_namespace('env1_placeholder'), 'lazy smurf')
      config_server_helper.put_value(prepend_namespace('color_placeholder'), 'blue')
    end

    it 'should send the flag to the agent with interpolated values' do
      deploy_from_scratch(no_login: true, manifest_hash: simple_manifest, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

      invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(invocations[2].inputs).to match('agent_id' => String,
                                             'stemcell_id' => String,
                                             'cloud_properties' => {},
                                             'networks' => Hash,
                                             'disk_cids' => Array,
                                             'env' =>
                                                {
                                                  'env1' => 'lazy smurf',
                                                  'env2' => 'env_value2',
                                                  'env3' => {
                                                    'color' => 'blue',
                                                  },
                                                  'bosh' => {
                                                    'mbus' => Hash,
                                                    'dummy_agent_key_merged' => 'This key must be sent to agent', # merged from the director yaml configuration (agent.env.bosh key)
                                                    'password' => 'foobar',
                                                    'remove_dev_tools' => true,
                                                    'group' => 'testdirector-simple-foobar',
                                                    'groups' => ['testdirector', 'simple', 'foobar', 'testdirector-simple', 'simple-foobar', 'testdirector-simple-foobar'],
                                                  },
                                                })
    end

    it 'does not cause a recreate vm on redeploy' do
      deploy_from_scratch(no_login: true, manifest_hash: simple_manifest, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

      invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(invocations.size).to eq(3) # 2 compilation vms and 1 for the one in the instance_group

      deploy_simple_manifest(no_login: true, manifest_hash: simple_manifest, include_credentials: false, env: client_env)

      invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(invocations.size).to eq(3) # no vms should have been deleted/created
    end
  end

  context 'when use_tmpfs_config key exists' do
    with_reset_sandbox_before_each

    let(:simple_manifest) do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['features'] = { 'use_tmpfs_config' => true }
      manifest_hash
    end

    let(:cloud_config) { Bosh::Spec::NewDeployments.simple_cloud_config }

    it 'should send the flag to the agent with interpolated values' do
      deploy_from_scratch(no_login: true, manifest_hash: simple_manifest, cloud_config_hash: cloud_config)

      invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(invocations[2].inputs['env']['bosh']).to include('job_dir' => { 'tmpfs' => true })
      expect(invocations[2].inputs['env']['bosh']).to include('agent' => { 'settings' => { 'tmpfs' => true } })
    end
  end
end
