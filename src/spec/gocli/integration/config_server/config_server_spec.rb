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
  let(:deployment_name) { manifest_hash['name'] }
  let(:director_name) { current_sandbox.director_name }
  let(:cloud_config)  { Bosh::Spec::Deployments.simple_cloud_config }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger)}
  let(:client_env) { {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => "#{current_sandbox.certificate_path}"} }
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

    context 'when deployment manifest has variables' do
      context 'when some variables are not set in config server' do

        let(:job_properties) do
          {
              'gargamel' => {
                  'color' => '((i_am_not_here_1))',
                  'age' => '((i_am_not_here_2))',
                  'dob' => '((i_am_not_here_3))',
              }
          }
        end

        it 'raises an error' do
          output, exit_code = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash,
                                                  cloud_config_hash: cloud_config, failure_expected: true,
                                                  return_exit_code: true, include_credentials: false, env: client_env)

          expect(exit_code).to_not eq(0)

          expect(output).to include <<-EOF.strip
Error: Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'our_instance_group'. Errors are:
    - Unable to render templates for job 'job_1_with_many_properties'. Errors are:
      - Failed to find variable '/TestDirector/simple/i_am_not_here_1' from config server: HTTP Code '404', Error: 'Name '/TestDirector/simple/i_am_not_here_1' not found'
      - Failed to find variable '/TestDirector/simple/i_am_not_here_2' from config server: HTTP Code '404', Error: 'Name '/TestDirector/simple/i_am_not_here_2' not found'
      - Failed to find variable '/TestDirector/simple/i_am_not_here_3' from config server: HTTP Code '404', Error: 'Name '/TestDirector/simple/i_am_not_here_3' not found'
          EOF
        end
      end

      context 'when all variables are set in config server' do
        it 'does not log interpolated properties in the task debug logs and deploy output' do
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'he is colorless')

          deploy_output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
          expect(deploy_output).to_not include('he is colorless')

          task_id = deploy_output.match(/^Task (\d+)$/)[1]

          debug_output = bosh_runner.run("task --debug --event --cpi --result #{task_id}", no_login: true, include_credentials: false, env: client_env)
          expect(debug_output).to_not include('he is colorless')
        end

        it 'replaces variables in the manifest when config server has value for placeholders' do
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are happy')

          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

          instance = director.instance('our_instance_group', '0', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)

          template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')
        end

        it 'does not add namespace to keys starting with slash' do
          config_server_helper.put_value('/my_placeholder', 'cats are happy')
          job_properties['gargamel']['color'] = "((/my_placeholder))"

          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
        end

        context 'mid string interpolation' do
          let(:job_properties) do
            {
              'gargamel' => {
                'color' => 'mild brownish ((my_placeholder)) yellowish ((smurf_age_placeholder))'
              }
            }
          end

          it 'replaces the variables in the manifest' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'greenish')
            config_server_helper.put_value(prepend_namespace('smurf_age_placeholder'), 9)
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

            instance = director.instance('our_instance_group', '0', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)
            template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['gargamel_color']).to eq('mild brownish greenish yellowish 9')
          end

          context 'when value returned by config server is not a string or a number' do
            let(:job_properties) do
              {
                'smurfs' => {
                  'color' => 'my color is ((my_placeholder_1))'
                },
                'gargamel' => {
                  'color' => 'smurf ((my_placeholder_2)) yellow ((my_placeholder_3))'
                }
              }
            end

            let(:my_placeholder_value) do
              {
                'cat' => 'meow',
                'dog' => 'woof'
              }
            end

            it 'errors' do
              config_server_helper.put_value(prepend_namespace('my_placeholder_1'), my_placeholder_value)
              config_server_helper.put_value(prepend_namespace('my_placeholder_2'), my_placeholder_value)
              config_server_helper.put_value(prepend_namespace('my_placeholder_3'), my_placeholder_value)

              output, exit_code =  deploy_from_scratch(
                no_login: true,
                manifest_hash: manifest_hash,
                cloud_config_hash: cloud_config,
                failure_expected: true,
                return_exit_code: true,
                include_credentials: false,
                env: client_env
              )

              expect(exit_code).to_not eq(0)
              expect(output).to include <<-EOF.strip
