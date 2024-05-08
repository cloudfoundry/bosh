require_relative '../../spec_helper'

describe 'sequenced deploys scenarios when using config server', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', enable_nats_delivered_templates: true)

  let(:manifest_hash) do
    Bosh::Spec::Deployments.test_release_manifest_with_stemcell.merge(
      'instance_groups' => [Bosh::Spec::Deployments.instance_group_with_many_jobs(
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
  let(:cloud_config) do
    Bosh::Spec::Deployments.simple_cloud_config.tap do |config|
      config['vm_types'] = [
        { 'name' => 'a' },
        { 'name' => 'b', 'cloud_properties' => { 'foo' => 'bar' } },
      ]
    end
  end
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

  describe 'given a successful deployment that used config server values' do
    before do
      config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are happy')

      manifest_hash['instance_groups'].first['instances'] = 1
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

      instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
      template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
      expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')
    end

    context 'when config server values changes post deployment' do
      before do
        config_server_helper.put_value(prepend_namespace('my_placeholder'), 'dogs are happy')
      end

      it 'updates necessary jobs, picking up new config server values, on bosh redeploy' do
        output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
        expect(output).to match(/Updating instance our_instance_group: our_instance_group\/[0-9a-f]{8}-[0-9a-f-]{27} \(0\)/)

        new_instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        new_template_hash = YAML.load(new_instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        expect(new_template_hash['properties_list']['gargamel_color']).to eq('dogs are happy')
      end

      it "does NOT update jobs (does NOT pick up new config server values) on 'bosh start' after 'bosh stop'" do
        bosh_runner.run('stop', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)
        output = parse_blocks(bosh_runner.run('start', deployment_name: 'simple', json: true, include_credentials: false, env: client_env))
        expect(scrub_random_ids(output)).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

        instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')
      end

      it "does NOT update jobs (does NOT pick up new config server values) on 'bosh start' after 'bosh stop --hard'" do
        bosh_runner.run('stop --hard', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)
        output = parse_blocks(bosh_runner.run('start', deployment_name: 'simple', json: true, include_credentials: false, env: client_env))

        scrubbed_output = scrub_random_ids(output)
        expect(scrubbed_output).to include('Creating missing vms: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
        expect(scrubbed_output).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

        instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')
      end

      it "does NOT update jobs (does NOT pick up new config server values) on 'bosh restart'" do
        output = parse_blocks(bosh_runner.run('restart', json: true, deployment_name: 'simple', include_credentials: false, env: client_env))
        expect(scrub_random_ids(output)).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

        instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')
      end

      it "does NOT update jobs (does NOT pick up new config server values) on 'bosh recreate'" do
        output = parse_blocks(bosh_runner.run('recreate', deployment_name: 'simple', json: true, include_credentials: false, env: client_env))
        expect(scrub_random_ids(output)).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

        instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')
      end

      it "does not update jobs (does NOT pick up new config server values) on 'stop' then 'start' then 'restart' then 'recreate'" do
        bosh_runner.run('stop', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)
        instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')

        config_server_helper.put_value(prepend_namespace('my_placeholder'), 'rabbits are happy')

        bosh_runner.run('restart', json: true, deployment_name: 'simple', include_credentials: false, env: client_env)
        instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')

        config_server_helper.put_value(prepend_namespace('my_placeholder'), 'birds are happy')

        bosh_runner.run('recreate', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)
        instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')
      end

      it "DOES update jobs on 'stop' then 'deploy' then 'start'" do
        bosh_runner.run('stop', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)

        manifest_hash['instance_groups'].first['vm_type'] = 'b'
        deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
        instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')

        output = parse_blocks(bosh_runner.run('start', deployment_name: 'simple', json: true, include_credentials: false, env: client_env))
        expect(scrub_random_ids(output)).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

        instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        expect(template_hash['properties_list']['gargamel_color']).to eq('dogs are happy')
      end
    end
  end

  describe 'given a successful deployment that used config server values' do
    let(:job_properties) do
      {
        'gargamel' => {
          'color' => '((my_placeholder))',
        },
        'fail_instance_index' => 1,
        'fail_on_job_start' => false,
        'fail_on_template_rendering' => false,
      }
    end
    let(:manifest_hash) do
      Bosh::Spec::Deployments.test_release_manifest_with_stemcell.merge(
        'instance_groups' => [Bosh::Spec::Deployments.instance_group_with_many_jobs(
          name: 'our_instance_group',
          jobs: [
            {
              'name' => 'job_with_bad_template',
              'release' => 'bosh-release',
              'properties' => job_properties,
            },
          ],
          instances: 3,
        )],
      )
    end
    before do
      manifest_hash['update']['canaries'] = 1
      config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are happy')
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
      config_server_helper.put_value(prepend_namespace('my_placeholder'), 'dogs are more happy')
    end

    context 'failure on template rendering' do
      before do
        job_properties['fail_on_template_rendering'] = true
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env, failure_expected: true)
      end

      it 'should use previous variables set for non failing instance' do
        bosh_runner.run('recreate our_instance_group/0', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)

        instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
        template_hash = YAML.load(instance.read_job_template('job_with_bad_template', 'config/config.yml'))
        expect(template_hash['gargamel_color']).to eq('cats are happy')
      end

      it 'should use previous variables set for failing instance' do
        bosh_runner.run('recreate our_instance_group/1', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)

        instance = director.instance('our_instance_group', '1', deployment_name: 'simple', include_credentials: false, env: client_env)
        template_hash = YAML.load(instance.read_job_template('job_with_bad_template', 'config/config.yml'))
        expect(template_hash['gargamel_color']).to eq('cats are happy')
      end
    end

    context 'failure on job start' do
      before do
        job_properties['fail_on_job_start'] = true
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env, failure_expected: true)
      end

      it 'should use the last successfully deployed variable set on recreate' do
        bosh_runner.run('recreate our_instance_group',
                        deployment_name: 'simple',
                        json: true,
                        include_credentials: false,
                        env: client_env)

        successfully_updated_instance = director.instance('our_instance_group', '0',
                                                          deployment_name: 'simple',
                                                          include_credentials: false,
                                                          env: client_env)
        template_hash = YAML.load(successfully_updated_instance.read_job_template('job_with_bad_template', 'config/config.yml'))
        expect(template_hash['gargamel_color']).to eq('cats are happy')

        failed_instance = director.instance('our_instance_group', '1',
                                            deployment_name: 'simple',
                                            include_credentials: false,
                                            env: client_env)
        template_hash = YAML.load(failed_instance.read_job_template('job_with_bad_template', 'config/config.yml'))
        expect(template_hash['gargamel_color']).to eq('cats are happy')

        untouched_instance = director.instance('our_instance_group', '2',
                                               deployment_name: 'simple',
                                               include_credentials: false,
                                               env: client_env)
        template_hash = YAML.load(untouched_instance.read_job_template('job_with_bad_template', 'config/config.yml'))
        expect(template_hash['gargamel_color']).to eq('cats are happy')
      end

      it 'should use the last successfully deployed variable set on restart' do
        bosh_runner.run(
          'restart our_instance_group',
          deployment_name: 'simple',
          json: true,
          include_credentials: false,
          env: client_env,
        )

        successfully_updated_instance = director.instance('our_instance_group', '0',
                                                          deployment_name: 'simple',
                                                          include_credentials: false,
                                                          env: client_env)
        template_hash = YAML.load(successfully_updated_instance.read_job_template('job_with_bad_template', 'config/config.yml'))
        expect(template_hash['gargamel_color']).to eq('cats are happy')

        failed_instance = director.instance('our_instance_group', '1',
                                            deployment_name: 'simple',
                                            include_credentials: false,
                                            env: client_env)
        template_hash = YAML.load(failed_instance.read_job_template('job_with_bad_template', 'config/config.yml'))
        expect(template_hash['gargamel_color']).to eq('cats are happy')

        untouched_instance = director.instance('our_instance_group', '2',
                                               deployment_name: 'simple',
                                               include_credentials: false,
                                               env: client_env)
        template_hash = YAML.load(untouched_instance.read_job_template('job_with_bad_template', 'config/config.yml'))
        expect(template_hash['gargamel_color']).to eq('cats are happy')
      end
    end
  end

  describe 'given a successful deployment that used config server values' do
    let(:manifest_hash) do
      Bosh::Spec::Deployments.manifest_with_release.merge(
        'instance_groups' => [Bosh::Spec::Deployments.instance_group_with_many_jobs(
          name: 'our_instance_group',
          jobs: [
            {
              'name' => 'job_with_bad_template',
              'release' => 'bosh-release',
              'properties' => job_properties,
            },
          ],
          instances: 3,
        )],
        'variables' => variables,
      )
    end

    let(:job_properties) do
      {
        'gargamel' => {
          'color' => '((my_placeholder))',
        },
        'fail_instance_index' => 1,
        'fail_on_job_start' => false,
        'fail_on_template_rendering' => false,
      }
    end

    let(:variables) do
      [
        {
          'name' => 'var_a',
          'type' => 'password',
        },
      ]
    end

    before do
      config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are happy')
      deploy_from_scratch(
        manifest_hash: manifest_hash,
        cloud_config_hash: cloud_config,
        include_credentials: false,
        env: client_env,
      )
      config_server_helper.put_value(prepend_namespace('my_placeholder'), 'dogs are more happy')
    end

    context 'when a variable name changes in the next deploy' do
      before do
        manifest_hash['instance_groups'][0]['jobs'][0]['properties']['gargamel']['color'] = '((new_var_name))'
        manifest_hash['variables'][0]['name'] = 'new_var_name'

        config_server_helper.put_value(prepend_namespace('new_var_name'), 'dogs and cats are happy')
      end

      it 'should roll back to the last successfully deployed variable set if the deploy fails' do
        job_properties['fail_on_job_start'] = true

        output, exit_code = deploy_from_scratch(
          manifest_hash: manifest_hash,
          cloud_config_hash: cloud_config,
          include_credentials: false,
          env: client_env,
          failure_expected: true,
          return_exit_code: true,
        )
        expect(exit_code).to_not eq(0)
        expect(output).to include('pre-start scripts failed')

        expect do
          bosh_runner.run(
            'recreate our_instance_group/1',
            deployment_name: 'simple',
            json: true,
            include_credentials: false,
            env: client_env,
          )
        end.to_not raise_error

        successfully_updated_instance = director.instance('our_instance_group', '0',
                                                          deployment_name: 'simple',
                                                          include_credentials: false,
                                                          env: client_env)
        template_hash = YAML.load(successfully_updated_instance.read_job_template('job_with_bad_template', 'config/config.yml'))
        expect(template_hash['gargamel_color']).to eq('cats are happy')

        failed_instance = director.instance('our_instance_group', '1',
                                            deployment_name: 'simple',
                                            include_credentials: false,
                                            env: client_env)
        template_hash = YAML.load(failed_instance.read_job_template('job_with_bad_template', 'config/config.yml'))
        expect(template_hash['gargamel_color']).to eq('cats are happy')

        untouched_instance = director.instance('our_instance_group', '2',
                                               deployment_name: 'simple',
                                               include_credentials: false,
                                               env: client_env)
        template_hash = YAML.load(untouched_instance.read_job_template('job_with_bad_template', 'config/config.yml'))
        expect(template_hash['gargamel_color']).to eq('cats are happy')
      end

      it 'correctly uses the latest variable set if the deploy succeeds' do
        _, exit_code = deploy_from_scratch(
          manifest_hash: manifest_hash,
          cloud_config_hash: cloud_config,
          include_credentials: false,
          env: client_env,
          return_exit_code: true,
        )
        expect(exit_code).to eq(0)

        (0..2).each do |index|
          instance = director.instance('our_instance_group', index.to_s,
                                       deployment_name: 'simple',
                                       include_credentials: false,
                                       env: client_env)
          template_hash = YAML.load(instance.read_job_template('job_with_bad_template', 'config/config.yml'))
          expect(template_hash['gargamel_color']).to eq('dogs and cats are happy')
        end
      end
    end
  end
end
