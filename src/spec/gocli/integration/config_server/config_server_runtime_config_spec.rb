require_relative '../../spec_helper'

describe 'using director with config server', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

  let(:manifest_hash) do
    Bosh::Spec::Deployments.test_release_manifest.merge(
      {
        'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
          name: 'our_instance_group',
          templates: [
            {'name' => 'job_1_with_many_properties',
             'properties' => job_properties
            }
          ],
          instances: 1
        )]
      })
  end
  let(:client_env) { {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => "#{current_sandbox.certificate_path}"} }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger)}
  let(:deployment_name) { manifest_hash['name'] }
  let(:director_name) { current_sandbox.director_name }
  let(:cloud_config)  { Bosh::Spec::Deployments.simple_cloud_config }
  let(:job_properties) do
    {
      'gargamel' => {
        'color' => '((my_placeholder))'
      }
    }
  end

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, :preserve => true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir, include_credentials: false,  env: client_env)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir, include_credentials: false,  env: client_env)
  end

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  def bosh_run_cck_with_resolution(num_errors, option=1, env={})
    env.each do |key, value|
      ENV[key] = value
    end

    output = ''
    bosh_runner.run_interactively('cck', deployment_name: 'simple', no_login: true, include_credentials: false) do |runner|
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

  context 'when config server certificates are trusted' do
    context 'when runtime manifest has placeholders' do
      context 'when config server does not have all names' do
        let(:runtime_config) { Bosh::Spec::Deployments.runtime_config_with_addon_placeholders }

        it 'will throw a valid error for the runtime config on deploy' do
          upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)

          output, exit_code =  deploy_from_scratch(failure_expected: true, return_exit_code: true, no_login: true, include_credentials: false,  env: client_env)

          expect(exit_code).to_not eq(0)
          expect(output).to include("Failed to find variable '/release_name' from config server: HTTP Code '404', Error: 'Name '/release_name' not found'")
        end

        context 'when property cannot be found at render time' do
          let(:runtime_config) do
            {
              'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
              'addons' => [
                {
                  'name' => 'addon1',
                  'jobs' => [
                    {
                      'name' => 'job_2_with_many_properties',
                      'release' => 'bosh-release',
                      'properties' => {'gargamel' => {'color' => '((/placeholder_used_at_render_time))'}}
                    }
                  ]
                }]
            }
          end

          it 'will throw an error' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'I am here for deployment manifest')

            upload_stemcell(include_credentials: false,  env: client_env)
            create_and_upload_test_release(include_credentials: false,  env: client_env)
            upload_cloud_config(include_credentials: false,  env: client_env)
            upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)

            output, exit_code = deploy_simple_manifest(
              no_login: true,
              manifest_hash: manifest_hash,
              cloud_config_hash: cloud_config,
              failure_expected: true,
              return_exit_code: true,
              include_credentials: false,  env: client_env
            )

            expect(exit_code).to_not eq(0)
            expect(output).to include("Failed to find variable '/placeholder_used_at_render_time' from config server: HTTP Code '404', Error: 'Name '/placeholder_used_at_render_time' not found'")
          end
        end
      end

      context 'when config server has all keys' do
        let(:default_runtime_config) do
          {
            'releases' => [{'name' => 'bosh-release', 'version' => '((/addon_release_version_placeholder))'}],
            'addons' => [
              {
                'name' => 'addon1',
                'jobs' => [
                  {
                    'name' => 'job_2_with_many_properties',
                    'release' => 'bosh-release',
                    'properties' => {'gargamel' => {'color' => '((default_rc_placeholder))'}}
                  }
                ]
              }]
          }
        end

        let(:named_runtime_config) do
          {
            'releases' => [{'name' => 'bosh-release', 'version' => '((/addon_release_version_placeholder))'}],
            'addons' => [
              {
                'name' => 'addon1',
                'jobs' => [
                  {
                    'name' => 'job_3_with_many_properties',
                    'release' => 'bosh-release',
                    'properties' => {'gargamel' => {'color' => '((named_rc_placeholder))'}}
                  }
                ]
              }]
          }
        end

        before do
          create_and_upload_test_release(include_credentials: false,  env: client_env)

          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'i am just here for regular manifest')
          config_server_helper.put_value(prepend_namespace('default_rc_placeholder'), 'smurfs are blue')
          config_server_helper.put_value(prepend_namespace('named_rc_placeholder'), 'gargamel is fushia')
          config_server_helper.put_value('/addon_release_version_placeholder', '0.1-dev')

          expect(upload_runtime_config(runtime_config_hash: default_runtime_config, include_credentials: false,  env: client_env)).to include('Succeeded')
          expect(upload_runtime_config(runtime_config_hash: named_runtime_config, include_credentials: false,  env: client_env, name: 'named-rc-1')).to include('Succeeded')
          manifest_hash['jobs'].first['instances'] = 3
        end

        it 'interpolates variables in the addons and updates jobs on deploy' do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

          instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)
          default_rc_template_hash = YAML.load(instance.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))
          named_rc_template_hash_ = YAML.load(instance.read_job_template('job_3_with_many_properties', 'properties_displayer.yml'))

          expect(default_rc_template_hash['properties_list']['gargamel_color']).to eq('smurfs are blue')
          expect(named_rc_template_hash_['properties_list']['gargamel_color']).to eq('gargamel is fushia')
        end

        context 'when variables are updated in the config server after a deploy' do
          before do
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

            config_server_helper.put_value(prepend_namespace('default_rc_placeholder'), 'smurfs have changed to purple')
            config_server_helper.put_value(prepend_namespace('named_rc_placeholder'), 'gargamel has changed blue')
          end

          it 'replaces variables in the addons and updates jobs on redeploy' do
            redeploy_output = parse_blocks(deploy_simple_manifest(manifest_hash: manifest_hash, deployment_name: 'simple', json: true, include_credentials: false,  env: client_env))
            scrubbed_redeploy_output = scrub_random_ids(redeploy_output)

            concatted_output = scrubbed_redeploy_output.join(' ')
            expect(concatted_output).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
            expect(concatted_output).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)')
            expect(concatted_output).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)')

            instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)
            default_rc_template_hash = YAML.load(instance.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))
            named_rc_template_hash_ = YAML.load(instance.read_job_template('job_3_with_many_properties', 'properties_displayer.yml'))

            expect(default_rc_template_hash['properties_list']['gargamel_color']).to eq('smurfs have changed to purple')
            expect(named_rc_template_hash_['properties_list']['gargamel_color']).to eq('gargamel has changed blue')
          end

          it 'uses original variables versions upon recreate' do
            bosh_runner.run('recreate', deployment_name: 'simple', no_login: true, include_credentials: false, env: client_env)
            instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)
            default_rc_template_hash = YAML.load(instance.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))
            named_rc_template_hash_ = YAML.load(instance.read_job_template('job_3_with_many_properties', 'properties_displayer.yml'))

            expect(default_rc_template_hash['properties_list']['gargamel_color']).to eq('smurfs are blue')
            expect(named_rc_template_hash_['properties_list']['gargamel_color']).to eq('gargamel is fushia')
          end
        end

        context 'when tags are to be passed to a vm' do
          before do
            default_runtime_config['tags']= {
              'tag_mode' => '((/tag-mode))',
              'tag_value' => '((/tag-value))'
            }
            upload_runtime_config(runtime_config_hash: default_runtime_config, include_credentials: false,  env: client_env)
            create_and_upload_test_release(include_credentials: false,  env: client_env)

            config_server_helper.put_value('/tag-mode', 'ha')
            config_server_helper.put_value('/tag-value', 'deprecated')
          end

          it 'does variable substitution on the initial creation' do
            manifest_hash = Bosh::Spec::Deployments.simple_manifest
            manifest_hash['jobs'].first['instances'] = 1
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

            set_vm_metadata_invocations = current_sandbox.cpi.invocations.select {|invocation| invocation.method_name == 'set_vm_metadata' && invocation.inputs['metadata']['compiling'].nil? }
            expect(set_vm_metadata_invocations.count).to eq(3)
            set_vm_metadata_invocations.each {|set_vm_metadata_invocation|
              inputs = set_vm_metadata_invocation.inputs
              unless inputs['metadata']['compiling']
                expect(inputs['metadata']['tag_mode']).to eq('ha')
                expect(inputs['metadata']['tag_value']).to eq('deprecated')
              end
            }
          end

          it 'retains the tags with variable substitution on recreate' do
            skip("#139724667")

            manifest_hash['jobs'].first['instances'] = 1
            current_sandbox.cpi.kill_agents
            current_sandbox.cpi.invocations.drop(current_sandbox.cpi.invocations.size)

            recreate_vm_without_waiting_for_process = 3
            bosh_run_cck_with_resolution(1, recreate_vm_without_waiting_for_process, client_env)

            set_vm_metadata_invocation = current_sandbox.cpi.invocations.select { |invocation| invocation.method_name == 'set_vm_metadata' }.last
            inputs = set_vm_metadata_invocation.inputs
            expect(inputs['metadata']['tag_mode']).to eq('ha')
            expect(inputs['metadata']['tag_value']).to eq('deprecated')
          end
        end
      end

      context 'when variables use dot syntax' do
        let(:runtime_config) do
          {
            'releases' => [{'name' => 'bosh-release', 'version' => '((/placeholder1.version))'}],
            'addons' => [
              {
                'name' => 'addon1',
                'jobs' => [
                  {
                    'name' => 'job_2_with_many_properties',
                    'release' => 'bosh-release',
                    'properties' => {'gargamel' => {'color' => '((placeholder2.deeply.nested.color))'}}
                  }
                ]
              }]
          }
        end

        before do
          create_and_upload_test_release(include_credentials: false,  env: client_env)

          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'i am just here for regular manifest')
          config_server_helper.put_value('/placeholder1', { 'version' => '0.1-dev' })
          config_server_helper.put_value(prepend_namespace('placeholder2'), {'deeply' => {'nested' => {'color' => 'gold'}}})

          expect(upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)).to include('Succeeded')
        end

        it 'replaces variables in the manifest' do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

          instance = director.instance('our_instance_group', '0', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)
          template_hash = YAML.load(instance.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('gold')
        end
      end

      context 'when runtime config has variables section defined' do
        let(:runtime_config) do
          {
            'releases' => [{'name' => 'bosh-release', 'version' => '((/addon_release_version_placeholder))'}],
            'addons' => [
              {
                'name' => 'addon1',
                'jobs' => [
                  {
                    'name' => 'job_2_with_many_properties',
                    'release' => 'bosh-release',
                    'properties' => {
                      'gargamel' => {'color' => '((/bob))'},
                      'certificate' => '((/JoeService))'
                    }
                  }
                ]
              }],
            'variables' => [
              {
                'name' => '/bob',
                'type' => 'password'
              },
              {
                'name' => '/joeCA',
                'type' => 'certificate',
                'options' => {
                  'is_ca' => true,
                  'common_name' => 'Joe CA'
                }
              },
              {
                'name' => '/JoeService',
                'type' => 'certificate',
                'options' => {
                  'ca' => '/joeCA'
                }
              }
            ]
          }
        end

        let(:named_runtime_config) do
          {
            'releases' => [{'name' => 'bosh-release', 'version' => '((/addon_release_version_placeholder))'}],
            'variables' => [
              {
                'name' => '/bob2',
                'type' => 'password'
              },
              {
                'name' => '/joeCA2',
                'type' => 'certificate',
                'options' => {
                  'is_ca' => true,
                  'common_name' => 'Joe CA'
                }
              },
              {
                'name' => '/JoeService2',
                'type' => 'certificate',
                'options' => {
                  'ca' => '/joeCA2'
                }
              }
            ]
          }
        end

        let(:unnamed_runtime_config_expected_variables) do
          [
            {'id' => String, 'name' => '/JoeService'},
            {'id' => String, 'name' => '/addon_release_version_placeholder'},
            {'id' => String, 'name' => '/TestDirector/simple/my_placeholder'},
            {'id' => String, 'name' => '/bob'},
            {'id' => String, 'name' => '/joeCA'}
          ]
        end

        let(:named_runtime_config_expected_variables) do
          [
            {'id' => String, 'name' => '/JoeService2'},
            {'id' => String, 'name' => '/joeCA2'},
            {'id' => String, 'name' => '/bob2'}
          ]
        end

        before do
          config_server_helper.put_value('/addon_release_version_placeholder', '0.1-dev')
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'value')
        end

        it 'generates and saves variables' do
          expect(upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)).to include('Succeeded')

          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

          expect(config_server_helper.get_value('/bob')).to_not be_empty
          expect(config_server_helper.get_value('/joeCA')['certificate']).to include('-----BEGIN CERTIFICATE-----')
          expect(config_server_helper.get_value('/JoeService')['certificate']).to include('-----BEGIN CERTIFICATE-----')

          variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))
          expect(variables).to match_array(unnamed_runtime_config_expected_variables)
        end

        context 'with multiple runtime configs with variables' do
          it 'saves all variables' do
            expect(upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)).to include('Succeeded')
            expect(upload_runtime_config(runtime_config_hash: named_runtime_config, include_credentials: false,  env: client_env, name: 'named_runtime_config')).to include('Succeeded')

            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

            expect(config_server_helper.get_value('/bob')).to_not be_empty
            expect(config_server_helper.get_value('/joeCA')['certificate']).to include('-----BEGIN CERTIFICATE-----')
            expect(config_server_helper.get_value('/JoeService')['certificate']).to include('-----BEGIN CERTIFICATE-----')
            expect(config_server_helper.get_value('/bob2')).to_not be_empty
            expect(config_server_helper.get_value('/joeCA2')['certificate']).to include('-----BEGIN CERTIFICATE-----')
            expect(config_server_helper.get_value('/JoeService2')['certificate']).to include('-----BEGIN CERTIFICATE-----')

            variables = table(bosh_runner.run('variables', json: true, include_credentials: false, deployment_name: deployment_name, env: client_env))
            expect(variables).to match_array(unnamed_runtime_config_expected_variables + named_runtime_config_expected_variables)
          end
        end
      end
    end
  end
end
