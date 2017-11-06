require_relative '../spec_helper'

describe 'cli: variables', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

  let(:deployment_name) { manifest_hash['name'] }
  let(:director_name) { current_sandbox.director_name }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger)}
  let(:manifest_hash) do
    Bosh::Spec::NewDeployments.manifest_with_release.merge(
      {
        'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
          name: '((ig_placeholder))',
          jobs: [
            {'name' => 'job_with_property_types',
             'properties' => job_properties
            }
          ],
          instances: 1
        )]
      })
  end
  let(:cloud_config)  { Bosh::Spec::NewDeployments.simple_cloud_config }
  let(:client_env) { {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => "#{current_sandbox.certificate_path}"} }
  let(:job_properties) do
    {
      'gargamel' => {
        'secret_recipe' => 'poutine',
      },
      'smurfs' => {
        'happiness_level' => '((happiness_level))',
        'phone_password' => '((/phone_password))'
      }
    }
  end

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  def assert_count_variable_id_and_name(count_variable_ids, count_variable_names)
    variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))

    variable_ids = variables.map { |obj|
      obj['id']
    }
    expect(variable_ids.uniq.length).to eq(count_variable_ids)

    variable_names = variables.map { |obj|
      obj['name']
    }
    expect(variable_names.uniq.length).to eq(count_variable_names)
    variable_names
  end

  it 'should return list of variables' do
    config_server_helper.put_value(prepend_namespace('ig_placeholder'), 'my_group')
    config_server_helper.put_value(prepend_namespace('happiness_level'), '10')

    deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

    variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))

    variable_ids = variables.map { |obj|
      obj['id']
    }
    expect(variable_ids.uniq.length).to eq(3)

    variable_names = variables.map { |obj|
      obj['name']
    }
    expect(variable_names.uniq.length).to eq(3)

    expect(variable_names).to include("/#{director_name}/#{deployment_name}/ig_placeholder")
    expect(variable_names).to include("/#{director_name}/#{deployment_name}/happiness_level")
    expect(variable_names).to include("/phone_password")
  end

  it 'should return list of variables for the runtime_config' do
    runtime_config = Bosh::Spec::Deployments.runtime_config_with_job_placeholders
    upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)

    config_server_helper.put_value('/release_name', 'bosh-release')
    config_server_helper.put_value('/gargamel_colour', 'cement-grey')

    config_server_helper.put_value(prepend_namespace('ig_placeholder'), 'my_group')
    config_server_helper.put_value(prepend_namespace('happiness_level'), '10')

    deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

    variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))

    variable_ids = variables.map { |obj|
      obj['id']
    }
    expect(variable_ids.uniq.length).to eq(5)

    variable_names = variables.map { |obj|
      obj['name']
    }
    expect(variable_names.uniq.length).to eq(5)

    expect(variable_names).to include("/release_name")
    expect(variable_names).to include("/gargamel_colour")
  end

  context 'when dealing with multiple deploys' do
    let(:manifest_hash) do
      Bosh::Spec::NewDeployments.manifest_with_release.merge(
        {
          'releases'=>[{'name'=>'bosh-release', 'version'=>'0.1-dev'}],
          'instance_groups' => [
            Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
              name: 'ig1',
              jobs: [
                {
                  'name' => 'job_with_bad_template',
                  'properties' => {
                    'gargamel' => {
                      'color' => "((random_property))"
                    }
                  }
                }
              ],
              instances: 1
            ),
            Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
              name: 'ig2',
              jobs: [
                {
                  'name' => 'job_with_bad_template',
                  'properties' => {
                    'gargamel' => {
                      'color' => "((other_property))",
                    },
                  }
                },
              ],
              instances: 2
            )
          ]
        })
    end

    context 'when you have ignored VMs' do
      it 'should not fetch new values for the variable on that VM' do
        config_server_helper.put_value(prepend_namespace('random_property'), 'random_prop_now')
        config_server_helper.put_value(prepend_namespace('other_property'), 'other_prop_now')

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

        instance = director.instance('ig1', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)
        assert_count_variable_id_and_name(2, 2)

        bosh_runner.run("ignore #{instance.job_name}/#{instance.id}", deployment_name: 'simple', no_login: true, return_exit_code: true, include_credentials: false, env: client_env)

        config_server_helper.put_value(prepend_namespace('random_property'), 'random_prop2')
        config_server_helper.put_value(prepend_namespace('other_property'), 'other_prop2')

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

        assert_count_variable_id_and_name(3, 2)
      end
    end

    context 'when you have hard stopped VMs' do
      it 'should fetch new values for the variable on that VM' do
        config_server_helper.put_value(prepend_namespace('random_property'), 'random_prop_now')
        config_server_helper.put_value(prepend_namespace('other_property'), 'other_prop_now')

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

        instance = director.instance('ig1', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        assert_count_variable_id_and_name(2, 2)

        bosh_runner.run("stop --hard #{instance.job_name}/#{instance.id}", deployment_name: 'simple', no_login: true, return_exit_code: true, include_credentials: false, env: client_env)

        config_server_helper.put_value(prepend_namespace('random_property'), 'random_prop2')
        config_server_helper.put_value(prepend_namespace('other_property'), 'other_prop2')

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

        variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))
        variable_ids = variables.map { |obj| obj['id'] }
        expect(variable_ids.uniq.length).to eq(2)
        expect(variable_ids[0]).to eq("3")
        expect(variable_ids[1]).to eq("2")

        expect(variables.map{ |obj| obj['name'] }.uniq.length).to eq(2)
      end
    end
  end

  context 'when you have unused variable sets' do
    it 'should only have the versions of the variables used by the deployment' do
      config_server_helper.put_value(prepend_namespace('ig_placeholder'), 'my_group')
      config_server_helper.put_value(prepend_namespace('happiness_level'), '10')
      config_server_helper.put_value('/phone_password', '11')

      deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

      job_properties['gargamel']['secret_recipe'] = 'Nainamo Bars'
      config_server_helper.put_value(prepend_namespace('ig_placeholder'), 'my_2nd_group')
      config_server_helper.put_value(prepend_namespace('happiness_level'), '11')
      config_server_helper.put_value('/phone_password', '12')

      variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))
      expect(variables.size).to eq(3)

      deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
      variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))

      variable_ids = variables.map{ |obj| obj['ID'] }
      expect(variable_ids.size).to eq(3)
    end

    context 'when you have failed deploys' do
      let(:manifest_hash) do
        Bosh::Spec::NewDeployments.manifest_with_release.merge(
          {
            'releases'=>[{'name'=>'bosh-release', 'version'=>'0.1-dev'}],
            'instance_groups' => [
              Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                name: 'ig1',
                jobs: [
                  {
                    'name' => 'job_with_bad_template',
                    'properties' => {
                      'gargamel' => {
                        'color' => "((random_property))"
                      },
                      'fail_on_job_start' => false,
                      'fail_instance_index' => -1,
                    }
                  }
                ],
                instances: 1
              ),
              Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                name: 'ig2',
                jobs: [
                  {
                    'name' => 'job_with_bad_template',
                    'properties' => {
                      'gargamel' => {
                        'color' => "((other_property))",
                      },
                      'fail_on_job_start' => false,
                      'fail_instance_index' => -1,
                    }
                  },
                ],
                instances: 2
              )
            ]
          })
      end

      before do
        config_server_helper.put_value(prepend_namespace('random_property'), 'one two')
        config_server_helper.put_value(prepend_namespace('other_property'), 'buckle my shoe')

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env, failure_expected: true)

        props = manifest_hash['instance_groups'][1]['jobs'][0]['properties']
        props['fail_on_job_start'] = true
        props['fail_instance_index'] = 1
        config_server_helper.put_value(prepend_namespace('random_property'), 'three four')
        config_server_helper.put_value(prepend_namespace('other_property'), 'shut the door')

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env, failure_expected: true)

        props = manifest_hash['instance_groups'][1]['jobs'][0]['properties']
        props['fail_on_job_start'] = true
        props['fail_instance_index'] = 0

        config_server_helper.put_value(prepend_namespace('random_property'), 'five six')
        config_server_helper.put_value(prepend_namespace('other_property'), 'pick up the sticks')

        deploy_from_scratch(no_login: true, failure_expected: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)
      end

      it 'should keep all variables for deployed or partly deployed revisions' do
        variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))
        expect(variables.size).to eq(6)

        ig1_vm1 = director.instance('ig1', '0', deployment: manifest_hash['name'], include_credentials: false,  env: client_env, no_login: true)
        ig1_vm1_template = ig1_vm1.read_job_template('job_with_bad_template', 'config/config.yml')
        expect(ig1_vm1_template).to include("five six")

        ig2_vm1 = director.instance('ig2', '0', deployment: manifest_hash['name'], include_credentials: false,  env: client_env, no_login: true)
        ig2_vm1_template = ig2_vm1.read_job_template('job_with_bad_template', 'config/config.yml')
        expect(ig2_vm1_template).to include("pick up the sticks")

        ig2_vm2 = director.instance('ig2', '1', deployment: manifest_hash['name'], include_credentials: false,  env: client_env, no_login: true)
        ig2_vm2_template = ig2_vm2.read_job_template('job_with_bad_template', 'config/config.yml')
        expect(ig2_vm2_template).to include("shut the door")
      end

      it 'should clean up unused variables after the next successful deploy' do
        props = manifest_hash['instance_groups'][1]['jobs'][0]['properties']
        props['fail_on_job_start'] = false
        props['fail_instance_index'] = -1

        config_server_helper.put_value(prepend_namespace('random_property'), 'seven eight')
        config_server_helper.put_value(prepend_namespace('other_property'), 'lay them straight')

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

        variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))
        expect(variables.size).to eq(2)

        ig1_vm1 = director.instance('ig1', '0', deployment: manifest_hash['name'], include_credentials: false,  env: client_env, no_login: true)
        ig1_vm1_template = ig1_vm1.read_job_template('job_with_bad_template', 'config/config.yml')
        expect(ig1_vm1_template).to include("seven eight")

        ig2_vm1 = director.instance('ig2', '0', deployment: manifest_hash['name'], include_credentials: false,  env: client_env, no_login: true)
        ig2_vm1_template = ig2_vm1.read_job_template('job_with_bad_template', 'config/config.yml')
        expect(ig2_vm1_template).to include("lay them straight")

        ig2_vm2 = director.instance('ig2', '1', deployment: manifest_hash['name'], include_credentials: false,  env: client_env, no_login: true)
        ig2_vm2_template = ig2_vm2.read_job_template('job_with_bad_template', 'config/config.yml')
        expect(ig2_vm2_template).to include("lay them straight")
      end
    end
  end
end