Error: Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'our_instance_group'. Errors are:
    - Unable to render templates for job 'job_1_with_many_properties'. Errors are:
      - Failed to substitute variable: Can not replace '((my_placeholder_1))' in 'my color is ((my_placeholder_1))'. The value should be a String or an Integer.
      - Failed to substitute variable: Can not replace '((my_placeholder_2))' in 'smurf ((my_placeholder_2)) yellow ((my_placeholder_3))'. The value should be a String or an Integer.
      - Failed to substitute variable: Can not replace '((my_placeholder_3))' in 'smurf ((my_placeholder_2)) yellow ((my_placeholder_3))'. The value should be a String or an Integer.
            EOF
            end
          end
        end

        context 'with dot syntax' do
          let(:cloud_config_hash) do
            cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
            cloud_config_hash.delete('resource_pools')
            cloud_config_hash['vm_types'] = [Bosh::Spec::Deployments.vm_type]
            cloud_config_hash
          end

          let(:manifest_hash) do
            manifest_hash = Bosh::Spec::Deployments.simple_manifest
            manifest_hash.delete('resource_pools')
            manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]
            manifest_hash['jobs'] = [{
                                       'name' => 'foobar',
                                       'templates' => ['name' => 'job_1_with_many_properties'],
                                       'vm_type' => 'vm-type-name',
                                       'stemcell' => 'default',
                                       'instances' => 1,
                                       'networks' => [{ 'name' => 'a' }],
                                       'properties' => {},
                                     }]
            manifest_hash
          end

          it 'replaces the variables in the manifest' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), { 'text'=>'cats are angry'})

            manifest_hash['jobs'][0]['properties'] = {'gargamel' => {'color' => '((my_placeholder.text))'}}
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env)

            instance = director.instance('foobar', '0', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)
            template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['gargamel_color']).to eq('cats are angry')
          end

          it 'replaces nested variables in the manifest' do
            config_server_helper.put_value(prepend_namespace('my_placeholder_1'), { 'cat'=> {'color' => {'value' => 'orange'}}})
            config_server_helper.put_value(prepend_namespace('my_placeholder_2'), { 'cat'=> {'color' => {'value' => 'black'}}})
            config_server_helper.put_value(prepend_namespace('my_placeholder_3'), { 'cat'=> {'color' => {'value' => 'white'}}})

            manifest_hash['jobs'][0]['properties'] = {
              'smurfs' => {
                'color' => 'I am a ((my_placeholder_2.cat.color.value)) cat. My kitten is ((my_placeholder_3.cat.color.value))'
              },
              'gargamel' => {
                'color' => '((my_placeholder_1.cat.color.value))'
              }
            }

            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false, env: client_env)

            instance = director.instance('foobar', '0', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)
            template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['smurfs_color']).to eq('I am a black cat. My kitten is white')
            expect(template_hash['properties_list']['gargamel_color']).to eq('orange')
          end

          it 'errors if all parts of nested variable is not found' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), { 'cat'=> {'color' => {'value' => 'orange'}}})

            manifest_hash['jobs'][0]['properties'] = {'gargamel' => {'color' => '((my_placeholder.cat.dog.color.value))'}}

            output, exit_code =  deploy_from_scratch(
              no_login: true,
              manifest_hash: manifest_hash,
              cloud_config_hash: cloud_config_hash,
              failure_expected: true,
              return_exit_code: true,
              include_credentials: false,
              env: client_env
            )

            expect(exit_code).to_not eq(0)
            expect(output).to include("Failed to fetch variable '#{prepend_namespace('my_placeholder')}' from config server: Expected parent '#{prepend_namespace('my_placeholder')}.cat' hash to have key 'dog'")
          end
        end

        context 'when manifest is downloaded through CLI' do
          before do
            job_properties.merge!({'smurfs' => {'color' => '((!smurfs_color_placeholder))'}})
          end

          it 'returns original raw manifest (with no changes)' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'happy smurf')
            config_server_helper.put_value(prepend_namespace('smurfs_color_placeholder'), 'I am blue')

            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

            downloaded_manifest = bosh_runner.run("manifest", deployment_name: manifest_hash['name'], include_credentials: false, env: client_env)

            expect(downloaded_manifest).to include '((my_placeholder))'
            expect(downloaded_manifest).to include '((!smurfs_color_placeholder))'
            expect(downloaded_manifest).to_not include 'happy smurf'
            expect(downloaded_manifest).to_not include 'I am blue'
          end
        end

        context 'when a variable starts with an exclamation mark' do
          let(:job_properties) do
            {
              'gargamel' => {
                'color' => '((!my_placeholder))'
              }
            }
          end

          it 'strips the exclamation mark when getting value from config server' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are very happy')

            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

            instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)

            template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['gargamel_color']).to eq('cats are very happy')
          end
        end

        context 'when health monitor is around and resurrector is enabled' do
          with_reset_hm_before_each

          it 'interpolates values correctly when resurrector kicks in' do
            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are happy')

            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
            instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
            template_hash = YAML.load(instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')

            config_server_helper.put_value(prepend_namespace('my_placeholder'), 'smurfs are happy')

            director.kill_vm_and_wait_for_resurrection(instance, deployment_name: 'simple', include_credentials: false, env: client_env)

            new_instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false, env: client_env)
            template_hash = YAML.load(new_instance.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')
          end
        end

        describe 'env values in instance groups and resource pools' do
          context 'when instance groups env is using variables' do
            let(:cloud_config_hash) do
              cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
              cloud_config_hash.delete('resource_pools')

              cloud_config_hash['vm_types'] = [Bosh::Spec::Deployments.vm_type]
              cloud_config_hash
            end

            let(:env_hash) do
              {
                'env1' => '((env1_placeholder))',
                'env2' => 'env_value2',
                'env3' => {
                  'color' => '((color_placeholder))'
                },
                'bosh' => {
                  'group' => 'foobar'
                },
              }
            end

            let(:resolved_env_hash) do
              {
                'env1' => 'lazy smurf',
                'env2' => 'env_value2',
                'env3' => {
                  'color' => 'super_color'
                },
                'bosh' => {
                  'mbus' => Hash,
                  'group' => 'testdirector-simple-foobar',
                  'groups' =>['testdirector', 'simple', 'foobar', 'testdirector-simple', 'simple-foobar', 'testdirector-simple-foobar']
                },
              }
            end

            let(:manifest_hash) do
              manifest_hash = Bosh::Spec::Deployments.simple_manifest
              manifest_hash.delete('resource_pools')
              manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]
              manifest_hash['jobs'] = [{
                                         'name' => 'foobar',
                                         'templates' => ['name' => 'job_1_with_many_properties'],
                                         'vm_type' => 'vm-type-name',
                                         'stemcell' => 'default',
                                         'instances' => 1,
                                         'networks' => [{ 'name' => 'a' }],
                                         'properties' => {'gargamel' => {'color' => 'black'}},
                                         'env' => env_hash
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
              expect(create_vm_invocations.last.inputs['env']).to match(resolved_env_hash)
              deployments = table(bosh_runner.run('deployments', json: true, include_credentials: false, env: client_env))
              expect(deployments).to eq([{'name' => 'simple', 'release_s' => 'bosh-release/0+dev.1', 'stemcell_s' => 'ubuntu-stemcell/1', 'team_s' => '', 'cloud_config' => 'latest'}])
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

          context 'when resource pool env is using variables (legacy manifest)' do
            let(:env_hash) do
              {
                'env1' => '((env1_placeholder))',
                'env2' => 'env_value2',
                'env3' => {
                  'color' => '((color_placeholder))'
                },
                'bosh' => {
                  'group' => 'foobar',
                  'password' => 'foobar'
                },
              }
            end

            let(:resolved_env_hash) do
              {
                'env1' => 'lazy cat',
                'env2' => 'env_value2',
                'env3' => {
                  'color' => 'smurf blue'
                },
                'bosh' => {
                  'mbus' => Hash,
                  'group' => 'testdirector-simple-foobar',
                  'password' => 'foobar',
                  'groups' =>['testdirector', 'simple', 'foobar', 'testdirector-simple', 'simple-foobar', 'testdirector-simple-foobar']
                },
              }
            end

            it 'should interpolate them correctly' do
              config_server_helper.put_value(prepend_namespace('env1_placeholder'), 'lazy cat')
              config_server_helper.put_value(prepend_namespace('color_placeholder'), 'smurf blue')

              deployment_manifest = Bosh::Spec::Deployments.legacy_manifest
              deployment_manifest['resource_pools'][0]['env'] = env_hash

              deploy_from_scratch(no_login: true, include_credentials: false, env: client_env, manifest_hash: deployment_manifest)

              create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
              expect(create_vm_invocations.last.inputs['env']).to match(resolved_env_hash)

              deployments = table(bosh_runner.run('deployments', json: true, include_credentials: false, env: client_env))
              expect(deployments).to eq([{'name' => 'simple', 'release_s' => 'bosh-release/0+dev.1', 'stemcell_s' => 'ubuntu-stemcell/1',
                                          'team_s' => '', 'cloud_config' => 'none'}])
            end
          end

          context 'when remove_dev_tools key exist' do
            with_reset_sandbox_before_each(
              remove_dev_tools: true,
              config_server_enabled: true,
              user_authentication: 'uaa',
              uaa_encryption: 'asymmetric'
            )

            let(:env_hash) do
              {
                'env1' => '((env1_placeholder))',
                'env2' => 'env_value2',
                'env3' => {
                  'color' => '((color_placeholder))'
                },
                'bosh' => {
                  'password' => 'foobar'
                }
              }
            end

            let(:simple_manifest) do
              manifest_hash = Bosh::Spec::Deployments.simple_manifest
              manifest_hash['jobs'][0]['instances'] = 1
              manifest_hash['jobs'][0]['env'] = env_hash
              manifest_hash
            end

            let(:cloud_config) do
              cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
              cloud_config_hash['resource_pools'][0].delete('env')
              cloud_config_hash
            end

            before do
              config_server_helper.put_value(prepend_namespace('env1_placeholder'), 'lazy smurf')
              config_server_helper.put_value(prepend_namespace('color_placeholder'), 'blue')
            end

            it 'should send the flag to the agent with interpolated values' do
              deploy_from_scratch(no_login: true, manifest_hash: simple_manifest, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

              invocations = current_sandbox.cpi.invocations_for_method('create_vm')
              expect(invocations[2].inputs).to match({'agent_id' => String,
                                                      'stemcell_id' => String,
                                                      'cloud_properties' => {},
                                                      'networks' => Hash,
                                                      'disk_cids' => Array,
                                                      'env' =>
                                                        {
                                                          'env1' => 'lazy smurf',
                                                          'env2' => 'env_value2',
                                                          'env3' => {
                                                            'color' => 'blue'
                                                          },
                                                          'bosh' => {
                                                            'mbus' => Hash,
                                                            'password' => 'foobar',
                                                            'remove_dev_tools' => true,
                                                            'group' => 'testdirector-simple-foobar',
                                                            'groups' =>['testdirector', 'simple', 'foobar', 'testdirector-simple', 'simple-foobar', 'testdirector-simple-foobar']
                                                          }
                                                        }
                                                     })
            end

            it 'does not cause a recreate vm on redeploy' do
              deploy_from_scratch(no_login: true, manifest_hash: simple_manifest, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

              invocations = current_sandbox.cpi.invocations_for_method('create_vm')
              expect(invocations.size).to eq(3) # 2 compilation vms and 1 for the one in the instance_group

              deploy_simple_manifest(no_login: true, manifest_hash: simple_manifest, include_credentials: false,  env: client_env)

              invocations = current_sandbox.cpi.invocations_for_method('create_vm')
              expect(invocations.size).to eq(3) # no vms should have been deleted/created
            end
          end
        end

        context 'when tags are to be passed to a vm' do

          let(:cloud_config_hash) do
            cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
            cloud_config_hash.delete('resource_pools')

            cloud_config_hash['vm_types'] = [Bosh::Spec::Deployments.vm_type]
            cloud_config_hash
          end

          let(:manifest_hash) do
            manifest_hash = Bosh::Spec::Deployments.simple_manifest
            manifest_hash.delete('resource_pools')
            manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]
            manifest_hash['jobs'] = [{
                'name' => 'foobar',
                'templates' => ['name' => 'id_job'],
                'vm_type' => 'vm-type-name',
                'stemcell' => 'default',
                'instances' => 1,
                'networks' => [{ 'name' => 'a' }],
                'properties' => {}
            }, {
               'name' => 'goobar',
               'templates' => ['name' => 'errand_without_package'],
               'vm_type' => 'vm-type-name',
               'stemcell' => 'default',
               'instances' => 1,
               'networks' => [{ 'name' => 'a' }],
               'properties' => {},
               'lifecycle' => 'errand'
            }]
            manifest_hash['tags'] = {
                'tag-key1' => '((/tag-variable1))',
                'tag-key2' => '((tag-variable2))'
            }
            manifest_hash
          end

          before do
            config_server_helper.put_value('/tag-variable1', 'peanuts')
            config_server_helper.put_value(prepend_namespace('tag-variable2'), 'almonds')
          end

          it 'does variable substitution on the initial creation' do
            manifest_hash = Bosh::Spec::Deployments.simple_manifest
            manifest_hash['tags'] = {
              'tag-key1' => '((/tag-variable1))',
              'tag-key2' => '((tag-variable2))'
            }

            cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false,  env: client_env)

            set_vm_metadata_invocations = current_sandbox.cpi.invocations.select {|invocation| invocation.method_name == 'set_vm_metadata' && invocation.inputs['metadata']['compiling'].nil? }
            expect(set_vm_metadata_invocations.count).to eq(5)
            set_vm_metadata_invocations.each { |set_vm_metadata_invocation|
              inputs = set_vm_metadata_invocation.inputs
              unless inputs['metadata']['compiling']
                expect(inputs['metadata']['tag-key1']).to eq('peanuts')
                expect(inputs['metadata']['tag-key2']).to eq('almonds')
              end
            }
          end

          it 'retains the tags with variable substitution on re-deploy' do
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false,  env: client_env)

            pre_redeploy_invocations_size = current_sandbox.cpi.invocations.size

            manifest_hash['jobs'].first['instances'] = 2
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false,  env: client_env)

            invocations = current_sandbox.cpi.invocations.drop(pre_redeploy_invocations_size)
            set_vm_metadata_invocations = invocations.select { |invocation| invocation.method_name == 'set_vm_metadata' }
            expect(set_vm_metadata_invocations.size).to eq(1)

            inputs = set_vm_metadata_invocations.first.inputs
            expect(inputs['metadata']['tag-key2']).to eq('almonds')
            expect(inputs['metadata']['tag-key1']).to eq('peanuts')
          end

          it 'retains the tags with variable substitution on hard stop and start' do
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false,  env: client_env)

            instance = director.instance('foobar', '0', deployment_name: 'simple', include_credentials: false, env: client_env)

            bosh_runner.run("stop --hard #{instance.job_name}/#{instance.id}", deployment_name: 'simple', no_login: true, return_exit_code: true, include_credentials: false, env: client_env)
            pre_start_invocations_size = current_sandbox.cpi.invocations.size

            bosh_runner.run("start #{instance.job_name}/#{instance.id}", deployment_name: 'simple', no_login: true, return_exit_code: true, include_credentials: false, env: client_env)

            invocations = current_sandbox.cpi.invocations.drop(pre_start_invocations_size)
            set_vm_metadata_invocation = invocations.select { |invocation| invocation.method_name == 'set_vm_metadata' }.last
            inputs = set_vm_metadata_invocation.inputs
            expect(inputs['metadata']['tag-key1']).to eq('peanuts')
            expect(inputs['metadata']['tag-key2']).to eq('almonds')
          end

          it 'retains the tags with variable substitution on recreate' do
            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false,  env: client_env)

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
              deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash, include_credentials: false,  env: client_env)

              pre_errand_invocations_size = current_sandbox.cpi.invocations.size

              bosh_runner.run('run-errand goobar', deployment_name: 'simple', no_login: true, include_credentials: false, env: client_env)

              invocations = current_sandbox.cpi.invocations.drop(pre_errand_invocations_size)
              set_vm_metadata_invocation = invocations.select { |invocation| invocation.method_name == 'set_vm_metadata' }.last
              inputs = set_vm_metadata_invocation.inputs
              expect(inputs['metadata']['tag-key1']).to eq('peanuts')
              expect(inputs['metadata']['tag-key2']).to eq('almonds')
            end
          end
        end
      end
    end

    # Q. Why is this context commented?
    # A. variable generation based on release spec has been disabled since default CA was removed from config-server.
    # Ref: Tracker stories #138578557 and #139470935
    xcontext 'when release job spec properties have types' do

      let(:manifest_hash) do
        Bosh::Spec::Deployments.test_release_manifest.merge(
          {
            'jobs' => [Bosh::Spec::Deployments.job_with_many_templates(
              name: 'our_instance_group',
              templates: [
                {'name' => 'job_with_property_types',
                 'properties' => job_properties
                }
              ],
              instances: 3
            )]
          })
      end

      context 'when these properties are defined in deployment manifest as variables' do
        context 'when these properties are NOT defined in the config server' do
          let(:job_properties) do
            {
              'smurfs' => {
                'phone_password' => '((smurfs_phone_password_placeholder))',
                'happiness_level' => 5
              },
              'gargamel' => {
                'secret_recipe' => '((gargamel_secret_recipe_placeholder))',
                'cert' => '((gargamel_certificate_placeholder))'
              }
            }
          end

          context 'when the properties have default values defined' do
            it 'uses the default values defined' do
              job_properties['gargamel']['password'] = '((config_server_has_no_value_for_me))'
              job_properties['gargamel']['hard_coded_cert'] = '((config_server_has_no_value_for_me_either))'

              deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

              instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)

              template_hash = YAML.load(instance.read_job_template('job_with_property_types', 'properties_displayer.yml'))
              expect(template_hash['properties_list']['gargamel_password']).to eq('abc123')

              hardcoded_cert = instance.read_job_template('job_with_property_types', 'hardcoded_cert.pem')
              expect(hardcoded_cert).to eq('good luck hardcoding certs and private keys')
            end

            context 'when it is NOT a full variable' do
              let(:job_properties) do
                {
                  'smurfs' => {
                    'phone_password' => 'anything',
                    'happiness_level' => 5
                  },
                  'gargamel' => {
                    'password' => 'my password is: ((gargamel_password_placeholder))',
                    'cert' => 'anything'
                  }
                }
              end

              it 'does NOT use the default values, and fails' do
                output, exit_code = deploy_from_scratch(
                  no_login: true,
                  manifest_hash: manifest_hash,
                  cloud_config_hash: cloud_config,
                  failure_expected: true,
                  return_exit_code: true,
                  include_credentials: false,
                  env: client_env
                )

                expect(exit_code).to_not eq(0)
                expect(output).to include <<-EOF.strip
