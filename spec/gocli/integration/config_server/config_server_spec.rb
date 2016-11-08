require_relative '../../spec_helper'

describe 'using director with config server', type: :integration do
  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, :preserve => true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir, include_credentials: false,  env: client_env)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir, include_credentials: false,  env: client_env)
  end

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
      },
      'smurfs' => {
        'happiness_level' => 10
      }
    }
  end

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  context 'when config server certificates are not trusted' do
    with_reset_sandbox_before_each(config_server_enabled: true, with_config_server_trusted_certs: false, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

    it 'throws certificate validator error' do
      output, exit_code = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash,
                                              cloud_config_hash: cloud_config, failure_expected: true,
                                              return_exit_code: true, include_credentials: false, env: client_env)

      expect(exit_code).to_not eq(0)
      expect(output).to include('Config Server SSL error')
    end
  end

  context 'when config server certificates are trusted' do
    with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

    context 'when deployment manifest has placeholders' do
      it 'raises an error when config server does not have values for placeholders' do
        output, exit_code = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash,
                                                cloud_config_hash: cloud_config, failure_expected: true,
                                                return_exit_code: true, include_credentials: false, env: client_env)

        expect(exit_code).to_not eq(0)
        expect(output).to include("Failed to load placeholder names from the config server: #{prepend_namespace('my_placeholder')}")
      end

      it 'does not log interpolated properties in the task debug logs and deploy output' do
        skip("#130127863")
        config_server_helper.put_value(prepend_namespace('my_placeholder'), 'he is colorless')

        deploy_output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
        expect(deploy_output).to_not include('he is colorless')

        debug_output = bosh_runner.run('task last --debug', no_login: true, include_credentials: false, env: client_env)
        expect(debug_output).to_not include('he is colorless')
      end

      it 'replaces placeholders in the manifest when config server has value for placeholders' do
        config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are happy')

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

        vm = director.vm('our_instance_group', '0', json: true, include_credentials: false, env: client_env)

        template_hash = YAML.load(vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
        expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')
      end

      it 'does not add namespace to keys starting with slash' do
        config_server_helper.put_value('/my_placeholder', 'cats are happy')
        job_properties['gargamel']['color'] = "((/my_placeholder))"

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
      end

      context 'when manifest is downloaded through CLI' do
        before do
          job_properties['smurfs']['color'] = '((!smurfs_color_placeholder))'
        end

        it 'returns original raw manifest (with no changes) when downloaded through cli' do
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'happy smurf')

          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

          downloaded_manifest = bosh_runner.run("manifest", deployment_name: manifest_hash['name'], include_credentials: false, env: client_env)

          expect(downloaded_manifest).to include '((my_placeholder))'
          expect(downloaded_manifest).to include '((!smurfs_color_placeholder))'
          expect(downloaded_manifest).to_not include 'happy smurf'
        end
      end

      context 'when a placeholder starts with an exclamation mark' do
        let(:job_properties) do
          {
            'gargamel' => {
              'color' => '((!my_placeholder))'
            },
            'smurfs' => {
              'happiness_level' => 10
            }
          }
        end

        it 'strips the exclamation mark when getting value from config server' do
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are very happy')

          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

          vm = director.vm('our_instance_group', '0', include_credentials: false, env: client_env)

          template_hash = YAML.load(vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('cats are very happy')
        end
      end

      context 'when health monitor is around and resurrector is enabled' do
        before { current_sandbox.health_monitor_process.start }
        after { current_sandbox.health_monitor_process.stop }

        it 'interpolates values correctly when resurrector kicks in' do
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are happy')

          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)
          vm = director.vm('our_instance_group', '0', include_credentials: false, env: client_env)
          template_hash = YAML.load(vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')

          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'smurfs are happy')

          vm.kill_agent
          director.wait_for_vm('our_instance_group', '0', 300, include_credentials: false, env: client_env)

          new_vm = director.vm('our_instance_group', '0', include_credentials: false, env: client_env)
          template_hash = YAML.load(new_vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('smurfs are happy')
        end
      end

      context 'when config server values changes post deployment' do
        it 'updates the job on bosh redeploy' do
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are happy')

          manifest_hash['jobs'].first['instances'] = 1
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

          vm = director.vm('our_instance_group', '0', include_credentials: false, env: client_env)
          template_hash = YAML.load(vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')

          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'dogs are happy')

          output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

          expect(output).to match /Updating instance our_instance_group: our_instance_group\/[0-9a-f]{8}-[0-9a-f-]{27} \(0\)/

          new_vm = director.vm('our_instance_group', '0', include_credentials: false, env: client_env)
          new_template_hash = YAML.load(new_vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          expect(new_template_hash['properties_list']['gargamel_color']).to eq('dogs are happy')
        end

        it 'updates the job on start/restart/recreate' do
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'cats are happy')

          manifest_hash['jobs'].first['instances'] = 1
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false, env: client_env)

          vm = director.vm('our_instance_group', '0', include_credentials: false, env: client_env)
          template_hash = YAML.load(vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('cats are happy')

          # ============================================
          # Restart
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'dogs are happy')
          output = parse_blocks(bosh_runner.run('restart', json: true, deployment_name: 'simple', include_credentials: false, env: client_env))
          puts output
          expect(scrub_random_ids(output)).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

          vm = director.vm('our_instance_group', '0', include_credentials: false, env: client_env)
          template_hash = YAML.load(vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('dogs are happy')

          # ============================================
          # Recreate
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'smurfs are happy')
          output = parse_blocks(bosh_runner.run('recreate', deployment_name: 'simple', json: true, include_credentials: false, env: client_env))
          expect(scrub_random_ids(output)).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

          vm = director.vm('our_instance_group', '0', include_credentials: false, env: client_env)
          template_hash = YAML.load(vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('smurfs are happy')

          # ============================================
          # start
          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'kittens are happy')
          bosh_runner.run('stop', deployment_name: 'simple', json: true, include_credentials: false, env: client_env)
          output = parse_blocks(bosh_runner.run('start', deployment_name: 'simple', json: true, include_credentials: false, env: client_env))
          expect(scrub_random_ids(output)).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')

          vm = director.vm('our_instance_group', '0', include_credentials: false, env: client_env)
          template_hash = YAML.load(vm.read_job_template('job_1_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('kittens are happy')
        end
      end

      describe 'env values in instance groups and resource pools' do
        context 'when instance groups env is using placeholders' do
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
            expect(create_vm_invocations.last.inputs['env']).to eq(resolved_env_hash)
            deployments = table(bosh_runner.run('deployments', json: true, include_credentials: false, env: client_env))
            expect(deployments).to eq([{'Name' => 'simple', 'Release(s)' => 'bosh-release/0+dev.1', 'Stemcell(s)' => 'ubuntu-stemcell/1', 'Cloud Config' => 'latest'}])
          end

          it 'should not log interpolated env values in the debug logs and deploy output' do
            skip("#130127863")
            debug_output = bosh_runner.run('task last --debug', no_login: true, include_credentials: false, env: client_env)

            expect(deploy_output).to_not include('lazy smurf')
            expect(deploy_output).to_not include('super_color')

            expect(debug_output).to_not include('lazy smurf')
            expect(debug_output).to_not include('super_color')
          end
        end

        context 'when resource pool env is using placeholders (legacy manifest)' do
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
            expect(create_vm_invocations.last.inputs['env']).to eq(resolved_env_hash)

            deployments = table(bosh_runner.run('deployments', json: true, include_credentials: false, env: client_env))
            expect(deployments).to eq([{'Name' => 'simple', 'Release(s)' => 'bosh-release/0+dev.1', 'Stemcell(s)' => 'ubuntu-stemcell/1', 'Cloud Config' => 'none'}])
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
    end

    context 'when runtime manifest has placeholders' do
      context 'when config server does not have all keys' do
        let(:runtime_config) { Bosh::Spec::Deployments.runtime_config_with_addon_placeholders }

        it 'will throw a valid error when uploading runtime config' do
          output, exit_code = upload_runtime_config(runtime_config_hash: runtime_config, failure_expected: true, return_exit_code: true, include_credentials: false,  env: client_env)
          expect(exit_code).to_not eq(0)
          expect(output).to include('Failed to load placeholder names from the config server: /release_name')
        end

        # please do not delete me: add test to cover generation of passwords and certs in runtime manifest

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
            expect(output).to include('Failed to load placeholder names from the config server: /placeholder_used_at_render_time')
          end
        end
      end

      context 'when config server has all keys' do
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
                    'properties' => {'gargamel' => {'color' => '((addon_placeholder))'}}
                  }
                ]
              }]
          }
        end

        before do
          create_and_upload_test_release(include_credentials: false,  env: client_env)

          config_server_helper.put_value(prepend_namespace('my_placeholder'), 'i am just here for regular manifest')
          config_server_helper.put_value(prepend_namespace('addon_placeholder'), 'addon prop first value')
          config_server_helper.put_value('/addon_release_version_placeholder', '0.1-dev')

          expect(upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)).to include('Succeeded')
          manifest_hash['jobs'].first['instances'] = 3
        end

        it 'replaces placeholders in the addons and updates jobs on redeploy when config server values change' do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

          vm = director.vm('our_instance_group', '0', include_credentials: false,  env: client_env)
          template_hash = YAML.load(vm.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('addon prop first value')

          config_server_helper.put_value(prepend_namespace('addon_placeholder'), 'addon prop second value')

          # redeploy_output = parse_blocks(bosh_runner.run('deploy', manifest_hash: manifest_hash, deployment_name: 'simple', json: true, include_credentials: false,  env: client_env))
          redeploy_output = parse_blocks(deploy_simple_manifest(manifest_hash: manifest_hash, deployment_name: 'simple', json: true, include_credentials: false,  env: client_env))
          scrubbed_redeploy_output = scrub_random_ids(redeploy_output)

          concatted_output = scrubbed_redeploy_output.join(' ')
          expect(concatted_output).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
          expect(concatted_output).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)')
          expect(concatted_output).to include('Updating instance our_instance_group: our_instance_group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)')

          vm = director.vm('our_instance_group', '0', include_credentials: false,  env: client_env)
          template_hash = YAML.load(vm.read_job_template('job_2_with_many_properties', 'properties_displayer.yml'))
          expect(template_hash['properties_list']['gargamel_color']).to eq('addon prop second value')
        end

        it 'throws errors when placeholders do not start with slash' do
          runtime_config['releases'][0]['version'] = '((addon_release_version_placeholder))'

          expect {
            upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)
          }.to raise_error(RuntimeError, /Names must be absolute path: addon_release_version_placeholder/)
        end
      end
    end

    context 'when running an errand that has placeholders' do
      let(:errand_manifest){ Bosh::Spec::Deployments.manifest_errand_with_placeholders }
      let(:namespaced_key) { "/#{director_name}/#{errand_manifest["name"]}/placeholder" }

      it 'replaces placeholder in properties' do
        config_server_helper.put_value(namespaced_key, 'test value')

        deploy_from_scratch(no_login: true, manifest_hash: errand_manifest,
                            cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)
        errand_result = bosh_runner.run('run-errand fake-errand-name --keep-alive', deployment_name: 'errand', include_credentials: false,  env: client_env)

        expect(errand_result).to include('test value')
      end
    end

    context 'when release job spec properties have types' do
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

      context 'when types are generatable' do
        context 'when type is password or certificate' do
          context 'when these properties are defined in deployment manifest as placeholders' do
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

                before do
                  job_properties['gargamel']['password'] = '((config_server_has_no_value_for_me))'
                  job_properties['gargamel']['hard_coded_cert'] = '((config_server_has_no_value_for_me_either))'
                end

                it 'uses the default values defined' do
                  deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

                  vm = director.vm('our_instance_group', '0', include_credentials: false,  env: client_env)

                  template_hash = YAML.load(vm.read_job_template('job_with_property_types', 'properties_displayer.yml'))
                  expect(template_hash['properties_list']['gargamel_password']).to eq('abc123')

                  hardcoded_cert = vm.read_job_template('job_with_property_types', 'hardcoded_cert.pem')
                  expect(hardcoded_cert).to eq('good luck hardcoding certs and private keys')
                end
              end

              context 'when the properties do NOT have default values defined' do
                it 'generates values for these properties' do
                  deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

                  vm = director.vm('our_instance_group', '0', include_credentials: false,  env: client_env)

                  # Passwords generation
                  template_hash = YAML.load(vm.read_job_template('job_with_property_types', 'properties_displayer.yml'))
                  expect(
                    template_hash['properties_list']['smurfs_phone_password']
                  ).to eq(config_server_helper.get_value(prepend_namespace('smurfs_phone_password_placeholder')))
                  expect(
                    template_hash['properties_list']['gargamel_secret_recipe']
                  ).to eq(config_server_helper.get_value(prepend_namespace('gargamel_secret_recipe_placeholder')))

                  # Certificate generation
                  generated_cert = vm.read_job_template('job_with_property_types', 'generated_cert.pem')
                  generated_private_key = vm.read_job_template('job_with_property_types', 'generated_key.key')
                  root_ca = vm.read_job_template('job_with_property_types', 'root_ca.pem')

                  generated_cert_response = config_server_helper.get_value(prepend_namespace('gargamel_certificate_placeholder'))

                  expect(generated_cert).to eq(generated_cert_response['certificate'])
                  expect(generated_private_key).to eq(generated_cert_response['private_key'])
                  expect(root_ca).to eq(generated_cert_response['ca'])

                  certificate_object = OpenSSL::X509::Certificate.new(generated_cert)
                  expect(certificate_object.subject.to_s).to include('CN=*.our-instance-group.a.simple.bosh')

                  subject_alt_name = certificate_object.extensions.find {|e| e.oid == 'subjectAltName'}
                  expect(subject_alt_name.to_s.scan(/\*.our-instance-group.a.simple.bosh/).count).to eq(1)
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

                    vms = director.vms(include_credentials: false,  env: client_env).select{ |vm|  vm.job_name == 'our_instance_group' }

                    vms.each do |vm|
                      generated_cert = vm.read_job_template('job_with_property_types', 'generated_cert.pem')
                      generated_private_key = vm.read_job_template('job_with_property_types', 'generated_key.key')
                      root_ca = vm.read_job_template('job_with_property_types', 'root_ca.pem')

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

                context 'when placeholders start with exclamation mark' do
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

                  it 'removes the exclamation mark from placeholder and generates values for these properties with no issue' do
                    deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)

                    vm = director.vm('our_instance_group', '0', include_credentials: false,  env: client_env)

                    template_hash = YAML.load(vm.read_job_template('job_with_property_types', 'properties_displayer.yml'))
                    expect(
                      template_hash['properties_list']['smurfs_phone_password']
                    ).to eq(config_server_helper.get_value(prepend_namespace('smurfs_phone_password_placeholder')))
                    expect(
                      template_hash['properties_list']['gargamel_secret_recipe']
                    ).to eq(config_server_helper.get_value(prepend_namespace('gargamel_secret_recipe_placeholder')))

                    generated_cert = vm.read_job_template('job_with_property_types', 'generated_cert.pem')
                    generated_private_key = vm.read_job_template('job_with_property_types', 'generated_key.key')
                    root_ca = vm.read_job_template('job_with_property_types', 'root_ca.pem')

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

                vm = director.vm('our_instance_group', '0', include_credentials: false,  env: client_env)

                template_hash = YAML.load(vm.read_job_template('job_with_property_types', 'properties_displayer.yml'))
                expect(template_hash['properties_list']['smurfs_phone_password']).to eq('i am smurf')
                expect(template_hash['properties_list']['gargamel_secret_recipe']).to eq('banana and jaggery')

                generated_cert = vm.read_job_template('job_with_property_types', 'generated_cert.pem')
                generated_private_key = vm.read_job_template('job_with_property_types', 'generated_key.key')
                root_ca = vm.read_job_template('job_with_property_types', 'root_ca.pem')

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

                vm = director.vm('our_instance_group', '0', include_credentials: false,  env: client_env)
                template_hash = YAML.load(vm.read_job_template('job_with_property_types', 'properties_displayer.yml'))
                expect(template_hash['properties_list']['gargamel_password']).to eq('abc123')

                hard_coded_cert = vm.read_job_template('job_with_property_types', 'hardcoded_cert.pem')
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

      context 'when types are NOT generatable' do
        context 'when these properties are defined in deployment manifest' do

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

          context 'when these properties are NOT defined in the config server' do
            context 'when the properties do NOT have default values defined' do
              it 'fails to deploy when not finding property in config server' do
                output, exit_code =  deploy_from_scratch(
                  no_login: true,
                  manifest_hash: manifest_hash,
                  cloud_config_hash: cloud_config,
                  failure_expected: true,
                  return_exit_code: true,
                  include_credentials: false,  env: client_env
                )

                expect(exit_code).to_not eq(0)
                expect(output).to include <<-EOF
