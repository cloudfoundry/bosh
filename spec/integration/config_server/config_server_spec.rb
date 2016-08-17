require 'spec_helper'

describe 'using director with config server', type: :integration do
  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, :preserve => true)
    bosh_runner.run_in_dir('create release --force', ClientSandbox.links_release_dir, env: client_env)
    bosh_runner.run_in_dir('upload release', ClientSandbox.links_release_dir, env: client_env)
  end

  let (:manifest_hash) { Bosh::Spec::Deployments.simple_manifest }
  let (:cloud_config)  { Bosh::Spec::Deployments.simple_cloud_config }
  let (:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox)}
  let (:client_env) { {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'} }

  context 'when config server certificates are not trusted' do
    with_reset_sandbox_before_each(config_server_enabled: true, with_config_server_trusted_certs: false, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

    before do
      bosh_runner.run("target #{current_sandbox.director_url}", {ca_cert: current_sandbox.certificate_path})
      bosh_runner.run('logout')
    end

    it 'throws certificate validator error' do
      manifest_hash['jobs'].first['properties'] = {'test_property' => '((test_property))'}
      output, exit_code = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash,
                                              cloud_config_hash: cloud_config, failure_expected: true,
                                              return_exit_code: true, env: client_env)

      expect(exit_code).to_not eq(0)
      expect(output).to include('Config Server SSL error')
    end
  end

  context 'when config server certificates are trusted' do
    with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

    before do
      bosh_runner.run("target #{current_sandbox.director_url}", {ca_cert: current_sandbox.certificate_path})
      bosh_runner.run('logout')
    end

    context 'when deployment manifest has placeholders' do
      before do
        manifest_hash['jobs'].first['properties'] = {'test_property' => '((test_property))'}
      end

      it 'raises an error when config server does not have values for placeholders' do
        output, exit_code = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash,
                                                cloud_config_hash: cloud_config, failure_expected: true,
                                                return_exit_code: true, env: client_env)

        expect(exit_code).to_not eq(0)
        expect(output).to include('Failed to find keys in the config server: test_property')
      end

      it 'does not log interpolated properties in the task debug logs and deploy output' do
        config_server_helper.put_value('test_placeholder', 'cats are happy')
        manifest_hash['jobs'].first['properties'] = {'test_property' => '((test_placeholder))'}

        deploy_output = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, env: client_env)
        expect(deploy_output).to_not include('cats are happy')

        debug_output = bosh_runner.run('task last --debug', no_login: true, env: client_env)
        expect(debug_output).to_not include('cats are happy')
      end

      it 'replaces placeholders in the manifest when config server has value for placeholders' do
        config_server_helper.put_value('test_property', 'cats are happy')
        manifest_hash['jobs'].first['properties'] = {'test_property' => '((test_property))'}

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, env: client_env)
        vm = director.vm('foobar', '0', env: client_env)

        template = vm.read_job_template('foobar', 'bin/foobar_ctl')

        expect(template).to include('test_property=cats are happy')
      end

      it 'returns original raw manifest when downloaded through cli' do
        config_server_helper.put_value('smurf_placeholder', 'happy smurf')
        manifest_hash['jobs'].first['properties'] = {'test_property' => '((smurf_placeholder))'}

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, env: client_env)

        downloaded_manifest = bosh_runner.run("download manifest #{manifest_hash['name']}", env: client_env)

        expect(downloaded_manifest).to include '((smurf_placeholder))'
        expect(downloaded_manifest).to_not include 'happy smurf'
      end

      context 'when health monitor is around and resurrector is enabled' do
        before { current_sandbox.health_monitor_process.start }
        after { current_sandbox.health_monitor_process.stop }

        it 'interpolates values correctly when resurrector kicks in' do
          config_server_helper.put_value('test_property', 'cats are happy')

          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, env: client_env)
          vm = director.vm('foobar', '0', env: client_env)

          template = vm.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include('test_property=cats are happy')

          config_server_helper.put_value('test_property', 'smurfs are happy')

          vm.kill_agent
          director.wait_for_vm('foobar', '0', 300, env: client_env)

          new_vm = director.vm('foobar', '0', env: client_env)
          template = new_vm.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include('test_property=smurfs are happy')
        end
      end

      context 'when config server values changes post deployment' do
        it 'updates the job on bosh redeploy' do
          config_server_helper.put_value('test_property', 'cats are happy')

          manifest_hash['jobs'].first['properties'] = {'test_property' => '((test_property))'}
          manifest_hash['jobs'].first['instances'] = 1
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, env: client_env)
          vm = director.vm('foobar', '0', env: client_env)

          template = vm.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include('test_property=cats are happy')

          config_server_helper.put_value('test_property', 'dogs are happy')

          output = bosh_runner.run('deploy', env: client_env)
          expect(scrub_random_ids(output)).to include('Started updating job foobar > foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')

          vm = director.vm('foobar', '0', env: client_env)
          template = vm.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include('test_property=dogs are happy')
        end

        it 'updates the job on start/restart/recreate' do
          config_server_helper.put_value('test_property', 'cats are happy')

          manifest_hash['jobs'].first['properties'] = {'test_property' => '((test_property))'}
          manifest_hash['jobs'].first['instances'] = 1
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, env: client_env)
          vm = director.vm('foobar', '0', env: client_env)

          template = vm.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include('test_property=cats are happy')

          # ============================================
          # Restart
          config_server_helper.put_value('test_property', 'dogs are happy')
          output = bosh_runner.run('restart', env: client_env)
          expect(scrub_random_ids(output)).to include('Started updating job foobar > foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')

          vm = director.vm('foobar', '0', env: client_env)
          template = vm.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include('test_property=dogs are happy')

          # ============================================
          # Recreate
          config_server_helper.put_value('test_property', 'smurfs are happy')
          output = bosh_runner.run('recreate', env: client_env)
          expect(scrub_random_ids(output)).to include('Started updating job foobar > foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')

          vm = director.vm('foobar', '0', env: client_env)
          template = vm.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include('test_property=smurfs are happy')

          # ============================================
          # start
          config_server_helper.put_value('test_property', 'kittens are happy')
          bosh_runner.run('stop', env: client_env)
          output = bosh_runner.run('start', env: client_env)
          expect(scrub_random_ids(output)).to include('Started updating job foobar > foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')

          vm = director.vm('foobar', '0', env: client_env)
          template = vm.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include('test_property=kittens are happy')
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
                'group_name' => 'foobar'
              },
            }
          end

          let(:resolved_env_hash) do
            {
              'env1' => 'lazy smurf',
              'env2' => 'env_value2',
              'env3' => {
                'color' => 'blue'
              },
              'bosh' => {
                'group_name' => 'foobar'
              },
            }
          end

          let(:manifest_hash) do
            manifest_hash = Bosh::Spec::Deployments.simple_manifest
            manifest_hash.delete('resource_pools')
            manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]
            manifest_hash['jobs'] = [{
                                       'name' => 'foobar',
                                       'templates' => ['name' => 'foobar'],
                                       'vm_type' => 'vm-type-name',
                                       'stemcell' => 'default',
                                       'instances' => 1,
                                       'networks' => [{ 'name' => 'a' }],
                                       'properties' => {},
                                       'env' => env_hash
                                     }]
            manifest_hash
          end

          before do
            manifest_hash['jobs'].first.delete('properties')
            config_server_helper.put_value('env1_placeholder', 'lazy smurf')
            config_server_helper.put_value('color_placeholder', 'blue')
          end

          it 'should interpolate them correctly' do
            deploy_from_scratch(no_login: true, cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash, env: client_env)
            create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
            expect(create_vm_invocations.last.inputs['env']).to eq(resolved_env_hash)
            expect(bosh_runner.run('deployments', env: client_env)).to match_output  %(
+--------+----------------------+-------------------+--------------+
| Name   | Release(s)           | Stemcell(s)       | Cloud Config |
+--------+----------------------+-------------------+--------------+
| simple | bosh-release/0+dev.1 | ubuntu-stemcell/1 | latest       |
+--------+----------------------+-------------------+--------------+
    )
          end

          it 'should not log interpolated env values in the debug logs and deploy output' do
            deploy_output = deploy_from_scratch(no_login: true, cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash, env: client_env)
            debug_output = bosh_runner.run('task last --debug', no_login: true, env: client_env)

            expect(deploy_output).to_not include('lazy smurf')
            expect(deploy_output).to_not include('blue')

            expect(debug_output).to_not include('lazy smurf')
            expect(debug_output).to_not include('blue')
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
                'group_name' => 'foobar',
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
                'group_name' => 'foobar',
                'password' => 'foobar'
              },
            }
          end

          it 'should interpolate them correctly' do
            config_server_helper.put_value('env1_placeholder', 'lazy cat')
            config_server_helper.put_value('color_placeholder', 'smurf blue')

            deployment_manifest = Bosh::Spec::Deployments.legacy_manifest
            deployment_manifest['resource_pools'][0]['env'] = env_hash

            deploy_from_scratch(no_login: true, env: client_env, manifest_hash: deployment_manifest)

            create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
            expect(create_vm_invocations.last.inputs['env']).to eq(resolved_env_hash)
            expect(bosh_runner.run('deployments', env: client_env)).to match_output  %(
+--------+----------------------+-------------------+--------------+
| Name   | Release(s)           | Stemcell(s)       | Cloud Config |
+--------+----------------------+-------------------+--------------+
| simple | bosh-release/0+dev.1 | ubuntu-stemcell/1 | none         |
+--------+----------------------+-------------------+--------------+
    )
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
            bosh_runner.run("target #{current_sandbox.director_url}", {ca_cert: current_sandbox.certificate_path})

            config_server_helper.put_value('env1_placeholder', 'lazy smurf')
            config_server_helper.put_value('color_placeholder', 'blue')
          end

          it 'should send the flag to the agent with interpolated values' do
            deploy_from_scratch(no_login: true, manifest_hash: simple_manifest, cloud_config_hash: cloud_config, env: client_env)

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
                                                          'group_name' => 'foobar'
                                                        }
                                                      }
                                                   })
          end

          it 'does not cause a recreate vm on redeploy' do
            deploy_from_scratch(no_login: true, manifest_hash: simple_manifest, cloud_config_hash: cloud_config, env: client_env)

            invocations = current_sandbox.cpi.invocations_for_method('create_vm')
            expect(invocations.size).to eq(3) # 2 compilation vms and 1 for the one in the instance_group

            output = deploy_simple_manifest(no_login: true, manifest_hash: simple_manifest, env: client_env)
            expect(output).to_not include('Started updating job foobar')

            invocations = current_sandbox.cpi.invocations_for_method('create_vm')
            expect(invocations.size).to eq(3) # no vms should have been deleted/created
          end
        end
      end
    end

    context 'when runtime manifest has placeholders' do
      let(:runtime_config) { Bosh::Spec::Deployments.runtime_config_with_addon_placeholders }

      context 'when config server does not have all keys' do
        it 'will throw a valid error when uploading runtime config' do
          output, exit_code = upload_runtime_config(runtime_config_hash: runtime_config, failure_expected: true, return_exit_code: true, env: client_env)
          expect(exit_code).to_not eq(0)
          expect(output).to include('Error 540000: Failed to find keys in the config server: release_name')
        end

        it 'will throw an error when property can not be found at render time' do
          bosh_runner.run("upload release #{spec_asset('dummy2-release.tgz')}", env: client_env)
          config_server_helper.put_value('release_name', 'dummy2')
          upload_runtime_config(runtime_config_hash: runtime_config, env: client_env)
          output, exit_code = deploy_from_scratch(
            no_login: true,
            manifest_hash: manifest_hash,
            cloud_config_hash: cloud_config,
            failure_expected: true,
            return_exit_code: true,
            env: client_env
          )
          expect(exit_code).to_not eq(0)
          expect(output).to include('Failed to find keys in the config server: addon_prop')
        end
      end

      context 'when config server has all keys' do
        before do
          bosh_runner.run("upload release #{spec_asset('dummy2-release.tgz')}", env: client_env)

          config_server_helper.put_value('release_name', 'dummy2')
          config_server_helper.put_value('addon_prop', 'i am Groot')

          expect(upload_runtime_config(runtime_config_hash: runtime_config, env: client_env)).to include("Successfully updated runtime config")
        end

        it 'replaces placeholders in the addons and updates jobs on redeploy when config server values change' do
          deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, env: client_env)

          vm = director.vm('foobar', '0', env: client_env)
          template = vm.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
          expect(template).to include("echo 'i am Groot'")

          # change value in config server and redeploy
          config_server_helper.put_value('addon_prop', 'smurfs are blue')

          redeploy_output = bosh_runner.run('deploy', env: client_env)

          scrubbed_redeploy_output = scrub_random_ids(redeploy_output)

          expect(scrubbed_redeploy_output).to include('Started updating job foobar > foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
          expect(scrubbed_redeploy_output).to include('Started updating job foobar > foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (1)')
          expect(scrubbed_redeploy_output).to include('Started updating job foobar > foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (2)')

          vm = director.vm('foobar', '0', env: client_env)
          template = vm.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
          expect(template).to include('smurfs are blue')
        end
      end
    end

    context 'when running an errand that has placeholders' do
      let(:errand_manifest){ Bosh::Spec::Deployments.manifest_errand_with_placeholders }

      it 'replaces placeholder in properties' do
        config_server_helper.put_value('placeholder', 'test value')
        deploy_from_scratch(no_login: true, manifest_hash: errand_manifest,
                            cloud_config_hash: cloud_config, env: client_env)
        errand_result = bosh_runner.run('run errand fake-errand-name --keep-alive', env: client_env)

        expect(errand_result).to include('test value')
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

      let(:my_job) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'my_job',
            templates: [
                {'name' => 'http_server_with_provides'},
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
        manifest['jobs'] = [my_job]
        manifest['properties'] = {'listen_port' => 9999}
        manifest
      end

      before do
        upload_links_release
        upload_stemcell(env: client_env)

        upload_cloud_config(cloud_config_hash: cloud_config, env: client_env)
      end

      it 'replaces the placeholder values of properties consumed through links' do
        config_server_helper.put_value('fibonacci_placeholder', 'fibonacci_value')
        deploy_simple_manifest(manifest_hash: manifest, env: client_env)

        link_vm = director.vm('my_job', '0', env: client_env)
        template = YAML.load(link_vm.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value')
      end

      it 'does not log interpolated properties in deploy output and debug logs' do
        config_server_helper.put_value('fibonacci_placeholder', 'fibonacci_value')
        deploy_output = deploy_simple_manifest(manifest_hash: manifest, env: client_env)
        debug_output = bosh_runner.run('task last --debug', no_login: true, env: client_env)

        expect(deploy_output).to_not include('fibonacci_value')
        expect(debug_output).to_not include('fibonacci_value')
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

        before do
          config_server_helper.put_value('a_placeholder', 'a_value')
          config_server_helper.put_value('b_placeholder', 'b_value')
          config_server_helper.put_value('c_placeholder', 'c_value')

          manifest['jobs'] = [job_with_manual_consumes_link]
        end

        it 'resolves the properties defined inside the links section of the deployment manifest' do
          deploy_simple_manifest(manifest_hash: manifest, env: client_env)

          link_vm = director.vm('property_job', '0', env: client_env)

          template = YAML.load(link_vm.read_job_template('consumer', 'config.yml'))

          expect(template['a']).to eq('a_value')
          expect(template['b']).to eq('b_value')
          expect(template['c']).to eq('c_value')
        end

        it 'does not log interpolated properties in deploy output and debug logs' do
          deploy_output = deploy_simple_manifest(manifest_hash: manifest, env: client_env)
          debug_output = bosh_runner.run('task last --debug', no_login: true, env: client_env)

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
                      'name' => 'http_server_with_provides',
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

        it 'should successfully use the shared link, where its properties are not stored in DB' do
          config_server_helper.put_value('fibonacci_placeholder', 'fibonacci_value')
          deploy_simple_manifest(no_login: true, manifest_hash: first_manifest, env: client_env)

          expect {
            deploy_simple_manifest(no_login: true, manifest_hash: second_manifest, env: client_env)
          }.to_not raise_error

          link_vm = director.vm('second_deployment_node', '0', {:deployment => 'second', :env => client_env})
          template = YAML.load(link_vm.read_job_template('http_proxy_with_requires', 'config/config.yml'))
          expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value')
        end
      end
    end


  end
end