Error: Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'our_instance_group'. Errors are:
    - Unable to render templates for job 'job_with_property_types'. Errors are:
      - Failed to find variable '/TestDirector/simple/gargamel_password_placeholder' from config server: HTTP code '404'
                EOF
              end
            end
          end

          context 'when the properties do NOT have default values defined' do
            it 'generates values for these properties' do
              deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

              instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)

              # Passwords generation
              template_hash = YAML.load(instance.read_job_template('job_with_property_types', 'properties_displayer.yml'))
              expect(
                template_hash['properties_list']['smurfs_phone_password']
              ).to eq(config_server_helper.get_value(prepend_namespace('smurfs_phone_password_placeholder')))
              expect(
                template_hash['properties_list']['gargamel_secret_recipe']
              ).to eq(config_server_helper.get_value(prepend_namespace('gargamel_secret_recipe_placeholder')))

              # Certificate generation
              generated_cert = instance.read_job_template('job_with_property_types', 'generated_cert.pem')
              generated_private_key = instance.read_job_template('job_with_property_types', 'generated_key.key')
              root_ca = instance.read_job_template('job_with_property_types', 'root_ca.pem')

              generated_cert_response = config_server_helper.get_value(prepend_namespace('gargamel_certificate_placeholder'))

              expect(generated_cert).to eq(generated_cert_response['certificate'])
              expect(generated_private_key).to eq(generated_cert_response['private_key'])
              expect(root_ca).to eq(generated_cert_response['ca'])

              certificate_object = OpenSSL::X509::Certificate.new(generated_cert)
              expect(certificate_object.subject.to_s).to include('CN=*.our-instance-group.a.simple.bosh')

              subject_alt_name = certificate_object.extensions.find {|e| e.oid == 'subjectAltName'}
              expect(subject_alt_name.to_s.scan(/\*.our-instance-group.a.simple.bosh/).count).to eq(1)
            end

            context 'when variable is NOT a full variable' do
              let(:job_properties) do
                {
                  'smurfs' => {
                    'phone_password' => 'vrooom ((smurfs_phone_password_placeholder))',
                    'happiness_level' => 5
                  },
                  'gargamel' => {
                    'secret_recipe' => 'hello ((gargamel_secret_recipe_placeholder))',
                    'cert' => 'meow ((gargamel_certificate_placeholder))'
                  }
                }
              end

              it 'does not generate values for these properties' do
                output, exit_code = deploy_from_scratch(
                  no_login: true,
                  manifest_hash: manifest_hash,
                  cloud_config_hash: cloud_config,
                  failure_expected: true,
                  return_exit_code: true,
                  include_credentials: false,
                  env: client_env
                )

                expect(exit_code).to_not eq(0)
                expect(output).to include <<-EOF.strip