Error: Unable to render instance groups for deployment. Errors are:
   - Failed to load placeholder names from the config server: /TestDirector/simple/happy_level_placeholder
                EOF
              end
            end
          end
        end
      end
    end

    context 'when links exist' do

      let(:cloud_config) do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
        cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13']
        cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
        cloud_config_hash['compilation']['az'] = 'z1'
        cloud_config_hash['networks'] << {
            'name' => 'dynamic-network',
            'type' => 'dynamic',
            'subnets' => [{'az' => 'z1'}]
        }

        cloud_config_hash
      end
      let(:provider_job_name) { 'http_server_with_provides' }
      let(:my_instance_group) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'my_instance_group',
            templates: [
                {'name' => provider_job_name},
                {'name' => 'http_proxy_with_requires'},
            ],
            instances: 1
        )
        job_spec['azs'] = ['z1']
        job_spec['properties'] = {'listen_port' => 9035, 'name_space' => {'fibonacci' => '((fibonacci_placeholder))'}}
        job_spec
      end
      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [my_instance_group]
        manifest['properties'] = {'listen_port' => 9999}
        manifest
      end

      before do
        upload_links_release
        upload_stemcell(include_credentials: false,  env: client_env)

        upload_cloud_config(cloud_config_hash: cloud_config, include_credentials: false,  env: client_env)
      end

      it 'replaces the placeholder values of properties consumed through links' do
        config_server_helper.put_value(prepend_namespace('fibonacci_placeholder'), 'fibonacci_value')
        deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)

        link_vm = director.vm('my_instance_group', '0', include_credentials: false,  env: client_env)
        template = YAML.load(link_vm.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value')
      end

      it 'does not log interpolated properties in deploy output and debug logs' do
        skip("#130127863")

        config_server_helper.put_value(prepend_namespace('fibonacci_placeholder'), 'fibonacci_value')
        deploy_output = deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)
        debug_output = bosh_runner.run('task last --debug', no_login: true, include_credentials: false,  env: client_env)

        expect(deploy_output).to_not include('fibonacci_value')
        expect(debug_output).to_not include('fibonacci_value')
      end

      context 'when provider job has properties with type password and values are generated' do
        let(:provider_job_name) { 'http_endpoint_provider_with_property_types' }

        it 'replaces the placeholder values of properties consumed through links' do
          deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)

          link_vm = director.vm('my_instance_group', '0', include_credentials: false,  env: client_env)
          template = YAML.load(link_vm.read_job_template('http_proxy_with_requires', 'config/config.yml'))
          expect(template['links']['properties']['fibonacci']).to eq(config_server_helper.get_value(prepend_namespace('fibonacci_placeholder')))
        end
      end

      context 'when manual links are involved' do
        let (:job_with_manual_consumes_link) do
          job_spec = Bosh::Spec::Deployments.simple_job(
              name: 'property_job',
              templates: [{
                              'name' => 'consumer',
                              'consumes' => {
                                  'provider' => {
                                      'properties' => {'a' => '((a_placeholder))', 'b' => '((b_placeholder))', 'c' => '((c_placeholder))'},
                                      'instances' => [{'name' => 'external_db', 'address' => '192.168.15.4'}],
                                      'networks' => {'network_1' => 2, 'network_2' => 3}
                                  }
                              }
                          }],
              instances: 1,
              static_ips: ['192.168.1.10'],
              properties: {}
          )
          job_spec['azs'] = ['z1']
          job_spec['networks'] << {
              'name' => 'dynamic-network',
              'default' => ['dns', 'gateway']
          }
          job_spec
        end

        let(:deployment_name) {manifest['name']}

        before do
          config_server_helper.put_value(prepend_namespace('a_placeholder'), 'a_value')
          config_server_helper.put_value(prepend_namespace('b_placeholder'), 'b_value')
          config_server_helper.put_value(prepend_namespace('c_placeholder'), 'c_value')

          manifest['jobs'] = [job_with_manual_consumes_link]
        end

        it 'resolves the properties defined inside the links section of the deployment manifest' do
          deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)

          link_vm = director.vm('property_job', '0', include_credentials: false,  env: client_env)

          template = YAML.load(link_vm.read_job_template('consumer', 'config.yml'))

          expect(template['a']).to eq('a_value')
          expect(template['b']).to eq('b_value')
          expect(template['c']).to eq('c_value')
        end

        it 'does not log interpolated properties in deploy output and debug logs' do
          skip("#130127863")

          deploy_output = deploy_simple_manifest(manifest_hash: manifest, include_credentials: false,  env: client_env)
          debug_output = bosh_runner.run('task last --debug', no_login: true, include_credentials: false,  env: client_env)

          expect(deploy_output).to_not include('a_value')
          expect(deploy_output).to_not include('b_value')
          expect(deploy_output).to_not include('c_value')

          expect(debug_output).to_not include('a_value')
          expect(debug_output).to_not include('b_value')
          expect(debug_output).to_not include('c_value')
        end
      end

      context 'when having cross deployment links' do
        let(:first_manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['name'] = 'first'
          manifest['jobs'] = [first_deployment_job_spec]
          manifest
        end

        let(:first_deployment_job_spec) do
          job_spec = Bosh::Spec::Deployments.simple_job(
              name: 'first_deployment_node',
              templates: [
                  {
                      'name' => provider_job_name,
                      'properties' => {
                          'listen_port' => 15672,
                          'name_space' => {
                              'fibonacci' => '((fibonacci_placeholder))'
                          }
                      },
                      'provides' => {
                          'http_endpoint' => {
                              'as' => 'vroom',
                              'shared' => true
                          }
                      }
                  }
              ],
              instances: 1,
              static_ips: ['192.168.1.10'],
          )
          job_spec['azs'] = ['z1']
          job_spec
        end

        let(:second_manifest) do
          manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
          manifest['name'] = 'second'
          manifest['jobs'] = [second_deployment_job_spec]
          manifest
        end

        let(:second_deployment_job_spec) do
          job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'second_deployment_node',
            templates: [
              {
                'name' => 'http_proxy_with_requires',
                'release' => 'bosh-release',
                'consumes' => {
                  'proxied_http_endpoint' => {
                    'from' => 'vroom',
                    'deployment' => 'first'
                  }
                }
              }
            ],
            instances: 1,
            static_ips: ['192.168.1.11']
          )
          job_spec['azs'] = ['z1']
          job_spec
        end

        let(:deployment_name) {first_manifest['name']}

        it 'should successfully use the shared link, where its properties are not stored in DB' do
          config_server_helper.put_value(prepend_namespace("fibonacci_placeholder"), 'fibonacci_value')
          deploy_simple_manifest(no_login: true, manifest_hash: first_manifest, include_credentials: false,  env: client_env)

          expect {
            deploy_simple_manifest(no_login: true, manifest_hash: second_manifest, include_credentials: false,  env: client_env)
          }.to_not raise_error

          link_vm = director.vm('second_deployment_node', '0', {:deployment => 'second', :env => client_env, include_credentials: false})
          template = YAML.load(link_vm.read_job_template('http_proxy_with_requires', 'config/config.yml'))
          expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value')
        end

        context 'when provider job has properties with type password and values are generated' do
          let(:provider_job_name) { 'http_endpoint_provider_with_property_types' }

          it 'should successfully use the shared link, where its properties are not stored in DB' do
            deploy_simple_manifest(no_login: true, manifest_hash: first_manifest, include_credentials: false,  env: client_env)

            expect {
              deploy_simple_manifest(no_login: true, manifest_hash: second_manifest, include_credentials: false,  env: client_env)
            }.to_not raise_error

            link_vm = director.vm('second_deployment_node', '0', {:deployment => 'second', :env => client_env, include_credentials: false})
            template = YAML.load(link_vm.read_job_template('http_proxy_with_requires', 'config/config.yml'))
            expect(
              template['links']['properties']['fibonacci']
            ).to eq(config_server_helper.get_value(prepend_namespace('fibonacci_placeholder')))
          end
        end

        context 'when using runtime config' do
          let(:runtime_config) do
            {
              'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
              'addons' => [
                {
                  'name' => 'addon_job',
                  'jobs' => [
                    'name' => 'http_proxy_with_requires',
                    'release' => 'bosh-release',
                    'consumes' => {
                      'proxied_http_endpoint' => {
                        'from' => 'vroom',
                        'deployment' => 'first'
                      }
                    }
                  ]

                }
              ]
            }
          end

          let(:second_deployment_job_spec) do
            job_spec = Bosh::Spec::Deployments.simple_job(
              name: 'second_deployment_node',
              templates: [
                {
                  'name' => 'provider',
                  'release' => 'bosh-release'
                }
              ],
              instances: 1,
              static_ips: ['192.168.1.11']
            )
            job_spec['azs'] = ['z1']
            job_spec
          end

          it 'should successfully use shared link from a previous deployment' do
            config_server_helper.put_value(prepend_namespace("fibonacci_placeholder"), 'fibonacci_value')

            deploy_simple_manifest(no_login: true, manifest_hash: first_manifest, include_credentials: false,  env: client_env)

            expect(upload_runtime_config(runtime_config_hash: runtime_config, include_credentials: false,  env: client_env)).to include('Succeeded')
            deploy_simple_manifest(no_login: true, manifest_hash: second_manifest, include_credentials: false,  env: client_env)

            link_vm = director.vm('second_deployment_node', '0', {:deployment => 'second', :env => client_env, include_credentials: false})

            template = YAML.load(link_vm.read_job_template('http_proxy_with_requires', 'config/config.yml'))
            expect(
              template['links']['properties']['fibonacci']
            ).to eq(config_server_helper.get_value(prepend_namespace('fibonacci_placeholder')))
          end
        end
      end
    end
  end
end