Error: Unable to render instance groups for deployment. Errors are:
  - Unable to render jobs for instance group 'our_instance_group'. Errors are:
    - Unable to render templates for job 'job_with_property_types'. Errors are:
      - Failed to find variable '/TestDirector/simple/smurfs_phone_password_placeholder' from config server: HTTP code '404'
      - Failed to find variable '/TestDirector/simple/gargamel_secret_recipe_placeholder' from config server: HTTP code '404'
      - Failed to find variable '/TestDirector/simple/gargamel_certificate_placeholder' from config server: HTTP code '404'
                EOF

                expect {
                  config_server_helper.get_value('/TestDirector/simple/smurfs_phone_password_placeholder')
                }.to raise_error { |error|
                  expect(error.message).to include('404 Not Found')
                }

                expect {
                  config_server_helper.get_value('/TestDirector/simple/gargamel_secret_recipe_placeholder')
                }.to raise_error { |error|
                  expect(error.message).to include('404 Not Found')
                }

                expect {
                  config_server_helper.get_value('/TestDirector/simple/gargamel_certificate_placeholder')
                }.to raise_error { |error|
                  expect(error.message).to include('404 Not Found')
                }
              end
            end

            context 'when config server raises an error while generating' do
              let(:job_properties) do
                {
                  'gargamel' => {
                    'secret_recipe' => 'stuff'
                  },
                  'smurfs' => {
                    'phone_password' => 'anything',
                    'happiness_level' => '((happy_level_placeholder))'
                  }
                }
              end

              it 'propagates that error back to the user and fails to deploy' do
                output, exit_code =  deploy_from_scratch(
                  no_login: true,
                  manifest_hash: manifest_hash,
                  cloud_config_hash: cloud_config,
                  failure_expected: true,
                  return_exit_code: true,
                  include_credentials: false,  env: client_env
                )

                expect(exit_code).to_not eq(0)
                expect(output).to include ("Error: Config Server failed to generate value for '/TestDirector/simple/happy_level_placeholder' with type 'happy'.")
              end
            end

            context 'when an instance group has multiple networks' do
              let(:job_properties) do
                {
                  'smurfs' => {
                    'phone_password' => 'vroom',
                    'happiness_level' => 5
                  },
                  'gargamel' => {
                    'secret_recipe' => 'hello',
                    'cert' => '((gargamel_certificate_placeholder))'
                  }
                }
              end

              let(:cloud_config) {
                cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
                cloud_config_hash['resource_pools'].first['size'] = 1
                cloud_config_hash['networks'] = [
                  {
                    'name' => 'a',
                    'subnets' => [
                      {
                        'range' => '192.168.1.0/24',
                        'gateway' => '192.168.1.1',
                        'dns' => ['192.168.1.2'],
                        'static' => '192.168.1.10-192.168.1.15',
                        'reserved' => [],
                        'cloud_properties' => {},
                      }
                    ]
                  },
                  {
                    'name' => 'b',
                    'subnets' => [
                      {
                        'range' => '192.168.2.0/24',
                        'gateway' => '192.168.2.1',
                        'dns' => ['192.168.2.2'],
                        'static' => '192.168.2.10-192.168.2.15',
                        'reserved' => [],
                        'cloud_properties' => {},
                      }
                    ]
                  }
                ]
                cloud_config_hash
              }

              before do
                manifest_hash['jobs'].first['networks'] = [
                  {
                    'name' => 'a',
                    'static_ips' => %w(192.168.1.10 192.168.1.11 192.168.1.12),
                    'default' => %w(dns gateway addressable)},
                  {
                    'name' => 'b',
                    'static_ips' => %w(192.168.2.10 192.168.2.11 192.168.2.12),
                  }
                ]
              end

              it 'generates cert with SAN including all the networks with no duplicates' do
                deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

                generated_cert_response = config_server_helper.get_value(prepend_namespace('gargamel_certificate_placeholder'))

                instances = director.instances(deployment_name: 'simple', include_credentials: false,  env: client_env).select{ |instance|  instance.job_name == 'our_instance_group' }

                instances.each do |instance|
                  generated_cert = instance.read_job_template('job_with_property_types', 'generated_cert.pem')
                  generated_private_key = instance.read_job_template('job_with_property_types', 'generated_key.key')
                  root_ca = instance.read_job_template('job_with_property_types', 'root_ca.pem')

                  expect(generated_cert).to eq(generated_cert_response['certificate'])
                  expect(generated_private_key).to eq(generated_cert_response['private_key'])
                  expect(root_ca).to eq(generated_cert_response['ca'])

                  certificate_object = OpenSSL::X509::Certificate.new(generated_cert)
                  expect(certificate_object.subject.to_s).to include('CN=*.our-instance-group.a.simple.bosh')

                  subject_alt_name = certificate_object.extensions.find {|e| e.oid == 'subjectAltName'}
                  expect(subject_alt_name.to_s.scan(/\*.our-instance-group.a.simple.bosh/).count).to eq(1)
                  expect(subject_alt_name.to_s.scan(/\*.our-instance-group.b.simple.bosh/).count).to eq(1)
                end
              end
            end

            context 'when variables start with exclamation mark' do
              let(:job_properties) do
                {
                  'smurfs' => {
                    'phone_password' => '((!smurfs_phone_password_placeholder))',
                    'happiness_level' => 9
                  },
                  'gargamel' => {
                    'secret_recipe' => '((!gargamel_secret_recipe_placeholder))',
                    'cert' => '((!gargamel_certificate_placeholder))'
                  }
                }
              end

              it 'removes the exclamation mark from variable and generates values for these properties with no issue' do
                deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

                instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)

                template_hash = YAML.load(instance.read_job_template('job_with_property_types', 'properties_displayer.yml'))
                expect(
                  template_hash['properties_list']['smurfs_phone_password']
                ).to eq(config_server_helper.get_value(prepend_namespace('smurfs_phone_password_placeholder')))
                expect(
                  template_hash['properties_list']['gargamel_secret_recipe']
                ).to eq(config_server_helper.get_value(prepend_namespace('gargamel_secret_recipe_placeholder')))

                generated_cert = instance.read_job_template('job_with_property_types', 'generated_cert.pem')
                generated_private_key = instance.read_job_template('job_with_property_types', 'generated_key.key')
                root_ca = instance.read_job_template('job_with_property_types', 'root_ca.pem')

                generated_cert_response = config_server_helper.get_value(prepend_namespace('gargamel_certificate_placeholder'))

                expect(generated_cert).to eq(generated_cert_response['certificate'])
                expect(generated_private_key).to eq(generated_cert_response['private_key'])
                expect(root_ca).to eq(generated_cert_response['ca'])
              end
            end
          end
        end

        context 'when these properties are defined in config server' do
          let(:job_properties) do
            {
              'smurfs' => {
                'phone_password' => '((smurfs_phone_password_placeholder))',
                'happiness_level' => 5
              },
              'gargamel' => {
                'secret_recipe' => '((gargamel_secret_recipe_placeholder))',
                'cert' => '((gargamel_certificate_placeholder))'
              }
            }
          end

          let(:certificate_payload) do
            {
              'certificate' => 'cert123',
              'private_key' => 'adb123',
              'ca' => 'ca456'
            }
          end

          it 'uses the values defined in config server' do
            config_server_helper.put_value(prepend_namespace('smurfs_phone_password_placeholder'), 'i am smurf')
            config_server_helper.put_value(prepend_namespace('gargamel_secret_recipe_placeholder'), 'banana and jaggery')
            config_server_helper.put_value(prepend_namespace('gargamel_certificate_placeholder'), certificate_payload)

            deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

            instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)

            template_hash = YAML.load(instance.read_job_template('job_with_property_types', 'properties_displayer.yml'))
            expect(template_hash['properties_list']['smurfs_phone_password']).to eq('i am smurf')
            expect(template_hash['properties_list']['gargamel_secret_recipe']).to eq('banana and jaggery')

            generated_cert = instance.read_job_template('job_with_property_types', 'generated_cert.pem')
            generated_private_key = instance.read_job_template('job_with_property_types', 'generated_key.key')
            root_ca = instance.read_job_template('job_with_property_types', 'root_ca.pem')

            expect(generated_cert).to eq('cert123')
            expect(generated_private_key).to eq('adb123')
            expect(root_ca).to eq('ca456')
          end
        end
      end

      context 'when these properties are NOT defined in deployment manifest' do
            context 'when these properties have defaults' do
              let(:certificate_payload) do
                {
                  'certificate' => 'cert123',
                  'private_key' => 'adb123',
                  'ca' => 'ca456'
                }
              end

              let(:job_properties) do
                {
                  'gargamel' => {
                    'secret_recipe' => 'stuff',
                    'cert' => certificate_payload
                  },
                  'smurfs' => {
                    'phone_password' => 'anything',
                    'happiness_level' => 5
                  }
                }
              end

              it 'does not ask config server to generate values and uses default values to deploy' do
                deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

                instance = director.instance('our_instance_group', '0', deployment_name: 'simple', include_credentials: false,  env: client_env)
                template_hash = YAML.load(instance.read_job_template('job_with_property_types', 'properties_displayer.yml'))
                expect(template_hash['properties_list']['gargamel_password']).to eq('abc123')

                hard_coded_cert = instance.read_job_template('job_with_property_types', 'hardcoded_cert.pem')
                expect(hard_coded_cert).to eq('good luck hardcoding certs and private keys')
              end
            end

            context 'when these properties DO NOT have defaults' do
              let(:job_properties) do
                # set this property so that it only complains about one missing property
                {
                  'gargamel' => {
                    'secret_recipe' => 'anything',
                  },
                  'smurfs' => {
                    'happiness_level' => 5
                  }
                }
              end

              it 'does not ask config server to generate values and fails to deploy while rendering templates' do
                output, exit_code =  deploy_from_scratch(
                  no_login: true,
                  manifest_hash: manifest_hash,
                  cloud_config_hash: cloud_config,
                  failure_expected: true,
                  return_exit_code: true,
                  include_credentials: false,
                  env: client_env
                )

                expect(exit_code).to_not eq(0)
                expect(output).to include("Error filling in template 'properties_displayer.yml.erb' (line 3: Can't find property '[\"smurfs.phone_password\"]')")
                expect(output).to include("Error filling in template 'generated_cert.pem.erb' (line 1: Can't find property '[\"gargamel.cert.certificate\"]')")
                expect(output).to include("Error filling in template 'generated_key.key.erb' (line 1: Can't find property '[\"gargamel.cert.private_key\"]')")
                expect(output).to include("Error filling in template 'root_ca.pem.erb' (line 1: Can't find property '[\"gargamel.cert.ca\"]')")
              end
            end
      end
    end
  end
end


